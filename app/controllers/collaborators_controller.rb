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

    collaborator = User.find_by("LOWER(username) = ?", username)

    if collaborator.nil?
      flash[:alert] = "User '#{params[:username]}' not found"
    elsif collaborator == current_user
      flash[:alert] = "You can't add yourself as a collaborator"
    elsif current_user.collaborators.include?(collaborator)
      flash[:alert] = "#{collaborator.username} is already a collaborator"
    else
      Collaboration.create!(user: current_user, collaborator: collaborator)
      flash[:notice] = "#{collaborator.username} added as a collaborator"
    end

    redirect_to collaborators_path
  end
end
