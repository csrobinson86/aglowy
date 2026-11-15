# Rendered in two sections, so the page can put what Aglowy keeps between the field and the buttons
# (frame child-login.png).
class Members::LoginForm < ApplicationForm
  # section: :fields or :actions. Only :actions needs cancel_path.
  def initialize(section:, cancel_path: nil)
    @section = section
    @cancel_path = cancel_path
  end

  form do |f|
    case @section
    when :fields
      f.text_field(name: :username, label: "Username", required: true, autocomplete: "off", autocapitalize: "none", spellcheck: false,
                   caption: "3 to 30 lowercase letters, numbers, dots or dashes. It must be unused across Aglowy.")
    when :actions
      f.group(layout: :horizontal) do |actions|
        actions.submit(name: :submit, label: "Create login", scheme: :primary)
        actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path)
      end
    end
  end
end
