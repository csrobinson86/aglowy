# Saves the current page at desktop and phone sizes, in light and dark, to
# tmp/screenshots/ui/<name>-<viewport>-<theme>.png (docs/design/app-shell.md,
# Screenshots). Does nothing unless ENV["SCREENSHOTS"] is set.
module ScreenshotHelper
  VIEWPORTS = { desktop: [ 1440, 1000 ], phone: [ 390, 844 ] }
  THEMES = %w[ light dark ]

  def capture_screens(name)
    return unless ENV["SCREENSHOTS"]

    FileUtils.mkdir_p(screenshot_dir)

    VIEWPORTS.each do |viewport, (width, height)|
      phone = viewport == :phone
      emulate_viewport(width, height, phone:)
      emulate_touch(phone)

      THEMES.each do |theme|
        emulate_color_scheme(theme)
        wait_for_transitions
        page.save_screenshot(screenshot_dir.join("#{name}-#{viewport}-#{theme}.png"))
      end
    end
  ensure
    if ENV["SCREENSHOTS"]
      emulate_color_scheme("light")
      emulate_touch(false)
      cdp("Emulation.clearDeviceMetricsOverride")
    end
  end

  private
    def screenshot_dir
      Rails.root.join("tmp/screenshots/ui")
    end

    # Headless Chrome won't shrink a window below 500px wide, and the window's
    # own frame takes height from the page, so emulate the viewport instead of
    # resizing the window. Clearing the override restores the suite's window.
    def emulate_viewport(width, height, phone:)
      cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 1, mobile: phone)
    end

    # Touch makes Chrome report a coarse pointer, so Primer's 44px touch targets show.
    def emulate_touch(enabled)
      cdp("Emulation.setTouchEmulationEnabled", enabled:)
      assert_equal enabled, page.evaluate_script("matchMedia('(pointer: coarse)').matches"), "touch emulation didn't change the pointer"
    end

    # Clearing the emulated media falls back to the computer's own scheme,
    # which may be dark, so set light explicitly.
    def emulate_color_scheme(scheme)
      cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: scheme } ])
    end

    # Primer buttons fade between colours, so a screenshot taken straight after
    # a theme change catches them halfway. Asking for the animations applies
    # the new styles first, so the wait includes the transitions they start.
    def wait_for_transitions
      page.evaluate_async_script(<<~JS)
        const done = arguments[arguments.length - 1]
        const transitions = document.getAnimations().filter(animation => animation instanceof CSSTransition)
        Promise.allSettled(transitions.map(transition => transition.finished)).then(() => done())
      JS
    end

    def cdp(command, **params)
      page.driver.browser.execute_cdp(command, **params)
    end
end
