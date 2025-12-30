class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def mark_read
    current_user.notifications.unread.update_all(read: true)
    head :ok
  end
end
