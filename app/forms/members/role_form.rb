# A member's role in household settings' Members and roles (frame household-settings.png). The member's name is the
# label, hidden because the row already shows it. A refusal from Membership (the last head) comes as validation_message.
class Members::RoleForm < ApplicationForm
  def initialize(name:, autofocus: false, validation_message: nil)
    @name = name
    @autofocus = autofocus
    @validation_message = validation_message
  end

  form do |f|
    f.select_list(name: :role, label: @name, visually_hide_label: true, autofocus: @autofocus, validation_message: @validation_message) do |list|
      Membership.roles.each_key { |role| list.option(label: role.humanize, value: role) }
    end
  end
end
