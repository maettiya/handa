import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = [
    "dropzone", "dropzoneContent", "options", "result",
    "filename", "resultFilename", "password", "expires",
    "url", "copyBtn", "fileInput", "progress", "progressFill",
    "progressFilename", "progressPercent"
  ]

  static values = {
    createUrl: String,
    directUploadUrl: String
  }

  connect() {
    this.file = null
  }

  // Drag & drop handlers
  dragOver(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("dragover")
  }

  dragLeave(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("dragover")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("dragover")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.selectFile(files[0])
    }
  }

  // File picker
  openFilePicker() {
    this.fileInputTarget.click()
  }

  handleFileSelect(event) {
    const files = event.target.files
    if (files.length > 0) {
      this.selectFile(files[0])
    }
  }

  selectFile(file) {
    this.file = file
    this.filenameTarget.textContent = file.name
    this.dropzoneContentTarget.classList.add("hidden")
    this.optionsTarget.classList.remove("hidden")
  }

  // Reset to initial state
  reset() {
    this.file = null
    this.fileInputTarget.value = ""
    this.dropzoneContentTarget.classList.remove("hidden")
    this.optionsTarget.classList.add("hidden")
    this.resultTarget.classList.add("hidden")
    this.progressTarget.style.display = "none"
    this.passwordTarget.value = ""
    this.expiresTarget.value = "24_hours"
  }

  // Create share link
  async createShare() {
    if (!this.file) return

    // Show progress
    this.optionsTarget.classList.add("hidden")
    this.progressTarget.style.display = "block"
    this.progressFilenameTarget.textContent = this.file.name

    try {
      // Direct upload to R2
      const blob = await this.uploadFile(this.file)

      // Create the quick share
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({
          signed_id: blob.signed_id,
          filename: this.file.name,
          password: this.passwordTarget.value || null,
          expires_at: this.expiresTarget.value || null
        })
      })

      const data = await response.json()

      if (data.success) {
        this.showResult(data.url, this.file.name)
      } else {
        alert("Failed to create share link: " + (data.errors || "Unknown error"))
        this.reset()
      }
    } catch (error) {
      console.error("Upload failed:", error)
      alert("Upload failed. Please try again.")
      this.reset()
    }
  }

  uploadFile(file) {
    return new Promise((resolve, reject) => {
      const upload = new DirectUpload(file, this.directUploadUrlValue, this)

      upload.create((error, blob) => {
        if (error) {
          reject(error)
        } else {
          resolve(blob)
        }
      })
    })
  }

  // DirectUpload delegate methods
  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress", event => {
      const progress = (event.loaded / event.total) * 100
      this.progressFillTarget.style.width = `${progress}%`
      this.progressPercentTarget.textContent = `${Math.round(progress)}%`
    })
  }

  showResult(url, filename) {
    this.progressTarget.style.display = "none"
    this.resultTarget.classList.remove("hidden")
    this.resultFilenameTarget.textContent = filename
    this.urlTarget.value = url
  }

  // Copy link
  copyLink() {
    this.urlTarget.select()
    document.execCommand("copy")
    this.copyBtnTarget.textContent = "Copied!"
    setTimeout(() => {
      this.copyBtnTarget.textContent = "Copy"
    }, 2000)
  }

  // Copy existing link from history
  copyExistingLink(event) {
    const url = event.currentTarget.dataset.url
    navigator.clipboard.writeText(url).then(() => {
      const btn = event.currentTarget
      const originalText = btn.textContent
      btn.textContent = "Copied!"
      setTimeout(() => {
        btn.textContent = originalText
      }, 2000)
    })
  }
}
