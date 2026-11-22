# frozen_string_literal: true

# What a phone shows about one step in its panel, a Primer Dialog that opens from the row's "›" (docs/design/phone.md,
# A goal, The step panel; frame phone-family-goal-step.png): who it's for and when it's due, who's done it, Schedule as
# a family study, and Edit step and Remove step. It takes the row's arguments and offers only what they allow, so a
# child's panel has at most their own tick box and a read-only goal's has no controls at all.
# Its root is replaced by a morphing Turbo Stream after a tick or a refused edit, so the Dialog stays open and the
# focused control keeps its focus.
class GoalStepPanelComponent < GoalStepComponent
  def body_id
    dom_id(step, :panel_body)
  end

  # "For Eli and Sofia · Due Feb 28", "Everyone · Done Dec 12". A personal goal's steps name no one: "Due Dec 18".
  def panel_meta_text
    [ (for_whom if goal.family?), panel_status ].compact.join(" · ")
  end

  # Named people each have their own part (docs/design/goals.md, Who can do what).
  def named?
    !everyone?
  end

  def panel_tickable?(person)
    ticking? && tickable?(person.id)
  end

  def check_box_name(person)
    "#{dom_id(step, :panel)}_#{person.id}"
  end

  def person_label(person)
    safe_join([ render(AvatarComponent.new(user: person, classes: "mr-2")), person.first_name ])
  end

  # "Sofia · not done yet", for someone the viewer may not tick, or anyone on a goal taking no ticks.
  def person_status(person)
    "#{person.first_name} · #{step.done_for?(person) ? "done" : "not done yet"}"
  end

  private
    def for_whom
      everyone? ? "Everyone" : "For #{first_names(people)}"
    end

    def panel_status
      if done?
        "Done #{short_date(step.completions.map(&:created_at).max)}"
      elsif step.due_on
        "Due #{step.due_on.strftime("%b %-d")}"
      end
    end
end
