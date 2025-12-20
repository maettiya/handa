# File Icon Helper provides methods for selecting appropriate icons to be displayed
# Used in views to visually distinguish between file types

module FileIconHelper
  def file_icon_for(project_file)
    if project_file.is_directory?
      "icons/folder.svg"
    else
      extension = File.extname(project_file.original_filename).downcase.delete(".")

      case extension
      when "als"
        "icons/ableton.svg"
      when "logicx"
        "icons/logic.svg"
      when "wav", "aif", "aiff", "flac"
        "icons/audio.svg"
      when "mp3", "m4a", "aac"
        "icons/mp3.svg"
      else
        "icons/file.svg"
      end
    end
  end
end
