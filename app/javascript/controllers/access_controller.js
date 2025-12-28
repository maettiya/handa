import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    this.element.classList.add("visible")
  }

  close() {
    this.element.classList.remove("visible")
  }
}
