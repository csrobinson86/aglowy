require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    sign_in identities(:head)
  end

  test "create a collection used in Personal study and Notes, last in my list" do
    assert_difference -> { users(:head).collections.count } do
      post household_collections_path(household_id: @home), params: { collection: { name: "Convention 2027", used_in: "both" } }
    end

    collection = users(:head).collections.find_by!(name: "Convention 2027")
    assert_redirected_to household_personal_studies_path(household_id: @home, collection: collection.id)
    assert collection.used_in_both?
    assert_equal 4, collection.position
  end

  test "create a collection for Personal study only" do
    post household_collections_path(household_id: @home), params: { collection: { name: "Prophecy", used_in: "studies" } }

    assert users(:head).collections.find_by!(name: "Prophecy").used_in_studies?
  end

  test "a name I already have comes back in the dialog with the reason" do
    assert_no_difference -> { Collection.count } do
      post household_collections_path(household_id: @home), params: { collection: { name: "Bible questions", used_in: "both" } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=new_collection] template", text: /Name has already been taken/
  end

  test "a name I already have, from Notes, comes back with Notes' choices" do
    post household_collections_path(household_id: @home), params: { section: "notes", collection: { name: "Bible questions", used_in: "notes" } }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=new_collection] template" do
      assert_select "label", text: "Notes only"
      assert_select "input[type=hidden][name=section][value=notes]"
    end
  end

  test "update: rename, and change where it's used" do
    collection = collections(:head_bible_questions)

    patch household_collection_path(household_id: @home, id: collection), params: { collection: { name: "Questions", used_in: "studies" } }

    assert_redirected_to household_personal_studies_path(household_id: @home, collection: collection.id)
    assert_equal [ "Questions", "studies" ], collection.reload.values_at(:name, :used_in)
  end

  test "update: changing used_in to notes is refused while studies are in it" do
    collection = collections(:head_talks)

    patch household_collection_path(household_id: @home, id: collection), params: { collection: { used_in: "notes" } }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=?] template", "edit_collection_#{collection.id}", text: /1 study is in this collection. Move it first./
    assert collection.reload.used_in_studies?
  end

  test "destroy keeps its studies" do
    study = personal_studies(:head_kindness)

    assert_difference -> { Collection.count }, -1 do
      delete household_collection_path(household_id: @home, id: collections(:head_talks))
    end

    assert_redirected_to household_personal_studies_path(household_id: @home)
    assert_nil study.reload.collection
  end

  test "another person's collection: 404" do
    collection = collections(:spouse_ministry)

    patch household_collection_path(household_id: @home, id: collection), params: { collection: { name: "Mine now" } }
    assert_response :not_found

    sign_in identities(:head) # a 404 doesn't keep the session
    assert_no_difference -> { Collection.count } do
      delete household_collection_path(household_id: @home, id: collection)
    end
    assert_response :not_found
    assert_equal "Ministry", collection.reload.name
  end

  test "from Settings, edit returns to Settings" do
    collection = collections(:head_quick_references)

    patch household_collection_path(household_id: @home, id: collection), params: { section: "settings", collection: { name: "References", used_in: "both" } }

    assert_redirected_to household_settings_tags_path(household_id: @home)
    assert_equal [ "References", "both" ], collection.reload.values_at(:name, :used_in)
  end

  test "from Settings, a refused Use in re-renders Settings' form with the message" do
    collection = collections(:head_bible_questions)

    patch household_collection_path(household_id: @home, id: collection), params: { section: "settings", collection: { name: "Bible questions", used_in: "notes" } }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=?] template", "edit_collection_#{collection.id}" do
      assert_select "label", text: "Personal study only"
      assert_select "label", text: "Notes only"
      assert_select "input[type=hidden][name=section][value=settings]"
      assert_select ".FormControl-inlineValidation", text: /1 study is in this collection. Move it first./
    end
    assert collection.reload.used_in_both?
  end

  test "from Settings, a name I already have shows its message once, by Name" do
    collection = collections(:head_talks)

    patch household_collection_path(household_id: @home, id: collection), params: { section: "settings", collection: { name: "Bible questions", used_in: "studies" } }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=?] template", "edit_collection_#{collection.id}" do
      assert_select ".FormControl-inlineValidation", count: 1, text: /Name has already been taken/
    end
  end

  test "from Settings, delete returns to Settings and keeps its studies" do
    study = personal_studies(:head_kindness)

    assert_difference -> { Collection.count }, -1 do
      delete household_collection_path(household_id: @home, id: collections(:head_talks)), params: { section: "settings" }
    end

    assert_redirected_to household_settings_tags_path(household_id: @home)
    assert_equal "Deleted Preparing a talk. Everything in it is kept.", flash[:notice]
    assert_nil study.reload.collection
  end

  test "from Settings, another person's collection: 404" do
    collection = collections(:spouse_ministry)

    patch household_collection_path(household_id: @home, id: collection), params: { section: "settings", collection: { name: "Mine now" } }
    assert_response :not_found

    sign_in identities(:head) # a 404 doesn't keep the session
    delete household_collection_path(household_id: @home, id: collection), params: { section: "settings" }
    assert_response :not_found
    assert_equal "Ministry", collection.reload.name
  end

  test "a child can make their own" do
    sign_in identities(:eli)

    post household_collections_path(household_id: @home), params: { collection: { name: "Creation", used_in: "both" } }

    assert users(:eli).collections.exists?(name: "Creation")
  end
end
