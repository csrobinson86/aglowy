# frozen_string_literal: true

# The household page frame: sidebar and main (docs/design/app-shell.md, Anatomy of the shell).
class AppShellComponent < ApplicationComponent
  # The phone menu dialog; the top bar's menu button opens it by this id.
  MENU_ID = "app-shell-menu"

  attr_reader :membership, :selected_item

  def initialize(membership:, selected_item:)
    @membership = membership
    @selected_item = selected_item
  end
end
