require "test_helper"

# A person's photo (docs/design/avatars.md, User; Traps 1–3): the middle square, upright, as a 256 × 256 WebP with no
# location or camera details, built before anything is stored. The upload itself is never attached.
#
# The files in test/fixtures/files/avatars/: gps.jpg (400 × 300, with a GPS position in its EXIF), sideways.jpg (red on
# its left and blue on its right, with EXIF orientation 6), photo.png, photo.webp and photo.heic (300 × 200),
# document.jpg (a PDF), tiny.png (40 × 40), huge.png (a PNG whose header says 8000 × 7500, with no picture after), and
# corrupt.webp (photo.webp with its last two thirds zeroed: the header reads, the pixels don't).
class User::AvatarTest < ActiveSupport::TestCase
  REFUSED = "Choose a JPEG, PNG, WebP or HEIC photo up to 10 MB."

  setup { @user = users(:head) }

  test "a JPEG with GPS data becomes a 256 × 256 WebP with no EXIF" do
    assert_includes Vips::Image.new_from_file(file_fixture("avatars/gps.jpg").to_s).get_fields, "exif-ifd3-GPSLatitude"

    assert @user.change_avatar(photo("gps.jpg"))

    avatar = @user.reload.avatar
    assert_equal [ "image/webp", "avatar.webp" ], [ avatar.content_type, avatar.filename.to_s ]
    image = saved_image
    assert_equal [ 256, 256 ], [ image.width, image.height ]
    assert_empty image.get_fields.grep(/exif|xmp|iptc/)
    assert_not_includes avatar.download, "Exif"
  end

  test "a sideways (orientation 6) photo comes out upright" do
    assert @user.change_avatar(photo("sideways.jpg"))

    # Turned upright, the photo's left (red) is on top and its right (blue) at the bottom.
    image = saved_image
    assert_color :red, image.getpoint(128, 16)
    assert_color :blue, image.getpoint(128, 240)
  end

  test "PNG, WebP and HEIC are accepted" do
    %w[ photo.png photo.webp photo.heic ].each do |name|
      assert @user.change_avatar(photo(name)), "#{name}: #{@user.errors.full_messages.to_sentence}"
      assert_equal [ 256, 256 ], [ saved_image.width, saved_image.height ], name
    end
  end

  test "refused: a PDF named .jpg" do
    assert_refused photo("document.jpg")
  end

  test "refused: 11 MB" do
    Tempfile.create([ "big", ".jpg" ]) do |file|
      file.binmode
      file.write(file_fixture("avatars/gps.jpg").binread)
      file.write("\0" * (11.megabytes - file.size))
      file.flush

      assert_refused Rack::Test::UploadedFile.new(file.path, "image/jpeg")
    end
  end

  test "refused: 40 × 40" do
    assert_refused photo("tiny.png")
  end

  test "refused: a 60-megapixel header, checked without decoding" do
    ImageProcessing::Vips.stub(:source, ->(*) { flunk "the photo was decoded" }) do
      assert_refused photo("huge.png")
    end
  end

  test "refused: a file libvips can't read" do
    Tempfile.create([ "broken", ".jpg" ]) do |file|
      file.binmode
      file.write(file_fixture("avatars/gps.jpg").binread.first(64))
      file.flush

      assert_refused Rack::Test::UploadedFile.new(file.path, "image/jpeg")
    end
  end

  test "refused: a readable header with pixels libvips can't decode" do
    assert_equal [ 300, 200 ], Vips::Image.new_from_file(file_fixture("avatars/corrupt.webp").to_s).then { [ it.width, it.height ] }

    assert_refused photo("corrupt.webp")
  end

  test "refused: anything that isn't an uploaded file" do
    assert_refused "photo.jpg"
  end

  test "after a refused change, nothing is attached and no blob is left" do
    assert_no_difference -> { ActiveStorage::Blob.count } do
      assert_not @user.change_avatar(photo("document.jpg"))
    end
    assert_not @user.reload.avatar.attached?
  end

  test "a refused change keeps the photo already there" do
    @user.change_avatar(photo("photo.png"))
    blob = @user.avatar.blob

    assert_not @user.change_avatar(photo("tiny.png"))

    assert_equal blob, @user.reload.avatar.blob
  end

  test "remove_avatar purges" do
    @user.change_avatar(photo("photo.png"))
    key = @user.avatar.blob.key

    assert_difference -> { ActiveStorage::Blob.count }, -1 do
      @user.remove_avatar
    end
    assert_not @user.reload.avatar.attached?
    assert_not ActiveStorage::Blob.service.exist?(key)
  end

  test "only a WebP Aglowy made can be the avatar: no other type, nothing over 100 KB" do
    @user.avatar.attach(io: file_fixture("avatars/photo.png").open, filename: "photo.png", content_type: "image/png")
    assert_not @user.valid?
    assert_includes @user.errors.messages_for(:avatar), "must be a WebP of at most 100 KB"

    @user.avatar.attach(io: StringIO.new("\0" * (100.kilobytes + 1)), filename: "avatar.webp", content_type: "image/webp")
    assert_not @user.valid?
  end

  test "visible_to? the person themselves" do
    assert users(:eli).visible_to?(users(:eli))
  end

  test "visible_to? a household mate, in any household they share" do
    assert users(:eli).visible_to?(users(:head))
    assert users(:grandparent).visible_to?(users(:head))
  end

  test "not visible_to? someone sharing only an inactive membership, either way round" do
    assert_not users(:former).visible_to?(users(:head))
    assert_not users(:head).visible_to?(users(:former))
  end

  test "not visible_to? a stranger, or nobody" do
    assert_not users(:eli).visible_to?(users(:outsider))
    assert_not users(:eli).visible_to?(nil)
  end

  private
    def photo(name)
      Rack::Test::UploadedFile.new(file_fixture("avatars/#{name}"))
    end

    def saved_image
      Vips::Image.new_from_buffer(@user.reload.avatar.download, "")
    end

    def assert_refused(file)
      assert_no_difference -> { ActiveStorage::Blob.count } do
        assert_not @user.change_avatar(file)
      end
      assert_equal [ REFUSED ], @user.errors.messages_for(:avatar)
      assert_not @user.reload.avatar.attached?
    end

    def assert_color(color, (red, green, blue))
      expected = { red: red > 180 && blue < 80, blue: blue > 180 && red < 80 }.fetch(color)
      assert expected, "expected #{color}, got rgb(#{red.round}, #{green.round}, #{blue.round})"
    end
end
