// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "@primer/view-components"
// Lexxy, the Action Text editor for notes. It uploads through Active Storage. Its extensions are configured here,
// in the module that imports it and before anything awaits, so they're registered before Lexxy defines its elements.
import * as Lexxy from "@37signals/lexxy"
import ScripturePicker from "./lexxy/scripture_picker"
Lexxy.configure({ global: { extensions: [ ScripturePicker ] } })
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
import AiPanelController from "../components/family_studies/ai_panel_component_controller"
application.register("ai-panel", AiPanelController)
import GoalStepController from "../components/goal_step_component_controller"
application.register("goal-step", GoalStepController)
import ColorPickerController from "../components/color_picker_component_controller"
application.register("color-picker", ColorPickerController)
import ScripturePickerController from "../components/scripture_picker_component_controller"
application.register("scripture-picker", ScripturePickerController)
import TagEditorController from "../components/tag_editor_component_controller"
application.register("tag-editor", TagEditorController)
