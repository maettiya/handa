// Handles the three-dot menu dropdown toggle
// Click to open, click outside to close

import { Controller } from "@hotwired/stimulus"

// Shared backdrop for all dropdowns
let sharedBackdrop = null
let activeDropdown = null

function getOrCreateBackdrop() {
  if (!sharedBackdrop) {
    sharedBackdrop = document.createElement("div")
    sharedBackdrop.className = "menu-backdrop"
    sharedBackdrop.addEventListener("click", () => {
      if (activeDropdown) {
        activeDropdown.close()
      }
    })
    document.body.appendChild(sharedBackdrop)
  }
  return sharedBackdrop
}

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

    // Check if mobile
    this.isMobile = window.matchMedia("(max-width: 768px)").matches
    this.mediaQuery = window.matchMedia("(max-width: 768px)")
    this.mediaQueryHandler = (e) => { this.isMobile = e.matches }
    this.mediaQuery.addEventListener("change", this.mediaQueryHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
    this.mediaQuery.removeEventListener("change", this.mediaQueryHandler)

    // If this was the active dropdown, hide backdrop
    if (activeDropdown === this) {
      this.hideBackdrop()
      activeDropdown = null
    }
  }

  showBackdrop() {
    const backdrop = getOrCreateBackdrop()
    backdrop.classList.add("visible")
    activeDropdown = this
  }

  hideBackdrop() {
    if (sharedBackdrop) {
      sharedBackdrop.classList.remove("visible")
    }
    if (activeDropdown === this) {
      activeDropdown = null
    }
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    // Close any other open dropdowns first
    document.querySelectorAll(".menu-dropdown.open").forEach((menu) => {
      if (menu !== this.menuTarget) {
        menu.classList.remove("open")
      }
    })

    const isOpening = !this.menuTarget.classList.contains("open")
    this.menuTarget.classList.toggle("open")

    // Show/hide backdrop on mobile
    if (this.isMobile) {
      if (isOpening) {
        this.showBackdrop()
      } else {
        this.hideBackdrop()
      }
    }

    // Reset any open submenus when closing
    if (!isOpening) {
      this.closeAllSubmenus()
    }
  }

  close() {
    this.menuTarget.classList.remove("open")
    this.closeAllSubmenus()
    this.hideBackdrop()
  }

  // Toggle submenu on mobile (click instead of hover)
  toggleSubmenu(event) {
    if (!this.isMobile) return // Let CSS hover handle desktop

    event.preventDefault()
    event.stopPropagation()

    const submenuParent = event.currentTarget.closest(".menu-item-with-submenu")
    if (!submenuParent) return

    // Close other submenus first
    this.element.querySelectorAll(".menu-item-with-submenu.submenu-open").forEach((item) => {
      if (item !== submenuParent) {
        item.classList.remove("submenu-open")
      }
    })

    // Toggle this submenu
    submenuParent.classList.toggle("submenu-open")
  }

  closeAllSubmenus() {
    this.element.querySelectorAll(".menu-item-with-submenu.submenu-open").forEach((item) => {
      item.classList.remove("submenu-open")
    })
  }

  // Close when a menu item is clicked (except submenu parents)
  closeOnAction(event) {
    if (!event.target.closest(".menu-item-with-submenu")) {
      this.close()
    }
  }
}
