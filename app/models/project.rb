class Project < ApplicationRecord
  belongs_to :user
  has_many :project_files, dependent: :destroy
  has_many :share_links, dependent: :destroy
  has_one_attached :file

  # Quick share support
  belongs_to :shared_from_user, class_name: 'User', optional: true

  # Scopes for filtering library vs ephemeral
  scope :library, -> { where(ephemeral: false) }
  scope :ephemeral_shares, -> { where(ephemeral: true) }

  validates :title, presence: true
  validates :file, presence: true, unless: :folder?

  before_save :detect_project_type, if: -> { file.attached? && project_type.blank? }

  def folder?
    project_type == "folder"
  end

  private

  def detect_project_type
    return unless file.attached?

    ext = File.extname(file.filename.to_s).delete('.').downcase

    self.project_type = case ext
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
