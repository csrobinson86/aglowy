module FamilyStudiesHelper
  # "7:00 – 7:45 PM", or "11:30 AM – 12:15 PM" when the session crosses noon.
  def session_time_range(study_session)
    starts, ends = study_session.local_scheduled_at, study_session.local_ends_at
    starts_format = starts.strftime("%p") == ends.strftime("%p") ? :clock : :clock_with_meridiem

    "#{l(starts, format: starts_format)} – #{l(ends, format: :clock_with_meridiem)}"
  end
end
