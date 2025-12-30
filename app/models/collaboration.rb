class Collaboration < ApplicationRecord
  belongs_to :user
  belongs_to :collaborator, class_name: 'User'

  validate :not_self_collaboration
  validate :mutual_uniqueness

  private

  def not_self_collaboration
    errors.add(:collaborator, "can't be yourself") if user_id == collaborator_id
  end


end
