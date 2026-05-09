import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { mode: String }

  connect() {
    this.writerRecords = this.canvasTargets.map((element) => this.buildWriter(element))
    this.startMode()
  }

  disconnect() {
    this.writerRecords.forEach(({ writer }) => writer.cancelQuiz?.())
  }

  replay() {
    this.writerRecords.forEach(({ writer }) => {
      writer.cancelQuiz?.()
      writer.animateCharacter()
    })
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
      width: 96,
      height: 96,
      padding: 8,
      showCharacter: false,
      showOutline: true,
      strokeAnimationSpeed: 1.2,
      delayBetweenStrokes: 180,
      charDataLoader() {
        return payload
      }
    })

    return { writer, payload }
  }
}
