class User < ApplicationRecord
  has_one :identity, dependent: :destroy

  normalizes :name, with: -> { it.squish }

  validates :name, presence: true
end
