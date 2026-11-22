require "application_system_test_case"

# Settings, a page per section: the person's own, then the household's (docs/design/settings.md; frames settings-profile.png,
# settings-child.png, settings-appearance-dark.png, settings-members.png, settings-adult-meetings.png and settings-tags.png).
class SettingsTest < ApplicationSystemTestCase
  test "a head opens Settings from the sidebar, changes their name, picks Dark and changes their password" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    within("aside") { click_on "Settings" }

    assert_selector "h1", text: "Settings"
    assert_selector "h2", text: "Profile"
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Profile"
    assert_selector "aside nav a[aria-current=page]", text: "Settings"
    assert_accessible
    capture_screens("settings-profile")

    fill_in "Name", with: "Hannah Rivera"
    click_on "Save profile"
    assert_text "Your profile is saved."
    assert_field "Name", with: "Hannah Rivera"
    within("aside") { assert_text "Hannah Rivera" }

    within("nav[aria-label='Settings']") { click_on "Appearance" }
    pick_dark

    within("nav[aria-label='Settings']") { click_on "Signing in" }
    fill_in "New password", with: "new-password-1"
    fill_in "Current password", with: "password123"
    click_on "Save sign-in details"
    assert_text "Your sign-in details are saved."
    assert_selector "h2", text: "Signing in"
    assert identities(:head).reload.valid_password?("new-password-1")
  end

  test "a child opens Settings, sees only their own sections, changes their name, picks Dark and changes their password" do
    sign_in identities(:eli)
    visit household_root_url(household_id: households(:home))

    within("aside") { click_on "Settings" }
    fill_in "Name", with: "Eli Rivera"
    click_on "Save profile"
    assert_text "Your profile is saved."

    within("nav[aria-label='Settings']") { click_on "Appearance" }
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Appearance"
    assert_equal [ "Profile", "Appearance", "Signing in", "My households", "Tags and collections", "Calendar", "Notifications" ], all("nav[aria-label='Settings'] a").map(&:text)
    assert_accessible
    capture_screens("settings-child")

    pick_dark

    within("nav[aria-label='Settings']") { click_on "Signing in" }
    assert_text "eli.rivera"
    assert_no_field "Email"
    fill_in "New password", with: "eli-new-pass"
    fill_in "Current password", with: "password123"
    click_on "Save sign-in details"
    assert_text "Your sign-in details are saved."
    assert identities(:eli).reload.valid_password?("eli-new-pass")
  end

  test "a head renames the household, changes its time zone, sets the meeting times, turns on the helper and changes a role" do
    sign_in identities(:head)
    visit household_settings_url(household_id: households(:home))

    assert_equal [ "Profile", "Appearance", "Signing in", "My households", "Tags and collections", "Calendar", "Notifications", "Study guide", "Household", "Meetings", "Children", "Members and roles" ],
                 all("nav[aria-label='Settings'] a").map(&:text)
    within("nav[aria-label='Settings']") { click_on "Household" }
    assert_selector "h2", text: "Household"
    assert_text "Changing it keeps each study at the same local time."
    assert_accessible
    fill_in "Name", with: "The Rivera Family"
    select "(GMT-06:00) Central Time (US & Canada)", from: "Time zone"
    click_on "Save"
    assert_text "Household settings saved."
    assert_selector "nav[aria-label='Settings'] h2", text: "The Rivera Family"
    assert_title "Household · Settings · The Rivera Family · Aglowy"
    find("aside button[aria-haspopup='true']", text: "The Rivera Family").click
    assert_selector "action-menu [role='menu'] [aria-checked=true]", text: "The Rivera Family", visible: true
    find("aside button[aria-haspopup='true']", text: "The Rivera Family").click

    within("nav[aria-label='Settings']") { click_on "Meetings" }
    set_meeting_times

    within("nav[aria-label='Settings']") { click_on "Children" }
    check "Meeting helper for children"
    click_on "Save"
    assert_text "Meeting helper turned on."
    assert_selector "h2", text: "Children"
    assert_checked_field "Meeting helper for children"
    assert_text "Turned on by Hannah Head on #{Time.current.in_time_zone("Central Time (US & Canada)").strftime("%B %-d")}."
    assert_accessible

    within("nav[aria-label='Settings']") { click_on "Members and roles" }
    assert_selector "h2", text: "Members and roles"
    assert_text "A household always keeps at least one head."
    assert_accessible
    capture_screens("settings-members")
    select "Head", from: "Sam Spouse"
    assert_text "Sam Spouse is now a head."
    assert memberships(:spouse_in_home).reload.head?
  end

  test "an adult sees only Meetings and Children of the household's sections, sets the meeting times and turns the helper on and off" do
    sign_in identities(:spouse)
    visit household_settings_url(household_id: households(:home))

    within("nav[aria-label='Settings']") do
      assert_selector "h2", text: "The Head Family"
      assert_equal [ "Profile", "Appearance", "Signing in", "My households", "Tags and collections", "Calendar", "Notifications", "Study guide", "Meetings", "Children" ], all("a").map(&:text)
      click_on "Meetings"
    end
    assert_selector "h2", text: "Meetings"
    assert_turbo_idle
    assert_accessible
    capture_screens("settings-adult-meetings")
    set_meeting_times

    within("nav[aria-label='Settings']") { click_on "Children" }
    check "Meeting helper for children"
    click_on "Save"
    assert_text "Meeting helper turned on."
    assert_text "Turned on by Sam Spouse on #{Time.current.strftime("%B %-d")}."
    uncheck "Meeting helper for children"
    click_on "Save"
    assert_text "Meeting helper turned off."
    assert_no_checked_field "Meeting helper for children"
    assert_no_text "Turned on by"
  end

  test "a person renames a tag, refused for a name they have, then deletes one" do
    users(:head).tags.create!(name: "prayer")
    sign_in identities(:head)
    visit household_settings_url(household_id: households(:home))

    within("nav[aria-label='Settings']") { click_on "Tags and collections" }
    assert_selector "h2", text: "Tags and collections"
    assert_selector "#my-tags .Box-row", count: 2
    assert_selector "aside nav a[aria-current=page]", text: "Settings"
    assert_accessible
    capture_screens("settings-tags")

    find("button[aria-label='Rename #ministry']").click
    within("dialog[open]") do
      fill_in "Name", with: "Prayer"
      click_on "Rename"
      assert_text "You already have #prayer."
    end
    assert_equal find("dialog[open]").find_field("Name")[:id], page.evaluate_script("document.activeElement.id")
    wait_for_transitions # the pointer rests on the new Rename button, whose colour fades in
    assert_accessible
    capture_screens("tag-rename-taken", viewports: ScreenshotHelper::VIEWPORTS.slice(:desktop))

    within("dialog[open]") do
      fill_in "Name", with: "Field service"
      click_on "Rename"
    end
    assert_selector ".flash", text: "Renamed to #field-service."
    assert_selector "h2", text: "Tags and collections"
    assert_selector "#my-tags a.Label", text: "#field-service"

    find("button[aria-label='Delete #field-service']").click
    within("dialog[open]") do
      assert_text "It comes off 1 item."
      click_on "Delete tag"
    end
    assert_selector ".flash", text: "Deleted #field-service."
    assert_selector "h2", text: "Tags and collections"
    assert_no_selector "#my-tags a.Label", text: "#field-service"
    assert_empty meeting_notes(:head_midweek).tags.reload
  end

  test "a person changes a collection to Notes only, refused while it holds studies, then deletes one and its studies stay" do
    sign_in identities(:head)
    visit household_settings_tags_url(household_id: households(:home))

    find("button[aria-label='Edit Bible questions']").click
    wait_for_dialog
    within("dialog[open]") do
      choose "Notes only"
      click_on "Save collection"
      assert_text "1 study is in this collection. Move it first."
    end
    wait_for_transitions
    assert_accessible
    assert collections(:head_bible_questions).reload.used_in_both?

    within("dialog[open]") do
      fill_in "Name", with: "Questions"
      choose "Notes and Personal study"
      click_on "Save collection"
    end
    assert_selector ".flash", text: "Collection saved."
    assert_selector "#collections .Box-row", text: /Questions\s+· 1 study\s+Used in Notes and Personal study/

    find("button[aria-label='Edit Quick references']").click
    wait_for_dialog
    within("dialog[open]") do
      choose "Personal study only"
      click_on "Save collection"
      assert_text "1 note is in this collection. Move it first."
      choose "Notes only"
      fill_in "Name", with: "References"
      click_on "Save collection"
    end
    assert_selector "#collections .Box-row", text: /References\s+· 1 note\s+Used in Notes only/

    find("button[aria-label='Delete Preparing a talk']").click
    wait_for_dialog
    within("dialog[open]") do
      assert_text "Everything in it stays; it just leaves the folder."
      click_on "Delete collection"
    end
    assert_selector ".flash", text: "Deleted Preparing a talk. Everything in it is kept."
    assert_selector "h2", text: "Tags and collections"
    assert_no_selector "#collections .Box-row", text: "Preparing a talk"
    assert_nil personal_studies(:head_kindness).reload.collection
    assert PersonalStudy.exists?(personal_studies(:head_kindness).id)
  end

  test "a head sees \"New household\" in My households and it opens the new household page" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    within("aside") { click_on "Settings" }
    within("nav[aria-label='Settings']") { click_on "My households" }
    assert_selector "h2", text: "My households"
    within(".Box-header") { assert_link "New household", href: new_household_path }
    assert_accessible
    capture_screens("settings-my-households")

    click_on "New household"
    assert_selector "h1", text: "New household"
    assert_current_path new_household_path
  end

  test "an adult sees \"New household\" in My households" do
    assert_new_household_in_my_households identities(:spouse)
  end

  test "a person who has only ever been a child sees no \"New household\"" do
    sign_in identities(:eli)
    visit household_settings_memberships_url(household_id: households(:home))

    assert_selector "h2", text: "My households"
    assert_no_link "New household"
    assert_accessible
    capture_screens("settings-my-households-child")
  end

  test "a child here who is an adult in another household sees \"New household\"" do
    Membership.create!(user: users(:eli), household: households(:other), role: :adult)

    assert_new_household_in_my_households identities(:eli)
  end

  test "a child here who left an adult seat elsewhere sees \"New household\"" do
    Membership.create!(user: users(:eli), household: households(:other), role: :adult, active: false)

    assert_new_household_in_my_households identities(:eli)
  end

  private
    def assert_new_household_in_my_households(identity)
      sign_in identity
      visit household_settings_memberships_url(household_id: households(:home))

      assert_selector "h2", text: "My households"
      within(".Box-header") { assert_link "New household", href: new_household_path }
      assert_accessible
    end

    def set_meeting_times
      assert_selector "h2", text: "Meetings"
      select "Friday", from: "Midweek day"
      fill_in "Midweek starts at", with: Time.zone.parse("19:00")
      select "Sunday", from: "Weekend day"
      fill_in "Weekend starts at", with: Time.zone.parse("10:00")
      click_on "Save"

      assert_text "Meeting times saved."
      assert_selector "h2", text: "Meetings"
      assert_select "Midweek day", selected: "Friday"
      assert_field "Midweek starts at", with: "19:00"
      assert_select "Weekend day", selected: "Sunday"
      assert_field "Weekend starts at", with: "10:00"
      assert_accessible
    end

    def pick_dark
      assert_selector "h2", text: "Appearance"
      assert_selector "body[data-color-mode=auto]"
      choose "Dark"
      click_on "Save appearance"

      assert_text "Your appearance is saved."
      assert_selector "body[data-color-mode=dark]"
      assert_checked_field "Dark"
      assert_accessible
      capture_screens("settings-appearance-dark")
    end
end
