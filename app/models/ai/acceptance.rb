# Someone turning on AI drafts, at one version of the terms (docs/design/ai.md, First use). It belongs to the person,
# so it follows them across households. Raising config.x.ai.terms_version asks everyone again.
class Ai::Acceptance < ApplicationRecord
  belongs_to :user

  # "I understand how AI drafts work". Primer's required: marks the box but doesn't add the HTML attribute, so the
  # tick is checked here. allow_nil: false, so a request without the box at all is refused too.
  validates :understood, acceptance: { allow_nil: false, message: "Tick “I understand how AI drafts work” to turn on AI drafts" }
end
