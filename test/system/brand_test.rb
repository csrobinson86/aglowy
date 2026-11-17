require "application_system_test_case"

# The Two flames logo where a person sees it (docs/design/brand.md, States the story checks).
class BrandTest < ApplicationSystemTestCase
  test "signed out, sign in shows the mark centred above the heading, and it links to the sign-in page" do
    visit root_url

    assert_selector "h1", text: "Sign in to Aglowy"
    assert_centred_mark_above "form"
    assert_accessible
    capture_screens("brand-sign-in")

    find("header a[href='/']").click

    assert_current_path root_path
    assert_selector "h1", text: "Sign in to Aglowy"
  end

  test "signed out, Create an account shows the same centred mark" do
    visit new_signup_url

    assert_selector "h1", text: "Create your account"
    assert_centred_mark_above "form"
    assert_accessible
    capture_screens("brand-sign-up")
  end

  test "signed in, the sidebar shows the mark and the link goes home" do
    sign_in identities(:head)
    visit household_members_url(household_id: households(:home))

    assert_selector "aside a img[src*='aglowy-mark'][width='24'][height='24']", count: 1
    assert_accessible
    capture_screens("brand-sidebar")

    within("aside") { click_on "Aglowy" }

    assert_current_path household_root_path(household_id: households(:home))
    assert_selector "h1", text: "Home"
  end

  private
    # The 48 px mark is the only logo, sits above the h1, and its horizontal centre is within 2 px of the given element's.
    def assert_centred_mark_above(selector)
      assert_selector "header a[href='/'] img[src*='aglowy-mark'][alt='Aglowy'][width='48'][height='48']", count: 1
      assert_no_selector "header a", text: "Aglowy"

      mark, heading, column = [ "header img", "main h1", "main #{selector}" ].map { rect(it) }

      assert_in_delta column["left"] + column["width"] / 2.0, mark["left"] + mark["width"] / 2.0, 2
      assert_operator mark["bottom"], :<=, heading["top"]
      assert_equal [ 48, 48 ], [ mark["width"], mark["height"] ]
    end

    def rect(selector)
      page.evaluate_script("document.querySelector(arguments[0]).getBoundingClientRect().toJSON()", selector)
    end
end
