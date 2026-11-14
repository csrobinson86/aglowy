require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  test "GET /signup/new renders for a visitor" do
    get new_signup_path

    assert_response :success
    assert_select "form[action=?]", signup_path
  end

  test "a valid POST /signup redirects to sign-in with the notice" do
    post signup_path, params: { signup: valid_params }

    assert_redirected_to new_identity_session_path
    assert_equal "Check your email to confirm your account.", flash[:notice]
  end

  test "an invalid POST /signup responds 422 and creates nothing" do
    assert_no_difference %w[ Identity.count User.count Household.count Membership.count ] do
      post signup_path, params: { signup: valid_params.merge(household_name: "") }
    end

    assert_response :unprocessable_content
    assert_select "input[name='signup[password]']:not([value])"
  end

  private

  def valid_params
    { name: "Rosa Robinson", email: "rosa@example.com", password: "password123",
      household_name: "The Robinson Family", time_zone: "London" }
  end
end
