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
end
