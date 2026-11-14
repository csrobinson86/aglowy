class Current < ActiveSupport::CurrentAttributes
  attribute :identity, :user

  def identity=(identity)
    super
    self.user = identity&.user
  end
end
