require "application_system_test_case"

class StorageQuotaTest < ApplicationSystemTestCase
  WARNING = "Your household has used 80% of its 2 GB of file storage."

  setup do
    use_home_storage((households(:home).storage_quota * 0.8).ceil)
  end

  test "the warning banner shows at 80% for a head on the session page and the schedule form" do
    sign_in identities(:head)

    visit session_url
    assert_selector ".Banner--warning", text: WARNING
    assert_accessible
    capture_screens("storage-warning")

    visit new_household_family_study_url(household_id: households(:home))
    assert_selector ".Banner--warning", text: WARNING
    assert_accessible
    capture_screens("storage-warning-schedule-form")
  end

  test "at 100% an upload is refused before it goes up" do
    use_home_storage(households(:home).storage_quota)
    sign_in identities(:head)

    visit session_url
    assert_selector ".Banner--warning", text: "Your household has used 100% of its 2 GB of file storage."
    attach_file "choose files", file_fixture("photo.png"), make_visible: true

    within "li", text: "photo.png" do
      assert_text "Your household has used its 2 GB of file storage. Remove some files to add more."
    end
    assert_accessible
    capture_screens("storage-full", scroll_to: ".file-drop")
  end

  test "a child sees no warning banner" do
    # Charlie Child has no login in the fixtures, so give them one here.
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)

    visit session_url
    assert_selector "h1", text: "Lessons From the Life of Ruth"
    assert_no_selector ".Banner"
    assert_accessible
  end

  private
    def session_url
      study_session = family_study_sessions(:weekly_past)
      household_family_study_session_url(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end
end
