# Development data only, safe to run again: each record is looked up before it's created.
# Every login's password is "password123".
return unless Rails.env.development?

def seed_person(name:, email:, staff: false)
  Identity.find_by(email: email)&.user ||
    User.create!(name: name).tap do |user|
      user.create_identity!(email: email, password: "password123", confirmed_at: Time.current, staff: staff)
    end
end

ActiveRecord::Base.transaction do
  seed_person(name: "Stella Staff", email: "staff@example.com", staff: true)

  head = seed_person(name: "Hannah Demo", email: "head@example.com")
  spouse = seed_person(name: "Sam Demo", email: "spouse@example.com")

  household = head.households.find_by(name: "The Demo Family") ||
    Household.create_with_head(household: { name: "The Demo Family" }, head: head)

  household.memberships.find_or_create_by!(user: spouse) { it.role = :adult }
  household.add_member(name: "Charlie Demo", role: :child) unless household.users.exists?(name: "Charlie Demo")
end
