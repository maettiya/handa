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

    // Listen for download requests from anywhere in the app
    this.boundStartDownload = this.handleStartDownload.bind(this)
    document.addEventListener('handa:start-download', this.boundStartDownload)
  }

  disconnect() {
    this.stopPolling()
    document.removeEventListener('handa:start-download', this.boundStartDownload)
  }

  // Handle custom event from download buttons
  handleStartDownload(event) {
    const { assetId, filename } = event.detail
    this.initiateDownload(assetId, filename)
  }

  // Called when user clicks "Download" on a folder (via custom event)
  async initiateDownload(assetId, filename) {
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
    this.stopPolling()
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
    this.element.classList.remove('hidden')
    this.containerTarget.dataset.status = status

    // Always show close button so user can dismiss at any time
    this.closeBtnTarget.classList.remove('hidden')

    if (status === 'ready') {
      this.textTarget.innerHTML = `<span class="download-filename">${filename}</span> ready!`
      this.progressTarget.classList.add('hidden')
      this.downloadBtnTarget.classList.remove('hidden')
    } else if (status === 'failed') {
      this.textTarget.innerHTML = `<span class="download-filename">${filename}</span> failed`
      this.progressTarget.classList.add('hidden')
      this.downloadBtnTarget.classList.add('hidden')
    } else {
      this.textTarget.innerHTML = `Preparing <span class="download-filename">${filename}</span>...`
      this.progressTarget.textContent = progressText
      this.progressTarget.classList.remove('hidden')
      this.downloadBtnTarget.classList.add('hidden')
    }
  }

  async downloadFile() {
    if (!this.downloadIdValue) return

    window.location.href = `/downloads/${this.downloadIdValue}/file`

    setTimeout(() => this.hide(), 1000)
  }

  async hide() {
    // Tell backend to dismiss this download so it doesn't reappear on reload
    if (this.downloadIdValue) {
      try {
        await fetch(`/downloads/${this.downloadIdValue}`, {
          method: 'DELETE',
          headers: {
            'X-CSRF-Token': this.csrfToken
          }
        })
      } catch (error) {
        console.error('Error dismissing download:', error)
      }
    }

    this.stopPolling()
    this.element.classList.add('hidden')
    this.downloadIdValue = 0
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
