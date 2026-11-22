import { Controller } from "@hotwired/stimulus"

// A goal's step, in its row (GoalStepComponent) or its phone panel (GoalStepPanelComponent). Ticks the step when a
// checkbox changes, shows the edit form in place of the row or the panel's facts, asks before the panel removes the
// step, and says how many ticks a change of people would clear before it's saved (docs/design/goals.md,
// "Changing who a step is for").
export default class extends Controller {
  static targets = [ "view", "form", "confirm", "checkbox", "editButton", "removeButton", "warning" ]
  static values = { mixed: Boolean, ticks: Array }

  // Only script can make a checkbox indeterminate.
  checkboxTargetConnected(checkbox) {
    checkbox.indeterminate = this.mixedValue
  }

  // A checkbox's own form ticks or unticks the step; the Turbo Stream answer redraws the row.
  // A request that fails without one (the network dropped) puts the checkbox back as it was.
  // One tick at a time: a change while one is on its way is undone, because a second submission would cancel the
  // first, and the first's turbo:submit-end would then put the checkbox back to the wrong state. Disabling the
  // checkbox instead would take focus off it.
  tick({ target: checkbox }) {
    if (this.ticking) {
      checkbox.checked = !checkbox.checked
      return
    }

    this.ticking = true
    const was = !checkbox.checked
    checkbox.form.addEventListener("turbo:submit-end", ({ detail }) => {
      this.ticking = false
      if (!detail.success) checkbox.checked = was
    }, { once: true })
    checkbox.form.requestSubmit()
  }

  edit() {
    this.viewTarget.hidden = true
    this.formTarget.hidden = false
    this.formTarget.querySelector("input:not([type=hidden])").focus()
  }

  cancel() {
    this.formTarget.querySelector("form").reset()
    this.warn()
    this.formTarget.hidden = true
    this.viewTarget.hidden = false
    this.editButtonTargets.find(button => button.checkVisibility())?.focus()
  }

  // The panel's Remove step asks first, in place of its facts; Cancel (keep) goes back to them.
  askToRemove() {
    this.viewTarget.hidden = true
    this.confirmTarget.hidden = false
    this.confirmTarget.querySelector("button").focus()
  }

  keep() {
    this.confirmTarget.hidden = true
    this.viewTarget.hidden = false
    this.removeButtonTarget.focus()
  }

  // Ticks that still fit stay: no one ticked means Everyone, which keeps only a done-together tick;
  // named people keep their own ticks (Goal::Step#reassign).
  warn() {
    const chosen = [ ...this.formTarget.querySelectorAll("input[type=checkbox]:checked") ].map(box => box.value)
    const fits = user => chosen.length === 0 ? user === "" : chosen.includes(user)
    const cleared = this.ticksValue.filter(user => !fits(user)).length

    this.warningTarget.textContent = cleared === 0 ? "" : `Changing who this is for clears ${cleared} ${cleared === 1 ? "tick" : "ticks"}.`
  }
}
