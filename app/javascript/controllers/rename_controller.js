import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "projectId"]

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    const projectId = event.currentTarget.dataset.projectId
    const projectTitle = event.currentTarget.dataset.projectTitle

    this.projectIdTarget.value = projectId
    this.inputTarget.value = projectTitle

    this.element.classList.add("visible")
    setTimeout(() => {
      this.inputTarget.focus()
      this.inputTarget.select()
    }, 50)
  }

  close() {
    this.element.classList.remove("visible")
    this.inputTarget.value = ""
  }

  submit(event) {
    event.preventDefault()

    const projectId = this.projectIdTarget.value
    const newTitle = this.inputTarget.value.trim()

    if (!newTitle) return

    // Create and submit a form
    const form = document.createElement("form")
    form.method = "POST"
    form.action = `/projects/${projectId}/rename`

    // CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    const csrfInput = document.createElement("input")
    csrfInput.type = "hidden"
    csrfInput.name = "authenticity_token"
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)

    // Method override for PATCH
    const methodInput = document.createElement("input")
    methodInput.type = "hidden"
    methodInput.name = "_method"
    methodInput.value = "patch"
    form.appendChild(methodInput)

    // Title
    const titleInput = document.createElement("input")
    titleInput.type = "hidden"
    titleInput.name = "title"
    titleInput.value = newTitle
    form.appendChild(titleInput)

    document.body.appendChild(form)
    form.submit()
  }
}
