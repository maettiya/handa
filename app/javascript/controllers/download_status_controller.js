import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "label", "filename", "filenameClone", "track", "suffix", "progress", "bar", "barFill", "downloadBtn", "closeBtn"]
  static values = {
    downloadId: Number,
    pollInterval: { type: Number, default: 2000 }
  }

  connect() {
    // Check for any active downloads on page load
    this.checkActiveDownloads()

    // Listen for download requests from anywhere in the app
    this.boundStartDownload = this.handleStartDownload.bind(this)
    this.boundStartShareDownload = this.handleStartShareDownload.bind(this)
    document.addEventListener('handa:start-download', this.boundStartDownload)
    document.addEventListener('handa:start-share-download', this.boundStartShareDownload)
  }

  disconnect() {
    this.stopPolling()
    document.removeEventListener('handa:start-download', this.boundStartDownload)
    document.removeEventListener('handa:start-share-download', this.boundStartShareDownload)
  }

  // Handle custom event from download buttons (library assets)
  handleStartDownload(event) {
    const { assetId } = event.detail
    // Use streaming download - redirect directly to stream endpoint
    window.location.href = `/downloads/stream?asset_id=${assetId}`
  }

  // Handle custom event from share link download buttons
  handleStartShareDownload(event) {
    const { token, fileId } = event.detail
    // Use streaming download - redirect directly to stream endpoint
    let url = `/downloads/stream?share_link_token=${token}`
    if (fileId) url += `&file_id=${fileId}`
    window.location.href = url
  }

  async checkActiveDownloads() {
    try {
      const response = await fetch('/downloads/active')
      const data = await response.json()

      if (data.id) {
        this.downloadIdValue = data.id

        if (data.status === 'ready') {
          this.showStatus('ready', data.filename, data.total, data.total)
        } else if (data.status === 'processing' || data.status === 'pending') {
          this.showStatus('processing', data.filename, data.progress, data.total)
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
          this.showStatus('processing', data.filename, data.progress, data.total)
          break
        case 'ready':
          this.stopPolling()
          this.showStatus('ready', data.filename, data.total, data.total)
          break
        case 'failed':
          this.stopPolling()
          this.showStatus('failed', data.filename, 0, 0, data.error_message)
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

  showStatus(status, filename, progress, total, errorMessage = null) {
    this.element.classList.remove('hidden')
    this.containerTarget.dataset.status = status

    // Always show close button so user can dismiss at any time
    this.closeBtnTarget.classList.remove('hidden')

    // Calculate progress percentage
    const percent = total > 0 ? Math.round((progress / total) * 100) : 0

    if (status === 'ready') {
      this.labelTarget.textContent = ''
      this.filenameTarget.textContent = filename
      this.filenameCloneTarget.textContent = ''
      this.filenameCloneTarget.classList.add('hidden')
      this.suffixTarget.textContent = 'ready!'
      this.suffixTarget.classList.remove('hidden')
      this.progressTarget.classList.add('hidden')
      this.barTarget.classList.add('hidden')
      this.downloadBtnTarget.classList.remove('hidden')
    } else if (status === 'failed') {
      this.labelTarget.textContent = ''
      this.filenameTarget.textContent = filename
      this.filenameCloneTarget.textContent = ''
      this.filenameCloneTarget.classList.add('hidden')
      this.suffixTarget.textContent = 'failed'
      this.suffixTarget.classList.remove('hidden')
      this.progressTarget.classList.add('hidden')
      this.barTarget.classList.add('hidden')
      this.downloadBtnTarget.classList.add('hidden')
    } else {
      this.labelTarget.textContent = 'Preparing'
      this.filenameTarget.textContent = filename
      this.filenameCloneTarget.textContent = filename
      this.filenameCloneTarget.classList.remove('hidden')
      this.suffixTarget.classList.add('hidden')
      this.progressTarget.textContent = total > 0 ? `${progress}/${total}` : 'Preparing...'
      this.progressTarget.classList.remove('hidden')
      this.barTarget.classList.remove('hidden')
      this.barFillTarget.style.width = `${percent}%`
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
