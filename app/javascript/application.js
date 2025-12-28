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
