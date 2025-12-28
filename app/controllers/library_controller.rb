class LibraryController < ApplicationController
  def index
    # Order by most recently created first (newest uploads/folders appear first)
    @projects = current_user.projects.order(created_at: :desc)
  end
end
