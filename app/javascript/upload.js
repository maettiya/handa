import * as Turbo from "@hotwired/turbo"
import { DirectUpload } from "@rails/activestorage"
import { containsFolders, processDroppedItems, FolderTooLargeError } from "./folder_zipper"

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

  dropZone.addEventListener("drop", async function(e) {
    e.preventDefault();
    dropZone.classList.remove("drag-over");

    // Check if drop contains folders
    if (containsFolders(e.dataTransfer)) {
      await handleFolderDrop(e.dataTransfer);
    } else {
      // Regular files - existing flow
      const files = Array.from(e.dataTransfer.files);
      if (files.length > 0) {
        uploadMultipleFiles(files);
      }
    }
  });

  // Track active uploads and pending extractions
  let activeUploads = 0;
  let uploadIdCounter = 0;
  let pendingExtractions = [];

  // Handle folder drop - zip and upload
  async function handleFolderDrop(dataTransfer) {
    const prepareId = ++uploadIdCounter;
    const progressItem = createProgressElement(prepareId, "folder");
    const progressFill = progressItem.querySelector(".upload-progress-fill");
    const progressFilename = progressItem.querySelector(".upload-filename");
    const progressPercent = progressItem.querySelector(".upload-percent");

    progressContainer.classList.add("active");
    progressFilename.textContent = "Scanning folder...";
    progressPercent.textContent = "";

    try {
      const files = await processDroppedItems(dataTransfer, (progress) => {
        if (progress.phase === "scanning") {
          progressFilename.textContent = `Scanning "${progress.folderName}"...`;
        } else if (progress.phase === "zipping") {
          progressFilename.textContent = `Preparing "${progress.folderName}" (${progress.fileCount} files)...`;
        } else if (progress.phase === "compressing") {
          progressFilename.textContent = `Compressing "${progress.folderName}"...`;
          progressFill.style.width = progress.percent + "%";
          progressPercent.textContent = progress.percent + "%";
        }
      });

      // Remove the preparation progress item
      progressItem.remove();

      // Upload the resulting files (zipped folders + regular files)
      if (files.length > 0) {
        uploadMultipleFiles(files);
      } else {
        progressContainer.classList.remove("active");
      }

    } catch (error) {
      if (error instanceof FolderTooLargeError) {
        progressFilename.textContent = error.message;
        progressPercent.textContent = "";
        progressItem.classList.add("upload-error");
        setTimeout(() => {
          progressItem.remove();
          if (activeUploads === 0) {
            progressContainer.classList.remove("active");
          }
        }, 5000);
      } else {
        console.error("Folder processing error:", error);
        progressFilename.textContent = "Failed to process folder";
        progressPercent.textContent = "";
        progressItem.classList.add("upload-error");
        setTimeout(() => {
          progressItem.remove();
          if (activeUploads === 0) {
            progressContainer.classList.remove("active");
          }
        }, 3000);
      }
    }
  }

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
    const isZip = file.name.toLowerCase().endsWith('.zip');

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
        setTimeout(() => removeProgressItem(progressItem, uploadId, null), 3000);
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
        headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
        body: formData
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          if (isZip) {
            // ZIP file - need to wait for extraction
            progressFilename.textContent = `Extracting "${data.title}"...`;
            progressPercent.textContent = "";
            progressFill.style.width = "100%";
            removeProgressItem(progressItem, uploadId, data.id);
          } else {
            // Regular file - no extraction needed
            progressFilename.textContent = file.name;
            progressPercent.textContent = "Done!";
            progressItem.classList.add("upload-complete");
            setTimeout(() => removeProgressItem(progressItem, uploadId, null), 1500);
          }
        } else {
          throw new Error(data.errors?.join(", ") || "Upload failed");
        }
      })
      .catch(err => {
        console.error("Form submission error:", err);
        progressFilename.textContent = "Upload failed: " + file.name;
        progressPercent.textContent = "";
        progressItem.classList.add("upload-error");
        setTimeout(() => removeProgressItem(progressItem, uploadId, null), 3000);
      });
    });
  }

  function removeProgressItem(progressItem, uploadId, assetId) {
    progressItem.remove();
    activeUploads--;

    // If this was a ZIP, track it for extraction polling
    if (assetId) {
      pendingExtractions.push(assetId);
    }

    if (activeUploads === 0) {
      if (pendingExtractions.length > 0) {
        // Wait for all extractions to complete before refreshing
        pollExtractions();
      } else {
        progressContainer.classList.remove("active");
        Turbo.visit("/");
      }
    }
  }

  // Poll for extraction completion
  async function pollExtractions() {
    const extractionProgressItem = createProgressElement(++uploadIdCounter, "extraction");
    const progressFilename = extractionProgressItem.querySelector(".upload-filename");
    const progressPercent = extractionProgressItem.querySelector(".upload-percent");

    progressFilename.textContent = "Extracting files...";
    progressPercent.textContent = "";

    const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    while (pendingExtractions.length > 0) {
      // Check each pending extraction
      const stillPending = [];

      for (const assetId of pendingExtractions) {
        try {
          const response = await fetch(`/items/${assetId}/status`, {
            headers: { "Accept": "application/json", "X-CSRF-Token": csrfToken }
          });
          const data = await response.json();

          if (!data.extracted) {
            stillPending.push(assetId);
          }
        } catch (err) {
          console.error("Status check failed:", err);
          stillPending.push(assetId);
        }
      }

      pendingExtractions = stillPending;

      if (pendingExtractions.length > 0) {
        progressFilename.textContent = `Extracting files... (${pendingExtractions.length} remaining)`;
        await sleep(1500); // Poll every 1.5 seconds
      }
    }

    extractionProgressItem.remove();
    progressContainer.classList.remove("active");
    Turbo.visit("/");
  }

  function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
});
