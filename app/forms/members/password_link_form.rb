# The "New password link" button on a child's row of the Members page. The aria-label names the child, so a screen
# reader can tell the rows apart.
class Members::PasswordLinkForm < ApplicationForm
  def initialize(name:)
    @name = name
  end

  form do |f|
    f.submit(name: :submit, label: "New password link", aria: { label: "New password link for #{@name}" })
  end
end
