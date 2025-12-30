class Collaboration < ApplicationRecord
  belongs_to :user
  belongs_to :collaborator, class_name: 'User'

  validate :not_self_collaboration
  validate :mutual_uniqueness

  private

  def not_self_collaboration
    errors.add(:collaborator, "Can't be yourself") if user_id == collaborator_id
  end

  def mutual_uniqueness
    # Check if reverse relationship already exists
    if Collaboration.exists?(user_id: collaborator_id, collaborator_id: user_id)
      errors.add(:base, "Collaboration already exists")
    end
  end
end
