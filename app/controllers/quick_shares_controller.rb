class QuickSharesController < ApplicationController
  # GET /share - Quick Share page with upload zone and history
  def index
    @quick_shares = current_user.quick_shares.includes(:share_links)
  end

  # POST /quick_shares - Create ephemeral asset + auto-generate share link
  def create
    @asset = current_user.assets.build(
      title: params[:title] || "Quick Share",
      ephemeral: true
    )

    # Attach file from signed blob ID (Direct Upload)
    if params[:signed_id].present?
      blob = ActiveStorage::Blob.find_signed(params[:signed_id])
      @asset.file.attach(blob)
      @asset.original_filename = blob.filename.to_s
      @asset.title = blob.filename.base if @asset.title == "Quick Share"
    end

    if @asset.save
      # Auto-create share link with expiry
      expires_at = parse_expiry(params[:expires])
      share_link = @asset.share_links.create!(
        expires_at: expires_at,
        password: params[:password].presence
      )

      # Trigger extraction if it's a ZIP
      if @asset.file.attached? && @asset.file.content_type == 'application/zip'
        AssetExtractionJob.perform_later(@asset.id)
      end

      render json: {
        success: true,
        url: share_link_url(share_link.token),
        asset_id: @asset.id
      }
    else
      render json: { success: false, errors: @asset.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /quick_shares/:id - Delete a quick share
  def destroy
    @asset = current_user.assets.ephemeral_shares.find(params[:id])
    @asset.destroy
    redirect_to quick_shares_path, notice: "Share deleted"
  end

  private

  def parse_expiry(value)
    case value
    when '1_hour'
      1.hour.from_now
    when '24_hours'
      24.hours.from_now
    when '7_days'
      7.days.from_now
    when '30_days'
      30.days.from_now
    else
      nil # Never expires
    end
  end
end
