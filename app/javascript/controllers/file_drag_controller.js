import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    moveUrl: String
  }

  connect() {
    this.draggedElement = null
    this.draggedFileId = null
    this.draggedFileType = null
    this.draggedIsDirectory = false
  }

  // Audio extensions that can be merged together
  get audioExtensions() {
    return ['wav', 'mp3', 'aiff', 'aif', 'flac', 'm4a', 'aac', 'ogg']
  }

  isAudioFile(extension) {
    return this.audioExtensions.includes(extension?.toLowerCase())
  }

  // ==================
  // CARD DRAG EVENTS
  // ==================

  dragStart(event) {
    const wrapper = event.target.closest('.project-card-wrapper')
    if (!wrapper) return

    this.draggedElement = wrapper
    this.draggedFileId = wrapper.dataset.fileId
    this.draggedFileType = wrapper.dataset.fileType
    this.draggedIsDirectory = wrapper.dataset.isDirectory === 'true'

    wrapper.classList.add('dragging')

    // Set drag data
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', this.draggedFileId)
  }

  dragEnd(event) {
    if (this.draggedElement) {
      this.draggedElement.classList.remove('dragging')
    }
    this.draggedElement = null
    this.draggedFileId = null
    this.draggedFileType = null
    this.draggedIsDirectory = false

    // Remove all drop-target highlights
    document.querySelectorAll('.drop-target').forEach(el => {
      el.classList.remove('drop-target')
    })
  }

  dragOver(event) {
    event.preventDefault()
    const wrapper = event.target.closest('.project-card-wrapper')
    if (!wrapper || wrapper === this.draggedElement) return

    const targetIsDirectory = wrapper.dataset.isDirectory === 'true'
    const targetFileType = wrapper.dataset.fileType

    // Check if this is a valid drop target
    if (this.isValidDropTarget(targetIsDirectory, targetFileType)) {
      event.dataTransfer.dropEffect = 'move'
      wrapper.classList.add('drop-target')
    }
  }

  dragLeave(event) {
    const wrapper = event.target.closest('.project-card-wrapper')
    if (wrapper) {
      wrapper.classList.remove('drop-target')
    }
  }

  drop(event) {
    event.preventDefault()
    const wrapper = event.target.closest('.project-card-wrapper')
    if (!wrapper || wrapper === this.draggedElement) return

    wrapper.classList.remove('drop-target')

    const targetId = wrapper.dataset.fileId
    const targetIsDirectory = wrapper.dataset.isDirectory === 'true'
    const targetFileType = wrapper.dataset.fileType

    if (targetIsDirectory) {
      // Move into folder
      this.moveFile(this.draggedFileId, targetId)
    } else if (this.isAudioFile(this.draggedFileType) && this.isAudioFile(targetFileType)) {
      // Merge two audio files into new folder
      this.mergeFiles(this.draggedFileId, targetId)
    }
  }

  isValidDropTarget(targetIsDirectory, targetFileType) {
    // Folders accept anything
    if (targetIsDirectory) return true

    // Audio files can merge with other audio files
    if (this.isAudioFile(this.draggedFileType) && this.isAudioFile(targetFileType)) {
      return true
    }

    return false
  }

  // ==================
  // BREADCRUMB EVENTS
  // ==================

  breadcrumbDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    event.target.classList.add('drop-target')
  }

  breadcrumbDragLeave(event) {
    event.target.classList.remove('drop-target')
  }

  breadcrumbDrop(event) {
    event.preventDefault()
    event.target.classList.remove('drop-target')

    if (!this.draggedFileId) return

    const folderId = event.target.dataset.folderId

    if (folderId === 'root') {
      // Moving to library - not supported (different model)
      console.log('Moving to library not supported')
      return
    }

    // project_root means the project's root level (parent_id = nil)
    const targetId = folderId === 'project_root' ? 'root' : folderId
    this.moveFile(this.draggedFileId, targetId)
  }

  // ==================
  // API CALLS
  // ==================

  async moveFile(fileId, targetId) {
    try {
      const response = await fetch(this.moveUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          file_id: fileId,
          target_id: targetId
        })
      })

      const data = await response.json()

      if (data.success) {
        // Reload the page to show updated file structure
        window.location.reload()
      } else {
        alert('Failed to move file: ' + (data.error || 'Unknown error'))
      }
    } catch (error) {
      console.error('Move failed:', error)
      alert('Failed to move file')
    }
  }

  async mergeFiles(fileId, otherFileId) {
    try {
      const response = await fetch(this.moveUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          file_id: fileId,
          merge_with_id: otherFileId
        })
      })

      const data = await response.json()

      if (data.success) {
        window.location.reload()
      } else {
        alert('Failed to merge files: ' + (data.error || 'Unknown error'))
      }
    } catch (error) {
      console.error('Merge failed:', error)
      alert('Failed to merge files')
    }
  }
}
