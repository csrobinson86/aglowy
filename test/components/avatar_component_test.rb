require "test_helper"

# A person's initial on a circle in their color (docs/design/avatars.md, AvatarComponent).
class AvatarComponentTest < ViewComponent::TestCase
  test "each color's class" do
    Avatar::Palette::COLORS.each do |color|
      users(:eli).avatar_color = color

      render_inline(AvatarComponent.new(user: users(:eli)))

      assert_selector ".avatar-initial.avatar-initial--#{color}", text: "E"
    end
  end

  test "a color outside the palette is never a class name: it draws blue" do
    users(:eli).avatar_color = "red\" onclick=\"x"

    render_inline(AvatarComponent.new(user: users(:eli)))

    assert_selector ".avatar-initial--blue"
    assert_no_selector "[onclick]"
  end

  test "the initial of a name that starts with a lowercase letter or an accent" do
    { "eli" => "E", "émile Durand" => "É", "émile" => "É", "Øyvind" => "Ø" }.each do |name, initial|
      users(:eli).name = name

      render_inline(AvatarComponent.new(user: users(:eli)))

      assert_equal initial, page.find(".avatar-initial", visible: :all).text
    end
  end

  test "the initial is escaped" do
    users(:eli).name = "<b>Bold"

    render_inline(AvatarComponent.new(user: users(:eli)))

    assert_no_selector "b"
    assert_selector ".avatar-initial", text: "<", visible: :all
  end

  test "aria-hidden beside a name" do
    render_inline(AvatarComponent.new(user: users(:eli)))

    assert_selector ".avatar-initial[aria-hidden=true]", visible: :all
    assert_no_selector "[role=img]", visible: :all
  end

  test "role=img and the name as its label when it stands alone" do
    render_inline(AvatarComponent.new(user: users(:eli), alone: true))

    assert_selector ".avatar-initial[role=img][aria-label='Eli Child']"
    assert_no_selector "[aria-hidden]"
  end

  test "Primer's sizes, 24 by default" do
    render_inline(AvatarComponent.new(user: users(:eli)))
    assert_selector ".avatar-initial--size-24", visible: :all

    [ 16, 20, 24, 32, 40, 48, 64, 80 ].each do |size|
      render_inline(AvatarComponent.new(user: users(:eli), size:))
      assert_selector ".avatar-initial--size-#{size}", visible: :all
    end
  end

  test "any other size is refused" do
    assert_raises(ArgumentError) { AvatarComponent.new(user: users(:eli), size: 28) }
  end

  test "classes are added for spacing" do
    render_inline(AvatarComponent.new(user: users(:eli), classes: "mr-2"))

    assert_selector ".avatar.circle.avatar-initial.mr-2", visible: :all
  end

  test "with a photo: Primer's round Avatar, its src carrying the photo's checksum, and alt empty beside a name" do
    users(:eli).change_avatar(Rack::Test::UploadedFile.new(file_fixture("avatars/photo.png")))

    render_inline(AvatarComponent.new(user: users(:eli), size: 32, classes: "mr-2"))

    src = Rails.application.routes.url_helpers.avatar_path(users(:eli), v: users(:eli).avatar.blob.checksum)
    assert_selector "img.avatar.circle.mr-2[src='#{src}'][alt=''][width=32][height=32]"
    assert_no_selector ".avatar-initial", visible: :all
  end

  test "with a photo, standing alone: alt is the name" do
    users(:eli).change_avatar(Rack::Test::UploadedFile.new(file_fixture("avatars/photo.png")))

    render_inline(AvatarComponent.new(user: users(:eli), size: 80, alone: true))

    assert_selector "img.avatar[alt='Eli Child'][width=80]"
  end
end
