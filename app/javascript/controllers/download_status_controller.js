import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "text", "progress", "downloadBtn", "closeBtn"]
  static values = {
    downloadId: Number,
    pollInterval: { type: Number, default: 2000 }
  }

  connect() {
    // Check for any active downloads on page load
    this.checkActiveDownloads()
  }

  disconnect() {
    this.stopPolling()
  }

  // Called when user clicks "Download" on a folder
  async startDownload(event) {
    event.preventDefault()

    const assetId = event.currentTarget.dataset.assetId
    const filename = event.currentTarget.dataset.filename || "Download"

    try {
      const response = await fetch('/downloads', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ asset_id: assetId })
      })

      if (!response.ok) throw new Error('Failed to start download')

      const data = await response.json()
      this.downloadIdValue = data.id

      this.showStatus('processing', filename, 'Preparing...')
      this.startPolling()
    } catch (error) {
      console.error('Download error:', error)
      alert('Failed to start download. Please try again.')
    }
  }

  async checkActiveDownloads() {
    try {
      const response = await fetch('/downloads/active')
      const data = await response.json()

      if (data.id) {
        this.downloadIdValue = data.id

        if (data.status === 'ready') {
          this.showStatus('ready', data.filename, 'Ready!')
        } else if (data.status === 'processing' || data.status === 'pending') {
          this.showStatus('processing', data.filename, data.progress_text)
          this.startPolling()
        }
      }
    } catch (error) {
      console.error('Error checking active downloads:', error)
    }
  }

  startPolling() {
    this.stopPolling() // Clear any existing interval
    this.pollTimer = setInterval(() => this.pollStatus(), this.pollIntervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async pollStatus() {
    if (!this.downloadIdValue) return

    try {
      const response = await fetch(`/downloads/${this.downloadIdValue}/status`)
      const data = await response.json()

      switch (data.status) {
        case 'pending':
        case 'processing':
          this.showStatus('processing', data.filename, data.progress_text)
          break
        case 'ready':
          this.stopPolling()
          this.showStatus('ready', data.filename, 'Ready!')
          break
        case 'failed':
          this.stopPolling()
          this.showStatus('failed', data.filename, data.error_message || 'Failed')
          break
        case 'downloaded':
          this.stopPolling()
          this.hide()
          break
      }
    } catch (error) {
      console.error('Error polling status:', error)
    }
  }

  showStatus(status, filename, progressText) {
    this.containerTarget.classList.remove('hidden')
    this.containerTarget.dataset.status = status

    if (status === 'ready') {
      this.textTarget.innerHTML = `<span class="download-filename">${filename}</span> ready!`
      this.progressTarget.classList.add('hidden')
      this.downloadBtnTarget.classList.remove('hidden')
      this.closeBtnTarget.classList.add('hidden')
    } else if (status === 'failed') {
      this.textTarget.innerHTML = `<span class="download-filename">${filename}</span> failed`
      this.progressTarget.classList.add('hidden')
      this.downloadBtnTarget.classList.add('hidden')
      this.closeBtnTarget.classList.remove('hidden')
    } else {
      this.textTarget.innerHTML = `Preparing <span class="download-filename">${filename}</span>...`
      this.progressTarget.textContent = progressText
      this.progressTarget.classList.remove('hidden')
      this.downloadBtnTarget.classList.add('hidden')
      this.closeBtnTarget.classList.add('hidden')
    }
  }

  async downloadFile() {
    if (!this.downloadIdValue) return

    // Trigger the actual download
    window.location.href = `/downloads/${this.downloadIdValue}/file`

    // Hide the status bar after a short delay
    setTimeout(() => this.hide(), 1000)
  }

  hide() {
    this.containerTarget.classList.add('hidden')
    this.downloadIdValue = 0
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
