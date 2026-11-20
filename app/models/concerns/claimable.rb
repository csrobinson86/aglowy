# The claim that a run is asking the AI for a household's week (docs/design/listening-game.md, When it runs; the same
# for Get ready, docs/design/meeting-prep.md, The weekly AI job). Taken and checked only inside household.with_lock; the
# run keeps the token it set, and saves only while the claim still holds it.
module Claimable
  extend ActiveSupport::Concern

  # A run's request times out after 5 minutes, so a claim this old belongs to a run that died.
  HELD_FOR = 15.minutes

  # This run's claim with a fresh token, or nil while another run's is held.
  def take
    return if held?

    update!(token: SecureRandom.uuid, created_at: Time.current)
    self
  end

  # Lets the claim go if it's still this run's: true when it was.
  def release
    self.class.where(id:, token:).delete_all == 1
  end

  private
    def held?
      created_at&.after?(HELD_FOR.ago)
    end
end
