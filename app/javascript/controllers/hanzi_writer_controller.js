import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { mode: String }

  connect() {
    this.playbackToken = 0
    this.writerRecords = []

    if (!window.HanziWriter) {
      return
    }

    this.writerRecords = this.canvasTargets.map((element) => this.buildWriter(element))
    this.startMode()
  }

  disconnect() {
    this.playbackToken += 1
    this.writerRecords.forEach(({ writer }) => {
      writer.cancelQuiz?.()
      writer.destroy?.()
    })
  }

  async replay() {
    const token = ++this.playbackToken

    for (const { writer } of this.writerRecords) {
      writer.cancelQuiz?.()
      writer.hideCharacter?.({ duration: 0 })
      writer.showOutline?.({ duration: 0 })
    }

    for (const { writer } of this.writerRecords) {
      if (token !== this.playbackToken) return

      await writer.animateCharacter()
    }
  }

  startMode() {
    if (this.modeValue === "quiz") {
      this.writerRecords.forEach(({ writer }) => writer.quiz())
      return
    }

    this.replay()
  }

  buildWriter(element) {
    const HanziWriter = window.HanziWriter

    const payload = {
      strokes: JSON.parse(element.dataset.strokes),
      medians: JSON.parse(element.dataset.medians)
    }

    const writer = HanziWriter.create(element, element.dataset.character, {
      width: 192,
      height: 192,
      padding: 12,
      showCharacter: false,
      showOutline: true,
      strokeColor: "#f8fafc",
      outlineColor: "#6b7280",
      highlightColor: "#f8fafc",
      strokeAnimationSpeed: 1.2,
      delayBetweenStrokes: 180,
      strokeFadeDuration: 0,
      charDataLoader() {
        return payload
      }
    })

    return { writer, payload }
  }
}
