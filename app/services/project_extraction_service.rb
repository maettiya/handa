# Handles extraction of uploaded ZIP files and creates ProjectFile records
# for each file/folder in the archive. Detects project type (Ableton, Logic, etc.)
# and auto-hides junk files (.asd, system folders, etc.)

require 'zip'

class ProjectExtractionService
  def initialize(project)
    @project = project
  end

  def extract!
    return unless zip_file?

    # Track folders we create so we can set parent relationships
    folder_map = {}

    # Download the ZIP to a temp file (required for cloud storage like S3/R2)
    download_and_extract(folder_map)

    detect_project_type!
    @project.update!(extracted: true)
  end

  private

  def zip_file?
    @project.file.attached? &&
      @project.file.content_type == 'application/zip'
  end

  def download_and_extract(folder_map)
    # Download blob to a temp file, then extract
    @project.file.open do |tempfile|
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

    # Create the file record
    is_directory = entry.directory?

    project_file = @project.project_files.create!(
      original_filename: filename,
      path: entry.name,
      file_type: is_directory ? 'directory' : File.extname(filename).delete('.').downcase,
      file_size: entry.size,
      is_directory: is_directory,
      hidden: ProjectFile.should_hide?(filename, is_directory: is_directory),
      parent: parent
    )

    # Attach the actual file content (skip for directories)
    unless is_directory
      project_file.file.attach(
        io: zip.get_input_stream(entry),
        filename: filename,
        content_type: detect_content_type(filename)
      )
    end

    # Track folders for parent relationships
    folder_map[entry.name] = project_file if is_directory
  end

  def ensure_folders_exist(folder_parts, folder_map)
    return nil if folder_parts.empty?

    parent = nil
    current_path = ""

    folder_parts.each do |folder_name|
      current_path = current_path.empty? ? folder_name : "#{current_path}/#{folder_name}"
      folder_key = "#{current_path}/"

      unless folder_map[folder_key]
        folder_map[folder_key] = @project.project_files.create!(
          original_filename: folder_name,
          path: folder_key,
          file_type: 'directory',
          is_directory: true,
          hidden: ProjectFile.should_hide?(folder_name, is_directory: true),
          parent: parent
        )
      end

      parent = folder_map[folder_key]
    end

    parent
  end

  def detect_project_type!
    # Check for known project file types
    als_file = @project.project_files.find_by("original_filename LIKE ?", "%.als")
    logic_file = @project.project_files.find_by("original_filename LIKE ?", "%.logicx")

    project_type = if als_file
                     'ableton'
                   elsif logic_file
                     'logic'
                   else
                     'folder'
                   end

    @project.update!(project_type: project_type)
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
