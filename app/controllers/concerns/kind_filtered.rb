# A meeting notes list on the Meeting notes tab that takes ?kind=midweek or ?kind=weekend (docs/design/notes.md, The
# Meeting notes tab). Any other kind is ignored.
module KindFiltered
  extend ActiveSupport::Concern

  included do
    before_action :set_kind, only: :index
  end

  private

  def set_kind
    @kind = params[:kind].presence_in(MeetingNote.kinds.keys)
  end

  def of_kind(notes)
    @kind ? notes.where(kind: @kind) : notes
  end
end
