class SaveToLibraryJob < ApplicationJob
  queue_as :default

  def perform(asset_id, user_id, shared_from_user_id)
    asset = Asset.find(asset_id)
    user = User.find(user_id)
    shared_from_user = User.find(shared_from_user_id)

    asset.deep_clone_to_user(user, shared_from: shared_from_user)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "SaveToLibraryJob: Record not found - #{e.message}"
  end
end
