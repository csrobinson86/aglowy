class Household < ApplicationRecord
  # Never dependent: :destroy on users: a shared-custody child belongs to other households too.
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  validates :name, presence: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

  def self.create_with_head(household:, head:)
    transaction do
      create!(household).tap { it.memberships.create!(user: head, role: :head) }
    end
  end

  def add_member(name:, role:)
    raise ArgumentError, "add_member adds adults or children, not heads" unless role.to_s.in?(%w[ adult child ])

    transaction do
      memberships.create!(user: User.create!(name: name), role: role)
    end
  end
end
