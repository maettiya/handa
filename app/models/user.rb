class User < ApplicationRecord
  has_one_attached :avatar

  has_many :projects, dependent: :destroy
  has_many :collaborations, dependent: :destroy
  has_many :inverse_collaborations, class_name: 'Collaboration', foreign_key: 'collaborator_id', dependent: :destroy
  has_many :notifications

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :username, presence: true, uniqueness: true

  # Library projects (non-ephemeral)
  def library_projects
    projects.library.order(created_at: :desc)
  end

  # Quick shares (ephemeral)
  def quick_shares
    projects.ephemeral_shares.order(created_at: :desc)
  end

  # Get all collaborators (mutual - both directions)
  def collaborators
    User.where(id: collaborations.select(:collaborator_id))
      .or(User.where(id: inverse_collaborations.select(:user_id)))
  end

  def collaborators_count
    collaborators.count
  end

  # Count all DAW project files (.als, .logicx, .flp, .ptx)
  # Excludes files inside "Backup" folders (Ableton auto-saves)
  def daw_projects_count
    # Get IDs of all "Backup" folders
    backup_folder_ids = project_files.directories
      .where("LOWER(original_filename) = 'backup'")
      .pluck(:id)

    # Count DAW files, excluding those inside Backup folders
    query = project_files.files.where(
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

  # Calculate storage breakdown by project type
  def storage_breakdown
    total = total_storage_used
    return {} if total.zero?

    breakdown = {
      daw: 0,
      lossless: 0,
      compressed: 0,
      other: 0
    }

    projects.includes(:project_files, file_attachment: :blob).find_each do |project|
      # Calculate total size of all extracted files in this project
      project_size = project.project_files.files.sum(:file_size) || 0

      # If no extracted files, use the original file size
      if project_size.zero? && project.file.attached?
        project_size = project.file.byte_size || 0
      end

      case project.project_type
      when 'ableton', 'logic', 'fl_studio', 'pro_tools'
        breakdown[:daw] += project_size
      when 'lossless_audio'
        breakdown[:lossless] += project_size
      when 'compressed_audio'
        breakdown[:compressed] += project_size
      when 'folder'
        # For folders, categorize by what's inside
        categorize_folder_contents(project, breakdown)
      when nil
        # Standalone file uploads (legacy) - categorize by file extension
        categorize_standalone_file(project, project_size, breakdown)
      else
        breakdown[:other] += project_size
      end
      end

    # Convert to percentages
    breakdown.transform_values { |v| (v.to_f / total * 100).round(1) }
  end

  # Calculate total storage used (in bytes)
  def total_storage_used
    # Sum extracted files
    extracted = project_files.sum(:file_size) || 0

    # Sum original attached files for projects with no extracted files
    original = 0
    projects.includes(:project_files, file_attachment: :blob).find_each do |project|
      if project.project_files.empty? && project.file.attached?
        original += project.file.byte_size || 0
      end
    end

    extracted + original
  end

  # Get all project files for this user
  def project_files
    ProjectFile.joins(:project).where(projects: { user_id: id })
  end

  private

  # For standalone folders, categorize by file type
  def categorize_folder_contents(project, breakdown)
    project.project_files.files.visible.find_each do |pf|
      ext = pf.extension
      size = pf.file_size || 0

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
  def categorize_standalone_file(project, size, breakdown)
    return if size.zero? || !project.file.attached?

    ext = File.extname(project.file.filename.to_s).delete('.').downcase

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
