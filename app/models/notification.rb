class Notification < ApplicationRecord
  belongs_to :user      # The recipient
  belongs_to :actor, class_name: 'User'     # The person who triggered the notification
  belongs_to :notifiable, polymorphic: true, optional: true     #Able to link to the associated record

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  validates :notification_type, presence: true
end
