require "test_helper"

# A person's photo at /people/:user_id/avatar (docs/design/avatars.md, Serving the image): kept by the browser but
# rechecked on every use, so leaving a household stops it showing, and an unchanged photo is a 304 with no body.
class AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @spouse = users(:spouse)
    @spouse.change_avatar(Rack::Test::UploadedFile.new(file_fixture("avatars/photo.png")))
  end

  test "a household mate gets image/webp with max-age=0, private, must-revalidate; with its ETag, a 304 and no body" do
    sign_in identities(:head)

    get avatar_path(@spouse, v: @spouse.avatar.blob.checksum)

    assert_response :success
    assert_equal "image/webp", response.media_type
    assert_equal "max-age=0, private, must-revalidate", response.headers["Cache-Control"]
    assert_equal @spouse.avatar.download, response.body
    assert_predicate response.headers["ETag"], :present?

    get avatar_path(@spouse, v: @spouse.avatar.blob.checksum), headers: { "If-None-Match" => response.headers["ETag"] }

    assert_response :not_modified
    assert_empty response.body
  end

  test "after leaving the household, the same request (with the ETag) is a 404" do
    sign_in identities(:head)
    get avatar_path(@spouse)
    etag = response.headers["ETag"]

    assert memberships(:spouse_in_home).deactivate
    get avatar_path(@spouse), headers: { "If-None-Match" => etag }

    assert_response :not_found
  end

  test "a stranger gets a 404" do
    sign_in identities(:outsider)

    get avatar_path(@spouse)

    assert_response :not_found
  end

  test "someone with no photo is a 404" do
    sign_in identities(:head)

    get avatar_path(users(:eli))

    assert_response :not_found
  end

  test "a non-existent id is a 404" do
    sign_in identities(:head)

    get avatar_path(SecureRandom.uuid_v7)

    assert_response :not_found
  end

  test "signed out: redirected to sign in" do
    get avatar_path(@spouse)

    assert_redirected_to new_identity_session_path
  end
end
