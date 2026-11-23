# The Riveras' go bags (docs/design/go-bags.md, Seeds): the family bag, made from the suggestions with most things
# ticked, a car kit with a category the family made, and Mateo's bag. Two use-by dates, kept relative to today: one
# 20 days out, so it's soon, and one 3 months out. Names are encrypted, so bags and items are found by name in Ruby,
# and a bag gets its items only when it's new.
rivera = seeded_household("The Rivera Family", head: "rivera@example.com")
maria = seeded_person("rivera@example.com")
mateo = rivera.users.find_by!(name: "Mateo Rivera")
today = rivera.today
category = ->(key) { rivera.go_bag_categories.find_by!(suggestion_key: key) }

unless find_seeded(rivera.go_bags, name: "Family go bag")
  bag = seeded!(rivera.go_bags.create_with_suggestions({ name: "Family go bag", kept_at: "the hall closet" }, suggested: true, by: maria))
  still_to_get = [ "Energy bars", "Spare batteries", "Copies of prescriptions", "Rain poncho", "Dust masks" ]
  bag.items.each { it.acquire(by: maria) unless it.name.in?(still_to_get) }
  find_seeded(bag.items, name: "Bottled water").update!(use_by: today + 20.days)
  find_seeded(bag.items, name: "Food that keeps, like cans or dried food").update!(use_by: today + 3.months)
  find_seeded(bag.items, name: "Phone charger and power bank").update!(stored_at: "the kitchen drawer")
end

unless find_seeded(rivera.go_bags, name: "Car kit")
  for_the_car = find_seeded(rivera.go_bag_categories, name: "For the car") || rivera.go_bag_categories.create!(name: "For the car")
  bag = rivera.go_bags.create!(name: "Car kit", kept_at: "the trunk of the car", created_by: maria)
  bag.items.create!(name: "Jumper cables", category: for_the_car).acquire(by: maria)
  bag.items.create!(name: "Ice scraper", category: for_the_car)
  bag.items.create!(name: "Bottled water", quantity: "2 gallons", category: category.("water_food")).acquire(by: maria)
  bag.items.create!(name: "Flashlight", stored_at: "the glove box", category: category.("light_power")).acquire(by: maria)
end

unless find_seeded(rivera.go_bags, name: "Mateo's bag")
  bag = rivera.go_bags.create!(name: "Mateo's bag", kept_at: "Mateo's closet", for_user: mateo, created_by: maria)
  bag.items.create!(name: "Change of clothes", category: category.("clothing_shelter")).acquire(by: maria)
  bag.items.create!(name: "A small toy or book", category: category.("children")).acquire(by: maria)
  bag.items.create!(name: "A favorite snack", category: category.("children"))
end

# Maria's reminder for the bottled water, 20 days out, as the 8 AM job would make it (docs/design/go-bags.md, The use-by
# reminder). Unread. None if the water or its date has gone since the bag was seeded.
water = find_seeded(find_seeded(rivera.go_bags, name: "Family go bag").items, name: "Bottled water")
if water&.use_by
  maria.notify(kind: "go_bag_use_by", household: rivera, subject: water, data: { use_by: water.use_by.iso8601 },
    dedupe_key: "go_bag_use_by:#{water.id}:#{water.use_by.iso8601}")
end
