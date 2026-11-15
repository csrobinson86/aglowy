# The meeting helper's end screen: what the child did on each step, and "Show my family"
# (docs/design/meeting-helper.md, Pages, The end; frame tablet-done.png).
class MeetingNotes::SummariesController < ApplicationController
  include MeetingHelperScoped

  def show
    @steps = @meeting_note.helper_steps
  end
end
