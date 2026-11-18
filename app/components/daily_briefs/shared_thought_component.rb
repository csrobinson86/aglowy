# frozen_string_literal: true

# "Today's thought" on Home, as another member sees a brief shared with the household (docs/design/daily-brief.md, For
# the children, and sharing; Trap 8; frame brief-family.png): the thread, the reading as a link and the children's box,
# with who shared it. It reads only those three things from the newest written writing; nothing else in the brief is
# ever shown to anyone else. Every field is escaped, and the reading's link is made by Bible::Reference.
class DailyBriefs::SharedThoughtComponent < ApplicationComponent
  with_collection_parameter :brief

  attr_reader :brief, :household

  def initialize(brief:, household:)
    @brief, @household, @writing = brief, household, brief.writing
  end

  def thread
    @writing.section(:thread)
  end

  def reading
    Bible::Reference.parse(@writing.section(:reading)&.dig("passage"))
  end

  # Nil when the checks left both of its fields empty.
  def children
    @writing.section(:children)&.compact_blank.presence
  end

  def sharer
    brief.user.name
  end
end
