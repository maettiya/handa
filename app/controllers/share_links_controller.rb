class ShareLinksController < ApplicationController
  before_action :authenticate_user!, only: [:create, :destroy]
  before_action :set_share_link, only: [:show, :download, :verify_password]
  before_action :set_project, only: [:create]

  # POST /projects/:project_id/share_links
  # Creates a new share link for a project (requires login)
  def create
    @share_link = @project.share_links.new(share_link_params)

    if @share_link.save
      render json: {
        success: true,
        url: share_link_url(@share_link.token),
        token: @share_link.token
      }
    else
      render json: { success: false, errors: @share_link.errors.full_messages }, status: unprocessable_entity
    end
  end

end
