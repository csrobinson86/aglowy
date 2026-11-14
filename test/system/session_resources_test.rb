require "application_system_test_case"

class SessionResourcesTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
  end

  test "add two links on the schedule form and see them on the session" do
    visit new_household_family_study_url(household_id: households(:home))

    fill_in "What will you study?", with: "Proverbs 3"
    fill_in "Date", with: 7.days.from_now.to_date
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    fill_in "Add a link", with: "https://www.jw.org/en/library/bible/proverbs/3/"
    click_on "Add link"
    # Enter adds the link too, instead of submitting the form.
    fill_in "Add a link", with: "https://wol.jw.org/en/wol/b/r1/lp-e/nwtsty/20/3"
    find_field("Add a link").send_keys(:enter)

    within "#schedule-links" do
      assert_selector "li", count: 2
      assert_text "https://www.jw.org/en/library/bible/proverbs/3/"
    end
    assert_field "Add a link", with: ""
    assert_accessible
    capture_screens("schedule-study-links")
    click_on "Schedule study"

    assert_text "Your family study is scheduled."
    click_on "Proverbs 3"

    assert_link "www.jw.org/en/library/bible/proverbs/3", href: "https://www.jw.org/en/library/bible/proverbs/3/"
    assert_link "wol.jw.org/en/wol/b/r1/lp-e/nwtsty/20/3"
  end

  test "a bad link on the schedule form shows its error on the field" do
    visit new_household_family_study_url(household_id: households(:home))

    fill_in "Date", with: 7.days.from_now.to_date
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    fill_in "Add a link", with: "https://www.jw.org/en/"
    click_on "Add link"
    fill_in "Add a link", with: "ftp://files.example.com/proverbs.pdf"
    click_on "Schedule study"

    assert_text "Link must be a web address starting with http:// or https://"
    assert_field "Add a link", with: "ftp://files.example.com/proverbs.pdf"
    within("#schedule-links") { assert_text "https://www.jw.org/en/" }
    assert_accessible
  end

  test "a link in another language goes through as the browser encodes it" do
    visit new_household_family_study_url(household_id: households(:home))

    fill_in "What will you study?", with: "Rut 1"
    fill_in "Date", with: 7.days.from_now.to_date
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    fill_in "Add a link", with: "https://wol.jw.org/es/wol/d/r4/lp-s/año"
    click_on "Add link"

    within("#schedule-links") { assert_text "https://wol.jw.org/es/wol/d/r4/lp-s/a%C3%B1o" }
    click_on "Schedule study"
    click_on "Rut 1"

    assert_link "wol.jw.org/es/wol/d/r4/lp-s/año", href: "https://wol.jw.org/es/wol/d/r4/lp-s/a%C3%B1o"
  end

  test "remove one on the session page" do
    study_session = family_study_sessions(:one_off_first)
    visit household_family_study_session_url(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)

    assert_link family_study_resources(:proverbs).title
    assert_selector "a[target='_blank'][rel='noopener noreferrer']", text: family_study_resources(:draw_close).title
    assert_accessible
    capture_screens("session-links")

    find("button[aria-label='Remove #{family_study_resources(:proverbs).title}']").click

    assert_text "Link removed."
    assert_no_link family_study_resources(:proverbs).title
    assert_link family_study_resources(:draw_close).title
  end

  test "add one on the session page" do
    study_session = family_study_sessions(:weekly_next)
    visit household_family_study_session_url(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)

    assert_text "No resources yet"
    fill_in "Add a link", with: "https://www.jw.org/en/bible-teachings/"
    click_on "Add link"

    assert_text "Link added."
    assert_link "www.jw.org/en/bible-teachings"
    assert_accessible
  end
end
