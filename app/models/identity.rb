class Identity < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable,
         :validatable, :confirmable, :lockable

  belongs_to :user

  delegate :name, to: :user
end
