# One day's brief for a person, made from a copy of their plan (docs/design/daily-brief.md, DailyBrief). It reads its
# own copy, never the live plan, so editing the plan can't change or break a brief already made (Trap 7). One a day per
# person, by a unique index.
class DailyBrief < ApplicationRecord
  belongs_to :user

  # The sections, the focus areas and that weekday's row, as they were when the brief was made.
  encrypts :plan

  # Today's brief (or the day's), found or made under the person's lock: the one Plan#pause takes, so none is made once
  # the plan is paused, though one already made is still found. With pause_if_unseen (the morning job only), a day with
  # no brief after seven unseen in a row pauses the plan instead, in the same lock, so a brief already made today is
  # never a reason to pause. Nil when there's nothing to do: no plan, paused, or paused just now (The morning job).
  def self.for(user, on: user.today, pause_if_unseen: false)
    user.with_lock do
      plan = user.daily_brief_plan or next
      brief = user.daily_briefs.find_by(on:)

      if brief || plan.paused?
        brief
      elsif pause_if_unseen && plan.gone_unseen?(on)
        plan.pause(reason: "unseen")
        nil
      else
        user.daily_briefs.create!(on:, plan: plan.copy_for(on))
      end
    end
  end

  def sections
    plan.fetch("sections")
  end

  def section?(name)
    name.to_s.in?(sections)
  end

  # The copy's focus areas and day, as unsaved records, so they read as the plan's do: a topic by its focus area, its
  # scriptures as references.
  def focus_areas
    @focus_areas ||= plan.fetch("focus_areas").map { copied(DailyBrief::FocusArea, it) }
  end

  def day
    @day ||= copied(DailyBrief::Day, plan.fetch("day"))
  end

  def topic_for(focus_area)
    day.topic_for(focus_area)
  end

  def quality_area
    focus_areas.find(&:quality?)
  end

  def appreciation_area
    focus_areas.find(&:appreciation?)
  end

  # "Your focus today": one row each, in the plan's order.
  def role_areas
    focus_areas.select(&:role?)
  end

  # Where the day's reading starts: the chapter it names, "Matthew 5" for "Matthew 5 to John" or "Matthew 5:3–12", or the
  # first chapter of its first book, "Matthew 1" for "Matthew – John". Nil when the box is empty or doesn't start with a book.
  def reading_start
    first = day.reading.to_s.split(/[–—,-]| to /i).first.to_s.sub(/:.*\z/, "")
    Bible::Reference.parse(first) || Bible::Reference.parse("#{first} 1")
  end

  # The day's text on wol.jw.org, in English. Aglowy links to it and never fetches it.
  def daily_text_url
    "https://wol.jw.org/en/wol/dt/r1/lp-e/#{on.year}/#{on.month}/#{on.day}"
  end

  # The first time the person saw it, on its page: the one fact the pause rule reads (Trap 5). Set once, under the brief's
  # lock, so two pages opened at once keep the first time.
  def mark_seen
    return if seen_at

    with_lock { update!(seen_at: Time.current) unless seen_at }
  end

  private
    # Only the columns the record still has, so a brief kept from before a column changed still reads.
    def copied(model, attributes)
      model.new(attributes.slice(*model.attribute_names)).tap(&:readonly!)
    end
end
