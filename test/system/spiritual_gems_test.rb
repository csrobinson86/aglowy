require "application_system_test_case"

class SpiritualGemsTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    meeting_note_gems(:head_anxiety).destroy!
    meeting_note_gems(:head_strength).destroy!
  end

  test "add two gems and save" do
    visit edit_note_url

    assert_text "Each gem is a scripture and what you found in it"
    click_on "Add a gem"
    within("fieldset", text: "Gem 1") do
      assert_selector ":focus", visible: true
      fill_in "Scripture", with: "Isa 41:10"
      fill_in "What I found", with: "He holds on to us with his right hand."
    end
    click_on "Add a gem"
    within("fieldset", text: "Gem 2") do
      fill_in "Scripture", with: "Isaiah 41:13"
      fill_in "What I found", with: "Courage comes from who is with us."
    end
    assert_selector "button[aria-label='Remove Isaiah 41:13']"
    click_on "Save notes"

    assert_text "Notes saved."
    assert_selector "h3", text: "Spiritual Gems"
    assert_equal [ "Isaiah 41:10", "Isaiah 41:13" ], all("main li strong").map(&:text)
    assert_text "He holds on to us with his right hand."
    assert_text "Courage comes from who is with us."
  end

  test "a bad reference shows its error and keeps the other gem" do
    visit edit_note_url

    click_on "Add a gem"
    within("fieldset", text: "Gem 1") do
      fill_in "Scripture", with: "Isaiah 41:10"
      fill_in "What I found", with: "He holds on to us."
    end
    click_on "Add a gem"
    within("fieldset", text: "Gem 2") do
      fill_in "Scripture", with: "Hezekiah 1:1"
      fill_in "What I found", with: "Not a real book."
    end
    click_on "Save notes"

    within("fieldset", text: "Gem 2") do
      assert_text "Use a reference like Isaiah 41:10."
      assert_field "Scripture", with: "Hezekiah 1:1"
      assert_field "What I found", with: "Not a real book."
    end
    within("fieldset", text: "Gem 1") do
      assert_field "Scripture", with: "Isaiah 41:10"
      assert_field "What I found", with: "He holds on to us."
    end
    assert_accessible
    capture_screens("spiritual-gems-error", scroll_to: "[aria-invalid='true']")

    within("fieldset", text: "Gem 2") { fill_in "Scripture", with: "Isaiah 41:13" }
    click_on "Save notes"

    assert_text "Notes saved."
    assert_equal [ "Isaiah 41:10", "Isaiah 41:13" ], all("main li strong").map(&:text)
  end

  test "remove one" do
    meeting_notes(:head_midweek).gems.create!(scripture: "Isaiah 41:10", insight: "He holds on to us.", position: 1)
    meeting_notes(:head_midweek).gems.create!(scripture: "Isaiah 41:13", insight: "Courage.", position: 2)
    visit edit_note_url

    click_on "Add a gem"
    find("button[aria-label='Remove gem 3']").click
    assert_no_selector "fieldset", text: "Gem 3"
    find("button[aria-label='Remove Isaiah 41:10']").click
    assert_no_field "Scripture", with: "Isaiah 41:10"
    assert_selector ":focus", text: "Add a gem"
    click_on "Save notes"

    assert_text "Notes saved."
    assert_equal [ "Isaiah 41:13" ], all("main li strong").map(&:text)
    assert_no_text "He holds on to us."
  end

  test "the gems pass assert_accessible" do
    meeting_notes(:head_midweek).gems.create!(scripture: "Isaiah 41:10", insight: "Jehovah promises to hold on to us with his right hand.", position: 1)
    meeting_notes(:head_midweek).gems.create!(scripture: "Isaiah 41:13", insight: "He tells us not to be afraid before the trouble is gone.", position: 2)
    visit edit_note_url

    click_on "Add a gem"
    ids = all("main [id]", visible: :all).map { it[:id] }
    assert_empty ids.tally.select { |_, count| count > 1 }.keys, "ids repeat after adding a gem"
    assert_accessible
    capture_screens("spiritual-gems", scroll_to: "[data-controller='gems']")

    visit household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))
    assert_selector "main li strong", text: "Isaiah 41:13"
    assert_accessible
    capture_screens("spiritual-gems-read")
  end

  private
    def edit_note_url
      edit_household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))
    end
end
