import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["revealPinyinBtn", "revealMeaningBtn", "pinyin", "meaning", "binaryButtons", "contextual"]

  connect() {
    this._handleKey = this.handleKey.bind(this)
    window.addEventListener("keydown", this._handleKey)
  }

  disconnect() {
    window.removeEventListener("keydown", this._handleKey)
  }

  revealPinyin() {
    this.revealPinyinBtnTarget.classList.add("hidden")
    this.pinyinTarget.classList.remove("hidden")
    this.revealMeaningBtnTarget.classList.remove("hidden")
  }

  revealMeaning() {
    this.revealMeaningBtnTarget.classList.add("hidden")
    this.meaningTarget.classList.remove("hidden")
    this.binaryButtonsTarget.classList.remove("hidden")
  }

  needToLearn() {
    this.binaryButtonsTarget.classList.add("hidden")
    this.contextualTarget.classList.remove("hidden")
  }

  handleKey(event) {
    if (event.target instanceof Element && event.target.closest("button, input, textarea, select, a")) return

    const pinyinHidden   = this.revealPinyinBtnTarget.classList.contains("hidden")
    const meaningHidden  = this.revealMeaningBtnTarget.classList.contains("hidden")
    const binaryVisible  = !this.binaryButtonsTarget.classList.contains("hidden")
    const contextVisible = !this.contextualTarget.classList.contains("hidden")

    const advance = event.key === " " || event.key === "Enter"

    // Phase 0 — reveal pinyin
    if (!pinyinHidden && advance) {
      event.preventDefault()
      this.revealPinyin()
      return
    }

    // Phase 1 — reveal meaning
    if (pinyinHidden && !meaningHidden && advance) {
      event.preventDefault()
      this.revealMeaning()
      return
    }

    // Phase 2 — binary choice: 1 = know it, 2 = need to learn
    if (binaryVisible) {
      if (event.key === "1") {
        this.binaryButtonsTarget.querySelector("form:first-of-type")?.requestSubmit()
      } else if (event.key === "2") {
        this.binaryButtonsTarget.querySelector("button[data-action]")?.click()
      }
      return
    }

    // Phase 3 — contextual panel: Space/Enter submits "Got it, next character"
    if (contextVisible && advance) {
      event.preventDefault()
      this.contextualTarget.querySelector("form:last-of-type")?.requestSubmit()
    }
  }
}
