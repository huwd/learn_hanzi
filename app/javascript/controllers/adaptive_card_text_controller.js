import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hanzi", "meaning"]

  connect() {
    this.applyHanziScale()
    this.applyMeaningScale()
  }

  applyHanziScale() {
    if (!this.hasHanziTarget) return

    const count = this.characterCount(this.hanziTarget.textContent)
    const sizeClass = count <= 3 ? "text-9xl" : (count === 4 ? "text-8xl" : "text-7xl")

    this.hanziTarget.classList.remove("text-9xl", "text-8xl", "text-7xl")
    this.hanziTarget.classList.add(sizeClass)
  }

  applyMeaningScale() {
    if (!this.hasMeaningTarget) return

    const hanziCount = this.hasHanziTarget ? this.characterCount(this.hanziTarget.textContent) : 0
    const meaningLength = this.characterCount(this.meaningTarget.textContent)
    const useCompactMeaning = hanziCount >= 5 || meaningLength > 36

    this.meaningTarget.classList.remove("text-xl", "text-lg")
    this.meaningTarget.classList.add(useCompactMeaning ? "text-lg" : "text-xl")
  }

  characterCount(text) {
    return Array.from((text || "").trim()).length
  }
}
