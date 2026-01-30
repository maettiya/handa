class User < ApplicationRecord
  has_one_attached :avatar

  has_many :assets, dependent: :destroy
  has_many :collaborations, dependent: :destroy
  has_many :inverse_collaborations, class_name: 'Collaboration', foreign_key: 'collaborator_id', dependent: :destroy
  has_many :notifications
  has_many :downloads, dependent: :destroy

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :username, presence: true, uniqueness: true

  # Notify admin of new signups
  after_create :notify_admin_of_signup

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

    # Process all non-root files (extracted content) using file_size column
    assets.files.where.not(parent_id: nil).find_each do |file|
      size = file.file_size || 0
      categorize_by_extension(file.original_filename, size, breakdown)
    end

    # Process root-level files (standalone uploads) using attached file size
    assets.root_level.includes(:children, file_attachment: :blob).find_each do |asset|
      if asset.children.empty? && asset.file.attached?
        size = asset.file.byte_size || 0
        categorize_by_extension(asset.file.filename.to_s, size, breakdown)
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

  # Send email to admin when a new user signs up
  def notify_admin_of_signup
    AdminMailer.new_signup(self).deliver_later
  end

  # Categorize a single file by its extension
  def categorize_by_extension(filename, size, breakdown)
    return if size.zero?

    ext = File.extname(filename.to_s).delete('.').downcase

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
