# Capybara 3.40.0 resets Chrome with Storage.clearDataForOrigin for origin "*", which Chrome 158 refuses ("* is not
# a valid URL"), so every system test errored (#502, teamcapybara/capybara#2865). This sends what Chrome accepts: the
# cookies cleared everywhere, then the other storage Capybara asked for (local storage) cleared for the app's origin.
# Remove it once a Capybara release fixes the reset.
unless Capybara::VERSION == "3.40.0"
  raise "Capybara #{Capybara::VERSION}: if it fixes teamcapybara/capybara#2865, delete #{__FILE__}. If not, check that " \
        "ChromeDriver#reset! still calls execute_cdp('Storage.clearDataForOrigin', origin: '*', ...), then update the version here"
end

module ChromeStorageReset
  private

  def execute_cdp(cmd, params = {})
    return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super("Network.clearBrowserCookies")
    other_types = params[:storageTypes].split(",") - [ "cookies" ]
    # The origin Rails builds system-test URLs from (ActionDispatch::SystemTestCase#url_options).
    origin = Capybara.app_host || Capybara.current_session.server_url
    super(cmd, origin:, storageTypes: other_types.join(",")) if other_types.any? && origin
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend ChromeStorageReset
