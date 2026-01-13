// Handles file uploads within an asset (adding files to existing asset/folder)
// Supports drag & drop and file picker - parallel uploads with stacked progress bars
// Now with folder support - folders are zipped client-side before upload

import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"
import * as Turbo from "@hotwired/turbo"
import { containsFolders, processDroppedItems, FolderTooLargeError } from "../folder_zipper"

export default class extends Controller {
  static targets = ["fileInput", "dropZone"]
  static values = { assetId: Number, parentId: Number }

  connect() {
    this.activeUploads = 0
    this.uploadIdCounter = 0
    this.progressContainer = document.getElementById("upload-progress")
  }

  openFilePicker() {
    this.fileInputTarget.click()
  }

  handleFileSelect(event) {
    const files = Array.from(event.target.files)
    if (files.length > 0) {
      this.uploadMultipleFiles(files)
    }
  }

  dragOver(event) {
    // If dragging over a card wrapper, let file-drag controller handle it
    if (event.target.closest('.project-card-wrapper')) {
      return
    }
    // Only handle external file drops (from desktop), not internal card drags
    if (!event.dataTransfer.types.includes('Files')) {
      return
    }
    event.preventDefault()
    this.dropZoneTarget.classList.add("drag-over")
  }

  dragLeave(event) {
    this.dropZoneTarget.classList.remove("drag-over")
  }

  async drop(event) {
    // If dropping on a card wrapper, let file-drag controller handle it
    if (event.target.closest('.project-card-wrapper')) {
      return
    }

    // Only handle external file drops, not internal card drags
    if (!event.dataTransfer.types.includes('Files')) {
      return
    }

    event.preventDefault()
    this.dropZoneTarget.classList.remove("drag-over")

    // Check if drop contains folders
    if (containsFolders(event.dataTransfer)) {
      await this.handleFolderDrop(event.dataTransfer)
    } else {
      const files = Array.from(event.dataTransfer.files)
      if (files.length > 0) {
        this.uploadMultipleFiles(files)
      }
    }
  }

  async handleFolderDrop(dataTransfer) {
    const prepareId = ++this.uploadIdCounter
    const progressItem = this.createProgressElement(prepareId, "folder")
    const progressFill = progressItem.querySelector(".upload-progress-fill")
    const progressFilename = progressItem.querySelector(".upload-filename")
    const progressPercent = progressItem.querySelector(".upload-percent")

    this.progressContainer.classList.add("active")
    progressFilename.textContent = "Scanning folder..."
    progressPercent.textContent = ""

    try {
      const files = await processDroppedItems(dataTransfer, (progress) => {
        if (progress.phase === "scanning") {
          progressFilename.textContent = `Scanning "${progress.folderName}"...`
        } else if (progress.phase === "zipping") {
          progressFilename.textContent = `Preparing "${progress.folderName}" (${progress.fileCount} files)...`
        } else if (progress.phase === "compressing") {
          progressFilename.textContent = `Compressing "${progress.folderName}"...`
          progressFill.style.width = progress.percent + "%"
          progressPercent.textContent = progress.percent + "%"
        }
      })

      // Remove the preparation progress item
      progressItem.remove()

      // Upload the resulting files (zipped folders + regular files)
      if (files.length > 0) {
        this.uploadMultipleFiles(files)
      } else {
        this.progressContainer.classList.remove("active")
      }

    } catch (error) {
      if (error instanceof FolderTooLargeError) {
        progressFilename.textContent = error.message
        progressPercent.textContent = ""
        progressItem.classList.add("upload-error")
        setTimeout(() => {
          progressItem.remove()
          if (this.activeUploads === 0) {
            this.progressContainer.classList.remove("active")
          }
        }, 5000)
      } else {
        console.error("Folder processing error:", error)
        progressFilename.textContent = "Failed to process folder"
        progressPercent.textContent = ""
        progressItem.classList.add("upload-error")
        setTimeout(() => {
          progressItem.remove()
          if (this.activeUploads === 0) {
            this.progressContainer.classList.remove("active")
          }
        }, 3000)
      }
    }
  }

  uploadMultipleFiles(files) {
    this.progressContainer.classList.add("active")

    files.forEach(file => {
      const uploadId = ++this.uploadIdCounter
      this.uploadSingleFile(file, uploadId)
    })
  }

  createProgressElement(uploadId, fileName) {
    const progressItem = document.createElement("div")
    progressItem.className = "upload-progress-item"
    progressItem.id = `upload-item-${uploadId}`
    progressItem.innerHTML = `
      <div class="upload-progress-info">
        <span class="upload-filename">Uploading '${this.escapeHtml(fileName)}'</span>
        <span class="upload-percent">0%</span>
      </div>
      <div class="upload-progress-bar">
        <div class="upload-progress-fill"></div>
      </div>
    `
    this.progressContainer.appendChild(progressItem)
    return progressItem
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  uploadSingleFile(file, uploadId) {
    this.activeUploads++

    const progressItem = this.createProgressElement(uploadId, file.name)
    const progressFill = progressItem.querySelector(".upload-progress-fill")
    const progressFilename = progressItem.querySelector(".upload-filename")
    const progressPercent = progressItem.querySelector(".upload-percent")

    const url = this.fileInputTarget.dataset.directUploadUrl

    const upload = new DirectUpload(file, url, {
      directUploadWillStoreFileWithXHR: (request) => {
        request.upload.addEventListener("progress", (event) => {
          if (event.lengthComputable) {
            const percent = Math.round((event.loaded / event.total) * 100)
            progressFill.style.width = percent + "%"
            progressPercent.textContent = percent + "%"
          }
        })
      }
    })

    upload.create((error, blob) => {
      if (error) {
        console.error("Direct upload error:", error)
        progressFilename.textContent = "Upload failed: " + file.name
        progressPercent.textContent = ""
        progressItem.classList.add("upload-error")
        setTimeout(() => this.removeProgressItem(progressItem, uploadId), 3000)
        return
      }

      progressFilename.textContent = "Processing '" + file.name + "'"
      progressPercent.textContent = ""

      const formData = new FormData()
      formData.append("signed_id", blob.signed_id)
      if (this.parentIdValue) {
        formData.append("parent_id", this.parentIdValue)
      }

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
          progressFilename.textContent = file.name
          progressPercent.textContent = "Done!"
          progressItem.classList.add("upload-complete")
          setTimeout(() => this.removeProgressItem(progressItem, uploadId), 1500)
        } else {
          throw new Error(data.errors?.join(", ") || "Upload failed")
        }
      })
      .catch(err => {
        console.error("Form submission error:", err)
        progressFilename.textContent = "Upload failed: " + file.name
        progressPercent.textContent = ""
        progressItem.classList.add("upload-error")
        setTimeout(() => this.removeProgressItem(progressItem, uploadId), 3000)
      })
    })
  }

  removeProgressItem(progressItem, uploadId) {
    progressItem.remove()
    this.activeUploads--

    if (this.activeUploads === 0) {
      this.progressContainer.classList.remove("active")
      Turbo.visit(window.location.href)
    }
  }
}
