require "test_helper"

class FamilyStudies::Sessions::FilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @study_session = family_study_sessions(:weekly_next)
  end

  test "a head adds uploaded files as file resources titled with their names" do
    sign_in identities(:head)

    assert_difference -> { @study_session.resources.file.count }, 2 do
      post files_path, params: { files: [ direct_uploaded_blob("study-guide.pdf").signed_id, direct_uploaded_blob("photo.png").signed_id ] }
    end

    assert_redirected_to session_path
    assert_equal "2 files added.", flash[:notice]
    assert_equal [ "study-guide.pdf", "photo.png" ], @study_session.resources.map(&:title)
  end

  test "a file whose bytes aren't allowed is refused, and none of the others are added" do
    sign_in identities(:spouse)

    assert_no_difference -> { FamilyStudy::Resource.count } do
      post files_path, params: { files: [ direct_uploaded_blob("study-guide.pdf").signed_id, direct_uploaded_blob("program.exe", filename: "notes.pdf").signed_id ] }
    end

    assert_redirected_to session_path
    assert_equal "notes.pdf wasn't added: it must be a PDF or an image (PNG, JPEG, GIF, WebP or HEIC).", flash[:alert]
  end

  test "an id that can't be found adds nothing and says so; the same file twice is added once" do
    sign_in identities(:head)

    assert_no_difference -> { FamilyStudy::Resource.count } do
      post files_path, params: { files: [ "not-a-signed-id" ] }
    end
    assert_redirected_to session_path
    assert_equal "Those files couldn't be found. Upload them again.", flash[:alert]

    signed_id = direct_uploaded_blob("photo.png").signed_id
    assert_difference -> { @study_session.resources.count }, 1 do
      post files_path, params: { files: [ signed_id, signed_id, "not-a-signed-id" ] }
    end
  end

  test "files that would take the household over its quota are refused with the quota message" do
    sign_in identities(:head)
    use_home_storage(households(:home).storage_quota)

    assert_no_difference -> { FamilyStudy::Resource.count } do
      post files_path, params: { files: [ direct_uploaded_blob("photo.png").signed_id ] }
    end

    assert_redirected_to session_path
    assert_equal "Your household has used its 2 GB of file storage. Remove some files to add more.", flash[:alert]
  end

  test "an adult sees the storage warning from 80% on the session page and the schedule form" do
    sign_in identities(:spouse)
    use_home_storage((households(:home).storage_quota * 0.85).ceil)

    get session_path
    assert_select ".Banner--warning", text: "Your household has used 85% of its 2 GB of file storage."
    get new_household_family_study_path(household_id: households(:home))
    assert_select ".Banner--warning", text: "Your household has used 85% of its 2 GB of file storage."
  end

  test "under 80% there's no storage warning" do
    sign_in identities(:head)
    use_home_storage((households(:home).storage_quota * 0.79).ceil)

    get session_path
    assert_select ".Banner", count: 0
  end

  test "a child is refused" do
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)

    assert_no_difference -> { FamilyStudy::Resource.count } do
      post files_path, params: { files: [ direct_uploaded_blob("study-guide.pdf").signed_id ] }
    end
    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    assert_no_difference -> { FamilyStudy::Resource.count } do
      post files_path, params: { files: [ direct_uploaded_blob("study-guide.pdf").signed_id ] }
    end
    assert_response :not_found
  end

  test "the session page lists a file with its icon and size, linked only through Aglowy" do
    sign_in identities(:head)
    study_session = family_study_sessions(:weekly_past)

    get household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)

    file_path = household_resource_file_path(household_id: households(:home), resource_id: family_study_resources(:study_guide))
    assert_select ".Box-row", text: /study-guide.pdf/ do
      assert_select "a[href='#{file_path}']", "study-guide.pdf"
      assert_select "svg.octicon-file"
      assert_select "span", text: "191 Bytes"
    end
    # Gotcha 22: Active Storage's own signed URLs never appear in a page.
    assert_no_match %r{/rails/active_storage}, response.body
  end

  test "a head sees the drop zone on the session page; a child doesn't" do
    sign_in identities(:head)
    get session_path
    assert_select "input[type=file][multiple]"

    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    get session_path
    assert_select "input[type=file]", count: 0
  end

  test "removing a file says so" do
    sign_in identities(:head)
    study_session = family_study_sessions(:weekly_past)

    delete household_family_study_session_resource_path(household_id: households(:home), family_study_id: study_session.family_study, session_id: study_session, id: family_study_resources(:study_guide))

    assert_equal "File removed.", flash[:notice]
  end

  private
    def session_path
      household_family_study_session_path(household_id: households(:home), family_study_id: @study_session.family_study, id: @study_session)
    end

    def files_path
      household_family_study_session_files_path(household_id: households(:home), family_study_id: @study_session.family_study, session_id: @study_session)
    end
end
