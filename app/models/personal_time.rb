# A time a person sets aside on some weekdays: Bible reading, personal study, meeting prep (docs/design/calendar.md,
# PersonalTime). Personal: it belongs to the person and follows them between households. Its time of day is in the
# person's own zone, users.time_zone, which saving the first one settles. Occurrences are worked out for the range asked
# for, never stored (Trap 6).
class PersonalTime < ApplicationRecord
  KINDS = { "bible_reading" => "Bible reading", "personal_study" => "Personal study", "meeting_prep" => "Meeting prep", "other" => "Other" }.freeze
  # What choosing a kind puts in Title while Title hasn't been edited.
  DEFAULT_TITLES = { "bible_reading" => "Daily Bible reading", "personal_study" => "Personal study", "meeting_prep" => "Meeting prep", "other" => "" }.freeze
  # The kinds that can open one of the person's studies or notes. Meeting prep opens that week's note, which isn't stored.
  OPENING_KINDS = %w[ personal_study other ].freeze
  OPENS_TYPES = %w[ PersonalStudy PersonalNote ].freeze
  DURATIONS = { 15 => "15 minutes", 30 => "30 minutes", 45 => "45 minutes", 60 => "1 hour", 90 => "1½ hours", 120 => "2 hours" }.freeze
  MAX_PER_PERSON = 30

  belongs_to :user
  belongs_to :opens, polymorphic: true, optional: true
  # The database deletes them with the time (on_delete: :cascade).
  has_many :completions, class_name: "PersonalTime::Completion"

  enum :kind, KINDS.keys.index_by(&:itself), validate: true

  encrypts :title

  # Wall-clock time in the person's zone, so never shifted by the process zone (family-studies gotcha 14).
  self.skip_time_zone_conversion_for_attributes = %i[ time_of_day ]

  # The zone the dialog showed, sent back so a zone changed meanwhile is caught rather than saved under.
  attribute :zone_shown, :string

  normalizes :title, with: -> { it.squish }
  # The check boxes send strings, and an empty one so that none ticked still clears them.
  normalizes :wdays, with: -> { it.compact_blank.map(&:to_i).uniq.sort }

  validates :title, presence: true, length: { maximum: 80 }
  validates :wdays, presence: { message: "need at least one day" }
  validate -> { errors.add(:wdays, "must be days of the week") unless wdays.to_a.all?(0..6) }
  validates :time_of_day, presence: true
  validates :duration_minutes, numericality: { only_integer: true, in: 5..240 }
  validates :opens_type, inclusion: { in: OPENS_TYPES }, allow_nil: true
  validate :opens_own, if: -> { opens_type.in?(OPENS_TYPES) }
  validate :at_most_per_person, on: :create

  # Every occurrence of these times starting inside the range of instants, in order, each knowing whether it's done.
  # One query for the times and one for their done marks, two days either side, as zones can be over a day apart.
  def self.occurring_between(range)
    times = all.to_a
    done = PersonalTime::Completion.where(personal_time: times, on: (range.begin - 2.days).to_date..(range.end + 2.days).to_date)
                                   .pluck(:personal_time_id, :on).to_set
    times.flat_map { it.occurrences_between(range, done:) }.sort_by(&:starts_at)
  end

  # Expanded over the person's own dates that cover the range's first and last instants, keeping each occurrence whose
  # start falls inside it: a 12:30 AM Monday time in Tokyo is Sunday afternoon in Los Angeles (How a calendar is put
  # together). done holds [id, date] pairs.
  def occurrences_between(range, done: Set.new)
    zone = self.zone
    (range.begin.in_time_zone(zone).to_date..range.end.in_time_zone(zone).to_date).filter_map do |date|
      next unless falls_on?(date)

      occurrence = occurrence_on(date, done: done.include?([ id, date ]))
      occurrence if range.cover?(occurrence.starts_at)
    end
  end

  # Built with zone.local from the person's date, never by adding days to a UTC time, so 6:30 AM stays 6:30 AM across a
  # daylight saving change (Trap 1).
  def occurrence_on(date, done: completions.exists?(on: date))
    starts_at = zone.local(date.year, date.month, date.day, time_of_day.hour, time_of_day.min)
    PersonalTime::Occurrence.new(personal_time: self, on: date, starts_at:, done:)
  end

  def falls_on?(date)
    wdays.include?(date.wday) && date >= starts_on
  end

  def zone
    ActiveSupport::TimeZone[user.calendar_time_zone]
  end

  def today
    Time.current.in_time_zone(zone).to_date
  end

  # Saves the dialog's fields. Under the person's lock, a zone changed elsewhere since the dialog showed it is refused
  # with the new one to show; otherwise the first time settles the person's zone, in the same transaction
  # (docs/design/calendar.md, The person's own zone). Only study and other times keep what they open.
  def plan(attributes, household:)
    assign_attributes(attributes)
    self.opens = nil unless kind.in?(OPENING_KINDS)
    return false unless valid?

    user.with_lock do
      next false unless zone_still_shown?(household)

      user.settle_time_zone(household)
      self.starts_on ||= today
      save!
    end
  end

  # The meeting this time prepares for on a date: the next one after it that week, as a Household::Meeting (kind and
  # week_of, for the meeting note), or nil. Nothing is stored for it.
  def meeting_note_for(date, household:)
    starts_at = occurrence_on(date, done: false).starts_at
    monday = date.beginning_of_week(:monday)
    household.meetings_between(monday..monday + 6).find { it.starts_at > starts_at }
  end

  def complete(on:)
    completions.create_or_find_by!(on:)
  end

  def uncomplete(on:)
    completions.where(on:).delete_all
  end

  # The opens select's value, "PersonalStudy/<id>", so one field can name a study or a note. Blank opens nothing.
  def opens_key
    "#{opens_type}/#{opens_id}" if opens_id
  end

  def opens_key=(key)
    self.opens_type, self.opens_id = key.presence&.split("/", 2)
  end

  private
    # Read through the person, so another person's study or note is never loaded as this one's.
    def opens_own
      owned = opens_type == "PersonalStudy" ? user.personal_studies : user.personal_notes
      errors.add(:opens_key, "must be one of your own studies or notes") unless owned.exists?(opens_id)
    end

    def at_most_per_person
      errors.add(:base, "You can have at most #{MAX_PER_PERSON} times") if user && user.personal_times.count >= MAX_PER_PERSON
    end

    def zone_still_shown?(household)
      zone = user.time_zone || household.time_zone
      return true if zone_shown.blank? || zone_shown == zone

      self.zone_shown = zone
      name = zone.sub(/ \(.*\)\z/, "")
      errors.add(:base, "Your times are now in #{name}. Save again to #{new_record? ? "add" : "save"} this time in #{name}.")
      false
    end
end
