# Go bags

A household can write down its emergency go bags in Aglowy: what's in each bag, what still needs buying, where things are kept, and when something needs replacing. Stories live under the **GOBAGS-01** epic. Frames are in `docs/design/go-bags/` (README there), and the editable mockups are in the "Go bags (proposal)" row on the design canvas.

Read this before touching `GoBag`, its items, categories or the go-bag reminder.

## Decisions (Casey, 23 Nov)

- **A feature of its own, not a goal.** Go bags get their own page in the sidebar. They aren't part of Goals and use none of the goal models.
- **As many bags as the household wants.** For example, one for the family, one for the car and one for each child. Items belong to one bag.
- **Use-by dates, with a reminder.** An item can have a use-by date. A month before it, heads and adults get one notification.
- **Suggested items.** A new bag can start with a list of common go-bag items, in Aglowy's own words. People remove what they don't need.
- **Children can look, but can't change anything.** Heads and adults change bags, items and categories.
- **Categories belong to the household.** Heads and adults add, rename and delete them.
- **Ticking an item's box saves straight away.**

## How it fits the vision

Go bags help a family get ready for a disaster together. They serve vision goal 3 ("households work the way real families do": parents run it, children see it) and goal 4 (calm and private). The guardrails come from the vision:

- **No nagging.** One reminder for each use-by date and nothing else: no reminder for an empty bag or for unbought items, and no streaks.
- **Private.** Everything people type here is encrypted: bag names, places, category names, item names and how many. Use-by dates aren't, as goals' target and due dates aren't, because the database has to find the items whose date is coming up; a date alone says nothing about the item. The reminder keeps a copy of that date (The use-by reminder). A household's bags are invisible to non-members, who get a 404.
- **Linked, never copied.** The guide is the *Awake!* article "When Disaster Strikes—Steps That Can Save Lives" (g17 No. 5), linked on wol.jw.org. Aglowy shows its title and link only. The suggested items are Aglowy's own list, not copied from the article (vision, non-goals; `docs/design/ai.md`). Aglowy never fetches the page.

## What GOBAGS-01 builds, and what comes later

| In GOBAGS-01 | Later |
| --- | --- |
| Go bags: a list of bags, a bag's page with its items by category | Keeping go bags on the device for offline use (`docs/design/offline.md`), useful when the network is down in an emergency |
| Items: name, category, how many, have it, kept somewhere else, use-by date | Printing a bag's list or the To buy list |
| Ticking "we have it" from the row | Reordering categories and items |
| To buy: every item still to get, across all bags, plus anything due for replacing | Copying a bag |
| Categories in Settings → Go bags | Go bags on Home |
| Suggested items for a new bag | AI help of any kind |
| One reminder a month before a use-by date | |

## Who can do what

All reached through `Current.household`.

| Action | Head | Adult | Child |
| --- | --- | --- | --- |
| See the bags, their items and how ready each bag is | yes | yes | yes, read-only |
| Create, edit and delete a bag | yes | yes | no |
| Add, edit and remove items; tick "we have it" | yes | yes | no |
| See To buy | yes | yes | no |
| Add, rename and delete categories (Settings → Go bags) | yes | yes | no |
| Get the use-by reminder | yes | yes | no |

- A bag from another household is a 404, never a 403 (CLAUDE.md, Scoping).
- A child who opens a page they can't use (New bag, To buy, an item's edit page, Settings → Go bags) gets the usual refusal, `not_authorized`. It isn't a 404, because they're a member of the household.
- Hiding a button is not authorization. Each controller authorizes.

## Words

- **Ready:** we have the item, whether it's in the bag or kept somewhere else. "18 of 24 ready".
- **To get:** we don't have the item yet.
- **Use by soon:** we have it, and its use-by date is within 30 days (`GoBag::Item::SOON = 30.days`) or has passed, in the household's time zone (`household.today`).
- **To buy:** to get, or use by soon. Both need a trip to the shop. A bag's "4 to buy", the To buy page and the "7 things to buy" card all count the same things (`GoBag::Item#to_buy?`, and a `to_buy` scope built the same way).

## Models

### `GoBag`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null, cascade | |
| `name` | string | not null, `encrypts :name` | "Family go bag" |
| `kept_at` | string | nullable, `encrypts :kept_at` | Where the bag is kept: "the hall closet". Shown as "Kept in the hall closet" |
| `for_user_id` | uuid | FK → users, nullable, `on_delete: :nullify` | The person it's for. Null means everyone. Must be an active member of the household (validated under `household.lock!`, so it can't land just after that person leaves) |
| `created_by_id` | uuid | FK → users, not null | |

- Bags are listed in the order they were made (by id, which is UUIDv7). Never sort by name in SQL, since it's encrypted.
- At most 20 bags in a household (validated under `household.lock!`).
- `GoBag.preloaded` includes items with their acquisitions and categories, so the list and a bag's page count without a query per item.
- `Membership#deactivate` sets `for_user_id` to null on that household's bags for the person leaving, in the same transaction (`user.stop_being_go_bag_owner_in(household)`, an explicit step beside the others, not a callback). The bag then reads "For everyone".

### `GoBag::Category`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null, cascade | Shared by all the household's bags |
| `name` | string | not null, `encrypts :name` | "Water and food" |
| `position` | integer | not null | New categories go last. Listed by position |
| `suggestion_key` | string | nullable, unique with `household_id` | Set on categories made from the suggestions (`water_food`), so a later bag's suggestions reuse the same category even after it's renamed. Not shown anywhere |

- At most 50 categories in a household (validated under `household.lock!`, which also sets the next `position`).
- `category.destroy` keeps the items: `go_bag_items.category_id` is `on_delete: :nullify`, so they show under "No category".

### `GoBag::Item`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `go_bag_id` | uuid | FK → go_bags, not null, cascade | |
| `category_id` | uuid | FK → go_bag_categories, nullable, `on_delete: :nullify` | Must be one of the bag's household's categories (validated). Null means "No category" |
| `name` | string | not null, `encrypts :name` | "Bottled water" |
| `quantity` | string | nullable, `encrypts :quantity` | Free text: "6 gallons", "2 packs" |
| `stored_at` | string | nullable, `encrypts :stored_at` | Where it's kept when it isn't in the bag: "the bathroom cabinet". Blank means it's in the bag |
| `use_by` | date | nullable | |

- On a bag's page, items are grouped by category in the categories' order, with "No category" last. Within a group they're in the order they were added.
- At most 200 items in a bag (validated under `household.lock!`).

### `GoBag::Item::Acquisition`

"We have it" is a record, not a boolean (CLAUDE.md, State as Records).

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `item_id` | uuid | FK → go_bag_items, not null, unique, cascade | One per item |
| `acquired_by_id` | uuid | FK → users, not null | Who ticked it |
| `created_at` | datetime | | |

- `item.acquire(by:)` uses `create_or_find_by!`, so two adults ticking at once leave one record. `item.unacquire` deletes it. Both are safe to repeat.
- Scopes on `GoBag::Item`: `acquired`, `to_get` (`where.missing(:acquisition)`), `use_by_soon(today)` and `to_buy(today)`.
- Saving an item from its form takes the form's "We have it" box: `item.save_with(have:, by:)` saves the item and creates or deletes the acquisition in one transaction. It's an explicit method, not a `before_save`.

### `GoBag::Suggestions`

A PORO in `app/models/go_bag/suggestions.rb` that reads `config/go_bag_suggestions.yml`: the categories with their key and name, and each category's items with a name and an optional quantity. The file also holds the guide's title and wol.jw.org link. Nothing else from jw.org is stored.

`household.go_bags.create_with_suggestions(attributes, by:)` creates the bag. When "Start with suggested items" is ticked, in the same transaction and under `household.lock!` it:

1. Finds each suggested category by `suggestion_key`, or creates it last.
2. Adds the suggested items to the bag, none of them acquired, so they all start as "To buy".

The list (Aglowy's own words; the stories can tidy the wording):

| Key | Category | Items (how many) |
| --- | --- | --- |
| `water_food` | Water and food | Bottled water (1 gallon a person a day, for 3 days) · Food that keeps, like cans or dried food (3 days) · Can opener · Energy bars · Cups, plates and spoons |
| `light_power` | Light, power and radio | Flashlight · Spare batteries · Battery or wind-up radio · Phone charger and power bank |
| `first_aid` | First aid and medicine | First-aid kit · Daily medicines (a week) · Copies of prescriptions · Spare glasses · Hand sanitizer |
| `documents_money` | Documents and money | Copies of IDs and important papers, in a waterproof bag · Cash in small bills · Emergency phone numbers on paper · Local map with your meeting place marked |
| `clothing_shelter` | Clothing and shelter | Change of clothes · Sturdy shoes · Rain poncho · Emergency blanket · Work gloves · Dust masks |
| `tools` | Tools and safety | Whistle · Multi-tool · Duct tape · Spare keys |
| `hygiene` | Hygiene | Toothbrushes and toothpaste · Wet wipes · Toilet paper · Rubbish bags |
| `children` | For children | Diapers and wipes · A small toy or book · A favorite snack |
| `worship` | Comfort and worship | Bible · Notebook and pen |

## Pages

All under `/:household_id` in the household layout (`docs/design/app-shell.md`), with Primer components and Primer form classes. On a phone, pages follow `docs/design/phone.md`.

**Sidebar:** "Go bags" (`briefcase` octicon) in the **Household** group, after Family goals, for everyone. It's added in the story that builds the list.

| Page | Route | What's on it |
| --- | --- | --- |
| Go bags | `GET /:household_id/go_bags` (`GoBagsController#index`) | Frame `go-bags.png`. Title "Go bags" with "+ New" beside it (heads, adults), and the muted line "Children can look; adults keep them up to date." For heads and adults, an attention card "7 things to buy" with "Across 3 bags · 2 need replacing soon", linking to To buy (hidden when there's nothing to buy). A BorderBox row per bag: the bag icon, the name, and one muted line with where it's kept and "4 to buy" (or "All ready"). Children see the same rows with "18 of 24 ready" instead, and no card. Then a "Categories" link to Settings → Go bags (heads, adults), and the guide: "Ideas for what to pack:" and the article's title linking to wol.jw.org, opening in a new tab. A Blankslate when there are no bags: "No go bags yet", with "New go bag" for heads and adults |
| New go bag | `GET /:household_id/go_bags/new` | Frame `go-bag-new.png`. `GoBagForm`: Name; Where it's kept (caption "So anyone can grab it in a hurry"); For (a select: Everyone, then each active member); "Start with suggested items" (a check box, with the caption "About 35 common go-bag items, grouped and marked to buy. Remove what you don't need."), ticked when the household has no bags yet. "Create bag" goes to the bag |
| A bag | `GET /:household_id/go_bags/:id` (`?show=to_buy` or `use_by_soon`) | Frames `go-bag.png`, `go-bag-dark.png` and, for a child, `go-bag-child.png`. Back row "‹ Go bags" with "…" (Edit bag, Delete bag) on a phone; breadcrumbs with Edit and "…" on desktop. Title, then one muted line: "Kept in the hall closet · For everyone" (or "For Charlie"). A box with "18 of 24 ready", the percentage and a Primer `ProgressBar`. An `UnderlineNav` of links with `Counter`s: All, To buy, Use by soon. Then a section per category: an `h2`, and a BorderBox of item rows, ending with "+ Add item", which opens the item form with that category chosen. An empty filter shows "Nothing to buy for this bag." or "Nothing to use soon." |
| Item rows | | A checkbox for "we have it" (a form that posts or deletes the acquisition; a Turbo Stream replaces the row, the progress box and the counters), the name, one muted line, and "›" opening the item. The line joins, with " · ": "To buy" when we don't have it; how many; "Kept in the kitchen drawer" when it's somewhere else, or "in the bag"; and "use by Dec 20". The use-by date is in the attention color when it's soon, and reads "expired Dec 20" in the danger color once it has passed. Two lines at most, cut off with an ellipsis |
| A bag, as a child sees it | | Frame `go-bag-child.png`. No "…", no tabs, no checkboxes and no "+ Add item". Each row starts with an icon, `check-circle` in green ("We have it") or a dashed `circle` ("Still to get"), as an image with that label. The rows aren't links. The line says "Still to get" instead of "To buy" and has no warning colors. The meta line ends "The adults keep it up to date" instead of who it's for |
| An item | `GET …/go_bags/:go_bag_id/items/new` (`?category_id=`) and `…/items/:id/edit` (`GoBags::ItemsController`) | Frame `go-bag-item.png`. Opened from a row, it's a Primer `Dialog` (`position_narrow: :bottom` on a phone, centered on desktop) loaded in a Turbo Frame. Opened directly, as from a notification, it's a page with a back row to the bag. `GoBags::ItemForm`: Name; Category (a select of the household's categories and "No category"); How many and Use by (optional, `type: :date`) side by side; "Stored somewhere else?" (caption "Leave empty when it's in the bag"); "We have it" (a check box). Save, and on an existing item, "Remove item" (a `scheme: :danger` button that deletes without a second question, since an item is quick to add back) |
| Edit / delete a bag | `GET …/go_bags/:id/edit`, `PATCH`, `DELETE` | `GoBagForm` without the suggestions box. Delete asks in a Primer `Dialog`: "Delete Family go bag? Its 24 items are deleted too." |
| To buy | `GET /:household_id/go_bags/to_buy` (`GoBags::ShoppingListsController#show`) | Frame `go-bags-to-buy.png`. Back row "‹ Go bags". Title "To buy", the line "Tick a thing once you've bought it.", then a group per bag that has something to buy, headed "Family go bag · Hall closet". Items to get have a checkbox. Ticking one creates the acquisition, and the row stays, ticked, until the page is reloaded, so a mis-tap can be unticked. Items to use soon have no checkbox: a clock icon, "Use by Dec 20 · replace it" in the attention color, and "›" opening the item to set the new date. A Blankslate when there's nothing: "Nothing to buy. Every bag is ready." Declare its route before `resources :go_bags`, so `to_buy` isn't taken for an id |
| Settings → Go bags | `GET /:household_id/settings/go_bag_categories` (`Settings::GoBagCategoriesController`, `index`, `create`, `update`, `destroy`) | Frame `go-bag-categories.png`. A section in the household group of Settings, for heads and adults (`docs/design/settings.md`). The line "Categories for Rivera household's go bags. Heads and adults can change them. Deleting one keeps its items, under "No category"." A BorderBox row per category: the name, a muted line "9 items in 2 bags", and a "…" (Rename, Delete). Rename swaps the row for a one-field Primer form in a Turbo Frame. Delete asks in a `Dialog`: "Delete Water and food? Its 9 items stay in their bags, under No category." "+ Add category" at the bottom opens the same one-field form |

```ruby
# Inside the household scope.
namespace :go_bags do
  resource :shopping_list, only: :show, path: "to_buy"
end
resources :go_bags do
  resources :items, only: %i[ new create edit update destroy ], module: :go_bags do
    resource :acquisition, only: %i[ create destroy ], module: :items
  end
end
namespace :settings do
  resources :go_bag_categories, only: %i[ index create update destroy ]
end
```

**Loading:** every go-bag controller finds the bag in `Current.household.go_bags`, its item in `@go_bag.items` and a category in `Current.household.go_bag_categories`, so anything from another household is a 404. A `category_id` param from another household is a validation error on the item, never saved.

**Policies** receive the membership: `GoBagPolicy` (`index?` and `show?` for any member; `create?`, `update?` and `destroy?` for heads and adults; `shopping_list?` for heads and adults), `GoBag::ItemPolicy` and `GoBag::CategoryPolicy` (heads and adults for everything). Ticking authorizes the item with `update?`.

**Desktop** uses the same parts in the main column: the list as a Subhead and BorderBox, as Family goals does, and a bag's page with breadcrumbs, Edit and a "…" in the header. There are no desktop frames. Build from the phone frames and check the desktop screenshot against Family goals (`docs/design/goals/goals-list.png`, `milestone-goal.png`).

## The use-by reminder

A new notification kind, added by its own story as `docs/design/notifications.md` says later kinds are.

| Kind | Who gets it | Made when | Subject | Says | Opens | Email |
| --- | --- | --- | --- | --- | --- | --- |
| `go_bag_use_by` | The household's active heads and adults | Each day at 8 AM in the household's zone, for items we have whose use-by date is today or within the next 30 days | `GoBag::Item`, with `data: { use_by: }` | "Bottled water in Family go bag: use by December 20", then "Replace it, then set the new use-by date." | The item's page | Daily summary |

- **Each reminder shows its own date.** The item and bag names and the link come from the subject when it's shown, as for other kinds, but the date comes from `data["use_by"]`, like the weekly preview's `week_of`. So after a date changes, the older reminder still says the date it was sent for. A date isn't personal, so storing it keeps to the notifications rule.
- **Once for each date.** The dedupe key is `go_bag_use_by:<item id>:<use_by>`, so the daily job never sends it twice. A new use-by date makes a new key, so the next date gets its own reminder. An item with no date, an item we don't have, and a date already past get nothing.
- **Right away for a date already close.** When an item is saved or ticked with a use-by date already inside the 30 days (today included), `item.remind_about_use_by_later` sends the reminder straight away, with the same dedupe key. Otherwise a date set for today after the 8 AM run would never get one. The daily job then finds it already sent.
- **Job:** `Notification::GoBagUseByJob`, every hour at minute 20 (`config/recurring.yml`): `Household.at_local_hour(8).find_each(&:remind_about_go_bag_use_by)`.
- **The subject goes with the item.** `GoBag::Item` gets `has_many :notifications, as: :subject, dependent: :delete_all`, as the other subjects do, so removing an item or its bag removes its reminders.
- **Settings → Notifications** offers the kind to anyone who is a head or adult in some household. Label "Go bag use-by dates", description "A month before something in a go bag needs replacing. Heads and adults." Icon `briefcase`, in yellow.
- Widen the `kind` check constraints on `notifications` and `notification_settings`.

## Seeds

`db/seeds/15_go_bags.rb` gives the Rivera household three bags: Family go bag (hall closet, for everyone, made from the suggestions with most items ticked), Car kit (trunk of the car) and Charlie's bag (for Charlie). Put one item's use-by date 20 days out and one 3 months out, and keep the dates relative to today. The categories come from the suggestions, plus one the family made ("For the car").

## Traps

- Everything typed is encrypted. Sort by `position`, id or dates, never by a name in SQL.
- "To buy" means the same thing everywhere: to get, or use by soon. Use the one scope and method; don't count it two ways.
- "Soon" uses the household's today (`household.today`), not the server's date.
- A child must not tick, edit or add anything, even with a crafted request. The policy refuses it, and request tests prove it for each write.
- A category from another household can't be put on an item, and an item from another bag can't be reached through this bag's URL.
- Deleting a category never deletes items.
- The bag list and a bag's page use `GoBag.preloaded`. A household with 3 bags and 80 items must not run a query per item.
- The guide is a title and a link. Never fetch wol.jw.org, and never put its text in the suggestions or anywhere else.

## States each story checks

- Viewer: head, adult, child (read-only, with no menus, checkboxes or To buy), non-member (404)
- Bags: none (the Blankslate), one, three; a bag for one person; that person leaving the household
- Items: to get, ready in the bag, ready and kept somewhere else, use by soon, expired, no category, a long name
- Filters: All, To buy, Use by soon, each empty and full
- To buy: nothing to buy, items to get in several bags, an item to replace, a row just ticked
- Categories: none yet, made from the suggestions, renamed, deleted while it holds items
- The reminder: sent once, not sent again the next day, sent again after the date changes, not sent for an item we don't have, sent right away for a date set to today after 8 AM
- Phone and desktop; light and dark; `assert_accessible` with the item dialog and each "…" menu open
