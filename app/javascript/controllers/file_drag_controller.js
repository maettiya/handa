import * as Turbo from "@hotwired/turbo"
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
    this.selectedFileIds = new Set()

    // Listen for clicks to handle selection
    this.handleClick = this.handleClick.bind(this)
    this.element.addEventListener('click', this.handleClick)

    // Listen for Escape to clear selection
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.handleKeydown)
  }

  disconnect() {
    this.element.removeEventListener('click', this.handleClick)
    document.removeEventListener('keydown', this.handleKeydown)
  }

  // Audio extensions that can be merged together
  get audioExtensions() {
    return ['wav', 'mp3', 'aiff', 'aif', 'flac', 'm4a', 'aac', 'ogg']
  }

  isAudioFile(extension) {
    return this.audioExtensions.includes(extension?.toLowerCase())
  }

  // ==================
  // SELECTION HANDLING
  // ==================

  handleClick(event) {
    const wrapper = event.target.closest('.project-card-wrapper')

    // If clicking on menu or its children, don't handle selection
    if (event.target.closest('.card-menu') || event.target.closest('.menu-dropdown')) {
      return
    }

    // If clicking on a link (folder navigation), don't handle selection
    if (event.target.closest('a.project-card')) {
      // Unless Cmd/Ctrl is held - then prevent navigation and select instead
      if (event.metaKey || event.ctrlKey) {
        event.preventDefault()
        if (wrapper) {
          this.toggleSelection(wrapper)
        }
      }
      return
    }

    // If clicking on a card wrapper with Cmd/Ctrl or Shift held
    if (wrapper && (event.metaKey || event.ctrlKey || event.shiftKey)) {
      event.preventDefault()

      if (event.shiftKey && this.lastSelectedWrapper) {
        // Shift+click: select range
        this.selectRange(this.lastSelectedWrapper, wrapper)
      } else {
        // Cmd/Ctrl+click: toggle single selection
        this.toggleSelection(wrapper)
      }
      return
    }

    // Regular click on empty space or without modifier - clear selection
    if (!wrapper || (!event.metaKey && !event.ctrlKey && !event.shiftKey)) {
      // Don't clear if clicking on audio player card (to play audio)
      if (wrapper && wrapper.querySelector('[data-audio-url]')) {
        // Allow audio to play, but clear selection
        this.clearSelection()
        return
      }

      if (!wrapper) {
        this.clearSelection()
      }
    }
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.clearSelection()
    }
  }

  toggleSelection(wrapper) {
    const fileId = wrapper.dataset.fileId

    if (this.selectedFileIds.has(fileId)) {
      this.selectedFileIds.delete(fileId)
      wrapper.classList.remove('selected')
    } else {
      this.selectedFileIds.add(fileId)
      wrapper.classList.add('selected')
      this.lastSelectedWrapper = wrapper
    }

    this.updateSelectionCount()
  }

  selectRange(startWrapper, endWrapper) {
    const wrappers = Array.from(this.element.querySelectorAll('.project-card-wrapper'))
    const startIndex = wrappers.indexOf(startWrapper)
    const endIndex = wrappers.indexOf(endWrapper)

    const minIndex = Math.min(startIndex, endIndex)
    const maxIndex = Math.max(startIndex, endIndex)

    for (let i = minIndex; i <= maxIndex; i++) {
      const wrapper = wrappers[i]
      const fileId = wrapper.dataset.fileId
      this.selectedFileIds.add(fileId)
      wrapper.classList.add('selected')
    }

    this.lastSelectedWrapper = endWrapper
    this.updateSelectionCount()
  }

  clearSelection() {
    this.selectedFileIds.clear()
    this.element.querySelectorAll('.project-card-wrapper.selected').forEach(el => {
      el.classList.remove('selected')
    })
    this.lastSelectedWrapper = null
    this.updateSelectionCount()
  }

  updateSelectionCount() {
    // Optional: could show a selection count indicator
    const count = this.selectedFileIds.size
    // console.log(`${count} files selected`)
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

    // If dragged file is not in selection, clear selection and just drag this one
    if (!this.selectedFileIds.has(this.draggedFileId)) {
      this.clearSelection()
      this.selectedFileIds.add(this.draggedFileId)
      wrapper.classList.add('selected')
    }

    // Add dragging class to all selected items
    this.selectedFileIds.forEach(id => {
      const el = this.element.querySelector(`[data-file-id="${id}"]`)
      if (el) el.classList.add('dragging')
    })

    // Set drag data
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', Array.from(this.selectedFileIds).join(','))
  }

  dragEnd(event) {
    // Remove dragging class from all
    this.element.querySelectorAll('.dragging').forEach(el => {
      el.classList.remove('dragging')
    })

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
    if (!wrapper) return

    // Don't allow dropping on a selected item
    if (this.selectedFileIds.has(wrapper.dataset.fileId)) return

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
    if (!wrapper) return

    // Don't allow dropping on a selected item
    if (this.selectedFileIds.has(wrapper.dataset.fileId)) return

    wrapper.classList.remove('drop-target')

    const targetId = wrapper.dataset.fileId
    const targetIsDirectory = wrapper.dataset.isDirectory === 'true'
    const targetFileType = wrapper.dataset.fileType

    const fileIds = Array.from(this.selectedFileIds)

    if (targetIsDirectory) {
      // Move all selected files into folder
      this.moveFiles(fileIds, targetId)
    } else if (fileIds.length === 1 && this.isAudioFile(this.draggedFileType) && this.isAudioFile(targetFileType)) {
      // Single audio file merge (only works with 1 selected file)
      this.mergeFiles(fileIds[0], targetId)
    } else if (fileIds.length > 1) {
      // Multiple files dropped on non-folder - create new folder with all
      this.mergeMultipleFiles(fileIds, targetId)
    }
  }

  isValidDropTarget(targetIsDirectory, targetFileType) {
    // Folders accept anything
    if (targetIsDirectory) return true

    // For single file: audio files can merge with other audio files
    if (this.selectedFileIds.size === 1 && this.isAudioFile(this.draggedFileType) && this.isAudioFile(targetFileType)) {
      return true
    }

    // For multiple files: can drop on any file to create a folder
    if (this.selectedFileIds.size > 1) {
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

    if (this.selectedFileIds.size === 0) return

    const folderId = event.target.dataset.folderId
    const fileIds = Array.from(this.selectedFileIds)

    if (folderId === 'root') {
      // Moving to library root level
      this.moveFiles(fileIds, 'library')
      return
    }

    // asset_root means the asset's root level (parent_id = asset.id)
    const targetId = folderId === 'asset_root' ? 'root' : folderId
    this.moveFiles(fileIds, targetId)
  }

  // ==================
  // API CALLS
  // ==================

  async moveFiles(fileIds, targetId) {
    try {
      const response = await fetch(this.moveUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          file_ids: fileIds,
          target_id: targetId
        })
      })

      const data = await response.json()

      if (data.success) {
        this.clearSelection()
        if (data.redirect) {
          Turbo.visit(data.redirect)
        } else {
          Turbo.visit(window.location.href)
        }
      } else {
        alert('Failed to move files: ' + (data.error || 'Unknown error'))
      }
    } catch (error) {
      console.error('Move failed:', error)
      alert('Failed to move files')
    }
  }

  // Keep single file move for backwards compatibility
  async moveFile(fileId, targetId) {
    return this.moveFiles([fileId], targetId)
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
          file_ids: [fileId],
          merge_with_id: otherFileId
        })
      })

      const data = await response.json()

      if (data.success) {
        this.clearSelection()
        Turbo.visit(window.location.href)
      } else {
        alert('Failed to merge files: ' + (data.error || 'Unknown error'))
      }
    } catch (error) {
      console.error('Merge failed:', error)
      alert('Failed to merge files')
    }
  }

  async mergeMultipleFiles(fileIds, targetFileId) {
    // Add the target file to the list, then create a folder with all of them
    const allFileIds = [...fileIds, targetFileId]

    try {
      const response = await fetch(this.moveUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          file_ids: allFileIds,
          create_folder: true
        })
      })

      const data = await response.json()

      if (data.success) {
        this.clearSelection()
        Turbo.visit(window.location.href)
      } else {
        alert('Failed to create folder: ' + (data.error || 'Unknown error'))
      }
    } catch (error) {
      console.error('Create folder failed:', error)
      alert('Failed to create folder')
    }
  }
}
