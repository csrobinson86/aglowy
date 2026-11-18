# A paused daily brief: while there is one, nothing is written and no request is sent (docs/design/daily-brief.md,
# DailyBrief::Pause). Made by Plan#pause, by the person's choice or after seven briefs in a row they never saw; Plan#resume
# deletes it. One per plan, by a unique index.
class DailyBrief::Pause < ApplicationRecord
  belongs_to :plan, inverse_of: :pausing

  # Keep in step with daily_brief_pauses_reason_check.
  enum :reason, %w[ chosen unseen ].index_by(&:itself), validate: true
end
