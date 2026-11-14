// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "@primer/view-components"
import "./controllers"

// Component sidecar controllers live beside their component in app/components.
import { application } from "./controllers/application"
import HouseholdSwitcherController from "../components/app_shell/household_switcher_component_controller"
application.register("household-switcher", HouseholdSwitcherController)
