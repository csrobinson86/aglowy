# Join household or Decline, on the page for someone signed in with the invited email.
class InvitationAcceptances::AnswerForm < ApplicationForm
  def initialize(label:, scheme: :default)
    @label = label
    @scheme = scheme
  end

  form do |f|
    f.submit(name: :submit, label: @label, scheme: @scheme)
  end
end
