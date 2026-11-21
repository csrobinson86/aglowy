require "test_helper"
require "axe/matchers/be_axe_clean"
require_relative "support/accessibility_helper"
require_relative "support/screenshot_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AccessibilityHelper
  include ScreenshotHelper
  include Devise::Test::IntegrationHelpers

  # Fixture passwords are in breach lists, so after a real sign-in Chrome's
  # password manager opens a leak warning that swallows every later click.
  # Capybara's reset leaves the page for about:blank, then clears the cookies.
  # With the back-forward cache on, the page left keeps its requests running (a
  # Turbo pre-load of the link the pointer rests on), and one that answers after
  # the clear sets the session cookie again, so the next test starts signed in.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
    options.add_argument("--disable-features=BackForwardCache")
  end

  # The full suite runs in parallel workers, so pages can take longer than the 2s default.
  Capybara.default_max_wait_time = 5

  # Devise's sign_in logs in whoever makes the app's next request, and the open page can still make one (or rewrite the
  # session cookie) as the person signed in before. Clear the browser first so switching people mid-test can't race.
  def sign_in(...)
    Capybara.reset_session!
    super
  end

  # Turbo pre-loads a link the pointer rests on, and a page that shifts under a still pointer can put one there. If
  # that response lands after a form's, it overwrites the session cookie the form's response set and the flash is
  # lost. So every button click rests the pointer on the button, where no pre-load can start, and lets one in flight
  # finish first. A link click is a GET, which has no flash to lose.
  def click_button(locator = nil, **options)
    click_after_prefetch find(:button, locator, **options)
  end

  def click_on(locator = nil, **options)
    click_after_prefetch find(:link_or_button, locator, **options)
  end
  alias_method :click_link_or_button, :click_on

  def click_after_prefetch(element)
    unless element.tag_name == "a"
      element.hover
      page.server.wait_for_pending_requests
    end
    element.click
  end

  # A Primer Dialog scales up for 0.2s as it opens, and a click aimed while it moves can land beside its target.
  # Wait for the open Dialog to stop before working in it.
  def wait_for_dialog
    assert_selector "dialog[open]"
    page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      const animations = document.querySelector("dialog[open]").getAnimations().filter(animation => animation instanceof CSSAnimation)
      Promise.allSettled(animations.map(animation => animation.finished)).then(() => done())
    JS
  end

  # A dialog or menu grows in as it opens, so measure once it has.
  def wait_for_animations
    page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      Promise.allSettled(document.getAnimations().map(animation => animation.finished)).then(() => done())
    JS
  end

  # At least 44px each way, or, for a smaller control, touching anywhere within 22px of its middle, across and down,
  # lands on it or its label: a pseudo-element reaching past it.
  def assert_touch_target(element)
    missed = element.evaluate_script(<<~JS)
      (() => {
        this.scrollIntoView({ block: "center", inline: "center", behavior: "instant" })
        const { left, top, width, height } = this.getBoundingClientRect()
        if (width >= 44 && height >= 44) return 0
        const x = left + width / 2, y = top + height / 2
        const lands = hit => hit && (this.contains(hit) || hit.closest("label")?.htmlFor === this.id)
        return [ [ x - 21.5, y ], [ x + 21.5, y ], [ x, y - 21.5 ], [ x, y + 21.5 ] ].filter(([ px, py ]) => !lands(document.elementFromPoint(px, py))).length
      })()
    JS
    assert_equal 0, missed, "#{element.tag_name} “#{element[:"aria-label"] || element.text.presence || element[:name]}” is less than 44px to touch"
  end

  # What an open Primer ActionMenu shows, top to bottom: each item's label, and "—" for a divider. Items hidden at
  # this screen size are left out.
  def menu_entries(menu_id)
    evaluate_script(<<~JS, menu_id)
      [ ...document.querySelectorAll(`#${arguments[0]}-list > li`) ].filter(entry => entry.checkVisibility())
        .map(entry => entry.matches("[role=presentation]") ? "—" : entry.textContent.trim())
    JS
  end

  # The color an element is drawn in, as the browser computed it ("rgba(255, 118, 118, 0.3)").
  def background_color(selector)
    find(selector, visible: :all).evaluate_script("getComputedStyle(this).backgroundColor")
  end

  # What a CSS color value, like a primitive's var(), computes to on this page, to compare with background_color.
  def computed_color(value)
    page.evaluate_script(<<~JS, value)
      (value => {
        const probe = document.createElement("div")
        probe.style.backgroundColor = value
        document.body.append(probe)
        const color = getComputedStyle(probe).backgroundColor
        probe.remove()
        return color
      })(arguments[0])
    JS
  end

  # Turbo marks <html aria-busy> until a visit completes and may move focus as
  # it finishes, which closes an open menu. Wait for it before interacting.
  def assert_turbo_idle
    assert_selector "html:not([aria-busy])"
  end
end
