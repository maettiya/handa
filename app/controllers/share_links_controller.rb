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

  # GET /s/:token
  # Public page for viewing/downloading shared project
  def show
    if @share_link.expired?
      render :expired and return
    end

    @project = @share_link.project
    @require_password = @share_link.password_required? && !session_authenticated?
  end

  # POST /s/:token/verify_password
  # Verify password for protected links
  def verify_password
    if @share_link.authenticate(params[:password])
      session["share_link_#{@share_link.token}"] = true
      redirect_to share_link_path(@share_link.token)
    else
      @project = @share_link.project
      @requires_password = true
      @password_error = "Incorrect password"
      render :show
    end
  end

  # GET /s/:token/download
  # Download the shared project
  def download
    if @share_link.expired?
      redirect_to share_link_path(@share_link.token), alert: "This link has expired"
      return
    end

    if @share_link.password_required? && !session_authenticated?
      redirect_to share_link_path(@share_link.token)
      return
    end

    @share_link.record_download!
    @project = @share_link.project

    if @project.file.attached?
      redirect_to rails_blob_path(@project.file, disposition: "attachment")
    else
      redirect_to share_link_path(@share_link.token), alert: "File not available"
    end
  end


end
