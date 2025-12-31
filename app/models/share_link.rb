class ShareLink < ApplicationRecord
  belongs_to :project

  has_secure_password validations: false

  # Generate unique token before creation
  before_create :generate_token
end
