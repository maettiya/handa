import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  search() {
    clearTimeout(this.timeout)

    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      this.resultsTarget.classList.remove("visible")
      return
    }

    // Debounce: wait 200ms after typing stops
    this.timeout = setTimeout(() => {
      this.fetchResults(query)
    }, 200)
  }

  async fetchResults(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
      const users = await response.json()

      if (users.length === 0) {
        this.resultsTarget.innerHTML = `
          <div class="search-no-results">No users found</div>
        `
      } else {
        this.resultsTarget.innerHTML = users.map(user => `
          <div class="search-result-item">
            <div class="search-result-avatar">
              ${user.avatar_url
                ? `<img src="${user.avatar_url}" class="avatar-image" alt="${user.username}">`
                : `<span class="avatar-placeholder">${user.username[0].toUpperCase()}</span>`
              }
            </div>
            <span class="search-result-username">${user.username}</span>
            <form action="/collaborators" method="post" class="search-result-form">
              <input type="hidden" name="authenticity_token" value="${document.querySelector('meta[name="csrf-token"]').content}">
              <input type="hidden" name="username" value="${user.username}">
              <button type="submit" class="search-add-btn">+ Add</button>
            </form>
          </div>
        `).join("")
      }

      this.resultsTarget.classList.add("visible")
    } catch (error) {
      console.error("Search error:", error)
    }
  }

  hideResults(event) {
    // Delay hiding to allow click on results
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) {
        this.resultsTarget.classList.remove("visible")
      }
    }, 150)
  }

  showResults() {
    if (this.inputTarget.value.trim().length >= 2 && this.resultsTarget.innerHTML.trim() !== "") {
      this.resultsTarget.classList.add("visible")
    }
  }
}
