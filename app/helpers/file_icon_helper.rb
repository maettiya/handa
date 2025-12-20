# File Icon Helper provides methods for selecting appropriate icons to be displayed
# Used in views to visually distinguish between file types

module FileIconHelper

  # First check project_type for extracted ZIP projects
  def project_icon_for(project)
    case project.project_type
    when "ableton"
      "icons/ableton.svg"
    when "logic"
      "icons/logic.svg"
    end

    # For single file uploads or unknown types, check the file extension
    if project.file.attached?
      extension = File.extname(project.file.filename.to_s).downcase.delete(".")

      case extension
      # DAW Project Files (if uploaded directly, not as ZIP)
      when "als"
        "icons/ableton.svg"
      when "logicx"
        "icons/logic.svg"

      # Lossless Audio Formats
      when "wav", "aif", "aiff", "flac"
        "icons/audio.svg"

      # Compressed Audio Formats
      when "mp3", "m4a", "aac"
        "icons/mp3.svg"

      # ZIP files that weren't categorized
      when "zip"
        "icons/folder.svg"

      # Fallback for unknown file types
      else
        "icons/file.svg"
      end
    else
      # No file attached, default to folder
      "icons/folder.svg"
    end
  end

  # Method for Project Files
  def file_icon_for(project_file)
    # Directories always get the folder icon
    if project_file.is_directory?
      "icons/folder.svg"
    else
      # Extract extension, make lowercase, remove the dot "Track.als" → "als"
      extension = File.extname(project_file.original_filename).downcase.delete(".")

      case extension
        # DAW Project Files
      when "als"
        "icons/ableton.svg"
      when "logicx"
        "icons/logic.svg"
        # Lossless Audio Formats
      when "wav", "aif", "aiff", "flac"
        "icons/audio.svg"
        # Compressed Audio Formats
      when "mp3", "m4a", "aac"
        "icons/mp3.svg"
        # Fallback for unknown file types
      else
        "icons/file.svg"
      end
    end
  end
end
