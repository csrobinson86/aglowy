# Sample data for every page, in development (and in test/seeds_test.rb). Safe to run again: each record is looked up
# before it's created, so a second db:seed adds nothing; db:seed:replant starts afresh. Every login's password is
# "password123". Nothing leaves the machine: no AI calls or jobs, no mail, no request to jw.org or wol.jw.org.
return unless Rails.env.local?

def seed_password = "password123"

def seed_person(name:, email:, staff: false)
  Identity.find_by(email: email)&.user ||
    User.create!(name: name).tap do |user|
      user.create_identity!(email: email, password: seed_password, confirmed_at: Time.current, staff: staff)
    end
end

def seeded_person(login)
  Identity.find_for_database_authentication(login: login).user
end

# Through its head, as the app finds a household through the person: another household with the same name is left alone.
def seeded_household(name, head:)
  seeded_person(head).households.find_by!(name: name)
end

# Model methods that answer with the record, saved or not, rather than raising.
def seeded!(record)
  record.persisted? ? record : raise(ActiveRecord::RecordInvalid, record)
end

# Encrypted columns can't be searched in SQL, so these are found in Ruby; there are only a few of each.
def find_seeded(records, **attributes)
  records.find { |record| attributes.all? { |name, value| record.public_send(name) == value } }
end

# Sharing and user.notify make notifications, and each enqueues its delivery. Seeding sends nothing, so while the seeds
# run those enqueues are dropped: the notifications still show in the inbox (docs/design/notifications.md, Elsewhere).
# Turning the helper on asks the AI for this week's listening game; the seeds make that game themselves, and ask nothing.
unless defined?(SEEDS_DROP_DELIVERIES)
  SEEDS_DROP_DELIVERIES = true
  [ Notification::DeliveryJob, ListeningGame::PrepareJob ].each { it.before_enqueue { throw :abort if Thread.current[:seeding] } }
end

begin
  Thread.current[:seeding] = true
  ActiveRecord::Base.transaction do
    Dir[Rails.root.join("db/seeds/*.rb")].sort.each { load it }
  end
ensure
  Thread.current[:seeding] = nil
end
