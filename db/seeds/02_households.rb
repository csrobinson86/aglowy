# Two households, with Sam an adult in both so the switcher has something to switch. Each has its time zone and
# meeting times, the Riveras have the meeting helper on, and the Demo Family has an invitation that's never delivered.
head, spouse, maria = seeded_person("head@example.com"), seeded_person("spouse@example.com"), seeded_person("rivera@example.com")

def seed_household(name:, head:, time_zone:, midweek:, weekend:)
  household = head.households.find_by(name: name) || Household.create_with_head(household: { name: name }, head: head)
  household.update_settings(name: name, time_zone: time_zone) || raise(ActiveRecord::RecordInvalid, household)

  unless household.meeting_times_set?
    household.change_meeting_times(midweek_wday: midweek.first, midweek_time: midweek.last,
                                   weekend_wday: weekend.first, weekend_time: weekend.last) || raise(ActiveRecord::RecordInvalid, household)
  end

  household
end

def seed_member(household, name:, role:)
  household.users.find_by(name: name) || household.add_member(name: name, role: role).user
end

demo = seed_household(name: "The Demo Family", head: head, time_zone: "Eastern Time (US & Canada)", midweek: [ 3, "19:00" ], weekend: [ 0, "10:00" ])
demo.memberships.find_or_create_by!(user: spouse) { it.role = :adult }
seed_member(demo, name: "Charlie Demo", role: :child)
demo.invitations.find_by(email: "grandma@example.com") || demo.invitations.create!(email: "grandma@example.com", invited_by: head)

rivera = seed_household(name: "The Rivera Family", head: maria, time_zone: "Pacific Time (US & Canada)", midweek: [ 4, "19:30" ], weekend: [ 6, "16:00" ])
rivera.memberships.find_or_create_by!(user: spouse) { it.role = :adult }
seed_member(rivera, name: "Mateo Rivera", role: :child)
rivera.enable_meeting_helper(by: maria)
rivera.enable_meeting_prep(by: maria)

# A child's username login (docs/design/invitations.md, Child logins). give_login picks a password nobody knows;
# the sample one replaces it, as the child would through a password link.
lucia = seed_member(rivera, name: "Lucia Rivera", role: :child)
lucia.identity || seeded!(lucia.give_login(username: "lucia.rivera")).update!(password: seed_password)
seeded!(rivera.memberships.find_by!(user: lucia).grant_study_ai(by: maria))
