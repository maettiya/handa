class Collaboration < ApplicationRecord
  belongs_to :user
  belongs_to :collaborator, class_name: 'User'

  validate :not_self_collaboration
  validate :mutual_uniqueness
end
