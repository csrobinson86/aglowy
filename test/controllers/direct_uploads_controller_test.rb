require "test_helper"

class DirectUploadsControllerTest < ActionDispatch::IntegrationTest
  test "a head gets a blob and somewhere to upload it" do
    sign_in identities(:head)

    assert_difference "ActiveStorage::Blob.count" do
      post direct_uploads_path, params: blob_params("study-guide.pdf", "application/pdf"), as: :json
    end

    assert_response :success
    assert response.parsed_body["signed_id"].present?
    assert_match %r{/rails/active_storage/disk/}, response.parsed_body.dig("direct_upload", "url")
  end

  test "an adult can upload an image" do
    sign_in identities(:spouse)

    post direct_uploads_path, params: blob_params("photo.png", "image/png"), as: :json

    assert_response :success
  end

  test "an oversized blob request is refused before upload" do
    sign_in identities(:head)

    assert_no_difference "ActiveStorage::Blob.count" do
      post direct_uploads_path, params: blob_params("study-guide.pdf", "application/pdf", byte_size: 25.megabytes + 1), as: :json
    end

    assert_response :unprocessable_content
    assert_equal "Must be 25 MB or smaller.", response.parsed_body["error"]
  end

  test "a disallowed blob request is refused before upload" do
    sign_in identities(:head)

    assert_no_difference "ActiveStorage::Blob.count" do
      post direct_uploads_path, params: blob_params("program.exe", "application/x-msdownload"), as: :json
    end

    assert_response :unprocessable_content
    assert_equal "Must be a PDF or an image (PNG, JPEG, GIF, WebP or HEIC).", response.parsed_body["error"]
  end

  test "a blob that would take the household over its quota is refused before upload" do
    sign_in identities(:spouse)
    use_home_storage(households(:home).storage_quota - file_fixture("study-guide.pdf").size + 1)

    assert_no_difference "ActiveStorage::Blob.count" do
      post direct_uploads_path, params: blob_params("study-guide.pdf", "application/pdf"), as: :json
    end

    assert_response :unprocessable_content
    assert_equal "Your household has used its 2 GB of file storage. Remove some files to add more.", response.parsed_body["error"]
  end

  test "a blob that fills the quota exactly is accepted" do
    sign_in identities(:head)
    use_home_storage(households(:home).storage_quota - file_fixture("study-guide.pdf").size)

    post direct_uploads_path, params: blob_params("study-guide.pdf", "application/pdf"), as: :json

    assert_response :success
  end

  test "a signed-out request is refused" do
    assert_no_difference "ActiveStorage::Blob.count" do
      post direct_uploads_path, params: blob_params("study-guide.pdf", "application/pdf"), as: :json
    end

    assert_response :unauthorized
  end

  test "a child is refused" do
    # Charlie Child has no login in the fixtures, so give them one here.
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)

    assert_no_difference "ActiveStorage::Blob.count" do
      post direct_uploads_path, params: blob_params("study-guide.pdf", "application/pdf"), as: :json
    end

    assert_response :forbidden
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    assert_no_difference "ActiveStorage::Blob.count" do
      post direct_uploads_path, params: blob_params("study-guide.pdf", "application/pdf"), as: :json
    end

    assert_response :not_found
  end

  private
    def direct_uploads_path
      household_direct_uploads_path(household_id: households(:home))
    end

    def blob_params(name, content_type, byte_size: file_fixture(name).size)
      { blob: { filename: name, byte_size: byte_size, content_type: content_type,
                checksum: OpenSSL::Digest::MD5.base64digest(file_fixture(name).read) } }
    end
end
