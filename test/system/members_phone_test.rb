require "application_system_test_case"

# Members on a phone (docs/design/phone.md, Members; frames phone-members.png and phone-members-menu.png; story #413):
# each member and invitation is a two-line row, with its actions behind one plain "…". Desktop rows don't change.
class MembersPhoneTest < ApplicationSystemTestCase
  setup do
    # Charlie gets a username-only login and a study AI grant, so their row has New password link and the study.
    users(:child).give_login(username: "charlie")
    memberships(:child_in_home).grant_study_ai(by: users(:head))
    sign_in identities(:head)
    visit root_url
    on_a_phone
  end

  teardown do
    on_desktop
  end

  test "each row's second line is the role and how they sign in, and no role Labels show" do
    long = households(:home).invitations.create!(invited_by: users(:head), email: "grandparents.robinson.family@example.com")
    visit household_members_url(household_id: households(:home))

    within("#members") do
      assert_selector ".Box-row", text: /Hannah Head\s*Head · head@example.com\z/
      assert_selector ".Box-row", text: /Sam Spouse\s*Adult · spouse@example.com\z/
      assert_selector ".Box-row", text: /Charlie Child\s*Child · signs in as charlie\z/
      assert_selector ".Box-row", text: /Eli Child\s*Child · signs in as eli.rivera\z/
      assert_selector ".Box-row", text: /Sofia Child\s*Child\z/
      assert_no_selector ".Label"
      assert_no_link "Give a login"
      assert_no_button "New password link"
    end
    within("#invitations") do
      assert_selector ".Box-row", text: /ana.ortiz@example.com\s*Adult · invited by Hannah · until \w+ \d+\z/
      assert_no_selector ".Label"
      assert_no_button "Resend"
      # A long address wraps beside the "…" instead of pushing it under the row's text.
      row = find(".Box-row", text: long.email)
      assert_in_delta row.find(".text-bold").evaluate_script("this.getBoundingClientRect().top"),
                      row.find("button[aria-label='Actions for #{long.email}']").evaluate_script("this.getBoundingClientRect().top"), 16,
                      "the … isn't beside the address"
    end
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth"), "the page is wider than the phone"
    assert_accessible
    capture_screens("phone-members", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "Charlie's … lists New password link and Read Charlie's personal study, and each works" do
    visit household_members_url(household_id: households(:home))
    assert_turbo_idle

    menu_button = find("button[aria-label='Actions for Charlie Child']")
    assert_touch_target menu_button
    menu_button.click
    menu_id = "member-#{memberships(:child_in_home).id}-menu"
    assert_equal [ "New password link", "Read Charlie's personal study" ], menu_entries(menu_id)
    wait_for_animations
    all("##{menu_id}-list [role=menuitem]").each { assert_touch_target it }
    assert_accessible
    capture_screens("phone-members-menu", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))

    find("body").send_keys(:escape)
    on_a_phone # capture_screens puts the desktop size back.
    choose_from_row_menu "Actions for Charlie Child", "New password link"
    assert_selector "h2", text: "Open this link on Charlie's device"

    visit household_members_url(household_id: households(:home))
    choose_from_row_menu "Actions for Charlie Child", "Read Charlie's personal study"
    assert_selector "h1", text: "Charlie Child's personal study"
  end

  test "a row with no actions has no …" do
    visit household_members_url(household_id: households(:home))

    within("#members .Box-row", text: "Hannah Head") { assert_no_button }
    within("#members .Box-row", text: "Sam Spouse") { assert_no_button }
    assert_selector "button[aria-label='Actions for Sofia Child']"
  end

  test "an invitation's … resends it, and cancels it after asking" do
    ana = invitations(:ana)
    visit household_members_url(household_id: households(:home))

    choose_from_row_menu "Actions for #{ana.email}", "Resend"
    assert_text "Invitation sent again to #{ana.email}."

    choose_from_row_menu "Actions for #{ana.email}", "Cancel invitation…"
    wait_for_dialog
    within("dialog[open]") do
      assert_selector "h1", text: "Cancel the invitation to #{ana.email}?"
      assert_accessible
      click_on "Cancel invitation"
    end

    assert_text "Invitation to #{ana.email} cancelled."
    within("#invitations") { assert_no_text ana.email }
  end

  private
    # choose_from_menu, for a row's "…", which has only its aria-label.
    def choose_from_row_menu(label, item)
      assert_turbo_idle
      find("button[aria-label='#{label}']").click
      find("[role=menuitem]", exact_text: item).click
    end

    def on_a_phone
      emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
      emulate_touch(true)
    end

    def on_desktop
      cdp("Emulation.clearDeviceMetricsOverride")
      cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    end
end
