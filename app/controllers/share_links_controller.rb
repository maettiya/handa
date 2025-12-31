class ShareLinksController < ApplicationController
  before_action :authenticate_user!, only: [:create, :destroy, :save_to_library]
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
      render json: { success: false, errors: @share_link.errors.full_messages }, status: :unprocessable_entity
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

  # POST /s/:token/save - Save shared project to current user's library
  def save_to_library
    @share_link = ShareLink.find_by(token: params[:token])

    # Handle missing/expired links
    unless @share_link
      redirect_to root_path, alert: "Share link not found"
      return
    end

    if @share_link.expired?
      redirect_to root_path, alert: "Share link has expired"
      return
    end

    # Check password if required
    if @share_link.password_required? && !session["share_link_#{@share_link.token}"]
      redirect_to share_link_path(@share_link.token), alert: "Please verify password first"
      return
    end

    original_project = @share_link.project

    # Clone the project to current user's library
    new_project = current_user.projects.build(
      title: original_project.title,
      project_type: original_project.project_type,
      ephemeral: false,  # Save to permanent library
      shared_from_user: original_project.user  # Attribution
    )

    # Copy the attached file
    if original_project.file.attached?
      new_project.file.attach(
        io: StringIO.new(original_project.file.download),
        filename: original_project.file.filename.to_s,
        content_type: original_project.file.content_type
      )
    end

    if new_project.save
      # If original had extracted files, trigger extraction for the copy
      if original_project.project_files.any?
        ProjectExtractionJob.perform_later(new_project.id)
      end

      redirect_to root_path, notice: "Saved to your library!"
    else
      redirect_to share_link_path(@share_link.token), alert: "Could not save to library"
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

  # DELETE /share_links/:id
  # Delete a share link (owner only)
  def destroy
    @share_link = current_user.projects.find(params[:project_id]).share_links.find(params[:id])
    @share_link.destroy
    render json: { success: true }
  end

  private

  def set_share_link
    @share_link = ShareLink.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render :not_found
  end

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def share_link_params
    permitted = params.permit(:password, :expires_at)

    # Convert expiry option to actual timestamp
    if permitted[:expires_at].present?
      permitted[:expires_at] = case permitted[:expires_at]
      when '1_hour' then 1.hour.from_now
      when '24_hours' then 24.hours.from_now
      when '7_days' then 7.days.from_now
      when '30_days' then 30.days.from_now
      else nil
      end
    end

    permitted
  end

  def session_authenticated?
    session["share_link_#{@share_link.token}"] == true
  end

end
