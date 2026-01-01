class AssetExtractionJob < ApplicationJob
  queue_as :default

  def perform(asset_id)
    asset = Asset.find(asset_id)
    AssetExtractionService.new(asset).extract!
  rescue ActiveRecord::RecordNotFound
    # Asset was deleted before extraction could run
    Rails.logger.warn "AssetExtractionJob: Asset #{asset_id} not found"
  end
end
