document.addEventListener("turbo:load", function() {
  const addBtn = document.getElementById("add-project-btn");
  const dropZone = document.getElementById("drop-zone");
  const fileInput = document.getElementById("file-input");
  const uploadForm = document.getElementById("upload-form");
  const titleInput = document.getElementById("project-title-input");

  // Progress UI elements
  const progressContainer = document.getElementById("upload-progress");
  const progressFill = document.getElementById("upload-progress-fill");
  const progressFilename = document.getElementById("upload-filename");
  const progressPercent = document.getElementById("upload-percent");

  if (!addBtn) return;

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

      // Upload with progress tracking
      uploadWithProgress(file, titleInput.value);
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

  function uploadWithProgress(file, title) {
    // Show progress UI
    progressContainer.classList.add("active");
    progressFilename.textContent = "Uploading '" + file.name + "'";
    progressFill.style.width = "0%";
    progressPercent.textContent = "0%";

    // Build form data
    const formData = new FormData();
    formData.append("project[file]", file);
    formData.append("project[title]", title);

    // Get CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    // XMLHttpRequest for progress events
    const xhr = new XMLHttpRequest();

    xhr.upload.addEventListener("progress", function(e) {
      if (e.lengthComputable) {
        const percent = Math.round((e.loaded / e.total) * 100);
        progressFill.style.width = percent + "%";
        progressPercent.textContent = percent + "%";
      }
    });

    xhr.addEventListener("load", function() {
      if (xhr.status >= 200 && xhr.status < 300) {
        // Success - redirect to library
        progressPercent.textContent = "Done!";
        setTimeout(function() {
          window.location.href = "/";
        }, 500);
      } else {
        // Error
        progressFilename.textContent = "Upload failed";
        progressPercent.textContent = "";
        setTimeout(function() {
          progressContainer.classList.remove("active");
        }, 3000);
      }
    });

    xhr.addEventListener("error", function() {
      progressFilename.textContent = "Upload failed";
      progressPercent.textContent = "";
      setTimeout(function() {
        progressContainer.classList.remove("active");
      }, 3000);
    });

    xhr.open("POST", "/projects");
    xhr.setRequestHeader("X-CSRF-Token", csrfToken);
    xhr.setRequestHeader("Accept", "text/html");
    xhr.send(formData);
  }
});
