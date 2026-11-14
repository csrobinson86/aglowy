require "application_system_test_case"

class ScreenshotsTest < ApplicationSystemTestCase
  test "with SCREENSHOTS set, capture_screens writes the four PNGs" do
    files = %w[ desktop-light desktop-dark phone-light phone-dark ].map { screenshot_path("smoke-#{it}") }
    files.each { FileUtils.rm_f(it) }

    visit root_url
    with_screenshots("1") { capture_screens("smoke") }

    files.each { assert File.exist?(it), "expected #{it}" }
    assert_equal [ 1440, 1000 ], png_size(files.first)
    assert_equal [ 390, 844 ], png_size(files.last)
  end

  test "without SCREENSHOTS, capture_screens writes none" do
    FileUtils.rm_f(Dir[screenshot_path("unset-*")])

    visit root_url
    with_screenshots(nil) { capture_screens("unset") }

    assert_empty Dir[screenshot_path("unset-*")]
  end

  test "afterwards the window is back to the suite's size and the theme back to light" do
    visit root_url
    with_screenshots("1") { capture_screens("reset") }

    assert_equal [ 1400, 1400 ], page.current_window.size
    assert_equal 1400, page.evaluate_script("innerWidth")
    assert_not page.evaluate_script("matchMedia('(prefers-color-scheme: dark)').matches")
    assert_not page.evaluate_script("matchMedia('(pointer: coarse)').matches")
  end

  private
    def screenshot_path(name)
      Rails.root.join("tmp/screenshots/ui/#{name}.png").to_s
    end

    # A PNG's width and height are the two 32-bit integers after its 16-byte header.
    def png_size(path)
      File.binread(path, 8, 16).unpack("NN")
    end

    def with_screenshots(value)
      original = ENV["SCREENSHOTS"]
      ENV["SCREENSHOTS"] = value
      yield
    ensure
      ENV["SCREENSHOTS"] = original
    end
end
