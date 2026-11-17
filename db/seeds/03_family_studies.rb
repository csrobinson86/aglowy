# In each household: a weekly study whose first session was last week, with its topic, notes and two links, and a
# one-off study later this month. No AI drafts. The links only point at jw.org and wol.jw.org; nothing fetches them.
def seed_family_studies(household, conductor:, weekly:, once:)
  today = household.today

  unless household.family_study_sessions.exists?(topic: weekly)
    notes = Bible::Linker.new(ActionText::Content.new(<<~HTML)).link.to_html
      <p>We read Phil 4:11-13 and talked about what Paul learned in prison.</p>
      <p>Next time: everyone brings one thing they're thankful for. See also 1 Tim 6:6-8.</p>
    HTML
    # Started six days ago, so its next session is tomorrow and today never has one that's already over.
    study = seeded!(household.schedule_family_study(starts_on: today - 6, time_of_day: "19:00", duration_minutes: 45,
      frequency: :weekly, default_conductor: conductor, topic: weekly, notes: notes))
    session = study.first_session
    session.resources.create!(url: "https://www.jw.org/en/library/bible/", title: "[Sample article] The Bible online")
    session.resources.create!(url: "https://wol.jw.org/en/wol/h/r1/lp-e", title: "[Sample article] Today's daily text")
  end

  unless household.family_study_sessions.exists?(topic: once)
    # Tomorrow on the last day of a month, which has no later day.
    later = today == today.end_of_month ? today + 1 : [ today + 9, today.end_of_month ].min
    seeded!(household.schedule_family_study(starts_on: later, time_of_day: "20:00",
      duration_minutes: 30, default_conductor: conductor, topic: once))
  end
end

seed_family_studies(seeded_household("The Demo Family", head: "head@example.com"), conductor: seeded_person("head@example.com"),
  weekly: "Being content with what we have", once: "Getting ready for the convention")
seed_family_studies(seeded_household("The Rivera Family", head: "rivera@example.com"), conductor: seeded_person("rivera@example.com"),
  weekly: "Courage like Esther's", once: "Getting ready for the circuit assembly")
