class CreateZipJob < ApplicationJob
  queue_as :default

  def perform(download_id)
    download = Download.find(download_id)
    asset = download.asset

    # Mark as processing
    download.update!(status: 'processing')

    # Count all files we need to zip
    file_count = count_files(asset)
    download.update!(total: file_count, progress: 0)

    # Create the ZIP in a temp file
    temp_file = Tempfile.new(['download', '.zip'])

    begin
      build_zip(temp_file.path, asset, download)

      # Attach the completed ZIP to the download record
      download.zip_file.attach(
        io: File.open(temp_file.path),
        filename: "#{download.filename}.zip",
        content_type: 'application/zip'
      )

      download.update!(status: 'ready')

      # Notify share link owner if this was a share link download
      notify_share_link_owner(download)
    rescue => e
      download.update!(status: 'failed', error_message: e.message)
      Rails.logger.error "CreateZipJob failed: #{e.message}\n#{e.backtrace.join("\n")}"
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  private

  def count_files(asset)
    return 1 unless asset.is_directory?
    count_files_recursive(asset)
  end

  def count_files_recursive(asset)
    count = 0
    asset.children.each do |child|
      if child.is_directory?
        count += count_files_recursive(child)
      else
        count += 1
      end
    end
    count
  end

  def build_zip(zip_path, asset, download)
    require 'zip'

    Zip::File.open(zip_path, create: true) do |zipfile|
      if asset.is_directory?
        add_folder_to_zip(zipfile, asset, asset.title, download)
      else
        # Single file download
        add_file_to_zip(zipfile, asset, '', download)
      end
    end
  end

  def add_folder_to_zip(zipfile, folder, path_prefix, download)
    folder.children.each do |child|
      if child.is_directory?
        # Recurse into subfolder
        add_folder_to_zip(zipfile, child, "#{path_prefix}/#{child.title}", download)
      else
        add_file_to_zip(zipfile, child, path_prefix, download)
      end
    end
  end

  def add_file_to_zip(zipfile, file_asset, path_prefix, download)
    return unless file_asset.file.attached?

    # Build the path inside the ZIP
    filename = file_asset.original_filename || file_asset.file.filename.to_s
    zip_entry_path = path_prefix.present? ? "#{path_prefix}/#{filename}" : filename

    # Download from storage and add to ZIP
    file_content = file_asset.file.download
    zipfile.get_output_stream(zip_entry_path) { |f| f.write(file_content) }

    # Update progress
    download.increment!(:progress)
  end

  def notify_share_link_owner(download)
    return unless download.share_link.present?

    share_link = download.share_link
    owner = share_link.asset.user

    # Don't notify if owner is downloading their own file
    return if download.user == owner

    Notification.create!(
      user: owner,
      actor: download.user, # nil for anonymous downloads
      notification_type: 'share_link_download',
      notifiable: download
    )
  end
end
