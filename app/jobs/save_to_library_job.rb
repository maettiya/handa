class SaveToLibraryJob < ApplicationJob
  queue_as :default

  def perform(asset_id, user_id, shared_from_user_id, placeholder_id = nil)
    asset = Asset.find(asset_id)
    user = User.find(user_id)
    shared_from_user = User.find(shared_from_user_id)

    # If we have a placeholder, use it; otherwise create the clone directly
    if placeholder_id
      placeholder = Asset.find(placeholder_id)
      clone_with_progress(asset, user, shared_from_user, placeholder)
    else
      asset.deep_clone_to_user(user, shared_from: shared_from_user)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "SaveToLibraryJob: Record not found - #{e.message}"
  end

  private

  def clone_with_progress(source_asset, new_owner, shared_from, placeholder)
    # Count total items to clone
    total_count = count_descendants(source_asset) + 1
    # Use update_columns to skip validation (placeholder has no file yet)
    placeholder.update_columns(
      processing_status: 'importing',
      processing_progress: 0,
      processing_total: total_count
    )

    @progress = 0

    # Clone the source into the placeholder
    update_placeholder_from_source(placeholder, source_asset, shared_from)
    @progress += 1
    placeholder.update_columns(processing_progress: @progress)

    # Clone all children recursively
    clone_children(source_asset, new_owner, placeholder, shared_from, placeholder)

    # Mark as complete
    placeholder.update_columns(
      processing_status: nil,
      processing_progress: 0,
      processing_total: 0
    )
  end

  def update_placeholder_from_source(placeholder, source, shared_from)
    # Copy file attachment first if present
    if source.file.attached?
      placeholder.file.attach(
        io: StringIO.new(source.file.download),
        filename: source.file.filename.to_s,
        content_type: source.file.content_type
      )
    end

    # Update attributes - use update_columns for non-file fields to skip validation
    placeholder.update_columns(
      title: source.title,
      original_filename: source.original_filename,
      asset_type: source.asset_type,
      is_directory: source.is_directory,
      path: source.path,
      file_size: source.file_size,
      file_type: source.file_type,
      extracted: source.extracted,
      hidden: source.hidden,
      shared_from_user_id: shared_from&.id
    )
  end

  def clone_children(source_asset, new_owner, new_parent, shared_from, placeholder)
    source_asset.children.each do |child|
      # Build the child asset
      cloned_child = new_owner.assets.new(
        title: child.title,
        original_filename: child.original_filename,
        asset_type: child.asset_type,
        is_directory: child.is_directory,
        path: child.path,
        file_size: child.file_size,
        file_type: child.file_type,
        extracted: child.extracted,
        hidden: child.hidden,
        ephemeral: false,
        parent: new_parent,
        shared_from_user: shared_from
      )

      # Copy file attachment first if present
      if child.file.attached?
        cloned_child.file.attach(
          io: StringIO.new(child.file.download),
          filename: child.file.filename.to_s,
          content_type: child.file.content_type
        )
        cloned_child.save!
      else
        # No file (directory) - skip validation
        cloned_child.save(validate: false)
      end

      @progress += 1
      placeholder.update_columns(processing_progress: @progress)

      # Recursively clone children
      clone_children(child, new_owner, cloned_child, shared_from, placeholder)
    end
  end

  def count_descendants(asset)
    children = asset.children.to_a
    children.size + children.sum { |child| count_descendants(child) }
  end
end
