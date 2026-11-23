require "test_helper"

class GoBagsControllerTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.utc(2026, 11, 23, 18) }

  test "a head and an adult see the list with New, each bag's place and what's to buy, and the guide" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get household_go_bags_path(household_id: households(:home))

      assert_response :success
      assert_select "title", "Go bags · The Head Family · Aglowy"
      assert_select "h1", "Go bags"
      assert_select "main a[href='#{new_household_go_bag_path(household_id: households(:home))}']", "New"
      assert_select "main .Box-row", count: 2
      assert_select "main .Box-row a[href='#{bag_path(go_bags(:family))}']", text: /Family go bag\s*Kept in the hall closet · 1 to buy/
      assert_select "main .Box-row", text: /Charlie's bag\s*No items yet/
      assert_select "main a[href='https://wol.jw.org/en/wol/d/r1/lp-e/102017165'][target=_blank][rel=noopener]", "When Disaster Strikes—Steps That Can Save Lives"
    end
  end

  test "a child sees the list with how ready each bag is, and no New" do
    sign_in child_identity
    get household_go_bags_path(household_id: households(:home))

    assert_response :success
    assert_select "main .Box-row", text: /Family go bag\s*Kept in the hall closet · 2 of 3 ready/
    assert_select "main a", { text: "New", count: 0 }
  end

  test "with no bags, the Blankslate offers New go bag to heads and adults, not children" do
    households(:home).go_bags.destroy_all

    sign_in identities(:spouse)
    get household_go_bags_path(household_id: households(:home))
    assert_select ".blankslate h2", "No go bags yet"
    assert_select ".blankslate a[href='#{new_household_go_bag_path(household_id: households(:home))}']", "New go bag"

    sign_in child_identity
    get household_go_bags_path(household_id: households(:home))
    assert_select ".blankslate h2", "No go bags yet"
    assert_select ".blankslate a", count: 0
  end

  test "a head and an adult see a bag's items by category, No category last, with Edit and the delete dialog" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get bag_path(go_bags(:family))

      assert_response :success
      assert_select "h1", "Family go bag"
      assert_select "#go-bag-meta", "Kept in the hall closet · For everyone"
      assert_select "#go-bag-progress", text: /2 of 3 ready\s*67%/
      assert_equal [ "Water and food", "Light, power and radio", "No category" ], css_select("main h2").map { it.text.strip }.last(3)
      assert_select "main a[href='#{edit_household_go_bag_path(household_id: households(:home), id: go_bags(:family))}']", "Edit"
      assert_select "dialog#delete-go-bag", text: /Delete Family go bag\?\s*Its 3 items are deleted too./
    end

    get bag_path(go_bags(:charlies))
    assert_select "#go-bag-meta", "For Charlie"
  end

  test "a child sees a bag read-only, and its meta line says the adults keep it up to date" do
    sign_in child_identity
    get bag_path(go_bags(:family))

    assert_response :success
    assert_select "#go-bag-meta", "Kept in the hall closet · The adults keep it up to date"
    assert_select "main .Box-row", text: /Flashlight\s*Still to get/
    assert_select "main a", { text: "Edit", count: 0 }
    assert_select "dialog#delete-go-bag", count: 0
    assert_select "button[aria-label='Go bag actions']", count: 0
  end

  test "a bag's page and the list ask no more queries for three bags of many items than for one small bag" do
    sign_in identities(:spouse)
    get household_go_bags_path(household_id: households(:home))
    list_before = queries_for { get household_go_bags_path(household_id: households(:home)) }
    bag_before = queries_for { get bag_path(go_bags(:family)) }

    bag = households(:home).go_bags.create!(name: "Car kit", created_by: users(:spouse))
    5.times { bag.items.create!(name: "Thing #{it}", category: go_bag_categories(:water_food)).acquire(by: users(:spouse)) }
    5.times { go_bags(:family).items.create!(name: "More #{it}", category: go_bag_categories(:light_power)) }

    assert_equal list_before, queries_for { get household_go_bags_path(household_id: households(:home)) }
    assert_equal bag_before, queries_for { get bag_path(go_bags(:family)) }
  end

  test "New ticks Start with suggested items only when the household has no bags" do
    sign_in identities(:spouse)
    get new_household_go_bag_path(household_id: households(:home))
    assert_response :success
    assert_select "input[type=checkbox][name='go_bag[suggested]']:not([checked])"

    households(:home).go_bags.destroy_all
    get new_household_go_bag_path(household_id: households(:home))
    assert_select "input[type=checkbox][name='go_bag[suggested]'][checked]"
    assert_select "select[name='go_bag[for_user_id]'] option", text: "Everyone"
    assert_select "select[name='go_bag[for_user_id]'] option", text: "Charlie Child"
    assert_select "select[name='go_bag[for_user_id]'] option", { text: "Frances Former", count: 0 }
  end

  test "Create with suggestions adds the suggested items, none acquired, and goes to the bag" do
    sign_in identities(:head)

    assert_difference -> { GoBag.count } => 1, -> { GoBag::Item.count } => GoBag::Suggestions.new.categories.sum { it.items.size } do
      post household_go_bags_path(household_id: households(:home)),
           params: { go_bag: { name: "Car kit", kept_at: "the trunk", for_user_id: users(:eli).id, suggested: "1" } }
    end

    bag = households(:home).go_bags.last
    assert_redirected_to bag_path(bag)
    assert_equal [ "Car kit", "the trunk", users(:eli), users(:head) ], [ bag.name, bag.kept_at, bag.for_user, bag.created_by ]
    assert_empty bag.items.acquired
  end

  test "Create without suggestions makes an empty bag, for everyone" do
    sign_in identities(:spouse)

    assert_difference -> { GoBag.count } => 1, -> { GoBag::Item.count } => 0 do
      post household_go_bags_path(household_id: households(:home)), params: { go_bag: { name: "Car kit", kept_at: "", for_user_id: "", suggested: "0" } }
    end
    assert_nil households(:home).go_bags.last.for_user
  end

  test "Create with a blank name shows the form again with the error" do
    sign_in identities(:spouse)

    assert_no_difference -> { GoBag.count } do
      post household_go_bags_path(household_id: households(:home)), params: { go_bag: { name: "", suggested: "1" } }
    end
    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /can't be blank/
    assert_select "input[type=checkbox][name='go_bag[suggested]'][checked]"
  end

  test "for_user_id of a non-member is refused with the error by the field" do
    sign_in identities(:spouse)

    assert_no_difference -> { GoBag.count } do
      post household_go_bags_path(household_id: households(:home)), params: { go_bag: { name: "Car kit", for_user_id: users(:outsider).id } }
    end
    assert_response :unprocessable_content
    assert_select "select[name='go_bag[for_user_id]'][aria-invalid=true]"
    assert_select ".FormControl-inlineValidation", text: /must be an active member of the household/

    patch bag_path(go_bags(:family)), params: { go_bag: { for_user_id: users(:former).id } }
    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /must be an active member of the household/
    assert_nil go_bags(:family).reload.for_user
  end

  test "Edit has no suggestions box, and Update saves the bag" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get edit_household_go_bag_path(household_id: households(:home), id: go_bags(:family))
      assert_response :success
      assert_select "input[name='go_bag[name]'][value='Family go bag']"
      assert_select "input[name='go_bag[suggested]']", count: 0
    end

    patch bag_path(go_bags(:family)), params: { go_bag: { name: "Home bag", kept_at: "the garage", for_user_id: users(:child).id } }
    assert_redirected_to bag_path(go_bags(:family))
    assert_equal [ "Home bag", "the garage", users(:child) ], go_bags(:family).reload.then { [ it.name, it.kept_at, it.for_user ] }

    patch bag_path(go_bags(:family)), params: { go_bag: { name: "" } }
    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /can't be blank/
  end

  test "Destroy deletes the bag and its items" do
    sign_in identities(:spouse)

    assert_difference -> { GoBag.count } => -1, -> { GoBag::Item.count } => -3 do
      delete bag_path(go_bags(:family))
    end
    assert_redirected_to household_go_bags_path(household_id: households(:home))
    assert_equal "Go bag deleted.", flash[:notice]
  end

  test "a child is refused New, Create, Edit, Update and Destroy" do
    sign_in child_identity

    get new_household_go_bag_path(household_id: households(:home))
    assert_not_authorized

    assert_no_difference -> { GoBag.count } do
      post household_go_bags_path(household_id: households(:home)), params: { go_bag: { name: "Mine", suggested: "1" } }
    end
    assert_not_authorized

    get edit_household_go_bag_path(household_id: households(:home), id: go_bags(:family))
    assert_not_authorized

    patch bag_path(go_bags(:family)), params: { go_bag: { name: "Mine" } }
    assert_not_authorized
    assert_equal "Family go bag", go_bags(:family).reload.name

    assert_no_difference -> { GoBag.count } do
      delete bag_path(go_bags(:family))
    end
    assert_not_authorized
  end

  test "a bag from another household is a 404, and so is the list for a non-member" do
    outsiders = households(:other).go_bags.create!(name: "Theirs", created_by: users(:outsider))
    sign_in identities(:spouse)

    get household_go_bag_path(household_id: households(:home), id: outsiders)
    assert_response :not_found
    get edit_household_go_bag_path(household_id: households(:home), id: outsiders)
    assert_response :not_found
    patch household_go_bag_path(household_id: households(:home), id: outsiders), params: { go_bag: { name: "Mine" } }
    assert_response :not_found
    delete household_go_bag_path(household_id: households(:home), id: outsiders)
    assert_response :not_found
    assert_equal "Theirs", outsiders.reload.name

    get household_go_bags_path(household_id: households(:other))
    assert_response :not_found
    get household_go_bag_path(household_id: households(:other), id: outsiders)
    assert_response :not_found
  end

  private
    def bag_path(bag)
      household_go_bag_path(household_id: bag.household_id, id: bag)
    end

    def assert_not_authorized
      assert_redirected_to household_root_path(household_id: households(:home))
      assert_equal "You can't do that in this household.", flash[:alert]
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end

    def queries_for(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
