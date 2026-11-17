require "test_helper"

# Avatar::Palette (docs/design/avatars.md): the six colors, each drawn from Primer display primitives that exist in the
# pinned @primer/primitives, in light and in dark.
class Avatar::PaletteTest < ActiveSupport::TestCase
  test "the six colors of notes, without none" do
    assert_equal %w[ blue green purple pink orange yellow ], Avatar::Palette::COLORS
    assert_equal PersonalNote.colors.keys - %w[ none ], Avatar::Palette::COLORS.sort_by { PersonalNote.colors.keys.index(it) }
  end

  test "each color's circle and letter are Primer primitives, in light and dark" do
    themes = %w[ light dark ].index_with { Rails.root.join("node_modules/@primer/primitives/dist/css/functional/themes/#{it}.css").read }

    Avatar::Palette::PRIMITIVES.each do |color, primitives|
      assert_equal [ "--display-#{color}-bgColor-muted", "--display-#{color}-fgColor" ], primitives.values_at(:background, :foreground)
      primitives.each_value do |primitive|
        themes.each { |theme, css| assert_includes css, "#{primitive}:", "#{primitive} is missing from the #{theme} theme" }
      end
    end
  end
end
