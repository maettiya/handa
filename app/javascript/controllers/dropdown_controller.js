// Handles the three-dot menu dropdown toggle
// Click to open, click outside to close

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // Close dropdown when clicking outside
    this.outsideClickHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
    document.addEventListener("click", this.outsideClickHandler)

    // Close all other dropdowns when this one opens
    this.element.addEventListener("click", () => {
      document.querySelectorAll(".menu-dropdown.open").forEach((menu) => {
        if (menu !== this.menuTarget) {
          menu.classList.remove("open")
        }
      })
    })
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.menuTarget.classList.toggle("open")
  }

  close() {
    this.menuTarget.classList.remove("open")
  }

  // Close when a menu item is clicked (except submenu parents)
  closeOnAction(event) {
    if (!event.target.closest(".menu-item-with-submenu")) {
      this.close()
    }
  }
}
