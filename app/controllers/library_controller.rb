class LibraryController < ApplicationController
  def index
    # Order by most recently created first (newest uploads/folders appear first)
    @assets = current_user.library_assets
  end

  # Move/merge library-level assets
  # Uses same param names as AssetsController#move_file for consistency
  # Move/merge library-level assets
# Supports single file (file_id) or multiple files (file_ids array)
  def move_asset
    file_ids = params[:file_ids] || [params[:file_id]]
    target_id = params[:target_id]
    merge_with_id = params[:merge_with_id]
    create_folder = params[:create_folder]

    @assets = current_user.assets.root_level.where(id: file_ids)

    if @assets.empty?
      render json: { success: false, error: "No assets found" }, status: :not_found
      return
    end

    if create_folder
      # Create a new folder and move all files into it
      folder_name = generate_untitled_folder_name
      new_folder = current_user.assets.create!(
        title: folder_name,
        original_filename: folder_name,
        is_directory: true,
        asset_type: 'folder',
        path: folder_name
      )

      @assets.each { |asset| move_asset_to_folder(asset, new_folder) }
      render json: { success: true, folder_id: new_folder.id }

    elsif merge_with_id.present?
      # Merging files into a new folder (original 2-file merge behavior)
      @other_asset = current_user.assets.root_level.find(merge_with_id)
      folder_name = generate_untitled_folder_name

      new_folder = current_user.assets.create!(
        title: folder_name,
        original_filename: folder_name,
        is_directory: true,
        asset_type: 'folder',
        path: folder_name
      )

      @assets.each { |asset| move_asset_to_folder(asset, new_folder) }
      move_asset_to_folder(@other_asset, new_folder)

      render json: { success: true, folder_id: new_folder.id }

    elsif target_id.present?
      # Moving into an existing folder
      target_folder = current_user.assets.root_level.find(target_id)

      unless target_folder.is_directory?
        render json: { success: false, error: "Target is not a folder" }, status: :unprocessable_entity
        return
      end

      @assets.each { |asset| move_asset_to_folder(asset, target_folder) }
      render json: { success: true }

    else
      render json: { success: false, error: "No target specified" }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "Asset not found" }, status: :not_found
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  # Move an asset into a folder, properly setting path and original_filename
  def move_asset_to_folder(asset, folder)
    # For root-level assets, original_filename may not be set - derive from title or attached file
    filename = asset.original_filename.presence ||
               asset.file&.filename&.to_s ||
               asset.title

    asset.update!(
      parent_id: folder.id,
      original_filename: filename,
      path: "#{folder.path}/#{filename}"
    )
  end

  def generate_untitled_folder_name
    existing = current_user.assets.root_level.where(is_directory: true)
                  .where("LOWER(title) LIKE 'untitled folder%'")
                  .pluck(:title)

    return "untitled folder" unless existing.map(&:downcase).include?("untitled folder")

    numbers = existing.map { |n| n[/\d+$/]&.to_i }.compact
    next_num = numbers.empty? ? 2 : numbers.max + 1
    "untitled folder #{next_num}"
  end
end
