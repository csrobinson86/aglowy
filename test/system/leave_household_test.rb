require "application_system_test_case"

class LeaveHouseholdTest < ApplicationSystemTestCase
  test "an adult opens the dialog, leaves, and lands on the households page without that household" do
    sign_in identities(:head)
    visit edit_account_url

    within_my_households do
      assert_text "The Grandparent Family"
      assert_text "The Head Family"
      assert_text "Your meeting notes and personal goals stay with you, whichever households you're in."
    end

    click_leave "The Grandparent Family"

    within "dialog[open]" do
      assert_text "Leave the The Grandparent Family?"
      assert_text "Notes and goals you shared there become private again, and stay private if you rejoin."
      assert_text "Steps given to you that aren't done go back to the family."
      assert_text "Your own notes and goals aren't touched."
      assert_text "Anyone who runs the The Grandparent Family can invite you again later."
    end
    assert_accessible
    capture_screens("leave-household")

    within("dialog[open]") { click_on "Leave household" }

    assert_selector "h1", text: "Your households"
    assert_text "You left the The Grandparent Family."
    assert_link "The Head Family"
    assert_no_link "The Grandparent Family"
    assert_not memberships(:head_in_parents).reload.active?
  end

  test "cancel closes the dialog and leaves nothing" do
    sign_in identities(:head)
    visit edit_account_url

    click_leave "The Grandparent Family"
    within("dialog[open]") { click_on "Cancel" }

    assert_no_selector "dialog[open]"
    assert memberships(:head_in_parents).reload.active?
  end

  test "the last head is told to make someone else a head first" do
    sign_in identities(:head)
    visit edit_account_url

    click_leave "The Head Family"

    within "dialog[open]" do
      assert_text "Make someone else a head before you leave."
      assert_no_button "Leave household"
    end
    assert_accessible
  end

  test "a child sees their households without Leave" do
    sign_in identities(:eli)
    visit edit_account_url

    within_my_households do
      assert_text "The Head Family"
      assert_text "Child"
      assert_no_selector "button[aria-label^='Leave']"
    end
    assert_accessible
  end

  private
    def within_my_households(&)
      within(:xpath, "//*[contains(concat(' ', @class, ' '), ' Box ')][.//h2[normalize-space()='My households']]", &)
    end

    # Every row's button says only "Leave"; its aria-label names the household.
    def click_leave(household)
      find("button[aria-label='Leave #{household}']").click
    end
end
