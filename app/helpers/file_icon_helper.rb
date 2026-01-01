# FileIconHelper provides methods for selecting appropriate icons to be displayed
# Used in views to visually distinguish between file types

module FileIconHelper

  # Returns icon for an Asset (used throughout the app)
  # Works for root-level assets in library AND child assets within extracted ZIPs
  #
  # @param asset [Asset] The asset record
  # @return [String] Path to the SVG icon

  def asset_icon_for(asset)
    # Check asset_type first - works for both files and folders
    # Folders containing .als files get asset_type='ableton' during extraction
    case asset.asset_type
    when "ableton"
      return "icons/ableton.svg"
    when "logic"
      return "icons/logic.svg"
    end

    # Regular directories/folders get the folder icon
    if asset.is_directory?
      return "icons/folder.svg"
    end

    # For files, check the extension
    extension = asset.extension

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

    # ZIP files
    when "zip"
      "icons/folder.svg"

    # Fallback for unknown file types
    else
      "icons/file.svg"
    end
  end

  # Legacy alias for backwards compatibility during transition
  # TODO: Remove after migration is complete
  def project_icon_for(project)
    asset_icon_for(project)
  end

  # Legacy alias for backwards compatibility during transition
  # TODO: Remove after migration is complete
  def file_icon_for(project_file)
    asset_icon_for(project_file)
  end
end
