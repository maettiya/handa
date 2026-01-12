import { Controller } from "@hotwired/stimulus"

// Simple client-side search to filter files within a folder
export default class extends Controller {
  static targets = ["input", "card"]

  connect() {
    this.filterCards = this.filterCards.bind(this)
  }

  filterCards() {
    const query = this.inputTarget.value.toLowerCase().trim()

    this.cardTargets.forEach(card => {
      const filename = card.dataset.filename?.toLowerCase() || ""

      if (query === "" || filename.includes(query)) {
        card.style.display = ""
      } else {
        card.style.display = "none"
      }
    })
  }

  clear() {
    this.inputTarget.value = ""
    this.filterCards()
  }
}
