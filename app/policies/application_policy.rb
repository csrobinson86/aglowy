# Policies receive the current household Membership, never a User (gotcha 4).
# It is nil outside household URLs.
class ApplicationPolicy
  attr_reader :membership, :record

  def initialize(membership, record)
    @membership = membership
    @record = record
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def new?     = create?
  def update?  = false
  def edit?    = update?
  def destroy? = false

  private

  def member?
    membership.present? && membership.active?
  end

  def head?
    member? && membership.head?
  end

  def head_or_adult?
    member? && (membership.head? || membership.adult?)
  end
end
