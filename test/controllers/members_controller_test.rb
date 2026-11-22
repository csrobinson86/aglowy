require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
  test "a member sees the active members with their roles, heads first, not the former member" do
    sign_in identities(:spouse)

    get household_members_path(household_id: households(:home))

    assert_response :success
    assert_select "h1", "Members"
    assert_select "#members .Box-header", "5 members"
    assert_select "#members .Box-row", count: 5
    assert_select "#members", text: /Hannah Head.*Head.*Sam Spouse.*Adult.*Charlie Child.*Child/m
    assert_select "#members .Box-row", text: /Eli Child/
    assert_select "#members .Box-row", text: /Sofia Child/
    assert_not_includes response.body, "Frances Former"
  end

  test "the member list and Add a member have household page titles" do
    sign_in identities(:head)

    get household_members_path(household_id: households(:home))
    assert_select "title", "Members · The Head Family · Aglowy"

    get new_household_member_path(household_id: households(:home))
    assert_select "title", "Add a member · The Head Family · Aglowy"
  end

  test "a non-member gets 404 for the member list" do
    sign_in identities(:outsider)

    get household_members_path(household_id: households(:home))

    assert_response :not_found
  end

  test "a head and an adult get the New menu with Invite by email and Add without a login, and no standalone buttons" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity

      get household_members_path(household_id: households(:home))

      assert_select "main .Subhead-actions #members-new-menu-button.Button--primary", text: "New"
      assert_select "#members-new-menu-list" do
        assert_select "a[href=?]", new_household_invitation_path(household_id: households(:home)), text: "Invite by email"
        assert_select "a[href=?]", new_household_member_path(household_id: households(:home)), text: "Add without a login"
      end
      assert_select "main a.Button", text: "Invite by email", count: 0
      assert_select "main a.Button", text: "Add without a login", count: 0
    end
  end

  test "a child gets no New menu" do
    sign_in child_identity

    get household_members_path(household_id: households(:home))

    assert_response :success
    assert_select "#members-new-menu-button", count: 0
    assert_select "a", { text: "Invite by email", count: 0 }
    assert_select "a", { text: "Add without a login", count: 0 }
  end

  test "heads and adults see how each member signs in" do
    sign_in identities(:spouse)

    get household_members_path(household_id: households(:home))

    assert_select "#members .Box-row", text: /Hannah Head\s*head@example.com/
    assert_select "#members .Box-row", text: /Eli Child\s*Signs in as eli.rivera/
    assert_select "#members .Box-row", text: /Sofia Child\s*No login/
  end

  test "on a phone each member's second line is their role and how they sign in, and the role Label is desktop only" do
    sign_in identities(:spouse)

    get household_members_path(household_id: households(:home))

    assert_select "#members .Box-row .d-md-none", text: "Head · head@example.com"
    assert_select "#members .Box-row .d-md-none", text: "Adult · spouse@example.com"
    assert_select "#members .Box-row .d-md-none", text: "Child · signs in as eli.rivera"
    assert_select "#members .Box-row .d-md-none", text: "Child", count: 2 # Charlie and Sofia have no login
    assert_select "#members .Box-row .Label.d-none.d-md-inline-block", count: 5
  end

  test "heads and adults see Give a login on a child without one and New password link on a username-only child" do
    child_identity # Charlie's login has an email, so there's no password link for it.
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity

      get household_members_path(household_id: households(:home))

      give_login = new_household_member_login_path(household_id: households(:home), member_id: memberships(:sofia_in_home))
      password_link = household_member_password_link_path(household_id: households(:home), member_id: memberships(:eli_in_home))
      assert_select "#members .Box-row", text: /Sofia Child/ do
        assert_select ".d-md-flex a[href=?]", give_login, text: "Give a login"
        assert_select "#member-#{memberships(:sofia_in_home).id}-menu-list a[href=?]", give_login, text: "Give a login"
      end
      assert_select "#members .Box-row", text: /Eli Child/ do
        assert_select ".d-md-flex form[action=?] button", password_link, text: "New password link"
        assert_select "#member-#{memberships(:eli_in_home).id}-menu-list form[action=?][data-turbo=false] button", password_link, text: "New password link"
      end
      # Each once from md up, and once in the row's phone menu.
      assert_select "a", text: "Give a login", count: 2
      assert_select "button", text: "New password link", count: 2
    end
  end

  test "on a phone a row's actions are behind one \"…\" named for the member, and a row with none has no \"…\"" do
    sign_in identities(:head)

    get household_members_path(household_id: households(:home))

    assert_select "button[aria-label='Actions for Eli Child']"
    assert_select "button[aria-label='Actions for Sofia Child']"
    assert_select "button[aria-label='Actions for Charlie Child']" # Charlie has no login either
    assert_select "button[aria-label='Actions for Hannah Head']", count: 0
    assert_select "button[aria-label='Actions for Sam Spouse']", count: 0
  end

  test "a head's phone menu reads a child's personal study while the child has a study AI grant" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))
    sign_in identities(:head)

    get household_members_path(household_id: households(:home))

    assert_select "#member-#{memberships(:eli_in_home).id}-menu-list", text: /New password link.*Read Eli's personal study/m do
      assert_select "a[href=?]", household_member_personal_studies_path(household_id: households(:home), member_id: memberships(:eli_in_home)),
                    text: "Read Eli's personal study"
    end
  end

  test "a child sees neither Give a login nor New password link" do
    sign_in identities(:eli)

    get household_members_path(household_id: households(:home))

    assert_select "a", text: "Give a login", count: 0
    assert_select "button", text: "New password link", count: 0
  end

  test "a child sees no one's email, and no invitations" do
    sign_in child_identity

    get household_members_path(household_id: households(:home))

    assert_select "#members .Box-row", count: 5
    assert_not_includes response.body, "head@example.com"
    assert_not_includes response.body, "Signs in as"
    assert_not_includes response.body, "No login"
    assert_select "#invitations", count: 0
    assert_not_includes response.body, invitations(:ana).email
    assert_select "#members .Box-row .d-md-none", text: "Child", count: 3
    assert_select "button[aria-label^='Actions for']", count: 0
  end

  test "open invitations are listed newest first, with resend and cancel for those the viewer may" do
    travel_to Time.zone.local(2026, 11, 14, 12)
    invitations(:ana).update_columns(created_at: 2.days.ago, expires_at: Time.zone.local(2026, 11, 21, 12))
    invitations(:expired).update_columns(created_at: 9.days.ago, expires_at: Time.zone.local(2026, 11, 10, 12))
    newest = households(:home).invitations.create!(invited_by: users(:spouse), email: "rosa@example.com")
    sign_in identities(:spouse)

    get household_members_path(household_id: households(:home))

    assert_select "#invitations h2", "Invited, not joined yet"
    assert_select "#invitations .Box-row", count: 3
    assert_select "#invitations", text: /rosa@example.com.*ana.ortiz@example.com.*luis@example.com/m
    assert_select "#invitations .Box-row", text: /ana.ortiz@example.com\s*Invited by Hannah · until Nov 21/
    assert_select "#invitations .Box-row .color-fg-attention", "Expired on Nov 10"
    assert_select "button[aria-label='Resend to #{newest.email}']", "Resend"
    assert_select "button[aria-label='Cancel the invitation to #{newest.email}']", "Cancel"
    assert_select "button[aria-label$='#{invitations(:ana).email}']", count: 0
  end

  test "on a phone an invitation's second line has its role, and its \"…\" holds Resend, then Cancel invitation… asking first" do
    travel_to Time.zone.local(2026, 11, 14, 12)
    invitations(:ana).update_columns(expires_at: Time.zone.local(2026, 11, 21, 12))
    invitations(:expired).update_columns(expires_at: Time.zone.local(2026, 11, 10, 12))
    sign_in identities(:head)

    get household_members_path(household_id: households(:home))

    ana = invitations(:ana)
    assert_select "#invitations .Box-row .d-md-none", text: "Adult · invited by Hannah · until Nov 21"
    assert_select "#invitations .Box-row .d-md-none.color-fg-attention", text: "Adult · expired on Nov 10"
    assert_select "#invitations .Box-row .d-none.d-md-flex .Label", count: 2
    assert_select "button[aria-label='Actions for #{ana.email}']"
    assert_select "#invitation-#{ana.id}-menu-list", text: /Resend.*Cancel invitation…/m do
      assert_select "form[action=?] input[name=_method][value=patch]", household_invitation_path(household_id: households(:home), id: ana)
      assert_select "li[role=presentation]" # the divider
      assert_select "button.ActionListContent[data-show-dialog-id=?]", "cancel-invitation-#{ana.id}", text: "Cancel invitation…"
    end
    assert_select "#invitation-#{invitations(:expired).id}-menu-list button", text: "Send again"
    assert_select "dialog#cancel-invitation-#{ana.id}" do
      assert_select "form[action=?] input[name=_method][value=delete]", household_invitation_path(household_id: households(:home), id: ana)
      assert_select "button", text: "Cancel invitation"
    end
  end

  test "an expired invitation offers Send again to a head" do
    sign_in identities(:head)

    get household_members_path(household_id: households(:home))

    assert_select "button[aria-label='Send again to #{invitations(:expired).email}']", "Send again"
    assert_select "button[aria-label='Resend to #{invitations(:ana).email}']", "Resend"
  end

  test "no invitations, no Invited section" do
    households(:home).invitations.delete_all
    sign_in identities(:head)

    get household_members_path(household_id: households(:home))

    assert_select "#invitations", count: 0
  end

  test "a head sees the add member form" do
    sign_in identities(:head)

    get new_household_member_path(household_id: households(:home))

    assert_response :success
    assert_select "form[action='#{household_members_path(household_id: households(:home))}']"
  end

  test "a head adds a child: one new User, no Identity, one child Membership" do
    sign_in identities(:head)

    assert_difference [ "User.count", "Membership.count" ], 1 do
      assert_no_difference "Identity.count" do
        post household_members_path(household_id: households(:home)), params: { member: { name: "Baby Head", role: "child" } }
      end
    end

    membership = households(:home).memberships.order(:created_at).last
    assert membership.child?
    assert_equal "Baby Head", membership.user.name
    assert_nil membership.user.identity
    assert_redirected_to household_members_path(household_id: households(:home))
  end

  test "an adult can add a member without a login" do
    sign_in identities(:spouse)

    assert_difference [ "User.count", "Membership.count" ], 1 do
      post household_members_path(household_id: households(:home)), params: { member: { name: "Rosa Spouse", role: "adult" } }
    end

    assert households(:home).memberships.joins(:user).find_by!(users: { name: "Rosa Spouse" }).adult?
    assert_redirected_to household_members_path(household_id: households(:home))
  end

  test "a child is refused with an alert and nothing is created" do
    sign_in child_identity

    assert_no_difference [ "User.count", "Membership.count" ] do
      post household_members_path(household_id: households(:home)), params: { member: { name: "Baby Head", role: "child" } }
    end

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "a blank name re-renders with 422" do
    sign_in identities(:head)

    assert_no_difference [ "User.count", "Membership.count" ] do
      post household_members_path(household_id: households(:home)), params: { member: { name: " ", role: "adult" } }
    end

    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /can't be blank/
    assert_select "option[value='adult'][selected]"
  end

  test "the head role can't be given here: 400 and nothing is created" do
    sign_in identities(:head)

    assert_no_difference [ "User.count", "Membership.count" ] do
      post household_members_path(household_id: households(:home)), params: { member: { name: "Second Head", role: "head" } }
    end

    assert_response :bad_request
  end

  test "a head of another household gets 404" do
    sign_in identities(:outsider)

    assert_no_difference "Membership.count" do
      post household_members_path(household_id: households(:home)), params: { member: { name: "Intruder", role: "adult" } }
    end

    assert_response :not_found
  end

  test "a head removes an adult and comes back to Members and roles: inactive, their shares here gone, their open steps released" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    note.share_with(households(:home))
    sign_in identities(:head)

    assert_no_difference -> { Membership.count } do
      delete household_member_path(household_id: households(:home), id: memberships(:spouse_in_home))
    end

    assert_redirected_to household_settings_members_path(household_id: households(:home))
    assert_equal "Sam Spouse was removed from the household.", flash[:notice]
    assert_not memberships(:spouse_in_home).reload.active?
    assert_empty note.reload.shared_households
    assert_empty goal_steps(:share_learned).reload.assignees
  end

  test "a head removes themselves while another head stays and goes to their households" do
    memberships(:spouse_in_home).update!(role: :head)
    sign_in identities(:head)

    delete household_member_path(household_id: households(:home), id: memberships(:head_in_home))

    assert_redirected_to households_path
    assert_equal "You left the The Head Family.", flash[:notice]
    assert_not memberships(:head_in_home).reload.active?
  end

  test "the last head can't remove themselves, and the row says why" do
    sign_in identities(:head)

    delete household_member_path(household_id: households(:home), id: memberships(:head_in_home)), as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=?]", ActionView::RecordIdentifier.dom_id(memberships(:head_in_home))
    assert_select ".FormControl-inlineValidation", text: /A household needs at least one active head/
    assert memberships(:head_in_home).reload.active?
  end

  test "an adult is refused removing a member" do
    sign_in identities(:spouse)

    delete household_member_path(household_id: households(:home), id: memberships(:child_in_home))

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
    assert memberships(:child_in_home).reload.active?
  end

  test "removing a member of another household is 404" do
    sign_in identities(:head)

    delete household_member_path(household_id: households(:home), id: memberships(:outsider_in_other))

    assert_response :not_found
    assert memberships(:outsider_in_other).reload.active?
  end

  private
    # Charlie Child has no login in the fixtures (a young child needs none), so give them one here.
    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
