import { DirectUpload } from "@rails/activestorage"

document.addEventListener("turbo:load", function() {
  const addBtn = document.getElementById("add-project-btn");
  const dropZone = document.getElementById("drop-zone");
  const fileInput = document.getElementById("file-input");
  const titleInput = document.getElementById("project-title-input");

  // Progress UI elements
  const progressContainer = document.getElementById("upload-progress");
  const progressFill = document.getElementById("upload-progress-fill");
  const progressFilename = document.getElementById("upload-filename");
  const progressPercent = document.getElementById("upload-percent");

  // Only run on library page (where titleInput exists)
  // Project show page uses project_upload_controller.js instead
  if (!addBtn || !titleInput) return;

  // Click button to open file browser
  addBtn.addEventListener("click", function() {
    fileInput.click();
  });

  // Auto-submit when file selected
  fileInput.addEventListener("change", function() {
    if (fileInput.files.length > 0) {
      const file = fileInput.files[0];
      const fileName = file.name;
      titleInput.value = fileName.replace(/\.[^/.]+$/, ""); // Remove file extension

      // Upload with Direct Upload (browser -> R2 directly)
      uploadWithDirectUpload(file, titleInput.value);
    }
  });

  // Drag and drop
  dropZone.addEventListener("dragover", function(e) {
    e.preventDefault();
    dropZone.classList.add("drag-over");
  });

  dropZone.addEventListener("dragleave", function() {
    dropZone.classList.remove("drag-over");
  });

  dropZone.addEventListener("drop", function(e) {
    e.preventDefault();
    dropZone.classList.remove("drag-over");
    fileInput.files = e.dataTransfer.files;
    fileInput.dispatchEvent(new Event("change"));
  });

  function uploadWithDirectUpload(file, title) {
    // Show progress UI
    progressContainer.classList.add("active");
    progressFilename.textContent = "Uploading '" + file.name + "'";
    progressFill.style.width = "0%";
    progressPercent.textContent = "0%";

    // Get the direct upload URL from the file input's data attribute
    const url = fileInput.dataset.directUploadUrl;

    // Create DirectUpload instance with progress callback
    const upload = new DirectUpload(file, url, {
      directUploadWillStoreFileWithXHR: (request) => {
        request.upload.addEventListener("progress", (event) => {
          if (event.lengthComputable) {
            const percent = Math.round((event.loaded / event.total) * 100);
            progressFill.style.width = percent + "%";
            progressPercent.textContent = percent + "%";
          }
        });
      }
    });

    // Upload directly to storage (R2/S3)
    upload.create((error, blob) => {
      if (error) {
        console.error("Direct upload error:", error);
        progressFilename.textContent = "Upload failed";
        progressPercent.textContent = "";
        setTimeout(function() {
          progressContainer.classList.remove("active");
        }, 3000);
        return;
      }

      // Success! Now submit form with just the signed blob ID
      progressFilename.textContent = "Processing...";
      progressPercent.textContent = "";

      // Create form and submit
      const formData = new FormData();
      formData.append("asset[file]", blob.signed_id);
      formData.append("asset[title]", title);

      // Get CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

      fetch("/items", {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/html"
        },
        body: formData
      })
      .then(response => {
        if (response.ok || response.redirected) {
          progressPercent.textContent = "Done!";
          setTimeout(function() {
            window.location.href = "/";
          }, 500);
        } else {
          throw new Error("Form submission failed");
        }
      })
      .catch(err => {
        console.error("Form submission error:", err);
        progressFilename.textContent = "Upload failed";
        progressPercent.textContent = "";
        setTimeout(function() {
          progressContainer.classList.remove("active");
        }, 3000);
      });
    });
  }
});
