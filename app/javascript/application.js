// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import "./upload"

// Auto-submit avatar form when file is selected
document.addEventListener("turbo:load", () => {
  const avatarInput = document.getElementById("avatar-input");
  if (avatarInput) {
    avatarInput.addEventListener("change", () => {
      avatarInput.closest("form").requestSubmit();
    });
  }
});

// Right-click context menu for creating folders
document.addEventListener("turbo:load", () => {
  const dropZone = document.getElementById("drop-zone");
  const contextMenu = document.getElementById("context-menu");
  const folderModal = document.getElementById("folder-modal");
  const folderNameInput = document.getElementById("folder-name-input");
  const cancelFolder = document.getElementById("cancel-folder");
  const contextNewFolder = document.getElementById("context-new-folder");

  if (!dropZone || !contextMenu) return;

  // Show context menu on right-click (only on empty space, not on cards)
  dropZone.addEventListener("contextmenu", (e) => {
    // Don't show context menu if right-clicking on a project card
    if (e.target.closest(".project-card-wrapper")) {
      return; // Let the default behavior happen (nothing)
    }

    e.preventDefault();
    contextMenu.style.left = e.pageX + "px";
    contextMenu.style.top = e.pageY + "px";
    contextMenu.classList.add("visible");
  });

  // Hide context menu on click elsewhere
  document.addEventListener("click", () => {
    contextMenu.classList.remove("visible");
  });

  // Open folder modal from context menu
  if (contextNewFolder) {
    contextNewFolder.addEventListener("click", () => {
      contextMenu.classList.remove("visible");
      folderModal.classList.add("visible");
      setTimeout(() => folderNameInput.focus(), 50);
    });
  }

  // Open folder modal from "+ New folder" button
  const addFolderBtn = document.getElementById("add-folder-btn");
  if (addFolderBtn) {
    addFolderBtn.addEventListener("click", () => {
      folderModal.classList.add("visible");
      setTimeout(() => folderNameInput.focus(), 50);
    });
  }

  // Cancel folder creation
  if (cancelFolder) {
    cancelFolder.addEventListener("click", () => {
      folderModal.classList.remove("visible");
      folderNameInput.value = "";
    });
  }

  // Close modal on escape key
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && folderModal?.classList.contains("visible")) {
      folderModal.classList.remove("visible");
      folderNameInput.value = "";
    }
  });
});
