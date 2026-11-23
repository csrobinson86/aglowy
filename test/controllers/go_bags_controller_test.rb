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

  test "a head and an adult see the tabs with counters, a checkbox and › on each row, and + Add item ending each section" do
    go_bag_items(:water).update!(use_by: Date.new(2026, 12, 10))
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get bag_path(go_bags(:family))

      assert_select "nav[aria-label=Show] a", count: 3
      assert_equal [ "All 3", "To buy 2", "Use by soon 1" ], css_select("nav[aria-label=Show] a").map { it.text.squish }
      assert_select "nav[aria-label=Show] a[aria-current=page][href='#{bag_path(go_bags(:family))}']", text: /All/
      assert_select "nav[aria-label=Show] a[href=?]", bag_path(go_bags(:family), show: "to_buy")
      assert_select "nav[aria-label=Show] a[href=?]", bag_path(go_bags(:family), show: "use_by_soon")
      assert_select "##{dom_id(go_bag_items(:flashlight))} input[type=checkbox]"
      assert_select "##{dom_id(go_bag_items(:flashlight))} a[aria-label='Open Flashlight'][data-turbo-frame=go_bag_item_dialog]"
      assert_select "main section .Box-row:last-child a[href=?][data-turbo-frame=go_bag_item_dialog]",
                    new_household_go_bag_item_path(household_id: households(:home), go_bag_id: go_bags(:family), category_id: go_bag_categories(:water_food).id), text: "Add item"
      assert_select "main section .Box-row:last-child a[href=?]", new_household_go_bag_item_path(household_id: households(:home), go_bag_id: go_bags(:family)), text: "Add item"
      assert_select "turbo-frame#go_bag_item_dialog"
    end
  end

  test "To buy and Use by soon keep their items, and an empty one says so" do
    sign_in identities(:spouse)
    get bag_path(go_bags(:family), show: "to_buy")
    assert_select "nav[aria-label=Show] a[aria-current=page]", text: /To buy/
    assert_equal [ "Flashlight" ], css_select(".go-bag-item-row__name").map { it.text.strip }

    get bag_path(go_bags(:family), show: "use_by_soon")
    assert_select "nav[aria-label=Show] a[aria-current=page]", text: /Use by soon/
    assert_select ".go-bag-item-row__name", count: 0
    assert_select ".blankslate", text: "Nothing to use soon."

    go_bag_items(:flashlight).acquire(by: users(:spouse))
    get bag_path(go_bags(:family), show: "to_buy")
    assert_select ".blankslate", text: "Nothing to buy for this bag."
  end

  test "a bag with no items offers Add item to heads and adults, not children" do
    sign_in identities(:spouse)
    get bag_path(go_bags(:charlies))
    assert_select ".blankslate a[href='#{new_household_go_bag_item_path(household_id: households(:home), go_bag_id: go_bags(:charlies))}'][data-turbo-frame=go_bag_item_dialog]", "Add item"

    sign_in child_identity
    get bag_path(go_bags(:charlies))
    assert_select ".blankslate h2", "No items in this bag yet"
    assert_select ".blankslate a", count: 0
  end

  test "a child sees every item, with no tabs, checkboxes, › or Add item, whatever the URL asks" do
    sign_in child_identity
    get bag_path(go_bags(:family), show: "to_buy")

    assert_select "nav[aria-label=Show]", count: 0
    assert_select ".go-bag-item-row__name", count: 3
    assert_select "main form, main input[type=checkbox], turbo-frame#go_bag_item_dialog", count: 0
    assert_select "main a", { text: "Add item", count: 0 }
    assert_select "main a[aria-label^=Open]", count: 0
  end

  test "a bag's page and the list ask no more queries for three bags of many items than for one small bag" do
    sign_in identities(:spouse)
    get household_go_bags_path(household_id: households(:home))
    get bag_path(go_bags(:family))
    list_before = queries_for { get household_go_bags_path(household_id: households(:home)) }
    bag_before = queries_for { get bag_path(go_bags(:family)) }

    bag = households(:home).go_bags.create!(name: "Car kit", created_by: users(:spouse))
    5.times { bag.items.create!(name: "Thing #{it}", category: go_bag_categories(:water_food)).acquire(by: users(:spouse)) }
    5.times { go_bags(:family).items.create!(name: "More #{it}", category: go_bag_categories(:light_power)) }

    assert_equal list_before, queries_for { get household_go_bags_path(household_id: households(:home)) }
    assert_equal bag_before, queries_for { get bag_path(go_bags(:family)) }
  end

  test "New ticks Start with suggested items only when the household has no bags" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get new_household_go_bag_path(household_id: households(:home))
      assert_response :success
      assert_select "input[type=checkbox][name='go_bag[suggested]']:not([checked])"
    end

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

    bag = households(:home).go_bags.excluding(go_bags(:family), go_bags(:charlies)).sole
    assert_redirected_to bag_path(bag)
    assert_equal [ "Car kit", "the trunk", users(:eli), users(:head) ], [ bag.name, bag.kept_at, bag.for_user, bag.created_by ]
    assert_empty bag.items.acquired
  end

  test "Create without suggestions makes an empty bag, for everyone" do
    sign_in identities(:spouse)

    assert_difference -> { GoBag.count } => 1, -> { GoBag::Item.count } => 0 do
      post household_go_bags_path(household_id: households(:home)), params: { go_bag: { name: "Car kit", kept_at: "", for_user_id: "", suggested: "0" } }
    end
    assert_nil households(:home).go_bags.excluding(go_bags(:family), go_bags(:charlies)).sole.for_user
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

  test "the household's 21st bag is refused, with the reason above the form" do
    18.times { households(:home).go_bags.create!(name: "Bag #{it}", created_by: users(:spouse)) }
    sign_in identities(:spouse)

    assert_no_difference -> { GoBag.count } do
      post household_go_bags_path(household_id: households(:home)), params: { go_bag: { name: "One too many" } }
    end
    assert_response :unprocessable_content
    assert_select ".flash-error", text: /The household already has 20 go bags, the most it can have/
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
      assert_select "input[name='go_bag[name]'][value='#{go_bags(:family).reload.name}']"
      assert_select "input[name='go_bag[suggested]']", count: 0

      patch bag_path(go_bags(:family)), params: { go_bag: { name: "Bag by #{identity.user.first_name}", kept_at: "the garage", for_user_id: users(:child).id } }
      assert_redirected_to bag_path(go_bags(:family))
      assert_equal [ "Bag by #{identity.user.first_name}", "the garage", users(:child) ], go_bags(:family).reload.then { [ it.name, it.kept_at, it.for_user ] }
    end

    patch bag_path(go_bags(:family)), params: { go_bag: { name: "" } }
    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /can't be blank/
  end

  test "Destroy deletes the bag and its items" do
    [ [ identities(:head), go_bags(:family), 3 ], [ identities(:spouse), go_bags(:charlies), 0 ] ].each do |identity, bag, items|
      sign_in identity

      assert_difference -> { GoBag.count } => -1, -> { GoBag::Item.count } => -items do
        delete bag_path(bag)
      end
      assert_redirected_to household_go_bags_path(household_id: households(:home))
      assert_equal "Go bag deleted.", flash[:notice]
    end
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

    # A 404 doesn't keep the session, so each request signs in again.
    [ -> { get household_go_bag_path(household_id: households(:home), id: outsiders) },
      -> { get edit_household_go_bag_path(household_id: households(:home), id: outsiders) },
      -> { patch household_go_bag_path(household_id: households(:home), id: outsiders), params: { go_bag: { name: "Mine" } } },
      -> { delete household_go_bag_path(household_id: households(:home), id: outsiders) },
      -> { get household_go_bags_path(household_id: households(:other)) },
      -> { get household_go_bag_path(household_id: households(:other), id: outsiders) } ].each do |request|
      sign_in identities(:spouse)
      request.call
      assert_response :not_found
    end
    assert_equal "Theirs", outsiders.reload.name
  end

  private
    def bag_path(bag, **params)
      household_go_bag_path(household_id: bag.household_id, id: bag, **params)
    end

    def dom_id(...)
      ActionView::RecordIdentifier.dom_id(...)
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
