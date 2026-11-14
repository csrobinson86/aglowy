# Code review rules

Read by the `code-reviewer` subagent (`.claude/agents/code-reviewer.md`), by the PR review workflow, and by Claude Code's managed Code Review if it's turned on. Humans can use it too.

A review **advises**; Casey decides what merges. The reviewer never edits code.

## How to report

Every finding states:

- **Severity:** Blocker, Major or Minor (below)
- **Where:** `path/to/file.rb:LINE`
- **Rule:** the section of this file, `CLAUDE.md` or `docs/design/` it breaks
- **Evidence:** what the code does, and for any claim about Rails or Ruby behavior, the source (Rails API docs, the Rails source file, or the Ruby docs). No unsupported assertions
- **Fix:** the smallest change that resolves it

| Severity | Meaning | Examples |
| --- | --- | --- |
| **Blocker** | Must not merge | Security hole, cross-household leak, data loss, missing authorization, failing or skipped tests, coverage gate weakened |
| **Major** | Should be fixed in this PR | Pattern violation from `CLAUDE.md`, missing acceptance test the story named, constraint enforced only by a validation |
| **Minor** | Worth fixing, fine as a follow-up | Unclear naming, a missing `preloaded` scope, a test that's hard to read |

Don't report formatting (RuboCop owns it) or personal preferences not written down here, in `CLAUDE.md`, or in `docs/design/`. If a rule seems missing, say so as a suggestion for `CLAUDE.md`, not as a finding.

End with a one-line verdict: **Ready to merge**, **Merge after fixes** (Majors only), or **Do not merge** (any Blocker).

## 1. Story fit

- The PR does what its story (GitHub issue) says, and nothing outside its "Out of scope" list.
- Every acceptance test the story names exists, under that name or an obvious equivalent.
- The diff is small enough to review (aim under ~400 changed lines excluding `db/schema.rb`). If it's bigger, say so.
- Nothing contradicts `docs/product/vision.md` (for example, no tracking, no billing).

## 2. Patterns (`CLAUDE.md`)

- Business logic in models, concerns and POROs in `app/models`. No `app/services/`, no `.call` objects.
- Thin controllers; CRUD resources instead of custom actions.
- Devise is on `Identity`: no `current_user`, `authenticate_user!` or `sign_in(:user, …)`.
- Roles live on `Membership` (household) or `identities.staff` (platform). No role on `User`.
- Personal content belongs to `User`; household content to `Household`; nothing personal points at a `Membership`.
- State as records, except the documented `memberships.active`.
- Views: ERB, Primer components, BEM for custom styles, no inline styles (mailer templates excepted), strict locals on partials.
- Minitest + fixtures only.

## 3. Security (Aglowy-specific)

Treat each as a Blocker unless clearly harmless.

- **Household scoping.** Every household page loads its household through `Current.user.memberships.active.find_by!(household_id: …)` or `Current.household`. Any `Household.find`, `Membership.find`, or lookup by a bare `params[:id]` outside `Current` is a cross-household leak.
- **404, not 403,** for anything in a household the person doesn't belong to.
- **Authorization.** Every controller action calls `authorize` (or is a documented public page that skips it). Policies read the membership, never a role on `User`, and don't call methods on a nil membership.
- **Strong parameters.** No `permit!`; no permitting `role`, `staff`, `user_id`, `household_id` or `active` from user input unless the story says so and a policy guards it.
- **SQL.** No string interpolation into SQL (`where("… #{x}")`, `order(params[:x])`). Use bound parameters or hashes.
- **Output.** No `html_safe` or `raw` on user content. Links accept only `http` and `https`.
- **Sessions and staff.** Staff checks use `current_identity.staff?`. Impersonation stores the staff identity in the session and can always be stopped.
- **Secrets.** No keys, tokens or passwords in code, fixtures (other than test passwords) or logs. New sensitive params added to `filter_parameter_logging.rb`.
- **Files** (when Active Storage arrives): served through a controller that runs the policy first; size checked before upload.
- **Tokens:** invite and mute links use `generates_token_for`; nothing raw stored or passed into job arguments.
- **Mass deletion:** never `has_many :users, dependent: :destroy` on `Household` (gotcha 10).

## 4. Data integrity

- Every rule that must always hold is enforced in the database (not null, unique index, check constraint, foreign key), with a validation on top only for friendly form errors.
- Each new constraint has a test that bypasses validations (`insert!` or `update_column`), one violating statement per test, last.
- Multi-row changes run in one transaction. Rules that can race (the last head) take a row lock.

## 5. Tests

- `bin/rails test:all` passes. Coverage stays at 100% lines; no new SimpleCov filters or `# :nocov:` without Casey's written approval in the PR.
- Tests go through public interfaces (model, policy, request/integration, component, system).
- Every new page has a system test calling `assert_accessible`.
- Policy changes have a test for each role (head, adult, child, nil membership).

## 6. Accessibility

- Landmarks (`<main>`, `<nav>`, …), labelled inputs, `alt` on images, `lang` on `<html>`.

## 7. UI (`docs/design/app-shell.md`)

- Household pages render in the `household` layout (the app shell); pages outside a household use the `focused` layout.
- A Primer component is used wherever one exists: navigation, menus, dialogs, page headers, empty states, flashes, banners, buttons. Custom Sass only for what Primer lacks, in BEM, built from primitives.
- Navigation lists only pages that exist, and the right item is selected (`aria-current="page"`).
- Every state the story names is shown, in a ViewComponent preview or a system test screenshot. The PR attaches desktop and phone screenshots (light, plus dark when colours change), and they match the mockup frames in `docs/design/app-shell/`.
- At phone width nothing scrolls sideways, touch targets are at least 44px, and long names truncate instead of breaking the layout.
- Hiding a link or button is never the only check: the controller behind it authorizes.

## 8. Privacy

- No analytics or tracking code, gems or scripts.
- Children's records hold only what the story requires.
- Personal text (notes, goals) is encrypted when those features arrive.
