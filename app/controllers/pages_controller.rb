class PagesController < ApplicationController
  skip_before_action :authenticate_user!

  def landing
    redirect_to library_index_path if user_signed_in?
  end
end
