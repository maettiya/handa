class Project < ApplicationRecord
  belongs_to :user
  has_many :project_files, dependent: :destroy
  has_one_attached :file

  validates :title, presence: true
  validates :file, presence: true, unless: :folder?

  def folder?
    project_type == "folder"
  end
end
