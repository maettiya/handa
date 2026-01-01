class LibraryController < ApplicationController
  def index
    # Order by most recently created first (newest uploads/folders appear first)
    @assets = current_user.library_assets
  end

  # Move/merge library-level assets
  # Uses same param names as AssetsController#move_file for consistency
  def move_asset
    @asset = current_user.assets.root_level.find(params[:file_id])
    target_id = params[:target_id]
    merge_with_id = params[:merge_with_id]

    if merge_with_id.present?
      # Merging two assets into a new folder
      @other_asset = current_user.assets.root_level.find(merge_with_id)
      folder_name = generate_untitled_folder_name

      # Create the new folder at root level
      new_folder = current_user.assets.create!(
        title: folder_name,
        is_directory: true,
        asset_type: 'folder'
      )

      # Move both assets into the new folder
      @asset.update!(parent_id: new_folder.id)
      @other_asset.update!(parent_id: new_folder.id)

      render json: { success: true, folder_id: new_folder.id }
    elsif target_id.present?
      # Moving into an existing folder
      target_folder = current_user.assets.root_level.find(target_id)

      unless target_folder.is_directory?
        render json: { success: false, error: "Target is not a folder" }, status: :unprocessable_entity
        return
      end

      @asset.update!(parent_id: target_folder.id)
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
