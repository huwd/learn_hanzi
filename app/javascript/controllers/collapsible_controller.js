import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "chevron"]
  static values  = { open: { type: Boolean, default: true } }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.contentTarget.classList.toggle("hidden", !this.openValue)
    this.chevronTarget.classList.toggle("rotate-90", this.openValue)
  }
}
