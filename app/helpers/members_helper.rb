module MembersHelper
  # "maria@example.com", "Signs in as eli.rivera" or "No login" (frame members.png). Show it only to heads and
  # adults: children don't see other members' emails.
  def how_they_sign_in(user)
    if (identity = user.identity).nil?
      "No login"
    else
      identity.email || "Signs in as #{identity.username}"
    end
  end

  # A member's second line on a phone: "Head · maria@example.com", "Child · signs in as eli.rivera", or the role alone
  # for someone without a login (docs/design/phone.md, Members). Without show_sign_in (a child viewing), the role alone.
  def role_and_sign_in(membership, show_sign_in:)
    identity = membership.user.identity if show_sign_in
    login = identity && (identity.email || "signs in as #{identity.username}")
    [ membership.role.humanize, login ].compact.join(" · ")
  end
end
