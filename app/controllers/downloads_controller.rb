class DownloadsController < ApplicationController
  include Zipline

  # Skip auth for share link downloads - use session to track anonymous downloads
  skip_before_action :authenticate_user!, only: [:create, :status, :file, :destroy, :active, :stream]
  before_action :require_auth_or_share_link, only: [:create, :stream]

  # POST /downloads
  # Creates a new background download job
  def create
    # Find asset - either from user's library or from a share link
    if params[:share_link_token].present?
      share_link = ShareLink.find_by!(token: params[:share_link_token])

      if share_link.expired?
        return render json: { error: 'Share link has expired' }, status: :unprocessable_entity
      end

      # If file_id is provided, download that specific file/folder
      if params[:file_id].present?
        asset = find_child_within_share(share_link.asset, params[:file_id])
        return render json: { error: 'File not found' }, status: :not_found unless asset
      else
        asset = share_link.asset
      end

      share_link.record_download!

      # Create download record (anonymous or authenticated)
      download = Download.create!(
        user: current_user, # nil for anonymous
        asset: asset,
        share_link: share_link,
        filename: asset.original_filename || asset.title,
        status: 'pending'
      )

      # Store in session for anonymous users to track
      session[:download_id] = download.id unless current_user
    else
      # Library download - requires authentication
      asset = current_user.assets.find(params[:asset_id])

      download = current_user.downloads.create!(
        asset: asset,
        filename: asset.title,
        status: 'pending'
      )
    end

    # Kick off background job
    CreateZipJob.perform_later(download.id)

    render json: {
      id: download.id,
      status: download.status,
      filename: download.filename
    }
  end

  # GET /downloads/:id/status
  # Polled by frontend to check progress
  def status
    download = find_download(params[:id])
    return head :not_found unless download

    render json: {
      id: download.id,
      status: download.status,
      progress: download.progress,
      total: download.total,
      progress_text: download.progress_text,
      filename: download.filename,
      error_message: download.error_message
    }
  end

  # GET /downloads/:id/file
  # Serves the completed ZIP file
  def file
    download = find_download(params[:id])
    return head :not_found unless download

    unless download.ready? && download.zip_file.attached?
      return head :not_found
    end

    # Mark as downloaded
    download.update!(status: 'downloaded')

    # Clear session for anonymous users
    session.delete(:download_id) if session[:download_id] == download.id

    # Redirect to the file (or stream it)
    redirect_to rails_blob_path(download.zip_file, disposition: 'attachment'),
                allow_other_host: true
  end

  # DELETE /downloads/:id
  # Dismisses/cancels a download
  def destroy
    download = find_download(params[:id])
    return head :not_found unless download

    download.update!(status: 'downloaded')

    # Clear session for anonymous users
    session.delete(:download_id) if session[:download_id] == download.id

    head :ok
  end

  # GET /downloads/active
  # Returns any active downloads for the current user (or session)
  def active
    download = find_active_download

    if download
      render json: {
        id: download.id,
        status: download.status,
        progress: download.progress,
        total: download.total,
        progress_text: download.progress_text,
        filename: download.filename
      }
    else
      render json: { id: nil }
    end
  end

  # GET /downloads/stream
  # Streaming download - no background job, streams directly to browser
  # For single files: redirects to direct URL
  # For folders: streams ZIP on-the-fly
  def stream
    asset, share_link = find_asset_for_stream

    return head :not_found unless asset

    # Record download for share links
    share_link&.record_download!

    # Single file with no children - redirect directly to file
    if !asset.is_directory? && asset.children.empty? && asset.file.attached?
      redirect_to rails_blob_path(asset.file, disposition: 'attachment'),
                  allow_other_host: true
      return
    end

    # Folder or asset with children - stream as ZIP
    filename = "#{asset.original_filename || asset.title}.zip"
    files = collect_files_for_zip(asset)

    zipline(files, filename)
  end

  private

  # Find download - checks user's downloads or session-based anonymous download
  def find_download(id)
    if current_user
      current_user.downloads.find_by(id: id)
    elsif session[:download_id].to_s == id.to_s
      Download.find_by(id: id)
    end
  end

  # Find active download for current user or session
  def find_active_download
    if current_user
      current_user.downloads.active.order(created_at: :desc).first
    elsif session[:download_id]
      Download.active.find_by(id: session[:download_id])
    end
  end

  # Require auth for library downloads, allow anonymous for share links
  def require_auth_or_share_link
    return if params[:share_link_token].present?
    authenticate_user!
  end

  # Find a file/folder within a shared asset's tree
  def find_child_within_share(root_asset, file_id)
    file = Asset.find_by(id: file_id)
    return nil unless file

    # Walk up the tree to verify this file belongs to the shared asset
    current = file
    while current
      return file if current.id == root_asset.id
      current = current.parent
    end

    nil
  end

  # Find asset for streaming - returns [asset, share_link]
  def find_asset_for_stream
    if params[:share_link_token].present?
      share_link = ShareLink.find_by(token: params[:share_link_token])
      return [nil, nil] unless share_link
      return [nil, nil] if share_link.expired?

      # If file_id is provided, download that specific file/folder
      if params[:file_id].present?
        asset = find_child_within_share(share_link.asset, params[:file_id])
      else
        asset = share_link.asset
      end

      [asset, share_link]
    else
      # Library download - requires authentication
      asset = current_user&.assets&.find_by(id: params[:asset_id])
      [asset, nil]
    end
  end

  # Collect files for zipline streaming
  # Returns array of [file_handle, path_in_zip] tuples
  def collect_files_for_zip(asset)
    files = []

    if asset.is_directory?
      # Directory - collect all children recursively
      collect_files_recursive(asset, asset.title, files)
    elsif asset.children.any?
      # Asset with extracted children (like a ZIP file)
      collect_files_recursive(asset, asset.title, files)
    elsif asset.file.attached?
      # Single file
      filename = asset.original_filename || asset.file.filename.to_s
      files << [asset.file, filename]
    end

    files
  end

  # Recursively collect files from asset tree
  def collect_files_recursive(asset, path_prefix, files)
    asset.children.each do |child|
      if child.is_directory?
        # Recurse into subfolder
        collect_files_recursive(child, "#{path_prefix}/#{child.title}", files)
      elsif child.file.attached?
        # Add file to collection
        filename = child.original_filename || child.file.filename.to_s
        files << [child.file, "#{path_prefix}/#{filename}"]
      end
    end
  end
end
