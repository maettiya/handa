class User < ApplicationRecord
  has_one_attached :avatar

  has_many :assets, dependent: :destroy
  has_many :collaborations, dependent: :destroy
  has_many :inverse_collaborations, class_name: 'Collaboration', foreign_key: 'collaborator_id', dependent: :destroy
  has_many :notifications

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :username, presence: true, uniqueness: true

  # Library assets (non-ephemeral, root-level)
  def library_assets
    assets.library.order(created_at: :desc)
  end

  # Quick shares (ephemeral, root-level)
  def quick_shares
    assets.ephemeral_shares.order(created_at: :desc)
  end

  # Get all collaborators (mutual - both directions)
  def collaborators
    User.where(id: collaborations.select(:collaborator_id))
      .or(User.where(id: inverse_collaborations.select(:user_id)))
  end

  def collaborators_count
    collaborators.count
  end

  # Get all files (non-directory assets) for this user
  def all_files
    assets.files
  end

  # Count all DAW project files (.als, .logicx, .flp, .ptx)
  # Excludes files inside "Backup" folders (Ableton auto-saves)
  def daw_projects_count
    # Get IDs of all "Backup" folders
    backup_folder_ids = assets.directories
      .where("LOWER(original_filename) = 'backup'")
      .pluck(:id)

    # Count DAW files, excluding those inside Backup folders
    query = all_files.where(
      "LOWER(original_filename) LIKE '%.als' OR " \
      "LOWER(original_filename) LIKE '%.logicx' OR " \
      "LOWER(original_filename) LIKE '%.flp' OR " \
      "LOWER(original_filename) LIKE '%.ptx'"
    )

    # Exclude files whose parent is a Backup folder
    if backup_folder_ids.any?
      query = query.where.not(parent_id: backup_folder_ids)
    end

    query.count
  end

  # Calculate storage breakdown by asset type
  def storage_breakdown
    total = total_storage_used
    return {} if total.zero?

    breakdown = {
      daw: 0,
      lossless: 0,
      compressed: 0,
      other: 0
    }

    # Process root-level assets
    assets.root_level.includes(file_attachment: :blob).find_each do |asset|
      # Calculate total size of all children
      children_size = asset.children.files.sum(:file_size) || 0

      # If no children, use the original file size
      if children_size.zero? && asset.file.attached?
        asset_size = asset.file.byte_size || 0
      else
        asset_size = children_size
      end

      case asset.asset_type
      when 'ableton', 'logic', 'fl_studio', 'pro_tools'
        breakdown[:daw] += asset_size
      when 'lossless_audio'
        breakdown[:lossless] += asset_size
      when 'compressed_audio'
        breakdown[:compressed] += asset_size
      when 'folder'
        # For folders, categorize by what's inside
        categorize_folder_contents(asset, breakdown)
      when nil
        # Standalone file uploads - categorize by file extension
        categorize_standalone_file(asset, asset_size, breakdown)
      else
        breakdown[:other] += asset_size
      end
    end

    # Convert to percentages
    breakdown.transform_values { |v| (v.to_f / total * 100).round(1) }
  end

  # Calculate total storage used (in bytes)
  def total_storage_used
    # Sum all file sizes from child assets
    children_total = assets.files.where.not(parent_id: nil).sum(:file_size) || 0

    # Sum original attached files for root-level assets with no children
    root_files_total = 0
    assets.root_level.includes(:children, file_attachment: :blob).find_each do |asset|
      if asset.children.empty? && asset.file.attached?
        root_files_total += asset.file.byte_size || 0
      end
    end

    children_total + root_files_total
  end

  private

  # For standalone folders, categorize by file type
  def categorize_folder_contents(asset, breakdown)
    asset.children.files.visible.find_each do |child|
      ext = child.extension
      size = child.file_size || 0

      case ext
      when 'als', 'logicx', 'flp', 'ptx'
        breakdown[:daw] += size
      when 'wav', 'aif', 'aiff', 'flac'
        breakdown[:lossless] += size
      when 'mp3', 'm4a', 'aac', 'ogg'
        breakdown[:compressed] += size
      else
        breakdown[:other] += size
      end
    end
  end

  # For standalone file uploads, categorize by file extension
  def categorize_standalone_file(asset, size, breakdown)
    return if size.zero? || !asset.file.attached?

    ext = File.extname(asset.file.filename.to_s).delete('.').downcase

    case ext
    when 'als', 'logicx', 'flp', 'ptx'
      breakdown[:daw] += size
    when 'wav', 'aif', 'aiff', 'flac'
      breakdown[:lossless] += size
    when 'mp3', 'm4a', 'aac', 'ogg'
      breakdown[:compressed] += size
    else
      breakdown[:other] += size
    end
  end
end
