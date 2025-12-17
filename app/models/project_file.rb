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


end
