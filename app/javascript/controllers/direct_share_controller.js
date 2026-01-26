import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "list", "loading", "empty"]
  static values = {
    assetId: Number,
    loaded: { type: Boolean, default: false }
  }

  connect() {
    // Close menu when clicking outside
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener('click', this.boundClickOutside)
  }

  disconnect() {
    document.removeEventListener('click', this.boundClickOutside)
  }

  clickOutside(event) {
    if (this.hasMenuTarget && !this.element.contains(event.target)) {
      this.menuTarget.classList.remove('show')
    }
  }

  // Load frequent recipients when submenu opens
  async loadRecipients() {
    if (this.loadedValue) return

    this.showLoading()

    try {
      const response = await fetch('/direct_shares/frequent_recipients')
      const recipients = await response.json()

      this.loadedValue = true
      this.renderRecipients(recipients)
    } catch (error) {
      console.error('Failed to load recipients:', error)
      this.showEmpty()
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove('hidden')
    if (this.hasEmptyTarget) this.emptyTarget.classList.add('hidden')
    if (this.hasListTarget) this.listTarget.innerHTML = ''
  }

  showEmpty() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add('hidden')
    if (this.hasEmptyTarget) this.emptyTarget.classList.remove('hidden')
  }

  renderRecipients(recipients) {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add('hidden')

    if (recipients.length === 0) {
      this.showEmpty()
      return
    }

    if (this.hasEmptyTarget) this.emptyTarget.classList.add('hidden')

    const html = recipients.map(recipient => `
      <button class="access-submenu-item share-recipient"
              data-action="click->direct-share#share"
              data-recipient-id="${recipient.id}"
              data-recipient-name="${recipient.username}">
        <div class="access-mini-avatar" style="background: ${this.avatarColor(recipient.username)};">
          ${recipient.username[0].toUpperCase()}
        </div>
        <span>${recipient.username}</span>
        <svg class="share-check hidden" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#22c55e" stroke-width="3">
          <polyline points="20 6 9 17 4 12"></polyline>
        </svg>
      </button>
    `).join('')

    this.listTarget.innerHTML = html
  }

  avatarColor(name) {
    const colors = ['#6366f1', '#22c55e', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6']
    const index = name.charCodeAt(0) % colors.length
    return colors[index]
  }

  async share(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const recipientId = button.dataset.recipientId
    const recipientName = button.dataset.recipientName
    const assetId = this.assetIdValue

    // Disable button to prevent double-clicks
    button.disabled = true

    try {
      const response = await fetch('/direct_shares', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          asset_id: assetId,
          recipient_id: recipientId
        })
      })

      const data = await response.json()

      if (data.success) {
        // Show success animation
        this.showSuccess(button)
      } else {
        console.error('Share failed:', data.error)
        button.disabled = false
      }
    } catch (error) {
      console.error('Share error:', error)
      button.disabled = false
    }
  }

  showSuccess(button) {
    // Show checkmark
    const check = button.querySelector('.share-check')
    if (check) {
      check.classList.remove('hidden')
    }

    // Add success styling
    button.classList.add('shared')

    // Hide after delay
    setTimeout(() => {
      if (check) check.classList.add('hidden')
      button.classList.remove('shared')
      button.disabled = false
    }, 2000)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
