import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["front", "back"]

  reveal() {
    this.frontTarget.classList.add("hidden")
    this.backTarget.classList.remove("hidden")
  }
}
