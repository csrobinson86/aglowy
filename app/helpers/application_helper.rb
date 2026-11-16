module ApplicationHelper
  # data-color-mode on <body>: the signed-in person's Appearance choice, auto when signed out
  # (docs/design/app-shell.md, Theming and appearance). The saved value, so a rejected choice never reaches the page.
  def color_mode
    Current.user&.appearance_in_database || "auto"
  end
end
