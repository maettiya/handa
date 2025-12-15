document.addEventListener("turbo:load", function() {
  const addBtn = document.getElementById("add-project-btn");
  const dropZone = document.getElementById("drop-zone");
  const fileInput = document.getElementById("file-input");
  const fileDetails = document.getElementById("file-details");
  const selectedFileName = document.getElementById("selected-file-title");

  if (!addBtn) return;

  // Click button to open file browser
  addBtn.addEventListener("click", function() {
    fileInput.click();
  });

  // Show title input when file selected
  fileInput.addEventListener("change", function() {
    if (fileInput.files.length > 0) {
      selectedFileName.textContent = fileInput.files[0].name;
      fileDetails.style.display = "block";
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
});
