require "test_helper"

# The web app manifest's icons and colours (docs/design/brand.md, Where it appears). It isn't routed yet.
class PwaManifestTest < ActionView::TestCase
  test "the manifest has the two app icons, the ink colours and the description" do
    render template: "pwa/manifest", formats: :json

    manifest = JSON.parse(rendered.to_s)

    assert_equal "Aglowy", manifest["name"]
    assert_equal [
      { "src" => "/icon-192.png", "type" => "image/png", "sizes" => "192x192", "purpose" => "any maskable" },
      { "src" => "/icon-512.png", "type" => "image/png", "sizes" => "512x512", "purpose" => "any maskable" }
    ], manifest["icons"]
    assert_equal "#1F2328", manifest["theme_color"]
    assert_equal "#1F2328", manifest["background_color"]
    assert_equal "Aglowy helps a family keep its spiritual routine together.", manifest["description"]
  end
end
