# frozen_string_literal: true

# A person as Aglowy shows them everywhere: their initial on a circle in their color (docs/design/avatars.md,
# AvatarComponent). Hidden from screen readers when their name is beside it; with alone, it's an image named for them.
#
# size:    one of Primer's avatar sizes, in pixels. 80 is Settings → Profile.
# classes: utilities for spacing, like mr-2
class AvatarComponent < ApplicationComponent
  SIZES = Primer::Beta::Avatar::SIZE_OPTIONS

  attr_reader :user, :size, :alone, :classes

  def initialize(user:, size: 24, alone: false, classes: nil)
    raise ArgumentError, "size must be one of #{SIZES.to_sentence}, not #{size.inspect}" unless size.in?(SIZES)

    @user = user
    @size = size
    @alone = alone
    @classes = classes
  end

  def call
    tag.span user.initial, class: [ "avatar circle avatar-initial", "avatar-initial--#{color}", "avatar-initial--size-#{size}", classes ],
                      **(alone ? { role: "img", aria: { label: user.name } } : { aria: { hidden: true } })
  end

  private
    # A class name only ever comes from the palette (docs/design/notes.md, Traps).
    def color
      user.avatar_color.in?(Avatar::Palette::COLORS) ? user.avatar_color : "blue"
    end
end
