# The submit button for "Mark goal complete", "Reopen goal" and "Restore" in a goal's Banners, and
# "Delete goal" in the delete Dialog.
class Goals::LifecycleForm < ApplicationForm
  def initialize(label:, scheme: :default)
    @label = label
    @scheme = scheme
  end

  form do |f|
    f.submit(name: :submit, label: @label, scheme: @scheme)
  end
end
