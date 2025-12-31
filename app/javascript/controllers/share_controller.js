import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "url", "copyBtn", "passwordField", "expiresField", "createForm", "linkDisplay"]

  open(event) {
    const projectId = event.currentTarget.dataset.projectId
    this.currentProjectId = projectId
    this.modalTarget.classList.add("visible")
    this.resetForm()
  }

  close() {
    this.modalTarget.classList.remove("visible")
    this.resetForm()
  }

  resetForm() {
    if (this.hasCreateFormTarget) {
      this.createFormTarget.classList.remove("hidden")
    }
    if (this.hasLinkDisplayTarget) {
      this.linkDisplayTarget.classList.add("hidden")
    }
    if (this.hasPasswordFieldTarget) {
      this.passwordFieldTarget.value = ""
    }
    if (this.hasExpiresFieldTarget) {
      this.expiresFieldTarget.value = ""
    }
  }

  async createLink(event) {
    event.preventDefault()
    const projectId = event.currentTarget.dataset.projectId || this.currentProjectId

    const formData = new FormData()
    if (this.hasPasswordFieldTarget && this.passwordFieldTarget.value) {
      formData.append("password", this.passwordFieldTarget.value)
    }
    if (this.hasExpiresFieldTarget && this.expiresFieldTarget.value) {
      formData.append("expires_at", this.expiresFieldTarget.value)
    }

    try {
      const response = await fetch(`/projects/${projectId}/share_links`, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: formData
      })

      const data = await response.json()

      if (data.success) {
        this.showLinkDisplay(data.url)
      } else {
        alert("Error creating link: " + data.errors.join(", "))
      }
    } catch (error) {
      console.error("Error:", error)
      alert("Failed to create share link")
    }
  }

  showLinkDisplay(url) {
    if (this.hasCreateFormTarget) {
      this.createFormTarget.classList.add("hidden")
    }
    if (this.hasLinkDisplayTarget) {
      this.linkDisplayTarget.classList.remove("hidden")
    }
    if (this.hasUrlTarget) {
      this.urlTarget.value = url
    }
  }

  copyLink() {
    if (this.hasUrlTarget) {
      this.urlTarget.select()
      navigator.clipboard.writeText(this.urlTarget.value)

      if (this.hasCopyBtnTarget) {
        const originalText = this.copyBtnTarget.textContent
        this.copyBtnTarget.textContent = "Copied!"
        setTimeout(() => {
          this.copyBtnTarget.textContent = originalText
        }, 2000)
      }
    }
  }

  // Close modal when clicking outside
  clickOutside(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }
}
