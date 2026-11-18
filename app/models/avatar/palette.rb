# The six colors a person's initial can be in, and the Primer display primitives that draw it (docs/design/avatars.md,
# Avatar::Palette): the circle in --display-<color>-bgColor-muted, the letter in --display-<color>-fgColor. Primer gives
# each its dark mode. Six of notes' hues (notes also have red, brown and gray). users_avatar_color_check,
# AvatarComponent, the color picker and components/_avatar.scss all draw from this list.
class Avatar::Palette
  COLORS = %w[ blue green purple pink orange yellow ].freeze

  PRIMITIVES = COLORS.index_with { { background: "--display-#{it}-bgColor-muted", foreground: "--display-#{it}-fgColor" } }.freeze
end
