import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { url: String }

  connect() {
    fetch(this.urlValue)
      .then(res => res.json())
      .then(data => this.renderChart(data))
  }

  renderChart(data) {
    if (data.length === 0) return

    new Chart(this.canvasTarget, {
      type: "line",
      data: {
        labels: data.map(d => d.date),
        datasets: [
          {
            label: "Characters seen",
            data: data.map(d => d.seen),
            borderColor: "rgb(99, 102, 241)",
            backgroundColor: "rgba(99, 102, 241, 0.08)",
            fill: true,
            tension: 0.3,
            pointRadius: 2
          },
          {
            label: "Mastered",
            data: data.map(d => d.mastered),
            borderColor: "rgb(34, 197, 94)",
            backgroundColor: "rgba(34, 197, 94, 0.08)",
            fill: true,
            tension: 0.3,
            pointRadius: 2
          },
          {
            label: "In learning",
            data: data.map(d => d.learning),
            borderColor: "rgb(245, 158, 11)",
            backgroundColor: "rgba(245, 158, 11, 0.08)",
            fill: true,
            tension: 0.3,
            pointRadius: 2
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "top" }
        },
        scales: {
          y: { beginAtZero: true, ticks: { precision: 0 } }
        }
      }
    })
  }
}
