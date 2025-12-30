class CollaboratorsController < ApplicationController
  before_action :authenticate_user!

  def index
    @collaborators = current_user.collaborators.order(:username)
  end
end
