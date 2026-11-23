require "test_helper"

# Settings → Go bags: the household's go-bag categories, added, renamed and deleted by heads and adults
# (docs/design/go-bags.md, Pages; docs/design/settings.md).
class Settings::GoBagCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @water = go_bag_categories(:water_food)
  end

  test "a head and an adult see each category with what's in it, a menu, and Add category" do
    %i[ head spouse ].each do |identity|
      sign_in identities(identity)

      get household_settings_go_bag_categories_path(household_id: @home)

      assert_response :success
      assert_select "title", "Go bags · Settings · The Head Family · Aglowy"
      assert_select "main h2", "Go bags"
      assert_select "main p", %(Categories for The Head Family's go bags. Heads and adults can change them. Deleting one keeps its items, under "No category".)
      assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Go bags"
      assert_select "turbo-frame##{dom_id(@water)}", text: /Water and food\s*1 item in 1 bag/
      assert_select "turbo-frame##{dom_id(go_bag_categories(:light_power))}", text: /Light, power and radio\s*1 item in 1 bag/
      assert_select "button[aria-label=?]", "Water and food actions"
      assert_select "a[href=?]", household_settings_go_bag_categories_path(household_id: @home, rename: @water.id), text: "Rename"
      assert_select "dialog##{dom_id(@water, :delete_dialog)}", text: /Delete Water and food\?\s*Its 1 item stays in its bag, under No category\./
      assert_select "turbo-frame#new_go_bag_category a[href=?]", household_settings_go_bag_categories_path(household_id: @home, add: 1), text: "Add category"
      assert_select "#go-bag-categories input[name='go_bag_category[name]']", count: 0 # until Rename or Add category is chosen
    end
  end

  test "a category with no items says so, and the counts span bags" do
    sign_in identities(:spouse)
    go_bags(:charlies).items.create!(name: "Canned beans", category: @water)
    go_bag_categories(:light_power).items.update_all(category_id: nil)

    get household_settings_go_bag_categories_path(household_id: @home)

    assert_select "turbo-frame##{dom_id(@water)}", text: /2 items in 2 bags/
    assert_select "turbo-frame##{dom_id(go_bag_categories(:light_power))}", text: /No items/
    assert_select "dialog##{dom_id(go_bag_categories(:light_power), :delete_dialog)}", text: /It has no items\./
  end

  test "a household with no categories says so, with Add category" do
    sign_in identities(:spouse)
    @home.go_bag_categories.destroy_all

    get household_settings_go_bag_categories_path(household_id: @home)

    assert_select "main .Box", text: /No categories yet/
    assert_select "turbo-frame#new_go_bag_category a", text: "Add category"
  end

  test "Rename shows the category's one-field form in its frame, sending the saved page to the top" do
    sign_in identities(:spouse)

    get household_settings_go_bag_categories_path(household_id: @home, rename: @water.id)

    assert_select "turbo-frame##{dom_id(@water)} form[action=?][data-turbo-frame=_top]", household_settings_go_bag_category_path(household_id: @home, id: @water) do
      assert_select "input[name='go_bag_category[name]'][value=?][autofocus]", "Water and food"
      assert_select "input[name=_method][value=patch]"
      assert_select "button[type=submit]", "Save"
      assert_select "a[href=?]", household_settings_go_bag_categories_path(household_id: @home), text: "Cancel"
    end
  end

  test "Add category shows the empty one-field form in its frame" do
    sign_in identities(:head)

    get household_settings_go_bag_categories_path(household_id: @home, add: 1)

    assert_select "turbo-frame#new_go_bag_category form[action=?][data-turbo-frame=_top]", household_settings_go_bag_categories_path(household_id: @home) do
      assert_select "input[name='go_bag_category[name]']:not([value])"
      assert_select "button[type=submit]", "Add category"
    end
  end

  test "a head and an adult add a category, which goes last" do
    { head: "For the car", spouse: "Pets" }.each do |identity, name|
      sign_in identities(identity)

      assert_difference -> { @home.go_bag_categories.count } do
        post household_settings_go_bag_categories_path(household_id: @home), params: { go_bag_category: { name: } }
      end

      assert_redirected_to household_settings_go_bag_categories_path(household_id: @home)
      assert_equal "Category added.", flash[:notice]
      assert_equal name, @home.go_bag_categories.last.name
    end
    assert_equal [ 1, 2, 3, 4 ], @home.go_bag_categories.pluck(:position)
  end

  test "a head and an adult rename a category" do
    { head: "Food and water", spouse: "Water, food and cups" }.each do |identity, name|
      sign_in identities(identity)

      patch household_settings_go_bag_category_path(household_id: @home, id: @water), params: { go_bag_category: { name: } }

      assert_redirected_to household_settings_go_bag_categories_path(household_id: @home)
      assert_equal "Category renamed.", flash[:notice]
      assert_equal name, @water.reload.name
    end
  end

  test "a head and an adult delete a category, and its items stay in their bags under No category" do
    { head: @water, spouse: go_bag_categories(:light_power) }.each do |identity, category|
      sign_in identities(identity)
      item = category.items.sole

      assert_no_difference -> { GoBag::Item.count } do
        delete household_settings_go_bag_category_path(household_id: @home, id: category)
      end

      assert_redirected_to household_settings_go_bag_categories_path(household_id: @home)
      assert_equal "Category deleted.", flash[:notice]
      assert_not GoBag::Category.exists?(category.id)
      assert_nil item.reload.category_id
      assert_equal go_bags(:family), item.go_bag
    end
  end

  test "a blank name is refused, with the error by the field, the rest of the page as it was" do
    sign_in identities(:spouse)

    patch household_settings_go_bag_category_path(household_id: @home, id: @water), params: { go_bag_category: { name: "" } }

    assert_response :unprocessable_content
    assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Go bags"
    assert_select "turbo-frame##{dom_id(@water)} input[name='go_bag_category[name]'][aria-invalid=true]"
    assert_select "turbo-frame##{dom_id(@water)} .FormControl-inlineValidation", text: /Name can't be blank/
    assert_select "turbo-frame##{dom_id(go_bag_categories(:light_power))}", text: /Light, power and radio/
    assert_equal "Water and food", @water.reload.name

    post household_settings_go_bag_categories_path(household_id: @home), params: { go_bag_category: { name: "x" * 41 } }

    assert_response :unprocessable_content
    assert_select "turbo-frame#new_go_bag_category .FormControl-inlineValidation", text: /Name is too long/
  end

  test "the 50 limit's error shows by the field" do
    sign_in identities(:head)
    now = Time.current
    GoBag::Category.insert_all!((3..GoBag::Category::LIMIT).map { { household_id: @home.id, name: "Category #{it}", position: it, created_at: now, updated_at: now } })

    assert_no_difference -> { GoBag::Category.count } do
      post household_settings_go_bag_categories_path(household_id: @home), params: { go_bag_category: { name: "One too many" } }
    end

    assert_response :unprocessable_content
    assert_select "turbo-frame#new_go_bag_category input[name='go_bag_category[name]'][value=?][aria-invalid=true]", "One too many"
    assert_select "turbo-frame#new_go_bag_category .FormControl-inlineValidation", text: /The household already has 50 go-bag categories, the most it can have/
  end

  test "a child is refused, to see the section or to change anything" do
    sign_in identities(:eli)

    get household_settings_go_bag_categories_path(household_id: @home)
    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]

    post household_settings_go_bag_categories_path(household_id: @home), params: { go_bag_category: { name: "Toys" } }
    assert_redirected_to household_root_path(household_id: @home)

    patch household_settings_go_bag_category_path(household_id: @home, id: @water), params: { go_bag_category: { name: "Toys" } }
    assert_redirected_to household_root_path(household_id: @home)

    delete household_settings_go_bag_category_path(household_id: @home, id: @water)
    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]

    assert_equal [ "Water and food", "Light, power and radio" ], @home.go_bag_categories.map(&:name)
  end

  test "a category from another household is a 404, to rename, delete or open the form for" do
    theirs = go_bag_categories(:outsiders_tools)

    [ -> { patch household_settings_go_bag_category_path(household_id: @home, id: theirs), params: { go_bag_category: { name: "Mine" } } },
      -> { delete household_settings_go_bag_category_path(household_id: @home, id: theirs) },
      -> { get household_settings_go_bag_categories_path(household_id: @home, rename: theirs.id) } ].each do |request|
      sign_in identities(:spouse)
      request.call
      assert_response :not_found
    end

    assert_equal "Tools", theirs.reload.name
  end

  test "a non-member gets a 404" do
    [ -> { get household_settings_go_bag_categories_path(household_id: @home) },
      -> { post household_settings_go_bag_categories_path(household_id: @home), params: { go_bag_category: { name: "Mine" } } } ].each do |request|
      sign_in identities(:outsider)
      request.call
      assert_response :not_found
    end
  end
end
