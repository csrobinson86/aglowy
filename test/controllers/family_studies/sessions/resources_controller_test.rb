require "test_helper"

class FamilyStudies::Sessions::ResourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @study_session = family_study_sessions(:one_off_first)
  end

  test "a head sees the Add a link form and a remove button per link" do
    sign_in identities(:head)

    get household_family_study_session_path(household_id: households(:home), family_study_id: @study_session.family_study, id: @study_session)

    assert_select "a[href='#{family_study_resources(:proverbs).url}'][target='_blank'][rel='noopener noreferrer']", family_study_resources(:proverbs).title
    assert_select "label", text: /Add a link/
    assert_select "button[aria-label='Remove #{family_study_resources(:proverbs).title}']"
  end

  test "a head can add a link" do
    sign_in identities(:head)

    assert_difference -> { @study_session.resources.count } do
      post resources_path, params: { family_study_resource: { url: "https://www.jw.org/en/library/" } }
    end

    assert_redirected_to session_path
    assert_equal "www.jw.org/en/library", @study_session.resources.last.title
  end

  test "an adult can add a link" do
    sign_in identities(:spouse)

    assert_difference -> { @study_session.resources.count } do
      post resources_path, params: { family_study_resource: { url: "https://wol.jw.org/en/" } }
    end
    assert_redirected_to session_path
  end

  test "a bad link shows its error on the field" do
    sign_in identities(:head)

    assert_no_difference -> { FamilyStudy::Resource.count } do
      post resources_path, params: { family_study_resource: { url: "javascript:alert(1)" } }
    end

    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /Link must be a web address starting with http:\/\/ or https:\/\//
    assert_select "a[href^='javascript']", count: 0
    assert_select ".Box-row", text: /#{Regexp.escape(family_study_resources(:proverbs).title)}/
  end

  test "a head can remove a link" do
    sign_in identities(:head)

    assert_difference -> { @study_session.resources.count }, -1 do
      delete resource_path(family_study_resources(:proverbs))
    end
    assert_redirected_to session_path
  end

  test "an adult can remove a link" do
    sign_in identities(:spouse)

    assert_difference -> { @study_session.resources.count }, -1 do
      delete resource_path(family_study_resources(:proverbs))
    end
    assert_redirected_to session_path
  end

  test "a child sees the links but no add or remove controls" do
    sign_in child_identity

    get session_path

    assert_select "a[href='#{family_study_resources(:proverbs).url}']"
    assert_select "label", text: /Add a link/, count: 0
    assert_select "button[aria-label^='Remove']", count: 0
  end

  test "a child gets refused" do
    sign_in child_identity

    assert_no_difference -> { FamilyStudy::Resource.count } do
      post resources_path, params: { family_study_resource: { url: "https://www.jw.org/" } }
      assert_redirected_to household_root_path(household_id: households(:home))

      delete resource_path(family_study_resources(:proverbs))
      assert_redirected_to household_root_path(household_id: households(:home))
    end
  end

  test "another household's resource gets 404" do
    outsiders_session = households(:other).schedule_family_study(frequency: :once, starts_on: 2.days.from_now.to_date, time_of_day: "18:00").sessions.sole
    outsiders_link = outsiders_session.resources.create!(url: "https://www.jw.org/")

    sign_in identities(:head)
    assert_no_difference -> { FamilyStudy::Resource.count } do
      # Through our own session, their resource's id isn't found.
      delete resource_path(outsiders_link)
      assert_response :not_found

      # The 404 response doesn't carry the session cookie, so sign in again.
      sign_in identities(:head)
      delete household_family_study_session_resource_path(household_id: households(:home), family_study_id: outsiders_session.family_study, session_id: outsiders_session, id: outsiders_link)
      assert_response :not_found

      sign_in identities(:head)
      post household_family_study_session_resources_path(household_id: households(:home), family_study_id: outsiders_session.family_study, session_id: outsiders_session),
           params: { family_study_resource: { url: "https://www.jw.org/" } }
      assert_response :not_found
    end
  end

  private
    def session_path
      household_family_study_session_path(household_id: households(:home), family_study_id: @study_session.family_study, id: @study_session)
    end

    def resources_path
      household_family_study_session_resources_path(household_id: households(:home), family_study_id: @study_session.family_study, session_id: @study_session)
    end

    def resource_path(resource)
      household_family_study_session_resource_path(household_id: households(:home), family_study_id: @study_session.family_study, session_id: @study_session, id: resource)
    end

    # Charlie Child has no login in the fixtures, so give them one here.
    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
