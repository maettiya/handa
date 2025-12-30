class Notification < ApplicationRecord
  belongs_to :user      # The recipient
  belongs_to :actor, class_name: 'User'     # The person who triggered the notification

  scope :unread, -> { where(read: false) }
  scope :recent
end
