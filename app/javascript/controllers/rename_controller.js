import * as Turbo from "@hotwired/turbo"

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "assetId", "fileId"]

  connect() {
    // Listen for rename button clicks anywhere on the page
    document.addEventListener("click", this.handleRenameClick.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.handleRenameClick.bind(this))
  }

  handleRenameClick(event) {
    const button = event.target.closest('[data-action="click->rename#open"]')
    if (button) {
      event.preventDefault()
      event.stopPropagation()
      this.openModal(button)
    }
  }

  openModal(button) {
    const assetId = button.dataset.assetId
    const assetTitle = button.dataset.assetTitle
    const fileId = button.dataset.fileId

    this.assetIdTarget.value = assetId
    this.inputTarget.value = assetTitle

    // Store fileId if renaming a child file (not root-level asset)
    if (this.hasFileIdTarget) {
      this.fileIdTarget.value = fileId || ""
    }

    this.element.classList.add("visible")
    setTimeout(() => {
      this.inputTarget.focus()
      this.inputTarget.select()
    }, 50)
  }

  // Keep open() for direct calls if needed
  open(event) {
    event.preventDefault()
    event.stopPropagation()
    this.openModal(event.currentTarget)
  }

  close() {
    this.element.classList.remove("visible")
    this.inputTarget.value = ""
  }

  async submit(event) {
    event.preventDefault()

    const assetId = this.assetIdTarget.value
    const newTitle = this.inputTarget.value.trim()
    const fileId = this.hasFileIdTarget ? this.fileIdTarget.value : null

    if (!newTitle) return

    // If fileId is present, this is renaming a child file (use AJAX)
    if (fileId) {
      await this.renameChildFile(assetId, fileId, newTitle)
    } else {
      // Renaming a root-level asset (use form submission)
      this.renameRootAsset(assetId, newTitle)
    }
  }

  async renameChildFile(assetId, fileId, newTitle) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    try {
      const response = await fetch(`/items/${assetId}/rename_file/${fileId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ title: newTitle })
      })

      const data = await response.json()

      if (data.success) {
        Turbo.visit(window.location.href)
      } else {
        alert("Could not rename: " + (data.error || "Unknown error"))
      }
    } catch (error) {
      console.error("Rename failed:", error)
      alert("Failed to rename")
    }
  }

  async renameRootAsset(assetId, newTitle) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    const formData = new FormData()
    formData.append("title", newTitle)

    try {
      const response = await fetch(`/items/${assetId}/rename`, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: formData
      })

      const data = await response.json()

      if (data.success) {
        this.close()
        Turbo.visit(window.location.href)
      } else {
        alert("Could not rename: " + (data.error || "Unknown error"))
      }
    } catch (error) {
      console.error("Rename failed:", error)
      alert("Failed to rename")
    }
  }
}
