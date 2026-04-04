import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["revealPinyinBtn", "revealMeaningBtn", "pinyin", "meaning", "binaryButtons", "contextual"]

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
}
