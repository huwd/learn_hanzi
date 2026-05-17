import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js"

const verticalLinePlugin = {
  id: "verticalLine",
  afterDraw(chart) {
    const active = chart.tooltip._active
    if (!active?.length) return
    const { ctx, scales: { y } } = chart
    const x = active[0].element.x
    ctx.save()
    ctx.beginPath()
    ctx.moveTo(x, y.top)
    ctx.lineTo(x, y.bottom)
    ctx.lineWidth = 1.5
    ctx.strokeStyle = "rgba(107, 114, 128, 0.4)"
    ctx.setLineDash([4, 4])
    ctx.stroke()
    ctx.restore()
  }
}

export default class extends Controller {
  static targets = ["canvas", "summary"]
  static values = { url: String }

  connect() {
    fetch(this.urlValue)
      .then(res => res.json())
      .then(response => this.renderChart(response))
  }

  renderChart({ labels, series }) {
    if (!labels || labels.length === 0) return

    const summaryEl = this.hasSummaryTarget ? this.summaryTarget : null

    new Chart(this.canvasTarget, {
      type: "line",
      plugins: [verticalLinePlugin],
      data: {
        labels,
        datasets: series.map(s => ({
          label: s.label,
          data: s.values,
          borderColor: s.color,
          backgroundColor: s.color.replace("rgb(", "rgba(").replace(")", ", 0.5)"),
          fill: true,
          tension: 0.3,
          pointRadius: 2
        }))
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { position: "top" },
          tooltip: {
            enabled: false,
            external: summaryEl
              ? (ctx) => this.updateSummary(ctx, summaryEl)
              : undefined
          }
        },
        scales: {
          x: { stacked: true },
          y: { stacked: true, beginAtZero: true, ticks: { precision: 0 } }
        }
      }
    })
  }

  updateSummary({ tooltip }, el) {
    if (tooltip.opacity === 0 || !tooltip.dataPoints?.length) {
      el.textContent = ""
      return
    }
    const date = tooltip.title?.[0] ?? ""
    const parts = tooltip.dataPoints.map(dp => `${dp.dataset.label}: ${dp.formattedValue}`)
    el.textContent = `${date}  ·  ${parts.join("  ·  ")}`
  }
}
