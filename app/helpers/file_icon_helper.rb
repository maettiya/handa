# File Icon Helper provides methods for selecting appropriate icons to be displayed
# Used in views to visually distinguish between file types

module FileIconHelper
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
