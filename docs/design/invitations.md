# Invitations, child logins and account settings

How people join a household, how a child gets a login, and the settings pages for a person and for a household. Read this before touching `Invitation`, usernames on `Identity`, password links, the Members page, account settings or household settings. Stories live under the **INVITES-01** epic. Mockup frames are in `docs/design/invitations/`.

This builds on `docs/design/users.md` (the four core models, gotchas 5, 6, 13 and 18) and replaces its planned `Invitation` row for household invitations. Inviting a guest to one family study session comes later, with guests.

## Decisions (Casey, 14 Nov)

- **Heads and adults can invite** adults by email. Only heads can invite someone as a head.
- **One sign-in field takes an email or a username.** A child signs in with a username, so a child never needs an email address.
- **Heads and adults can give a child a login** and make a new password link for a child.
- **A child's password link lasts 12 hours.**
- **Children can't start a household.**
- **Account settings:** name, time zone, email, password, "My households" and leaving one. **Household settings** (heads only): name, time zone, roles, removing a member. Deleting an account is a later epic.

## What INVITES-01 builds, and what comes later

| In INVITES-01 | Later |
| --- | --- |
| Sign in with email or username | Guests invited to one family study session |
| Invite an adult (or, by a head, a head) by email; resend, cancel | Deleting your account (erasure, gotcha 10) |
| Accept: new account, existing account, wrong email, expired | Shared custody: linking one child to a second household |
| Give a child a login with a username; password links | Two-factor sign-in |
| Account settings: profile, sign-in details | Invitation reminders |
| My households and leaving one | |
| Household settings: name, time zone | |
| Roles and removing members | |

## Who can do what

| Action | Head | Adult | Child |
| --- | --- | --- | --- |
| Add a member without a login | yes | yes (**new**: was heads only) | no |
| Invite by email as an adult | yes | yes | no |
| Invite by email as a head | yes | no | no |
| Resend or cancel an invitation | yes, any | their own | no |
| Give a child a login; make a new password link | yes | yes | no |
| Change roles, remove a member, edit household settings | yes | no | no |
| Start a new household | yes | yes | no, if all their seats are child seats |
| Edit their own account settings | yes | yes | yes, name and password (no email) |
| Leave a household | yes, unless the last head | yes | no (a head or adult removes them) |

Everything household-scoped is reached through `Current.household`; anything from another household is a 404 (CLAUDE.md, Scoping).

## Signing in with an email or a username

- `identities.username`: string, nullable, unique (index on `lower(username)`), check `username ~ '^[a-z0-9][a-z0-9.-]{2,29}$'`. Normalized to lowercase. It never contains `@`, so the sign-in field can tell the two apart.
- `identities.email` becomes nullable (existing `""` values migrate to `NULL`). Check `num_nonnulls(email, username) >= 1`: every login has one or both.
- Devise: `authentication_keys = [:login]`. `Identity.find_for_database_authentication` looks up by email when the value contains `@`, otherwise by username, both case-insensitively. Override `email_required?` (false when a username is set) and `confirmation_required?` (false when there's no email).
- Lockable: `unlock_strategy = :time` for username-only logins, which can't receive an unlock email; `:both` stays for email logins (`Identity#unlock_strategy_enabled?` override).
- Recoverable ("Forgot password?") works only for email logins. A username-only login gets a password link from a head or adult instead.
- The sign-in field's label is **Email or username** (frame `sign-in-username.png`), `autocomplete="username"`.

## Invitations

**Inviting** (`GET/POST /:household_id/invitations`, `InvitationsController#new/create`; resend `PATCH`, cancel `DELETE`): frame `invite.png`. Email and "Their role" (Adult; Head only for heads), the line "To add a child, use Add without a login, then give them a login with a username", and what happens next. The Members page lists open invitations under "Invited, not joined yet" with Resend (Send again when expired) and Cancel (frame `members.png`). The Members page shows "Invite by email" and "Add without a login" to heads and adults (frame `members-adult.png` is the adult's view).

### `Invitation`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null, cascade | Session invitations for guests come later and will relax this with gotcha 9's two-FK check |
| `email` | string | not null; `normalizes :email` (strip, downcase) | Compared normalized at acceptance (gotcha 18) |
| `role` | string | not null, check in (`adult`, `head`) | Children get usernames, not invitations |
| `invited_by_id` | uuid | FK → users, not null | "Invited by Daniel" |
| `expires_at` | datetime | not null | 7 days after it was last sent; shown as "until Nov 21" or "Expired on Nov 10" |
| unique index | | (`household_id`, `email`) | One open invitation per address per household |

- `generates_token_for :acceptance, expires_in: 7.days { expires_at }`. Resending sets a new `expires_at`, so links from earlier emails stop working.
- Accepting, declining or cancelling **deletes** the invitation. The membership's `created_at` records when someone joined.
- Inviting an address that already belongs to an active member of the household is a validation error on Email: "Already a member of this household."
- `InvitationMailer#invite` (`deliver_later`): subject "<inviter> invited you to the <household> household on Aglowy", one button, the deadline and the address it's for (frame `invitation-email.png`). Development uses letter_opener; production sends through Amazon SES in the deploy epic. The sender comes from `config.x.mail_from`, which replaces Devise's placeholder `mailer_sender`.
- `rate_limit to: 20, within: 1.hour` on creating and resending invitations.

### Accepting

All at `/invitation?token=…` (outside any household, focused layout; the token is a query parameter, never a path segment, see Traps): `InvitationAcceptancesController#show` renders the right case, `#create` joins (or signs up and joins), `#destroy` declines. The household-side `InvitationsController` above is a different controller under `/:household_id`. Frames `accept-*.png`, `invitation-invalid.png`, `phone-accept.png`.

| The visitor is | They see | What happens |
| --- | --- | --- |
| Signed out, and no login has that email | "Join the Rivera household": name and password; the email shown read-only (frame `accept-new-account.png`) | `InvitationSignup` (an Active Model, like `Signup`) creates a confirmed Identity with the invitation's email, a User and the Membership with the invited role, deletes the invitation, signs them in and goes to the household. It never creates a household (gotcha 13). The email comes from the invitation, never from the form |
| Signed out, and a login has that email | "Sign in to accept", then back to this page (`store_location_for`) | As below |
| Signed in with the invited email | "Join the Rivera household?" Join / Decline (frame `accept-existing-account.png`) | Join creates the membership, or reactivates an inactive one with the invited role. Old note and goal shares stay ended (they were deleted when the person left). Decline deletes the invitation |
| Signed in with another email | A warning naming the invited address partly hidden (`d•••••@example.com`) and a Sign out button (frame `accept-wrong-email.png`) | Nothing. The invitation stays open |
| Anyone, with an expired, cancelled, used or tampered token | "This invitation can't be used" (frame `invitation-invalid.png`) | Nothing. The page doesn't say which, or which household |

Showing an invitation and joining both look it up with `Invitation.find_acceptable(token)`: `find_by_token_for(:acceptance, token)` plus a check that `expires_at` hasn't passed (the token's own 7-day lifetime starts when the email job generates it, so it can outlive the deadline shown in the email). Joining takes `household.lock!` and calls `find_acceptable` again inside the transaction, so a link made stale by a resend or past its deadline is rejected and a double click can't create two memberships. Cancelling (household side), declining and resending take the same `household.lock!` before they delete or change the invitation, so a cancel at the same moment as a join either lands first (the join finds nothing) or after (the person has joined and the cancel finds nothing).

## Child logins

- **Give a login** (`GET/POST /:household_id/members/:member_id/login`, `Members::LoginsController`): for a child member with no Identity. Username field with the rules above, then "Create login". Creates an Identity with the username, no email, an unusable random password and `confirmed_at` set, and shows the password link (frames `child-login.png`, `child-login-link.png`). The form says Aglowy keeps only the child's name, username and password.
- **New password link** (`POST /:household_id/members/:member_id/password_link`, `Members::PasswordLinksController`): for a child member whose login has no email. Shows the same link page.
- **The link:** `identity.generate_token_for(:password_setup)`, `generates_token_for :password_setup, expires_in: 12.hours { encrypted_password.last(10) }`. Setting a password changes `encrypted_password`, so a link works once. The page shows it in a read-only field with "Copy link" and says to open it on the child's device and not share it outside the family. It's never emailed, logged or stored.
- **Choosing a password** (`GET/PATCH /password_setup?token=…`, `PasswordSetupsController`, focused layout, signed out allowed): "Hi Eli! Choose your password", the username shown, password and "Type it again", then signs them in (frame `child-password.png`). The update takes `identity.lock!` and resolves the token again inside the transaction, so two submissions with one link can't both set a password. An expired or used link shows "Ask a parent to make a new link."
- Members page: each row says how the person signs in ("maria@example.com", "Signs in as eli.rivera", "No login"), with "Give a login" or "New password link" on child rows for heads and adults (frame `members.png`).

## Account settings

At `/account` (outside any household, focused layout, frames `account-settings.png`, `leave-household.png`). Reached from the person's name in the sidebar footer. A "Back to <household>" link returns to the last household.

| Section | Route | Fields | Rules |
| --- | --- | --- | --- |
| Profile | `GET/PATCH /account` (`AccountsController`) | Name, your time zone | Updates `User`. The time zone is for personal reminders; studies use the household's |
| Signing in | `GET/PATCH /account/sign_in` (`Accounts::SignInsController`) | Email, new password, current password | `identity.update_with_password`. An email change is reconfirmed by Devise (`reconfirmable`): a Banner says where the link went and that the old email works until then. Children see their username read-only and only the password fields |
| My households | `DELETE /account/memberships/:id` (`Accounts::MembershipsController`) | Each household with the person's role and Leave | Loaded through `Current.user.memberships.active`. Leave opens a Dialog explaining what happens, then calls `membership.deactivate`. The last head is refused: "Make someone else a head before you leave." Children don't see Leave, and the controller refuses them |

Leaving runs the existing `Membership#deactivate`, including the steps other epics add to it (meeting-note and goal sharings deleted, open goal steps released). After leaving the household you were in, go to the households page.

## Household settings (heads)

> Since KIDS-01, adults also open this page, to see only its Meetings section (meeting times) and Children section (the meeting helper switch). Everything below stays heads-only. See `docs/design/meeting-helper.md`.

At `/:household_id/settings` (`Households::SettingsController`, household layout, frame `household-settings.png`). "Household settings" in the sidebar footer, for heads and adults since KIDS-01 (`docs/design/app-shell.md`).

- **Name and time zone.** Changing the time zone keeps every future family study session at the same local wall-clock time in the new zone: in one transaction holding `household.lock!`, recompute `scheduled_at` and `recurrence_at` of sessions after now from their local time in the old zone (gotcha 14). Past sessions don't move. The hint says so: "Changing it keeps each study at the same local time."
- **Members and roles.** A row per active member with a role select and Remove. `PATCH /:household_id/members/:member_id/role` (`Members::RolesController`) calls `membership.change_role`; `DELETE /:household_id/members/:id` calls `membership.deactivate`. Both keep the last-head guard (gotcha 5); a refusal shows "A household needs at least one active head" on that row.

## Traps

- **Never trust an email from the form at acceptance.** The account's email is the invitation's, and a signed-in person's email is compared normalized.
- **Tokens are bearer secrets.** Invitation and password-link tokens travel as a `token` query parameter, never in the URL path. `filter_parameters` already filters `token`, and Rails' `filtered_path` (which both the Rails log and Lograge's `path` use) filters query strings but **not** path segments, so a `/invitations/:token` route would write live tokens to the logs. A request test checks the logged line shows `token=[FILTERED]`. Tokens are never stored in the database, and the password link is shown only to the head or adult who made it.
- **The invalid-invitation page says nothing about the household,** so a guessed or old link reveals nothing.
- **Username-only logins have no email,** so any code that emails an identity (Devise mailers, future notifications) must skip them.
- **Children and the "New household" item:** hide it and refuse it in `HouseholdPolicy#create?`, which has no membership outside a household, so the rule lives on the user: `User#can_start_household?` is true when the person has no memberships at all, or has at least one non-child membership, active or not. So an adult who has left every household can start a new one, and someone who has only ever had child seats can't, even after leaving.
- **Rejoining reactivates, never duplicates,** because of the unique (`household_id`, `user_id`) index on memberships.

## States each story checks

- Viewer: head, adult, child, non-member (404), signed out
- Invitation: new, resent, expired, cancelled, accepted; same address invited to two households
- Login: email only, username only, both
- Leaving: an adult, the last head (refused), a child (refused), someone with shared notes and goals
- Desktop and phone; light and dark
