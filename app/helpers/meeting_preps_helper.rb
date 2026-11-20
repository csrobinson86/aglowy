module MeetingPrepsHelper
  # Jehovah's qualities' own decorative icons (PrepWeek::Card::QUALITIES), inline so they take the text colour. Each file
  # carries aria-hidden.
  MEETING_PREP_ICONS = Rails.root.glob("app/assets/images/meeting_prep/*.svg").to_h { [ it.basename(".svg").to_s, it.read.html_safe ] }.freeze
  # Get ready's tiles (frame tablet-prep-week.png): the helper's ear for the midweek meeting, Primer's calendar for the
  # weekend.
  def meeting_prep_tile_icon(kind)
    return meeting_helper_icon(icon: "ear", color: :accent, size: :medium) if kind == "midweek"

    tag.span(render(Primer::Beta::Octicon.new(:calendar)), class: "meeting-helper__icon meeting-helper__icon--medium meeting-helper__icon--attention")
  end

  # The card's quality icon on the attention colour (docs/design/meeting-prep.md, Jehovah's qualities).
  def meeting_prep_quality_icon(card)
    tag.span(MEETING_PREP_ICONS.fetch(card.quality_icon), class: "meeting-prep__box-icon meeting-prep__box-icon--attention")
  end

  # "I can…" has the listening game's action rays, on the success colour.
  def meeting_prep_i_can_icon
    tag.span(MeetingNotesHelper::MEETING_HELPER_ICONS.fetch("rays"), class: "meeting-prep__box-icon meeting-prep__box-icon--success")
  end
end
