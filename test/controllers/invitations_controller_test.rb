require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  test "an adult invites an adult and an email is enqueued" do
    sign_in identities(:spouse)

    assert_difference "Invitation.count", 1 do
      assert_enqueued_emails 1 do
        post household_invitations_path(household_id: households(:home)), params: { invitation: { email: " Rosa@Example.com ", role: "adult" } }
      end
    end

    invitation = households(:home).invitations.find_by!(email: "rosa@example.com")
    assert invitation.adult?
    assert_equal users(:spouse), invitation.invited_by
    assert_redirected_to household_members_path(household_id: households(:home))
    assert_equal "Invitation sent to rosa@example.com.", flash[:notice]
  end

  test "an adult posting role: head is refused" do
    sign_in identities(:spouse)

    assert_no_difference "Invitation.count" do
      assert_no_enqueued_emails do
        post household_invitations_path(household_id: households(:home)), params: { invitation: { email: "rosa@example.com", role: "head" } }
      end
    end

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "a head invites a head" do
    sign_in identities(:head)

    assert_enqueued_emails 1 do
      post household_invitations_path(household_id: households(:home)), params: { invitation: { email: "rosa@example.com", role: "head" } }
    end

    assert households(:home).invitations.find_by!(email: "rosa@example.com").head?
    assert_redirected_to household_members_path(household_id: households(:home))
  end

  test "a child is refused" do
    sign_in child_identity

    get new_household_invitation_path(household_id: households(:home))
    assert_redirected_to household_root_path(household_id: households(:home))

    assert_no_difference "Invitation.count" do
      post household_invitations_path(household_id: households(:home)), params: { invitation: { email: "rosa@example.com", role: "adult" } }
    end
    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "inviting an existing member re-renders with the error on Email" do
    sign_in identities(:head)

    assert_no_difference "Invitation.count" do
      assert_no_enqueued_emails do
        post household_invitations_path(household_id: households(:home)), params: { invitation: { email: "spouse@example.com", role: "adult" } }
      end
    end

    assert_response :unprocessable_content
    assert_select "input[name='invitation[email]'][value='spouse@example.com']"
    assert_select ".FormControl-inlineValidation", text: "Already a member of this household."
  end

  test "inviting an address that already has an open invitation re-renders with the error on Email" do
    sign_in identities(:head)

    assert_no_difference "Invitation.count" do
      post household_invitations_path(household_id: households(:home)), params: { invitation: { email: invitations(:ana).email, role: "adult" } }
    end

    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: "Already invited. Resend it from the Members page."
  end

  test "a mistyped email re-renders with a full sentence on Email" do
    sign_in identities(:head)

    assert_no_difference "Invitation.count" do
      post household_invitations_path(household_id: households(:home)), params: { invitation: { email: "rosa.example.com", role: "adult" } }
    end

    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: "Enter an email address, like name@example.com."
  end

  test "Daniel resends his own and can't cancel Maria's" do
    sign_in identities(:spouse)
    own = invitation_from(:spouse, expires_at: 1.day.ago)

    assert_enqueued_emails 1 do
      patch household_invitation_path(household_id: households(:home), id: own)
    end
    assert_not own.reload.expired?
    assert_redirected_to household_members_path(household_id: households(:home))
    assert_equal "Invitation sent again to rosa@example.com.", flash[:notice]

    assert_no_difference "Invitation.count" do
      delete household_invitation_path(household_id: households(:home), id: invitations(:ana))
    end
    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "a head cancels any invitation in the household" do
    sign_in identities(:head)
    invitation = invitation_from(:spouse)

    delete household_invitation_path(household_id: households(:home), id: invitation)

    assert_not Invitation.exists?(invitation.id)
    assert_redirected_to household_members_path(household_id: households(:home))
    assert_equal "Invitation to rosa@example.com cancelled.", flash[:notice]
  end

  test "an invitation from another household is 404" do
    sign_in identities(:head)
    elsewhere = households(:parents).invitations.create!(invited_by: users(:grandparent), email: "luz@example.com")

    patch household_invitation_path(household_id: households(:home), id: elsewhere)
    assert_response :not_found

    sign_in identities(:head) # A raised 404 doesn't write the session cookie.
    delete household_invitation_path(household_id: households(:home), id: elsewhere)
    assert_response :not_found
    assert Invitation.exists?(elsewhere.id)
  end

  test "the invite form offers Head to heads only" do
    sign_in identities(:head)
    get new_household_invitation_path(household_id: households(:home))
    assert_select "h1", "Invite someone to the The Head Family"
    assert_select "input[type=radio][name='invitation[role]'][value=adult][checked]"
    assert_select "input[type=radio][name='invitation[role]'][value=head]"

    sign_in identities(:spouse)
    get new_household_invitation_path(household_id: households(:home))
    assert_select "input[type=radio][name='invitation[role]'][value=adult]"
    assert_select "input[type=radio][name='invitation[role]'][value=head]", count: 0
  end

  private
    def invitation_from(user, **attributes)
      households(:home).invitations.create!(invited_by: users(user), email: "rosa@example.com", **attributes)
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
