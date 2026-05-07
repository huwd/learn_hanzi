import { Controller } from "@hotwired/stimulus"

const HANZI_LENGTH_THRESHOLDS = {
  largeMax: 3,
  medium: 4
}

const HANZI_SIZE_CLASSES = {
  large: "text-9xl",
  medium: "text-8xl",
  small: "text-7xl"
}

const COMPACT_MEANING_THRESHOLDS = {
  hanziCountMin: 5,
  meaningLengthMax: 36
}

const MEANING_SIZE_CLASSES = {
  normal: "text-xl",
  compact: "text-lg"
}

export default class extends Controller {
  static targets = ["hanzi", "meaning"]

  connect() {
    this.applyHanziScale()
    this.applyMeaningScale()
  }

  applyHanziScale() {
    if (!this.hasHanziTarget) return

    const count = this.characterCount(this.hanziTarget.textContent)

    let sizeClass = HANZI_SIZE_CLASSES.small
    if (count <= HANZI_LENGTH_THRESHOLDS.largeMax) {
      sizeClass = HANZI_SIZE_CLASSES.large
    } else if (count === HANZI_LENGTH_THRESHOLDS.medium) {
      sizeClass = HANZI_SIZE_CLASSES.medium
    }

    this.hanziTarget.classList.remove(
      HANZI_SIZE_CLASSES.large,
      HANZI_SIZE_CLASSES.medium,
      HANZI_SIZE_CLASSES.small
    )
    this.hanziTarget.classList.add(sizeClass)
  }

  applyMeaningScale() {
    if (!this.hasMeaningTarget) return

    const hanziCount = this.hasHanziTarget ? this.characterCount(this.hanziTarget.textContent) : 0
    const meaningLength = this.characterCount(this.meaningTarget.textContent)
    const useCompactMeaning = (
      hanziCount >= COMPACT_MEANING_THRESHOLDS.hanziCountMin ||
      meaningLength > COMPACT_MEANING_THRESHOLDS.meaningLengthMax
    )

    this.meaningTarget.classList.remove(MEANING_SIZE_CLASSES.normal, MEANING_SIZE_CLASSES.compact)
    this.meaningTarget.classList.add(
      useCompactMeaning ? MEANING_SIZE_CLASSES.compact : MEANING_SIZE_CLASSES.normal
    )
  }

  characterCount(text) {
    return Array.from((text || "").trim()).length
  }
}
