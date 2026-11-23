require "test_helper"

# Adding, changing and removing a bag's items (docs/design/go-bags.md, An item; story #437). Opened from a row it's a
# dialog in the bag page's Turbo Frame; opened directly it's a page with a back row to the bag.
class GoBags::ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 23, 18)
    @bag = go_bags(:family)
  end

  test "a head and an adult open Add item as a dialog in the frame, with the section's category chosen" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get new_item_path(category_id: go_bag_categories(:light_power).id), headers: { "Turbo-Frame" => "go_bag_item_dialog" }

      assert_response :success
      assert_select "turbo-frame#go_bag_item_dialog dialog[open]", text: /Add item/
      assert_select "select[name='go_bag_item[category_id]'] option[selected][value='#{go_bag_categories(:light_power).id}']"
      assert_equal [ "No category", "Water and food", "Light, power and radio" ], css_select("select[name='go_bag_item[category_id]'] option").map { it.text.strip }
      assert_select "input[type=date][name='go_bag_item[use_by]']"
      assert_select "input[type=checkbox][name='go_bag_item[have]']"
      assert_select "button", { text: "Remove item", count: 0 }
    end
  end

  test "Add item with a category from another household chooses No category" do
    sign_in identities(:spouse)
    get new_item_path(category_id: go_bag_categories(:outsiders_tools).id), headers: { "Turbo-Frame" => "go_bag_item_dialog" }

    assert_response :success
    assert_select "select[name='go_bag_item[category_id]'] option[selected]", "No category"
  end

  test "a head and an adult add an item, without and with We have it" do
    sign_in identities(:head)
    assert_difference -> { @bag.items.count } do
      post items_path, params: { go_bag_item: item_params(name: "Whistle", have: "0") }, headers: { "Turbo-Frame" => "go_bag_item_dialog" }
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=update][target=go_bag_item_dialog]"
    assert_select "turbo-stream[action=refresh]"
    whistle = item_named("Whistle")
    assert_equal [ go_bag_categories(:light_power), "2", "the car", Date.new(2026, 12, 10) ], [ whistle.category, whistle.quantity, whistle.stored_at, whistle.use_by ]
    assert_not whistle.acquired?

    sign_in identities(:spouse)
    post items_path, params: { go_bag_item: item_params(name: "Multi-tool", have: "1") }, headers: { "Turbo-Frame" => "go_bag_item_dialog" }
    multi_tool = item_named("Multi-tool")
    assert multi_tool.acquired?
    assert_equal users(:spouse), multi_tool.acquisition.acquired_by
  end

  test "opened directly, Add item and an item's edit are pages with a back row to the bag, and saving goes back to it" do
    sign_in identities(:spouse)
    get edit_item_path(go_bag_items(:water))

    assert_response :success
    assert_select "dialog#go-bag-item-dialog", count: 0
    assert_select ".back-row a[href='#{bag_path}']", text: "Family go bag"
    assert_select "h1", "Bottled water"
    assert_select "input[name='go_bag_item[name]'][value='Bottled water']"
    assert_select "input[type=checkbox][name='go_bag_item[have]'][checked]"
    assert_select "button", "Remove item"

    patch item_path(go_bag_items(:water)), params: { go_bag_item: { name: "Water", have: "1" } }
    assert_redirected_to bag_path
    assert_equal "Water", go_bag_items(:water).reload.name

    get new_item_path
    assert_select ".back-row a[href='#{bag_path}']", text: "Family go bag"
    assert_select "h1", "Add item"
    post items_path, params: { go_bag_item: item_params(name: "Whistle") }
    assert_redirected_to bag_path
  end

  test "a head and an adult change an item, and We have it both ways" do
    sign_in identities(:head)
    get edit_item_path(go_bag_items(:flashlight)), headers: { "Turbo-Frame" => "go_bag_item_dialog" }
    assert_select "turbo-frame#go_bag_item_dialog dialog[open]", text: /Flashlight/
    assert_select "button", "Remove item"

    patch item_path(go_bag_items(:flashlight)), params: { go_bag_item: { name: "Torch", quantity: "2", have: "1" } }, headers: { "Turbo-Frame" => "go_bag_item_dialog" }
    assert_select "turbo-stream[action=update][target=go_bag_item_dialog]"
    flashlight = go_bag_items(:flashlight).reload
    assert_equal [ "Torch", "2" ], [ flashlight.name, flashlight.quantity ]
    assert flashlight.acquired?

    sign_in identities(:spouse)
    patch item_path(go_bag_items(:water)), params: { go_bag_item: { category_id: "", have: "0" } }, headers: { "Turbo-Frame" => "go_bag_item_dialog" }
    water = go_bag_items(:water).reload
    assert_nil water.category
    assert_not water.acquired?
  end

  test "a refused save shows the dialog again with the reason by its field" do
    sign_in identities(:spouse)
    assert_no_difference -> { GoBag::Item.count } do
      post items_path, params: { go_bag_item: item_params(name: "") }, headers: { "Turbo-Frame" => "go_bag_item_dialog" }
    end
    assert_response :unprocessable_content
    assert_select "turbo-frame#go_bag_item_dialog dialog[open]", text: /Name can't be blank/

    patch item_path(go_bag_items(:water)), params: { go_bag_item: { name: "", have: "0" } }, headers: { "Turbo-Frame" => "go_bag_item_dialog" }
    assert_response :unprocessable_content
    assert go_bag_items(:water).reload.acquired?
  end

  test "a category from another household is refused, and nothing is saved" do
    sign_in identities(:spouse)
    assert_no_difference -> { GoBag::Item.count } do
      post items_path, params: { go_bag_item: item_params(category_id: go_bag_categories(:outsiders_tools).id) }
    end
    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /must be one of the household's categories/

    patch item_path(go_bag_items(:water)), params: { go_bag_item: { category_id: go_bag_categories(:outsiders_tools).id, have: "1" } }
    assert_response :unprocessable_content
    assert_equal go_bag_categories(:water_food), go_bag_items(:water).reload.category

    # One that doesn't exist, as when it's deleted while the dialog is open, is refused the same way.
    patch item_path(go_bag_items(:water)), params: { go_bag_item: { category_id: SecureRandom.uuid_v7, have: "1" } }
    assert_response :unprocessable_content
    assert_equal go_bag_categories(:water_food), go_bag_items(:water).reload.category
  end

  test "a head and an adult remove an item" do
    sign_in identities(:head)
    assert_difference -> { @bag.items.count }, -1 do
      delete item_path(go_bag_items(:flashlight)), headers: { "Turbo-Frame" => "go_bag_item_dialog" }
    end
    assert_select "turbo-stream[action=update][target=go_bag_item_dialog]"

    sign_in identities(:spouse)
    assert_difference -> { @bag.items.count }, -1 do
      delete item_path(go_bag_items(:water))
    end
    assert_redirected_to bag_path
  end

  test "a child is refused each, even with a crafted request" do
    sign_in child_identity

    get new_item_path
    assert_not_authorized

    assert_no_difference -> { GoBag::Item.count } do
      post items_path, params: { go_bag_item: item_params }
    end
    assert_not_authorized

    get edit_item_path(go_bag_items(:water))
    assert_not_authorized

    patch item_path(go_bag_items(:water)), params: { go_bag_item: { name: "Mine", have: "0" } }
    assert_not_authorized
    assert_equal "Bottled water", go_bag_items(:water).reload.name
    assert go_bag_items(:water).acquired?

    assert_no_difference -> { GoBag::Item.count } do
      delete item_path(go_bag_items(:water))
    end
    assert_not_authorized
  end

  test "an item from another bag through this bag's URL is a 404, and so is another household's bag" do
    outsiders = households(:other).go_bags.create!(name: "Theirs", created_by: users(:outsider))
    theirs = outsiders.items.create!(name: "Their water")

    # A 404 doesn't keep the session, so each request signs in again.
    [ -> { get edit_item_path(theirs) },
      -> { patch item_path(theirs), params: { go_bag_item: { name: "Mine" } } },
      -> { delete item_path(theirs) },
      -> { patch household_go_bag_item_path(household_id: households(:home), go_bag_id: go_bags(:charlies), id: go_bag_items(:water)), params: { go_bag_item: { name: "Mine" } } },
      -> { get new_household_go_bag_item_path(household_id: households(:home), go_bag_id: outsiders) },
      -> { post household_go_bag_items_path(household_id: households(:home), go_bag_id: outsiders), params: { go_bag_item: item_params } } ].each do |request|
      sign_in identities(:spouse)
      request.call
      assert_response :not_found
    end
    assert_equal [ "Their water", "Bottled water" ], [ theirs.reload.name, go_bag_items(:water).reload.name ]
    assert_equal 1, outsiders.items.count
  end

  private
    # Names are encrypted, so they're found in Ruby.
    def item_named(name)
      @bag.items.reload.find { it.name == name }
    end

    def item_params(name: "Whistle", category_id: go_bag_categories(:light_power).id, have: "0")
      { name:, category_id:, quantity: "2", use_by: "2026-12-10", stored_at: "the car", have: }
    end

    def bag_path
      household_go_bag_path(household_id: households(:home), id: @bag)
    end

    def items_path
      household_go_bag_items_path(household_id: households(:home), go_bag_id: @bag)
    end

    def new_item_path(**params)
      new_household_go_bag_item_path(household_id: households(:home), go_bag_id: @bag, **params)
    end

    def item_path(item)
      household_go_bag_item_path(household_id: households(:home), go_bag_id: @bag, id: item)
    end

    def edit_item_path(item)
      edit_household_go_bag_item_path(household_id: households(:home), go_bag_id: @bag, id: item)
    end

    def assert_not_authorized
      assert_redirected_to household_root_path(household_id: households(:home))
      assert_equal "You can't do that in this household.", flash[:alert]
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
