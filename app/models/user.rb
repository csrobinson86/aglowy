class User < ApplicationRecord
  has_one :identity, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :households, through: :memberships

  normalizes :name, with: -> { it.squish }

  validates :name, presence: true

  def active_households
    households.merge(Membership.active)
  end
end
