# Rendered in two sections, so the invite page can put "what happens next" between the fields and the buttons
# (frame invite.png). The Head option is shown only to heads; InvitationPolicy refuses it for anyone else.
class Invitations::InvitationForm < ApplicationForm
  # section: :fields or :actions. Only :actions needs cancel_path.
  def initialize(section:, head: false, cancel_path: nil)
    @section = section
    @head = head
    @cancel_path = cancel_path
  end

  form do |f|
    case @section
    when :fields
      f.text_field(name: :email, label: "Email", type: :email, autocomplete: "off", required: true, full_width: true)

      f.radio_button_group(name: :role, label: "Their role",
                           caption: "To add a child, use \"Add without a login\" on the Members page, then give them a login with a username.") do |roles|
        roles.radio_button(value: "adult", label: "Adult", caption: "Plans family studies, sets family goals and invites others.")
        roles.radio_button(value: "head", label: "Head", caption: "Also runs household settings and changes members' roles.") if @head
      end
    when :actions
      f.group(layout: :horizontal) do |actions|
        actions.submit(name: :submit, label: "Send invitation", scheme: :primary)
        actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path)
      end
    end
  end
end
