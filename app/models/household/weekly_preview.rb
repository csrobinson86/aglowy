# A household's coming Monday to Sunday as the weekly preview says it: "2 meetings · family study Tuesday · Circuit
# overseer's visit from Tuesday" (docs/design/notifications.md, The kinds). Built from Household::Calendar with
# everyone's personal times left out, so it reads no one's times and needs no viewer.
class Household::WeeklyPreview
  include ActionView::Helpers::TextHelper

  attr_reader :household, :week_of

  def initialize(household, week_of:)
    @household = household
    @week_of = week_of
  end

  def empty?
    items.empty?
  end

  # The meetings counted, then the family studies, then each event once, with the days it falls on in order. One over
  # several days stays on its own, so two of them with the same title are both named.
  def summary
    meetings, others = items.partition(&:meeting?)
    studies, events = others.partition { it.kind == "study" }
    named = (studies + events).group_by { [ it.title, (it.dates if it.dates.count > 1) ] }.map { |_, same| describe(same) }
    [ (pluralize(meetings.size, "meeting") if meetings.any?), *named ].compact.join(" · ")
  end

  # Each day of the week that has something on it, with what's on it in order, for the email's list.
  def days_with_items
    days.map { |date| [ date, items.select { it.on?(date) } ] }.reject { |_, on| on.empty? }
  end

  def days
    week_of..(week_of + 6)
  end

  private
    def items
      @items ||= Household::Calendar.new(household, viewer: nil, range: days, hide: %w[ my_times shared_times ]).items
    end

    # "family study Tuesday and Thursday", "Field service Saturday", or for one over several days "… from Tuesday", or
    # "… until Wednesday" when it began the week before.
    def describe(items)
      item = items.first
      name = item.kind == "study" ? "family study" : item.title

      if item.dates.count > 1
        item.dates.first < week_of ? "#{name} until #{weekday([ item.dates.last, days.last ].min)}" : "#{name} from #{weekday(item.dates.first)}"
      else
        "#{name} #{items.map { weekday(it.starts_at) }.to_sentence}"
      end
    end

    def weekday(date)
      date.strftime("%A")
    end
end
