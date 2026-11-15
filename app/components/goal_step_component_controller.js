import { Controller } from "@hotwired/stimulus"

// A goal's step (GoalStepComponent). Ticks the step when its checkbox changes, shows the edit form in place of
// the row, and says how many ticks a change of people would clear before it's saved (docs/design/goals.md,
// "Changing who a step is for").
export default class extends Controller {
  static targets = [ "view", "form", "checkbox", "editButton", "warning" ]
  static values = { mixed: Boolean, ticks: Array }

  // Only script can make a checkbox indeterminate.
  checkboxTargetConnected(checkbox) {
    checkbox.indeterminate = this.mixedValue
  }

  // A checkbox's own form ticks or unticks the step; the Turbo Stream answer redraws the row.
  // A request that fails without one (the network dropped) puts the checkbox back as it was.
  tick({ target: checkbox }) {
    const was = !checkbox.checked
    checkbox.form.addEventListener("turbo:submit-end", ({ detail }) => {
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
    this.editButtonTarget.focus()
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
