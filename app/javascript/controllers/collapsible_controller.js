import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "chevron", "button"]
  static values  = { open: { type: Boolean, default: true } }

  connect() {
    this.ensureContentId()
    this.openValueChanged()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.contentTarget.classList.toggle("hidden", !this.openValue)
    this.chevronTarget.classList.toggle("rotate-90", this.openValue)

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", this.openValue.toString())
      this.buttonTarget.setAttribute("aria-controls", this.contentTarget.id)
    }
  }

  ensureContentId() {
    if (this.contentTarget.id) return

    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1000)}`
    this.contentTarget.id = `collapsible-content-${suffix}`
  }
}
