import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurfer.js"

export default class extends Controller {
  static targets = ["waveform", "title", "currentTime", "duration", "playBtn", "volume", "volumePopup", "volumeBtn"]

  connect() {
    // Don't reinitialize if wavesurfer already exists (Turbo navigation)
    if (this.wavesurfer) return

    this.isPlaying = false
    this.currentUrl = null

    // Initialize WaveSurfer
    this.wavesurfer = WaveSurfer.create({
      container: this.waveformTarget,
      waveColor: "#888888",
      progressColor: "#f97316",
      cursorColor: "#f97316",
      cursorWidth: 2,
      barWidth: 2,
      barGap: 1,
      barRadius: 2,
      height: 48,
      responsive: true,
      normalize: true
    })

    // Event listeners for WaveSurfer
    this.wavesurfer.on("ready", () => {
      this.durationTarget.textContent = this.formatTime(this.wavesurfer.getDuration())
      this.updatePlayButton()
    })

    this.wavesurfer.on("audioprocess", () => {
      this.currentTimeTarget.textContent = this.formatTime(this.wavesurfer.getCurrentTime())
    })

    this.wavesurfer.on("seeking", () => {
      this.currentTimeTarget.textContent = this.formatTime(this.wavesurfer.getCurrentTime())
    })

    this.wavesurfer.on("finish", () => {
      this.isPlaying = false
      this.updatePlayButton()
    })

    this.wavesurfer.on("play", () => {
      this.isPlaying = true
      this.updatePlayButton()
    })

    this.wavesurfer.on("pause", () => {
      this.isPlaying = false
      this.updatePlayButton()
    })

    // Listen for audio file clicks anywhere on the page
    this.boundHandleAudioClick = this.handleAudioClick.bind(this)
    this.boundHandleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundHandleAudioClick)
    document.addEventListener("click", this.boundHandleOutsideClick)

    // Preserve state during Turbo navigation
    document.addEventListener("turbo:before-cache", () => {
      // Keep playing during navigation - don't destroy
    })
  }

  disconnect() {
    // Don't destroy on disconnect - we want persistence
    // Only clean up event listeners
    document.removeEventListener("click", this.boundHandleAudioClick)
    document.removeEventListener("click", this.boundHandleOutsideClick)
  }

  handleOutsideClick(event) {
    // Close volume popup if clicking outside of it
    if (this.hasVolumePopupTarget &&
        this.volumePopupTarget.classList.contains("visible") &&
        !event.target.closest(".audio-player-volume-wrapper")) {
      this.volumePopupTarget.classList.remove("visible")
    }
  }

  handleAudioClick(event) {
    const audioElement = event.target.closest("[data-audio-url]")
    if (!audioElement) return

    event.preventDefault()
    event.stopPropagation()

    const url = audioElement.dataset.audioUrl
    const title = audioElement.dataset.audioTitle || "Unknown Track"

    this.loadAndPlay(url, title)
  }

  loadAndPlay(url, title) {
    // Show the player
    this.element.classList.add("visible")

    // Update title and reset scroll animation
    this.titleTarget.classList.remove("scrolling")
    this.titleTarget.textContent = title

    // Clear any existing scroll timeout
    if (this.scrollTimeout) {
      clearTimeout(this.scrollTimeout)
    }

    // Start scrolling after 2 seconds if title is longer than container
    this.scrollTimeout = setTimeout(() => {
      if (this.titleTarget.scrollWidth > this.titleTarget.parentElement.clientWidth) {
        this.titleTarget.classList.add("scrolling")
      }
    }, 2000)

    // If same track, just toggle play/pause
    if (this.currentUrl === url) {
      this.togglePlay()
      return
    }

    // Load new track
    this.currentUrl = url
    this.currentTimeTarget.textContent = "0:00"
    this.durationTarget.textContent = "0:00"

    this.wavesurfer.load(url)
    this.wavesurfer.once("ready", () => {
      this.wavesurfer.play()
    })
  }

  togglePlay() {
    if (!this.wavesurfer) return

    this.wavesurfer.playPause()
  }

  setVolume(event) {
    const volume = parseFloat(event.target.value)
    this.wavesurfer.setVolume(volume)
  }

  toggleVolume(event) {
    event.stopPropagation()
    this.volumePopupTarget.classList.toggle("visible")
  }

  close() {
    // Hide volume popup if open
    this.volumePopupTarget.classList.remove("visible")

    // Clear scroll timeout
    if (this.scrollTimeout) {
      clearTimeout(this.scrollTimeout)
    }
    this.titleTarget.classList.remove("scrolling")

    // Stop playback
    if (this.wavesurfer) {
      this.wavesurfer.stop()
    }

    // Hide the player
    this.element.classList.remove("visible")

    // Reset state
    this.isPlaying = false
    this.currentUrl = null
    this.updatePlayButton()
  }

  updatePlayButton() {
    if (this.isPlaying) {
      this.playBtnTarget.innerHTML = `
        <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
          <rect x="6" y="4" width="4" height="16" rx="1"/>
          <rect x="14" y="4" width="4" height="16" rx="1"/>
        </svg>
      `
    } else {
      this.playBtnTarget.innerHTML = `
        <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
          <path d="M8 5v14l11-7z"/>
        </svg>
      `
    }
  }

  formatTime(seconds) {
    if (isNaN(seconds)) return "0:00"
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, "0")}`
  }
}
