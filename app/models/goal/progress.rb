# How far a goal has got, computed from its steps, never stored (docs/design/goals.md, Progress).
# Built from Goal.preloaded, it answers from loaded records without a query.
class Goal::Progress
  # One person's share of the goal: every Everyone step plus the steps naming them ("Eli · 4 of 6").
  Person = Data.define(:user, :done_count, :steps_count) do
    def name = user.name
  end

  attr_reader :goal

  def initialize(goal)
    @goal = goal
  end

  def steps_count
    steps.size
  end

  def done_count
    steps.count(&:done?)
  end

  def remaining_count
    steps_count - done_count
  end

  # Rounded down, so it never says 100% while a step is left.
  def percent
    steps_count.zero? ? 0 : done_count * 100 / steps_count
  end

  def all_done?
    steps.any? && remaining_count.zero?
  end

  # The first undone step by position; its due_on is the "next due" date, when it has one.
  def next_step
    steps.find { !it.done? }
  end

  # The earliest due date among the steps still to do ("next due Feb 15"), or nil when none has one.
  def next_due_on
    steps.reject(&:done?).filter_map(&:due_on).min
  end

  # Each active member of the household, in membership order. A personal goal has no household, so no one.
  def people
    return [] if goal.personal?

    goal.household.active_memberships.map do |membership|
      theirs = steps.select { it.for?(membership.user) }
      Person.new(user: membership.user, done_count: theirs.count { it.done_for?(membership.user) }, steps_count: theirs.size)
    end
  end

  private
    def steps
      @steps ||= goal.steps.to_a
    end
end
