class ProjectFile < ApplicationRecord
  belongs_to :project
  belongs_to :parent, class_name: "ProjectFile", optional: true
  has_many :children, class_name: "ProjectFile", foreign_key: "parent_id", dependent: :destroy

  has_one_attached :file

  # Scopes for filtering files (database queries)
  # Only show files where hidden: false. Filter out .asd files and junk
  scope :visible, -> { where(hidden: false) }
  # Only show folders
  scope :directories, -> { where(is_directory: true) }
  # Only show actual files (not folders)
  scope :files, -> { where(is_directory: false) }
  # Only show items at the top level (with no parent folder)
  scope :root_level, -> { where(parent_id: nil) }

  # Constants - list of files we know are junk / can be hidden
  # Freezing to make them immutable
  HIDDEN_EXTENSIONS = %w[asd ds_store].freeze
  HIDDEN_FOLDERS = ["Ableton Project Info", "__MACOSX"].freeze

  # Class method to check if file should be hidden
  def self.should_hide?(filename, is_directory: false)
    return true if HIDDEN_FOLDERS.include?(filename) && is_directory
    return true if filename.start_with?(".")

    extension = File.extname(filename).delete(".").downcase
    HIDDEN_EXTENSIONS.include?(extension)
  end

  # Extract the extension from the filename -- "File Name.als" -> "als"
  def extension
    File.extname(original_filename).delete(".").downcase
  end

  # Return string to select the correct icon to display in view
  def icon_type
    return "folder" if is_directory

    case extension
    when "als" then "ableton"
    when "logicx" then "logic"
    when "wav", "mp3", "aif", "aiff", "flac" then "audio"
    when "mid", "midi" then "midi"
    else "file"
    end
  end
end
