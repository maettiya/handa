class DownloadsController < ApplicationController
  before_action :authenticate_user!

  # POST /downloads
  # Creates a new background download job
  def create
    asset = current_user.assets.find(params[:asset_id])

    # Create download record
    download = current_user.downloads.create!(
      asset: asset,
      filename: asset.title,
      status: 'pending'
    )

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
    download = current_user.downloads.find(params[:id])

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
    download = current_user.downloads.find(params[:id])

    unless download.ready? && download.zip_file.attached?
      return head :not_found
    end

    # Mark as downloaded
    download.update!(status: 'downloaded')

    # Redirect to the file (or stream it)
    redirect_to rails_blob_path(download.zip_file, disposition: 'attachment'),
                allow_other_host: true
  end

  # DELETE /downloads/:id
  # Dismisses/cancels a download
  def destroy
    download = current_user.downloads.find(params[:id])
    download.update!(status: 'downloaded')  # Reuse 'downloaded' to remove from active
    head :ok
  end

  # GET /downloads/active
  # Returns any active downloads for the current user (for page load)
  def active
    download = current_user.downloads.active.order(created_at: :desc).first

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
end
