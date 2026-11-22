# frozen_string_literal: true

# An inner page's back row on a phone (docs/design/phone.md, The rules: 2): "‹ <parent>" on the left, a 44px link to
# the last breadcrumb above the page, and the page's "…" at the right end. Hidden from md up, where the page's
# breadcrumbs show instead. The menu slot takes the page's Primer ActionMenu, whose show button is a plain IconButton
# (scheme: :invisible, kebab-horizontal) named for the page, and whose menu_id differs from the desktop menu's.
class BackRowComponent < ApplicationComponent
  renders_one :menu

  attr_reader :href, :label

  def initialize(href:, label:)
    @href = href
    @label = label
  end
end
