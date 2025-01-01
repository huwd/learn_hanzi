import { Controller } from "stimulus"

export default class extends Controller {
  connect() {
    console.log("Tags controller connected")
  }

  load(event) {
    event.preventDefault()
    const url = event.currentTarget.getAttribute('href')
    fetch(url, {
      headers: {
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
    .then(response => response.text())
    .then(html => {
      document.getElementById('tag_details').innerHTML = html
    })
  }
}