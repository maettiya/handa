class CollaboratorsController < ApplicationController
  before_action :authenticate_user!

  def index
    @collaborators = current_user.collaborators.order(:username)
  end

  def search
    query = params[:q]&.strip&.downcase

    if query.blank? || query.length < 2
      render json: []
      return
    end

    # Find users matching the query, exclude current user and existing collaborators
    existing_ids = current_user.collaborators.pluck(:id) + [current_user.id]

    users = User.where("LOWER(username) LIKE ?", "#{query}%")
                .where.not(id: existing_ids)
                .limit(5)
                .select(:id, :username)

    render json: users.map { |u| { id: u.id, username: u.username } }
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

  def destroy
    collaborator = User.find(params[:id])

    # Remove collaboration in either direction
    Collaboration.where(user: current_user, collaborator: collaborator)
      .or(Collaboration.where(user: collaborator, collaborator: current_user))
      .destroy_all

    flash[:notice] = "#{collaborator.username} removed from collaborators"
    redirect_to collaborators_path
  end
end
