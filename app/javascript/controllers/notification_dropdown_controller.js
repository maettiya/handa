import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "badge"]
  static values = { markReadUrl: String }

  connect() {
    this.outsideClickHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
    document.addEventListener("click", this.outsideClickHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    const isOpening = !this.menuTarget.classList.contains("open")
    this.menuTarget.classList.toggle("open")

    // Mark as read when opening (if there's a badge)
    if (isOpening && this.hasBadgeTarget) {
      this.markAsRead()
    }
  }

  close() {
    this.menuTarget.classList.remove("open")
  }

  markAsRead() {
    fetch(this.markReadUrlValue, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      }
    }).then(() => {
      // Remove the badge
      if (this.hasBadgeTarget) {
        this.badgeTarget.remove()
      }
    })
  }
}
