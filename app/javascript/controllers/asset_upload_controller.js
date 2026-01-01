// Handles file uploads within an asset (adding files to existing asset/folder)
// Supports drag & drop and file picker

import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["fileInput", "dropZone", "progressContainer", "progressFill", "progressFilename", "progressPercent"]
  static values = { assetId: Number, parentId: Number }

  connect() {
    // Initialization if needed
  }

  openFilePicker() {
    this.fileInputTarget.click()
  }

  handleFileSelect(event) {
    const files = event.target.files
    if (files.length > 0) {
      this.uploadFiles(files)
    }
  }

  dragOver(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add("drag-over")
  }

  dragLeave(event) {
    this.dropZoneTarget.classList.remove("drag-over")
  }

  drop(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("drag-over")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.uploadFiles(files)
    }
  }

  async uploadFiles(files) {
    const url = this.fileInputTarget.dataset.directUploadUrl

    for (let i = 0; i < files.length; i++) {
      const file = files[i]
      await this.uploadFile(file, url, i + 1, files.length)
    }
  }

  uploadFile(file, url, current, total) {
    return new Promise((resolve, reject) => {
      // Show progress UI
      this.progressContainerTarget.classList.add("active")
      this.progressFilenameTarget.textContent = `Uploading '${file.name}' (${current}/${total})`
      this.progressFillTarget.style.width = "0%"
      this.progressPercentTarget.textContent = "0%"

      // Create DirectUpload instance with progress callback
      const upload = new DirectUpload(file, url, {
        directUploadWillStoreFileWithXHR: (request) => {
          request.upload.addEventListener("progress", (event) => {
            if (event.lengthComputable) {
              const percent = Math.round((event.loaded / event.total) * 100)
              this.progressFillTarget.style.width = percent + "%"
              this.progressPercentTarget.textContent = percent + "%"
            }
          })
        }
      })

      // Upload directly to storage (R2/S3)
      upload.create((error, blob) => {
        if (error) {
          console.error("Direct upload error:", error)
          this.progressFilenameTarget.textContent = `Failed: ${file.name}`
          this.progressPercentTarget.textContent = ""
          setTimeout(() => {
            this.progressContainerTarget.classList.remove("active")
            reject(error)
          }, 2000)
          return
        }

        // Success! Now submit to the server
        this.progressFilenameTarget.textContent = "Processing..."
        this.progressPercentTarget.textContent = ""

        // Create form data
        const formData = new FormData()
        formData.append("signed_id", blob.signed_id)
        if (this.parentIdValue) {
          formData.append("parent_id", this.parentIdValue)
        }

        // Get CSRF token
        const csrfToken = document.querySelector('meta[name="csrf-token"]').content

        fetch(`/items/${this.assetIdValue}/upload_files`, {
          method: "POST",
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "application/json"
          },
          body: formData
        })
        .then(response => response.json())
        .then(data => {
          if (data.success) {
            this.progressPercentTarget.textContent = "Done!"
            setTimeout(() => {
              // Reload the page to show the new file
              window.location.reload()
            }, 500)
            resolve()
          } else {
            throw new Error(data.errors?.join(", ") || "Upload failed")
          }
        })
        .catch(err => {
          console.error("Form submission error:", err)
          this.progressFilenameTarget.textContent = `Failed: ${err.message}`
          this.progressPercentTarget.textContent = ""
          setTimeout(() => {
            this.progressContainerTarget.classList.remove("active")
            reject(err)
          }, 2000)
        })
      })
    })
  }
}
