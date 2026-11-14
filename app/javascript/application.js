// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "@primer/view-components"
// Lexxy, the Action Text editor for session notes. It uploads through Active Storage.
import "@37signals/lexxy"
import "@rails/activestorage"
import "./controllers"

// Component sidecar controllers live beside their component in app/components.
import { application } from "./controllers/application"
import HouseholdSwitcherController from "../components/app_shell/household_switcher_component_controller"
application.register("household-switcher", HouseholdSwitcherController)
import AppShellController from "../components/app_shell_component_controller"
application.register("app-shell", AppShellController)
import FileDropController from "../components/file_drop_component_controller"
application.register("file-drop", FileDropController)
