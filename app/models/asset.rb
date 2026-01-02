# Asset represents any file or folder in the system.
# Uses self-referential parent_id for tree structure.
# parent_id: nil = library root level (what were "projects")
# is_directory: true = folder, false = file
class Asset < ApplicationRecord
  # Ownership
  belongs_to :user
  belongs_to :shared_from_user, class_name: 'User', optional: true

  # Tree structure (self-referential)
  belongs_to :parent, class_name: "Asset", optional: true
  has_many :children, class_name: "Asset", foreign_key: "parent_id", dependent: :destroy

  # Sharing
  has_many :share_links, dependent: :destroy

  # File attachment
  has_one_attached :file

  # Scopes
  scope :root_level, -> { where(parent_id: nil) }
  scope :library, -> { root_level.where(ephemeral: false) }
  scope :ephemeral_shares, -> { root_level.where(ephemeral: true) }
  scope :visible, -> { where(hidden: false) }
  scope :directories, -> { where(is_directory: true) }
  scope :files, -> { where(is_directory: false) }

  # Validations
  validates :title, presence: true
  validates :file, presence: true, unless: -> { is_directory? || parent_id.present? }

  # Hidden file detection constants
  HIDDEN_EXTENSIONS = %w[asd ds_store].freeze
  HIDDEN_FOLDERS = ["Ableton Project Info", "__MACOSX"].freeze

  # Auto-detect asset type for root-level uploads
  before_save :detect_asset_type, if: -> { file.attached? && asset_type.blank? && parent_id.nil? }

  # Class method to check if file should be hidden
  def self.should_hide?(filename, is_directory: false)
    return true if HIDDEN_FOLDERS.include?(filename) && is_directory
    return true if filename.start_with?(".")
    return true if filename.start_with?("Icon")

    extension = File.extname(filename).delete(".").downcase
    HIDDEN_EXTENSIONS.include?(extension)
  end

  # Is this a folder?
  def folder?
    is_directory?
  end

  # Extract the extension from the filename -- "File Name.als" -> "als"
  def extension
    filename = original_filename.presence || file&.filename&.to_s
    return "" unless filename
    File.extname(filename).delete(".").downcase
  end

  # Return string to select the correct icon to display in view
  def icon_type
    return "folder" if is_directory?

    case extension
    when "als" then "ableton"
    when "logicx" then "logic"
    when "wav", "mp3", "aif", "aiff", "flac" then "audio"
    when "mid", "midi" then "midi"
    else "file"
    end
  end

  # Display name (title for root-level, original_filename for children)
  def display_name
    title.presence || original_filename
  end

  # Download filename - uses the renamed name
  # For root-level assets: title + extension
  # For child assets: original_filename (which gets updated on rename)
  def download_filename
    if parent_id.nil?
      # Root-level asset - use title with the file's extension
      ext = file&.filename&.extension_with_delimiter || ""
      title_without_ext = title.sub(/#{Regexp.escape(ext)}$/i, "")
      "#{title_without_ext}#{ext}"
    else
      # Child asset - use original_filename (updated on rename)
      original_filename.presence || file&.filename&.to_s
    end
  end

  # Find the root-level asset (walks up the tree)
  def root_asset
    asset = self
    asset = asset.parent while asset.parent_id.present?
    asset
  end

  private

  def detect_asset_type
    return unless file.attached?

    ext = File.extname(file.filename.to_s).delete('.').downcase

    self.asset_type = case ext
    when 'als'
      'ableton'
    when 'logicx'
      'logic'
    when 'flp'
      'fl_studio'
    when 'ptx'
      'pro_tools'
    when 'wav', 'aif', 'aiff', 'flac'
      'lossless_audio'
    when 'mp3', 'm4a', 'aac', 'ogg'
      'compressed_audio'
    when 'zip'
      nil  # Let extraction service handle ZIPs
    else
      'other'
    end
  end
end
