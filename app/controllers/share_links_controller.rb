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

    # Deep clone the asset (and all children) to current user's library
    new_asset = original_asset.deep_clone_to_user(current_user, shared_from: original_asset.user)

    if new_asset.persisted?
      redirect_to root_path, notice: "Saved to your library!"
    else
      redirect_to share_link_path(@share_link.token), alert: "Could not save to library"
    end
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

    if @asset.is_directory? && @asset.children.any?
      # Folder with children - create ZIP on the fly
      zip_data = create_asset_zip(@asset)
      send_data zip_data,
                filename: "#{@asset.title}.zip",
                type: "application/zip",
                disposition: "attachment"
    elsif @asset.file.attached?
      # Single file - direct download
      redirect_to rails_blob_path(@asset.file, disposition: "attachment")
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

  # Creates a ZIP of all asset children
  def create_asset_zip(asset)
    require 'zip'

    stringio = Zip::OutputStream.write_buffer do |zio|
      asset.children.visible.each do |child|
        if child.is_directory?
          add_folder_to_zip(zio, child, child.original_filename)
        elsif child.file.attached?
          zio.put_next_entry(child.original_filename)
          zio.write(child.file.download)
        end
      end
    end

    stringio.rewind
    stringio.read
  end

  # Recursively adds folder contents to ZIP
  def add_folder_to_zip(zio, folder, path_prefix)
    folder.children.visible.each do |child|
      child_path = "#{path_prefix}/#{child.original_filename}"

      if child.is_directory?
        add_folder_to_zip(zio, child, child_path)
      elsif child.file.attached?
        zio.put_next_entry(child_path)
        zio.write(child.file.download)
      end
    end
  end
end
