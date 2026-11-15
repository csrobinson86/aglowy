# A personal goal shared, read-only, with one household. Only created through Goal#share_with.
# A family goal already belongs to its household, so it has none (docs/design/goals.md, Goal::Sharing).
class Goal::Sharing < ApplicationRecord
  belongs_to :goal
  belongs_to :household

  validate { errors.add(:goal, "must be a personal goal") if goal&.family? }
end
