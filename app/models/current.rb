class Current < ActiveSupport::CurrentAttributes
  attribute :identity, :user
  attribute :membership, :household

  def identity=(identity)
    super
    self.user = identity&.user
  end

  def membership=(membership)
    super
    self.household = membership&.household
  end
end
