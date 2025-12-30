import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "wrapper"]
  static values = { url: String }

  connect() {
    this.selectedIndex = -1
    this.debounceTimer = null

    // Close on click outside
    this.outsideClickHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.hideResults()
      }
    }
    document.addEventListener("click", this.outsideClickHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  search() {
    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.hideResults()
      return
    }

    // Debounce the search
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.fetchSuggestions(query)
    }, 200)
  }

  async fetchSuggestions(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
      const suggestions = await response.json()

      if (suggestions.length > 0) {
        this.showResults(suggestions)
      } else {
        this.hideResults()
      }
    } catch (error) {
      console.error("Search suggestions error:", error)
      this.hideResults()
    }
  }

  showResults(suggestions) {
    this.selectedIndex = -1
    this.resultsTarget.innerHTML = suggestions.map((suggestion, index) => `
      <div class="autocomplete-item" data-index="${index}" data-action="click->search-autocomplete#selectSuggestion">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <span>${this.escapeHtml(suggestion)}</span>
      </div>
    `).join('')

    this.resultsTarget.classList.add("visible")
  }

  hideResults() {
    this.resultsTarget.classList.remove("visible")
    this.selectedIndex = -1
  }

  keydown(event) {
    const items = this.resultsTarget.querySelectorAll(".autocomplete-item")
    if (items.length === 0) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
        this.highlightItem(items)
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
        this.highlightItem(items)
        break
      case "Enter":
        if (this.selectedIndex >= 0) {
          event.preventDefault()
          this.inputTarget.value = items[this.selectedIndex].querySelector("span").textContent
          this.hideResults()
          this.inputTarget.form.submit()
        }
        break
      case "Escape":
        this.hideResults()
        break
    }
  }

  highlightItem(items) {
    items.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add("highlighted")
      } else {
        item.classList.remove("highlighted")
      }
    })
  }

  selectSuggestion(event) {
    const item = event.currentTarget
    this.inputTarget.value = item.querySelector("span").textContent
    this.hideResults()
    this.inputTarget.form.submit()
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
