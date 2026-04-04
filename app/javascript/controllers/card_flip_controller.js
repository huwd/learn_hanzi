import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["front", "back"]

  reveal() {
    this.frontTargets.forEach(el => el.classList.add("hidden"))
    this.backTargets.forEach(el => el.classList.remove("hidden"))
  }
}
