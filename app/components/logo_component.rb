# frozen_string_literal: true

# Aglowy's logo, the Two flames, as a link (docs/design/brand.md, Where it appears).
#
# size: :medium is the mark at 24 px beside the word "Aglowy"; the word names the link, so the mark's alt is empty.
#       :large is the mark alone at 48 px, named "Aglowy", for signed-out pages whose heading follows it.
class LogoComponent < ApplicationComponent
  SIZES = %i[ medium large ]

  attr_reader :href, :size

  def initialize(href:, size: :medium)
    raise ArgumentError, "size must be one of #{SIZES.to_sentence}, not #{size.inspect}" unless size.in?(SIZES)

    @href = href
    @size = size
  end

  def large?
    size == :large
  end
end
