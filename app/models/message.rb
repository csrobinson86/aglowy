# A message in a Chat. Prompts and replies are private family text, so content is encrypted like notes
# (docs/design/ai.md, Conversations).
class Message < ApplicationRecord
  acts_as_message

  encrypts :content
end
