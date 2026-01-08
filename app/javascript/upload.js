import * as Turbo from "@hotwired/turbo"

import { DirectUpload } from "@rails/activestorage"

document.addEventListener("turbo:load", function() {
  const addBtn = document.getElementById("add-project-btn");
  const dropZone = document.getElementById("drop-zone");
  const fileInput = document.getElementById("file-input");
  const titleInput = document.getElementById("project-title-input");

  // Progress UI container
  const progressContainer = document.getElementById("upload-progress");

  // Only run on library page (where titleInput exists)
  if (!addBtn || !titleInput) return;

  // Click button to open file browser
  addBtn.addEventListener("click", function() {
    fileInput.click();
  });

  // Auto-submit when files selected
  fileInput.addEventListener("change", function() {
    if (fileInput.files.length > 0) {
      uploadMultipleFiles(Array.from(fileInput.files));
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

    const files = Array.from(e.dataTransfer.files);
    if (files.length > 0) {
      uploadMultipleFiles(files);
    }
  });

  // Track active uploads
  let activeUploads = 0;
  let uploadIdCounter = 0;

  function uploadMultipleFiles(files) {
    progressContainer.classList.add("active");

    files.forEach(file => {
      const uploadId = ++uploadIdCounter;
      const title = file.name.replace(/\.[^/.]+$/, "");
      uploadSingleFile(file, title, uploadId);
    });
  }

  function createProgressElement(uploadId, fileName) {
    const progressItem = document.createElement("div");
    progressItem.className = "upload-progress-item";
    progressItem.id = `upload-item-${uploadId}`;
    progressItem.innerHTML = `
      <div class="upload-progress-info">
        <span class="upload-filename">Uploading '${escapeHtml(fileName)}'</span>
        <span class="upload-percent">0%</span>
      </div>
      <div class="upload-progress-bar">
        <div class="upload-progress-fill"></div>
      </div>
    `;
    progressContainer.appendChild(progressItem);
    return progressItem;
  }

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  function uploadSingleFile(file, title, uploadId) {
    activeUploads++;

    const progressItem = createProgressElement(uploadId, file.name);
    const progressFill = progressItem.querySelector(".upload-progress-fill");
    const progressFilename = progressItem.querySelector(".upload-filename");
    const progressPercent = progressItem.querySelector(".upload-percent");

    const url = fileInput.dataset.directUploadUrl;

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

    upload.create((error, blob) => {
      if (error) {
        console.error("Direct upload error:", error);
        progressFilename.textContent = "Upload failed: " + file.name;
        progressPercent.textContent = "";
        progressItem.classList.add("upload-error");
        setTimeout(() => removeProgressItem(progressItem, uploadId), 3000);
        return;
      }

      progressFilename.textContent = "Processing '" + file.name + "'";
      progressPercent.textContent = "";

      const formData = new FormData();
      formData.append("asset[file]", blob.signed_id);
      formData.append("asset[title]", title);

      const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

      fetch("/items", {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken, "Accept": "text/html" },
        body: formData
      })
      .then(response => {
        if (response.ok || response.redirected) {
          progressFilename.textContent = file.name;
          progressPercent.textContent = "Done!";
          progressItem.classList.add("upload-complete");
          setTimeout(() => removeProgressItem(progressItem, uploadId), 1500);
        } else {
          throw new Error("Form submission failed");
        }
      })
      .catch(err => {
        console.error("Form submission error:", err);
        progressFilename.textContent = "Upload failed: " + file.name;
        progressPercent.textContent = "";
        progressItem.classList.add("upload-error");
        setTimeout(() => removeProgressItem(progressItem, uploadId), 3000);
      });
    });
  }

  function removeProgressItem(progressItem, uploadId) {
    progressItem.remove();
    activeUploads--;

    if (activeUploads === 0) {
      progressContainer.classList.remove("active");
      Turbo.visit("/");
    }
  }
});
