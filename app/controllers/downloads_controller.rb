class DownloadsController < ApplicationController
  # Skip auth for share link downloads - use session to track anonymous downloads
  skip_before_action :authenticate_user!, only: [:create, :status, :file, :destroy, :active]
  before_action :require_auth_or_share_link, only: [:create]

  # POST /downloads
  # Creates a new background download job
  def create
    # Find asset - either from user's library or from a share link
    if params[:share_link_token].present?
      share_link = ShareLink.find_by!(token: params[:share_link_token])

      if share_link.expired?
        return render json: { error: 'Share link has expired' }, status: :unprocessable_entity
      end

      asset = share_link.asset
      share_link.record_download!

      # Create download record (anonymous or authenticated)
      download = Download.create!(
        user: current_user, # nil for anonymous
        asset: asset,
        filename: asset.title,
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
end
