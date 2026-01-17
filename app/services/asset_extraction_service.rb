# Handles extraction of uploaded ZIP files and creates child Asset records
# for each file/folder in the archive. Detects asset type (Ableton, Logic, etc.)
# and auto-hides junk files (.asd, system folders, etc.)

require 'zip'

class AssetExtractionService
  def initialize(asset)
    @asset = asset
    @processed_count = 0
  end

  def extract!
    return unless zip_file?

    # Count total files first, then set processing status
    total_files = count_extractable_files
    @asset.update!(
      processing_status: 'extracting',
      processing_progress: 0,
      processing_total: total_files
    )

    # Track folders we create so we can set parent relationships
    folder_map = {}

    # Download the ZIP to a temp file (required for cloud storage like S3/R2)
    download_and_extract(folder_map)

    detect_asset_type!
    @asset.update!(
      extracted: true,
      is_directory: true,
      processing_status: nil,
      processing_progress: 0,
      processing_total: 0
    )
  end

  private

  def zip_file?
    @asset.file.attached? &&
      @asset.file.content_type == 'application/zip'
  end

  def count_extractable_files
    count = 0
    @asset.file.open do |tempfile|
      Zip::File.open(tempfile.path) do |zip|
        zip.each do |entry|
          next if entry.name.end_with?('/')
          parts = entry.name.split('/')
          filename = parts.last
          next if filename.start_with?('.')
          count += 1
        end
      end
    end
    count
  end

  def download_and_extract(folder_map)
    # Download blob to a temp file, then extract
    @asset.file.open do |tempfile|
      Zip::File.open(tempfile.path) do |zip|
        zip.each do |entry|
          # Skip the root folder that macOS creates when zipping
          next if entry.name.end_with?('/')

          process_entry(entry, folder_map, zip)
        end
      end
    end
  end

  def process_entry(entry, folder_map, zip)
    # Get path components: "MyProject/Samples/kick.wav" -> ["MyProject", "Samples", "kick.wav"]
    parts = entry.name.split('/')
    filename = parts.last

    # Skip hidden system files
    return if filename.start_with?('.')

    # Ensure parent folders exist
    parent = ensure_folders_exist(parts[0..-2], folder_map)

    # Create the file record as a child Asset
    is_directory = entry.directory?

    child_asset = @asset.user.assets.create!(
      title: filename,
      original_filename: filename,
      path: entry.name,
      file_type: is_directory ? 'directory' : File.extname(filename).delete('.').downcase,
      file_size: entry.size,
      is_directory: is_directory,
      hidden: Asset.should_hide?(filename, is_directory: is_directory),
      parent_id: parent&.id || @asset.id  # Parent is folder or root asset
    )

    # Attach the actual file content (skip for directories)
    unless is_directory
      # Read into StringIO so the stream can be rewound for checksum calculation
      content = StringIO.new(zip.get_input_stream(entry).read)
      child_asset.file.attach(
        io: content,
        filename: filename,
        content_type: detect_content_type(filename)
      )
    end

    # Track folders for parent relationships
    folder_map[entry.name] = child_asset if is_directory

    # Update progress
    @processed_count += 1
    @asset.update_columns(processing_progress: @processed_count)
  end

  def ensure_folders_exist(folder_parts, folder_map)
    return nil if folder_parts.empty?

    parent = nil
    current_path = ""

    folder_parts.each do |folder_name|
      current_path = current_path.empty? ? folder_name : "#{current_path}/#{folder_name}"
      folder_key = "#{current_path}/"

      unless folder_map[folder_key]
        folder_map[folder_key] = @asset.user.assets.create!(
          title: folder_name,
          original_filename: folder_name,
          path: folder_key,
          file_type: 'directory',
          is_directory: true,
          hidden: Asset.should_hide?(folder_name, is_directory: true),
          parent_id: parent&.id || @asset.id  # Parent is folder or root asset
        )
      end

      parent = folder_map[folder_key]
    end

    parent
  end

  def detect_asset_type!
    # Check for known project file types in ALL descendants
    all_descendants = collect_all_descendants(@asset)

    als_file = all_descendants.find { |a| a.original_filename&.downcase&.end_with?('.als') }
    logic_file = all_descendants.find { |a| a.original_filename&.downcase&.end_with?('.logicx') }

    asset_type = if als_file
                   'ableton'
                 elsif logic_file
                   'logic'
                 else
                   'folder'
                 end

    @asset.update!(asset_type: asset_type)

    # Also mark folder assets that contain DAW project files
    mark_daw_project_folders(all_descendants)
  end

  # Marks folders that directly contain .als or .logicx files as DAW project folders
  def mark_daw_project_folders(all_descendants)
    all_descendants.select(&:is_directory?).each do |folder|
      als_in_folder = folder.children.exists?(["LOWER(original_filename) LIKE ?", "%.als"])
      logic_in_folder = folder.children.exists?(["LOWER(original_filename) LIKE ?", "%.logicx"])

      if als_in_folder
        folder.update!(asset_type: 'ableton')
      elsif logic_in_folder
        folder.update!(asset_type: 'logic')
      end
    end
  end

  def collect_all_descendants(asset)
    children = asset.children.to_a
    children + children.select(&:is_directory?).flat_map { |c| collect_all_descendants(c) }
  end

  def detect_content_type(filename)
    extension = File.extname(filename).downcase

    {
      '.als' => 'application/x-ableton-live-set',
      '.wav' => 'audio/wav',
      '.mp3' => 'audio/mpeg',
      '.aif' => 'audio/aiff',
      '.aiff' => 'audio/aiff',
      '.flac' => 'audio/flac',
      '.mid' => 'audio/midi',
      '.midi' => 'audio/midi',
      '.asd' => 'application/x-ableton-analysis'
    }[extension] || 'application/octet-stream'
  end
end
