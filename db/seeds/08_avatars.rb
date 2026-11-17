# Each person's initial in their own color, with no two in a household the same (docs/design/avatars.md, Elsewhere).
# Sam is in both households, so blue is taken in each. Maria is green, as in the frames.
def seed_avatar_color(user, color)
  user.change_avatar_color(color) || raise(ActiveRecord::RecordInvalid, user)
end

{ "staff@example.com" => "yellow", "head@example.com" => "purple", "spouse@example.com" => "blue",
  "rivera@example.com" => "green", "lucia.rivera" => "pink" }.each { |login, color| seed_avatar_color(seeded_person(login), color) }

seed_avatar_color(seeded_household("The Demo Family", head: "head@example.com").users.find_by!(name: "Charlie Demo"), "orange")
seed_avatar_color(seeded_household("The Rivera Family", head: "rivera@example.com").users.find_by!(name: "Mateo Rivera"), "yellow")

# One adult has a photo: a plain gradient libvips draws here, through change_avatar like an upload. No stock photos and
# no download. Sam keeps it on a second run.
sam = seeded_person("spouse@example.com")
unless sam.avatar.attached?
  xyz = Vips::Image.xyz(512, 512)
  gradient = (xyz[0] / 4 + 40).bandjoin([ xyz[1] / 3 + 60, xyz[0] / -4 + 230 ]).cast(:uchar).copy(interpretation: :srgb)

  Tempfile.create([ "sam", ".jpg" ]) do |file|
    file.binmode
    file.write(gradient.write_to_buffer(".jpg"))
    file.flush
    sam.change_avatar(ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: "sam.jpg", type: "image/jpeg")) ||
      raise(ActiveRecord::RecordInvalid, sam)
  end
end
