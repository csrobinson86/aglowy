# The moderation check that runs on the person's text before the AI sees it (docs/design/ai.md, safety measure 2).
class Ai::Moderation
  def self.flagged?(text)
    RubyLLM.moderate(text).flagged?
  end
end
