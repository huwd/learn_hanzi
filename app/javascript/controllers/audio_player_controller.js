import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio"]

  play() {
    if (!this.hasAudioTarget) return

    this.audioTarget.currentTime = 0
    this.audioTarget.play().catch(() => {})
  }
}
