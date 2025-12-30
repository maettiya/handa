import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bpmMode", "bpmExact", "bpmRange", "searchInput", "bpmExactInput", "bpmMinInput", "bpmMaxInput"]

  connect() {
    this.debounceTimer = null
    this.shouldRefocusSearch = false
    this.searchCursorPosition = 0

    // Set up BPM input defaults for arrow clicks
    this.setupBpmDefaults()

    // If search input has autofocus and a value, move cursor to end
    if (this.hasSearchInputTarget && this.searchInputTarget.hasAttribute('autofocus')) {
      const len = this.searchInputTarget.value.length
      this.searchInputTarget.setSelectionRange(len, len)
    }
  }

  disconnect() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  setupBpmDefaults() {
    // When user clicks arrows on empty BPM inputs, start from sensible defaults
    if (this.hasBpmExactInputTarget) {
      this.bpmExactInputTarget.addEventListener('focus', (e) => {
        if (e.target.value === '') {
          e.target.value = '80'
        }
      })
    }

    if (this.hasBpmMinInputTarget) {
      this.bpmMinInputTarget.addEventListener('focus', (e) => {
        if (e.target.value === '') {
          e.target.value = '70'
        }
      })
    }

    if (this.hasBpmMaxInputTarget) {
      this.bpmMaxInputTarget.addEventListener('focus', (e) => {
        if (e.target.value === '') {
          e.target.value = '140'
        }
      })
    }
  }

  submit() {
    // Save search input state before submit for refocus
    if (this.hasSearchInputTarget && document.activeElement === this.searchInputTarget) {
      this.shouldRefocusSearch = true
      this.searchCursorPosition = this.searchInputTarget.selectionStart
      this.searchValue = this.searchInputTarget.value
    }

    this.element.requestSubmit()
  }

  // Debounced search for the text input - submits after user stops typing
  searchWithDebounce() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.submit()
    }, 300) // 300ms debounce
  }

  submitOnEnter(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      // Clear debounce and submit immediately
      if (this.debounceTimer) clearTimeout(this.debounceTimer)
      this.submit()
    }
  }

  toggleBpmMode() {
    const mode = this.bpmModeTarget.value

    if (mode === "exact") {
      this.bpmExactTarget.classList.remove("hidden")
      this.bpmRangeTarget.classList.add("hidden")
      // Clear range inputs when switching to exact
      this.bpmRangeTarget.querySelectorAll("input").forEach(input => input.value = "")
    } else {
      this.bpmExactTarget.classList.add("hidden")
      this.bpmRangeTarget.classList.remove("hidden")
      // Clear exact input when switching to range
      this.bpmExactTarget.querySelector("input").value = ""
    }
  }
}
