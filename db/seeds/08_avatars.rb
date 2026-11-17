# Each person's initial in their own color, with no two in a household the same (docs/design/avatars.md, Elsewhere).
# Sam is in both households, so blue is taken in each. Maria is green, as in the frames.
def seed_avatar_color(user, color)
  user.change_avatar_color(color) || raise(ActiveRecord::RecordInvalid, user)
end

{ "staff@example.com" => "yellow", "head@example.com" => "purple", "spouse@example.com" => "blue",
  "rivera@example.com" => "green", "lucia.rivera" => "pink" }.each { |login, color| seed_avatar_color(seeded_person(login), color) }

seed_avatar_color(seeded_household("The Demo Family", head: "head@example.com").users.find_by!(name: "Charlie Demo"), "orange")
seed_avatar_color(seeded_household("The Rivera Family", head: "rivera@example.com").users.find_by!(name: "Mateo Rivera"), "yellow")
