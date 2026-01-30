class Notification < ApplicationRecord
  belongs_to :user      # The recipient
  belongs_to :actor, class_name: 'User', optional: true     # The person who triggered the notification (nil for anonymous)
  belongs_to :notifiable, polymorphic: true, optional: true     #Able to link to the associated record

  # Notification types:
  # - collaborator_added: Someone added you as a collaborator
  # - share_link_viewed: Someone opened/viewed your share link
  # - share_link_listened: Someone played your shared audio file
  # - share_link_download: Someone downloaded your shared file
  # - share_link_save: Someone saved your shared file to their library
  # - direct_share: Someone shared a file directly with you
  TYPES = %w[collaborator_added share_link_viewed share_link_listened share_link_download share_link_save direct_share].freeze

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  validates :notification_type, presence: true, inclusion: { in: TYPES }

  # Helper to get the actor display name (or "Someone" for anonymous)
  def actor_display_name
    actor&.username || "Someone"
  end
end
