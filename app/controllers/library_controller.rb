class LibraryController < ApplicationController
  def index
    # Order by most recently created first (newest uploads/folders appear first)
    @projects = current_user.library_projects
  end
end
