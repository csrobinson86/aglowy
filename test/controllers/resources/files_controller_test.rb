require "test_helper"

class Resources::FilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @resource = family_study_resources(:study_guide)
  end

  test "a member is redirected to the file" do
    sign_in identities(:spouse)

    get household_resource_file_path(household_id: households(:home), resource_id: @resource)

    assert_response :redirect
    assert_match %r{\Ahttp://www.example.com/rails/active_storage/disk/.+/study-guide.pdf}, response.location

    get response.location
    assert_response :success
    assert_equal file_fixture("study-guide.pdf").binread, response.body
  end

  test "the file's address expires after five minutes" do
    sign_in identities(:head)
    get household_resource_file_path(household_id: households(:home), resource_id: @resource)

    travel 6.minutes do
      get response.location
      assert_response :not_found
    end
  end

  test "a non-member gets 404" do
    sign_in identities(:grandparent)

    get household_resource_file_path(household_id: households(:home), resource_id: @resource)

    assert_response :not_found
  end

  test "someone signed in to another household gets 404 even with the URL" do
    sign_in identities(:outsider)

    get household_resource_file_path(household_id: households(:other), resource_id: @resource)

    assert_response :not_found
  end

  test "a member of two households gets 404 asking through the other one" do
    sign_in identities(:head)

    get household_resource_file_path(household_id: households(:parents), resource_id: @resource)

    assert_response :not_found
  end

  test "a link has no file" do
    sign_in identities(:head)

    get household_resource_file_path(household_id: households(:home), resource_id: family_study_resources(:proverbs))

    assert_response :not_found
  end

  test "signed out goes to sign in" do
    get household_resource_file_path(household_id: households(:home), resource_id: @resource)

    assert_redirected_to new_identity_session_path
  end
end
