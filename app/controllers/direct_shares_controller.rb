class DirectSharesController < ApplicationController
  before_action :authenticate_user!

  # POST /direct_shares
  # Quick share an asset directly with a collaborator
  def create
    @asset = current_user.assets.find(params[:asset_id])
    @recipient = User.find(params[:recipient_id])

    # Create a share link for this direct share (no password, no expiry)
    share_link = @asset.share_links.create!

    # Record the direct share (for tracking frequent collaborators)
    direct_share = DirectShare.create!(
      user: current_user,
      recipient: @recipient,
      asset: @asset,
      share_link: share_link
    )

    # Notify the recipient
    Notification.create!(
      user: @recipient,
      actor: current_user,
      notification_type: 'direct_share',
      notifiable: direct_share
    )

    render json: {
      success: true,
      recipient: @recipient.username,
      asset: @asset.title
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Asset or recipient not found' }, status: :not_found
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /direct_shares/frequent_recipients
  # Get current user's top 5 most frequent share recipients
  def frequent_recipients
    recipients = DirectShare.top_recipients_for(current_user, limit: 5)

    # If user has no share history, fall back to their collaborators
    if recipients.empty?
      recipients = current_user.collaborators.limit(5)
    end

    render json: recipients.map { |u|
      {
        id: u.id,
        username: u.username,
        avatar_url: u.avatar.attached? ? url_for(u.avatar) : nil
      }
    }
  end
end
