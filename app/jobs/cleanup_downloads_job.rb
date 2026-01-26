class CleanupDownloadsJob < ApplicationJob
  queue_as :default

  def perform
    # Delete downloads older than 24 hours
    old_downloads = Download.where('created_at < ?', 24.hours.ago)

    count = old_downloads.count

    old_downloads.find_each do |download|
      # Purge the attached ZIP file from storage
      download.zip_file.purge if download.zip_file.attached?
      download.destroy
    end

    Rails.logger.info "CleanupDownloadsJob: Deleted #{count} old downloads"
  end
end
