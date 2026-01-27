class ShareLinksController < ApplicationController
  before_action :authenticate_user!, only: [:create, :destroy, :save_to_library]
  before_action :set_share_link, only: [:show, :download, :verify_password]
  before_action :set_asset, only: [:create]

  # POST /assets/:asset_id/share_links
  # Creates a new share link for an asset (requires login)
  def create
    @share_link = @asset.share_links.new(share_link_params)

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
  # Public page for viewing/downloading shared asset
  def show
    if @share_link.expired?
      render :expired and return
    end

    @asset = @share_link.asset
    @require_password = @share_link.password_required? && !session_authenticated?

    # Load children for preview (if not password protected or already authenticated)
    unless @require_password
      # Check if we should auto-skip a single root folder
      # (e.g., "SERENADE Project.zip" containing only "SERENADE Project/" folder)
      root_files = @asset.children.visible.order(is_directory: :desc, title: :asc)
      if root_files.count == 1 && root_files.first.is_directory?
        @skipped_root_folder = root_files.first
      else
        @skipped_root_folder = nil
      end

      if params[:folder_id].present?
        # Navigate into a subfolder
        @current_folder = find_child_folder(params[:folder_id])
        @files = @current_folder&.children&.visible&.order(is_directory: :desc, title: :asc) || []
      elsif @asset.is_directory? || @asset.children.any?
        # Root of shared folder/project
        if @skipped_root_folder
          # Skip into the single root folder automatically
          @current_folder = nil
          @files = @skipped_root_folder.children.visible.order(is_directory: :desc, title: :asc)
        else
          @current_folder = nil
          @files = root_files
        end
      else
        # Single file share
        @files = []
      end
    end
  end

  # POST /s/:token/verify_password
  # Verify password for protected links
  def verify_password
    if @share_link.authenticate(params[:password])
      session["share_link_#{@share_link.token}"] = true
      redirect_to share_link_path(@share_link.token)
    else
      @asset = @share_link.asset
      @requires_password = true
      @password_error = "Incorrect password"
      render :show
    end
  end

  # POST /s/:token/save - Save shared asset to current user's library
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

    original_asset = @share_link.asset

    # Create placeholder asset immediately so UI shows processing state
    # Use new + save(validate: false) to skip file validation - the job will copy the file
    placeholder = current_user.assets.new(
      title: original_asset.title,
      original_filename: original_asset.original_filename,
      processing_status: 'importing',
      processing_progress: 0,
      processing_total: 0
    )
    placeholder.save(validate: false)

    # Kick off background job for deep cloning with placeholder
    SaveToLibraryJob.perform_later(original_asset.id, current_user.id, original_asset.user.id, placeholder.id)

    redirect_to library_index_path, notice: "Saving to your library..."
  end

  # GET /s/:token/download
  # Download the shared asset
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
    @asset = @share_link.asset

    if @asset.is_directory? || @asset.children.any?
      # Folder with children - use background download
      download = Download.create!(
        user: current_user,
        asset: @asset,
        share_link: @share_link,
        status: 'pending',
        file_count: 0
      )
      CreateZipJob.perform_later(download.id)
      render json: { download_id: download.id }
    elsif @asset.file.attached?
      # Single file - direct download
      notify_download(@share_link, current_user)
      redirect_to rails_blob_path(@asset.file, disposition: "attachment")
    else
      redirect_to share_link_path(@share_link.token), alert: "File not available"
    end
  end

  # GET /s/:token/download/:file_id
  # Download an individual file or folder from within the shared asset
  def download_file
    @share_link = ShareLink.find_by!(token: params[:token])

    if @share_link.expired?
      redirect_to share_link_path(@share_link.token), alert: "This link has expired"
      return
    end

    if @share_link.password_required? && !session_authenticated?
      redirect_to share_link_path(@share_link.token)
      return
    end

    @asset = @share_link.asset
    @file = find_child_folder(params[:file_id])

    unless @file
      redirect_to share_link_path(@share_link.token), alert: "File not found"
      return
    end

    if @file.is_directory? || @file.children.any?
      # Folder - use background download
      download = Download.create!(
        user: current_user,
        asset: @file,
        share_link: @share_link,
        status: 'pending',
        file_count: 0
      )
      CreateZipJob.perform_later(download.id)
      render json: { download_id: download.id }
    elsif @file.file.attached?
      # Single file - direct download
      redirect_to rails_blob_path(@file.file, disposition: "attachment")
    else
      redirect_to share_link_path(@share_link.token), alert: "File not available"
    end
  end

  # DELETE /share_links/:id
  # Delete a share link (owner only)
  def destroy
    @share_link = current_user.assets.find(params[:asset_id]).share_links.find(params[:id])
    @share_link.destroy
    render json: { success: true }
  end

  private

  def set_share_link
    @share_link = ShareLink.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render :not_found
  end

  def set_asset
    @asset = current_user.assets.find(params[:asset_id])
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

  # Find a folder within the shared asset's tree (security: only allows access to descendants)
  def find_child_folder(folder_id)
    # Find the folder and verify it's a descendant of the shared asset
    folder = Asset.find_by(id: folder_id)
    return nil unless folder

    # Walk up the tree to verify this folder belongs to the shared asset
    current = folder
    while current
      return folder if current.id == @asset.id
      current = current.parent
    end

    nil # Folder is not within the shared asset
  end

  # Notify asset owner of a download (for single file direct downloads)
  def notify_download(share_link, downloader)
    owner = share_link.asset.user

    # Don't notify if owner is downloading their own file
    return if downloader == owner

    # Prevent duplicate notifications - check if we already notified in this session
    session_key = "notified_download_#{share_link.id}"
    return if session[session_key]
    session[session_key] = true

    Notification.create!(
      user: owner,
      actor: downloader, # nil for anonymous downloads
      notification_type: 'share_link_download',
      notifiable: share_link.asset
    )
  end

  # Creates ZIP using temp file (low memory usage for Heroku)
  def create_zip_tempfile(asset)
    require 'zip'
    require 'tempfile'

    tempfile = Tempfile.new(['download', '.zip'])
    tempfile.binmode

    Zip::OutputStream.open(tempfile.path) do |zio|
      asset.children.visible.each do |child|
        if child.is_directory?
          add_children_to_zip(zio, child, child.original_filename)
        elsif child.file.attached?
          zio.put_next_entry(child.original_filename)
          child.file.open { |file| zio.write(file.read) }
        end
      end
    end

    tempfile
  end

  # Recursively adds folder contents to ZIP
  def add_children_to_zip(zio, folder, path_prefix)
    folder.children.visible.each do |child|
      child_path = "#{path_prefix}/#{child.original_filename}"

      if child.is_directory?
        add_children_to_zip(zio, child, child_path)
      elsif child.file.attached?
        zio.put_next_entry(child_path)
        child.file.open { |file| zio.write(file.read) }
      end
    end
  end
end
