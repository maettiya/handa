class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  layout 'landing'

  def landing
    redirect_to library_index_path if user_signed_in?
  end
end
