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
      # Ableton project folder vs .als file
      if asset.is_directory?
        return "icons/ableton-folder.svg"
      else
        return "icons/ableton-als.svg"
      end
    when "logic"
      return "icons/logic.svg"
    when "lossless_audio"
      return "icons/audio.svg"
    when "compressed_audio"
      return "icons/mp3.svg"
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
      "icons/ableton-als.svg"
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

  # Smart truncate for asset display names
  # Shows beginning...end.ext format for long names
  def truncated_asset_name(asset, max_length: 28, use_original: false)
    full_name = use_original && asset.original_filename.present? ? asset.original_filename : asset.title

    # Check if name already has the extension (e.g., original_filename = "kick.wav")
    file_extension = asset.file.attached? ? File.extname(asset.file.filename.to_s).downcase : ""
    name_has_extension = full_name.downcase.end_with?(file_extension.downcase) && file_extension.present?

    # Only append extension if not already present and not a directory
    extension = (!asset.is_directory? && !name_has_extension && file_extension.present?) ? file_extension : ""

    # Build display name
    display_name = "#{full_name}#{extension}"
    return display_name if display_name.length <= max_length

    # For truncation, figure out the actual extension in the display name
    actual_ext = File.extname(display_name)

    if actual_ext.present?
      available = max_length - actual_ext.length - 3  # 3 for "..."
      return display_name if available < 8  # Too short, let CSS handle it

      beginning_length = (available * 0.6).to_i
      end_length = available - beginning_length
      name_without_ext = display_name.chomp(actual_ext)

      "#{name_without_ext[0, beginning_length]}...#{name_without_ext[-end_length, end_length]}#{actual_ext}"
    else
      beginning_length = (max_length * 0.6).to_i - 2
      end_length = max_length - beginning_length - 3

      "#{full_name[0, beginning_length]}...#{full_name[-end_length, end_length]}"
    end
  end

  # Returns the full display name for tooltips
  def full_asset_name(asset, use_original: false)
    full_name = use_original && asset.original_filename.present? ? asset.original_filename : asset.title

    # Check if name already has the extension
    file_extension = asset.file.attached? ? File.extname(asset.file.filename.to_s).downcase : ""
    name_has_extension = full_name.downcase.end_with?(file_extension.downcase) && file_extension.present?

    # Only append extension if not already present and not a directory
    if asset.is_directory? || name_has_extension || file_extension.blank?
      full_name
    else
      "#{full_name}#{file_extension}"
    end
  end

end
