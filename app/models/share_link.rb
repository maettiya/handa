class ShareLink < ApplicationRecord
  belongs_to :project

  has_secure_password validations: false

  # Generate unique token before creation
  before_create :generate_token

  # Validations
  validates :token, uniqueness: true, allow_nil: true
  validates :project, presence: true

  # Scopes
  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }


  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(16)
  end
end
