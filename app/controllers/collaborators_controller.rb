class CollaboratorsController < ApplicationController
  before_action :authenticate_user!

  def index
    @collaborators = current_user.collaborators.order(:username)
  end

  def create
    username = params[:username]&.strip&.downcase

    if username.blank?
      flash[:alert] = "Please enter a username"
      redirect_to collaborators_path and return
    end
  end
end
