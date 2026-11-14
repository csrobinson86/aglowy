class Household < ApplicationRecord
  # The roles a head can give someone they add; headship is never handed out here.
  MEMBER_ROLES = %w[ adult child ].freeze

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
    raise ArgumentError, "add_member adds adults or children, not heads" unless role.to_s.in?(MEMBER_ROLES)

    transaction do
      memberships.create!(user: User.create!(name: name), role: role)
    end
  end
end
