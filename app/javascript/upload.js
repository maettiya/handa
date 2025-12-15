document.addEventListener("turbo:load", function() {
  const addBtn = document.getElementById("add-project-btn");
  const uploadForm = document.getElementById("upload-form");
  const dropZone = document.getElementById("drop-zone");
  const fileInput = document.getElementById("file-input");
  const fileDetails = document.getElementById("file-details");
  const selectedFileName = document.getElementById("selected-file-title");

  if (!addBtn) return;

  // Toggle form when clicking button
  addBtn.addEventListener("click", function() {
    const isHidden = uploadForm.style.display === "none";
    uploadForm.style.display = isHidden ? "block" : "none";
    addBtn.textContent = isHidden ? "Cancel" : "+ Add projects";
  });

  // Click drop zone to open file browser
  dropZone.addEventListener("click", function() {
    fileInput.click();
  });

  // Show title input when file selected
  fileInput.addEventListener("change", function() {
    if (fileInput.files.length > 0) {
      selectedFileName.textContent = fileInput.files[0].name;
      fileDetails.style.display = "block";
    }
  });
});
