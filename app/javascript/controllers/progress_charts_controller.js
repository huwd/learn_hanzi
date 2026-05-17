import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { url: String }

  connect() {
    fetch(this.urlValue)
      .then(res => res.json())
      .then(response => this.renderChart(response))
  }

  renderChart({ labels, series }) {
    if (!labels || labels.length === 0) return

    new Chart(this.canvasTarget, {
      type: "line",
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
        plugins: {
          legend: { position: "top" }
        },
        scales: {
          x: { stacked: true },
          y: { stacked: true, beginAtZero: true, ticks: { precision: 0 } }
        }
      }
    })
  }
}
