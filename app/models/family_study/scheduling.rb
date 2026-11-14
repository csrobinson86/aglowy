# The Schedule a study form: friendly Date, Starts, Ends and Repeat values, saved as a
# FamilyStudy with starts_on, time_of_day and duration_minutes (docs/design/family-studies.md).
class FamilyStudy::Scheduling
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :household, :study

  attribute :topic, :string
  attribute :notes, :string
  attribute :starts_on, :date
  attribute :starts_at, :time
  attribute :ends_at, :time
  attribute :repeat, :string, default: "once"
  attribute :link_urls, default: -> { [] }
  attribute :link_url, :string
  attribute :files, default: -> { [] }

  validates :starts_on, :starts_at, :ends_at, presence: true
  validates :repeat, inclusion: { in: ->(scheduling) { scheduling.repeat_choices.map(&:last) } }
  validate :starts_on_not_in_the_past, :ends_after_starts, :links_are_web_links, :files_are_allowed

  def initialize(household:, **attributes)
    @household = household
    # Today unless the form sent a date, even a blank one.
    super(starts_on: today, **attributes)
  end

  # Scheduling rule 5: what the date offers, as [label, value] for the Repeat select.
  def repeat_choices
    [ [ "Does not repeat", "once" ], [ "Daily", "daily" ] ].tap do |choices|
      next unless starts_on

      choices << [ "Weekly on #{weekday}", "weekly" ]
      choices << [ "Monthly on the #{FamilyStudy::ORDINALS[week_of_month - 1]} #{weekday}", "monthly" ]
      choices << [ "Monthly on the last #{weekday}", "monthly_last" ] if calendar.last_week_of_month?(starts_on)
    end
  end

  # The links added to the list, then one still in the field, so nothing typed is lost.
  def links
    [ *link_urls, link_url ].compact_blank
  end

  # The files the drop zone uploaded, as signed blob ids. One that can't be found is dropped.
  def file_blobs
    @file_blobs ||= files.uniq.filter_map { ActiveStorage::Blob.find_signed(it) }
  end

  # The study, its first session with the topic, notes, links and files, then the later sessions (scheduling rule 1).
  def save
    return false unless valid?

    @study = household.schedule_family_study(topic: topic.presence, notes: notes.presence, links: links, files: file_blobs, **study_attributes)
    study.persisted?
  end

  private
    def study_attributes
      { starts_on: starts_on, time_of_day: starts_at.strftime("%H:%M"), duration_minutes: duration_minutes, **repetition }
    end

    def repetition
      case repeat
      when "monthly"      then { frequency: "monthly", week_of_month: week_of_month }
      when "monthly_last" then { frequency: "monthly", week_of_month: -1 }
      else { frequency: repeat }
      end
    end

    def duration_minutes
      ((ends_at - starts_at) / 60).floor
    end

    def weekday
      starts_on.strftime("%A")
    end

    def week_of_month
      calendar.week_of_month_for(starts_on)
    end

    # The week-of-month rules live on FamilyStudy, so the form and the schedule can't disagree.
    def calendar
      @calendar ||= FamilyStudy.new
    end

    def today
      Time.current.in_time_zone(household.time_zone).to_date
    end

    def starts_on_not_in_the_past
      errors.add(:starts_on, "can't be in the past") if starts_on && starts_on < today
    end

    # Shown on the "Add a link" field. A refused link from the list goes back into the field,
    # since the list has no way to edit or remove one; a valid link in the field moves to the list.
    def links_are_web_links
      refused = links.reject { FamilyStudy::Resource.new(url: it).web_link? }
      return if refused.empty?

      errors.add(:link_url, FamilyStudy::Resource::NOT_A_WEB_LINK)
      self.link_urls = links - refused
      self.link_url = refused.join(" ")
    end

    # Judged on the bytes, as the resource will judge them once attached. A refused file leaves the
    # list, so the form keeps only the good ones; the error goes by the drop zone.
    def files_are_allowed
      @file_blobs = file_blobs.select do |blob|
        blob.identify_without_saving
        problem = FamilyStudy::Resource::FileCheck.new(content_type: blob.content_type, byte_size: blob.byte_size).problem
        errors.add(:files, "#{blob.filename} #{problem}") if problem
        problem.nil?
      end
    end

    # Both times are on the same day, so an end after midnight looks like one before the start.
    # Judged in whole minutes, the unit the study stores.
    def ends_after_starts
      if starts_at && ends_at && duration_minutes < 1
        errors.add(:ends_at, "must be after Starts. Studies that end after midnight aren't supported.")
      end
    end
end
