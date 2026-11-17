# The name a push subscription goes by in Phones and browsers, from the browser's user agent and whether the page runs
# from the Home Screen: "iPhone · Aglowy on the Home Screen", "Chrome on Mac" (docs/design/notifications.md,
# PushSubscription).
class PushSubscription::Device
  SYSTEMS = { "iPhone" => /iPhone/, "iPad" => /iPad/, "Android" => /Android/, "Windows" => /Windows/,
              "ChromeOS" => /CrOS/, "Mac" => /Macintosh/, "Linux" => /Linux/ }.freeze
  # In order: Edge and Chrome both say Chrome, and Chrome says Safari.
  BROWSERS = { "Edge" => /Edg/, "Firefox" => /Firefox|FxiOS/, "Chrome" => /Chrome|CriOS/, "Safari" => /Safari/ }.freeze
  HOME_SCREEN_SYSTEMS = %w[ iPhone iPad Android ].freeze

  def initialize(user_agent, standalone:)
    @user_agent = user_agent.to_s
    @standalone = standalone
  end

  def label
    if @standalone && system.in?(HOME_SCREEN_SYSTEMS)
      "#{system} · Aglowy on the Home Screen"
    else
      [ browser, system ].compact.join(" on ").presence || "A browser"
    end.truncate(80)
  end

  private
    def system
      SYSTEMS.find { |_, pattern| pattern.match?(@user_agent) }&.first
    end

    def browser
      BROWSERS.find { |_, pattern| pattern.match?(@user_agent) }&.first
    end
end
