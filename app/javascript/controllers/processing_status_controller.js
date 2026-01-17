import { Controller } from "@hotwired/stimulus"

// Polls for asset processing status and updates the UI
// Attached to asset cards that have a processing_status
export default class extends Controller {
  static values = {
    assetId: Number,
    pollInterval: { type: Number, default: 2000 }
  }

  connect() {
    console.log("ProcessingStatusController connected for asset:", this.assetIdValue)
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.poll()
    this.timer = setInterval(() => this.poll(), this.pollIntervalValue)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  async poll() {
    try {
      const response = await fetch(`/items/${this.assetIdValue}/status`, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) return

      const data = await response.json()
      console.log("Poll response:", data)

      if (data.processing_status) {
        this.updateProgress(data)
      } else {
        // Processing complete - refresh the page to show final state
        this.stopPolling()
        window.location.reload()
      }
    } catch (error) {
      console.error("Error polling status:", error)
    }
  }

  updateProgress(data) {
    const progressText = this.element.querySelector("[data-processing-text]")
    if (progressText) {
      if (data.processing_status === "extracting") {
        progressText.textContent = `Extracting... ${data.processing_progress}/${data.processing_total}`
      } else if (data.processing_status === "importing") {
        progressText.textContent = `Saving... ${data.processing_progress}/${data.processing_total}`
      }
    }

    const progressBar = this.element.querySelector("[data-processing-bar]")
    if (progressBar && data.processing_total > 0) {
      const percent = Math.round((data.processing_progress / data.processing_total) * 100)
      progressBar.style.width = `${percent}%`
    }
  }
}
