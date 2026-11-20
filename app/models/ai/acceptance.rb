# Someone turning on AI drafts, at one version of the terms (docs/design/ai.md, First use). It belongs to the person,
# so it follows them across households. Raising config.x.ai.terms_version asks everyone again.
class Ai::Acceptance < ApplicationRecord
  belongs_to :user

  # Each household where they're an active head or adult, with the helper on and no game this week, can have its
  # listening game now, and each with Get ready on its week's cards. Once committed, so the job's worker sees the
  # acceptance (docs/design/listening-game.md, When it runs; docs/design/meeting-prep.md, The weekly AI job).
  after_create_commit do
    households = Household.where(id: user.memberships.active.where(role: %w[ head adult ]).select(:household_id))
      .includes(:meeting_helper, :meeting_prep)
    households.select(&:listening_game_due?).each(&:prepare_listening_game_later)
    households.select(&:meeting_prep?).each(&:prepare_meeting_prep_later)
  end

  # "I understand how AI drafts work". Primer's required: marks the box but doesn't add the HTML attribute, so the
  # tick is checked here. allow_nil: false, so a request without the box at all is refused too.
  validates :understood, acceptance: { allow_nil: false, message: "Tick “I understand how AI drafts work” to turn on AI drafts" }
end
