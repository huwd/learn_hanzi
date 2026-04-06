import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["front", "back"]

  connect() {
    this._handleKey = this.handleKey.bind(this)
    window.addEventListener("keydown", this._handleKey)
  }

  disconnect() {
    window.removeEventListener("keydown", this._handleKey)
  }

  reveal() {
    this.frontTargets.forEach(el => el.classList.add("hidden"))
    this.backTargets.forEach(el => el.classList.remove("hidden"))
  }

  handleKey(event) {
    // Ignore if focus is on an interactive element (e.g. a button mid-submit)
    if (event.target.closest("button, input, textarea, select, a")) return

    const revealed = this.backTargets.some(el => !el.classList.contains("hidden"))

    if (!revealed && (event.key === " " || event.key === "Enter")) {
      event.preventDefault()
      this.reveal()
      return
    }

    if (revealed && ["1", "2", "3", "4"].includes(event.key)) {
      const form = this.element.querySelector(`form[data-ease="${event.key}"]`)
      form?.requestSubmit()
    }
  }
}
