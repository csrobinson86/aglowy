# frozen_string_literal: true

# Aglowy's logo, the Two flames, as a link (docs/design/brand.md, Where it appears).
#
# size: :small is the mark alone at 24 px, named "Aglowy", in a link at least 44 px square, for the phone top bar.
#       :medium is the mark at 24 px beside the word "Aglowy"; the word names the link, so the mark's alt is empty.
#       :large is the mark alone at 48 px, named "Aglowy", for signed-out pages whose heading follows it.
class LogoComponent < ApplicationComponent
  SIZES = %i[ small medium large ]

  attr_reader :href, :size

  def initialize(href:, size: :medium)
    raise ArgumentError, "size must be one of #{SIZES.to_sentence}, not #{size.inspect}" unless size.in?(SIZES)

    @href = href
    @size = size
  end

  def small?
    size == :small
  end

  def large?
    size == :large
  end
end
