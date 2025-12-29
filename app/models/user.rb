class User < ApplicationRecord
  has_one_attached :avatar

  has_many :projects, dependent: :destroy
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :username, presence: true, uniqueness: true

    # Calculate total storage used (in bytes)
  def total_storage_used
    project_files.sum(:file_size) || 0
  end

  # Get all project files for this user
  def project_files
    ProjectFile.joins(:project).where(projects: { user_id: id })
  end

  # Calculate storage breakdown by file category
  def storage_breakdown
    total = total_storage_used
    return {} if total.zero?

    breakdown = {
      daw: 0,
      lossless: 0,
      compressed: 0,
      other: 0
    }

    project_files.files.find_each do |pf|
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

    # Convert to percentages
    breakdown.transform_values { |v| (v.to_f / total * 100).round(1) }
  end
end
