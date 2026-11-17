require "test_helper"

# The Two flames logo on the focused pages, in the browser tab and as the app icons (docs/design/brand.md).
class BrandIconsTest < ActionDispatch::IntegrationTest
  BRAND = Rails.root.join("docs/design/brand")

  # docs/design/brand.md, Files: each source and where the app serves it.
  FILES = {
    "aglowy-mark.svg" => %w[ app/assets/images/aglowy-mark.svg public/icon.svg ],
    "favicon-32.png" => %w[ public/icon.png ],
    "icon-512.png" => %w[ public/icon-512.png ],
    "icon-192.png" => %w[ public/icon-192.png ],
    "apple-touch-icon.png" => %w[ public/apple-touch-icon.png ]
  }

  test "signed out, sign in, create an account and forgot password have one header holding the 48 px mark alone" do
    [ new_identity_session_path, new_signup_path, new_identity_password_path ].each do |path|
      get path

      assert_response :success
      assert_select "header", { count: 1 }, "for #{path}"
      assert_select "header a[href='/'] img[src*='aglowy-mark'][alt='Aglowy'][width='48'][height='48']", { count: 1 }, "for #{path}"
      assert_select "header a", { text: /Aglowy/, count: 0 }, "for #{path}"
      assert_select "header img", { count: 1 }, "for #{path}"
    end
  end

  test "signed in, the household chooser's header holds the 24 px mark and the word Aglowy, and no 48 px mark" do
    sign_in identities(:head)

    get households_path

    assert_response :success
    assert_select "header", count: 1
    assert_select "header a[href='/'] img[src*='aglowy-mark'][alt=''][width='24'][height='24']", count: 1
    assert_select "header a[href='/']", text: "Aglowy"
    assert_select "img[width='48']", count: 0
  end

  test "the sign-in page's head links the SVG icon, the 32 px PNG, the apple touch icon and has the theme colour" do
    get new_identity_session_path

    assert_select "head link[rel=icon][href='/icon.svg'][type='image/svg+xml']", count: 1
    assert_select "head link[rel=icon][href='/icon.png'][type='image/png'][sizes='32x32']", count: 1
    assert_select "head link[rel=apple-touch-icon][href='/apple-touch-icon.png']", count: 1
    assert_select "head meta[name=theme-color][content='#1F2328']", count: 1
    assert_select "head link[rel=manifest][href='/manifest.json']", count: 1
  end

  test "every file in the Files table is where the app serves it, byte for byte" do
    FILES.each do |source, destinations|
      destinations.each do |destination|
        assert_path_exists Rails.root.join(destination)
        assert_equal BRAND.join(source).binread, Rails.root.join(destination).binread, "#{destination} differs from #{source}"
      end
    end
  end

  test "the app icons and the favicon are PNGs of 512, 192, 180 and 32 px" do
    { "icon-512.png" => 512, "icon-192.png" => 192, "apple-touch-icon.png" => 180, "icon.png" => 32 }.each do |file, size|
      bytes = Rails.root.join("public", file).binread

      # A PNG starts with its 8-byte signature, then the IHDR chunk: width and height are two 32-bit integers at byte 16.
      assert_equal "\x89PNG\r\n\x1A\n".b, bytes[0, 8], "#{file} isn't a PNG"
      assert_equal "IHDR", bytes[12, 4], "#{file} has no IHDR"
      assert_equal [ size, size ], bytes[16, 8].unpack("N2"), "for #{file}"
    end
  end

  test "the SVG icon isn't Rails' placeholder red circle" do
    assert_no_match(/fill="red"/, Rails.root.join("public/icon.svg").read)
  end
end
