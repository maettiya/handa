# Handles all asset-related actions:
# - Viewing asset contents (browse extracted files)
# - Uploading new assets (with automatic ZIP extraction)
# - Downloading assets
class AssetsController < ApplicationController

  def show
    # Find the asset - scoped to current_user for security
    @asset = current_user.assets.find_by(id: params[:id])

    # Handle missing or deleted assets gracefully (e.g., from stale notification links)
    unless @asset
      redirect_to library_index_path, alert: "This file no longer exists"
      return
    end

    # Check if we should auto-skip a single root folder
    # (e.g., "SERENADE Project.zip" containing only "SERENADE Project/" folder)
    root_files = @asset.children.visible.order(:original_filename)

    if root_files.count == 1 && root_files.first.is_directory?
      @skipped_root_folder = root_files.first
    else
      @skipped_root_folder = nil
    end

    if params[:folder_id].present?
      # Browsing inside a subfolder - folder can be any descendant, not just direct child
      @current_folder = current_user.assets.find_by(id: params[:folder_id])
      unless @current_folder
        redirect_to asset_path(@asset), alert: "This folder no longer exists"
        return
      end
      @files = @current_folder.children.visible.order(:original_filename)
    else
      # Root level - show top-level files
      if @skipped_root_folder
        # Skip into the single root folder automatically
        @current_folder = nil
        @files = @skipped_root_folder.children.visible.order(:original_filename)
      else
        @current_folder = nil
        @files = root_files
      end
    end
  end

# Handles file upload and triggers ZIP extraction
  def create
    @asset = current_user.assets.build(asset_params)
    @asset.original_filename = @asset.file&.filename&.to_s

    if @asset.save
      # For ZIP files, set processing status immediately so UI shows spinner
      # before the background job even starts
      if @asset.file.attached? && @asset.file.content_type == 'application/zip'
        @asset.update_columns(processing_status: 'extracting', processing_progress: 0, processing_total: 0)
      end

      # Extract ZIP contents in background job (avoids Heroku 30s timeout)
      AssetExtractionJob.perform_later(@asset.id)

      respond_to do |format|
        format.html { redirect_to root_path, notice: "Uploaded! Extraction in progress..." }
        format.json { render json: { success: true, id: @asset.id, title: @asset.title } }
      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Upload failed: #{@asset.errors.full_messages.join(', ')}" }
        format.json { render json: { success: false, errors: @asset.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # Check processing status for polling
  def status
    @asset = current_user.assets.find(params[:id])

    render json: {
      id: @asset.id,
      extracted: @asset.extracted?,
      title: @asset.title,
      processing_status: @asset.processing_status,
      processing_progress: @asset.processing_progress,
      processing_total: @asset.processing_total
    }
  end

  # Deletes an entire asset and all its children
  def destroy
    @asset = current_user.assets.find(params[:id])
    @asset.destroy

    redirect_to root_path, notice: "Deleted successfully"
  end

  # Deletes a single file or folder (and all children if it's a folder)
  def destroy_file
    @asset = current_user.assets.find(params[:id])
    @file = find_descendant(@asset, params[:file_id])

    # Store parent folder to redirect back to current location
    parent_folder_id = @file.parent_id

    # If it's a folder, this will also destroy all the children
    @file.destroy

    # Redirect back to where they were
    # Check if parent is the root asset or a subfolder
    if parent_folder_id == @asset.id
      redirect_to asset_path(@asset), notice: "Deleted successfully"
    elsif parent_folder_id
      redirect_to asset_path(@asset, folder_id: parent_folder_id), notice: "Deleted successfully"
    else
      redirect_to asset_path(@asset), notice: "Deleted successfully"
    end
  end

  # Downloads the original uploaded file or creates a ZIP for folders/extracted assets
  def download
    @asset = current_user.assets.find(params[:id])

    if @asset.file.attached? && !@asset.is_directory?
      # Has original file - redirect to blob URL for direct download
      redirect_to rails_blob_path(@asset.file, disposition: "attachment", filename: @asset.download_filename)
    elsif @asset.children.any?
      # Has children - create a ZIP using temp file (low memory)
      tempfile = create_zip_tempfile(@asset)
      send_file tempfile.path,
        type: 'application/zip',
        disposition: 'attachment',
        filename: "#{@asset.title}.zip"
    else
      # Empty folder - create empty ZIP
      tempfile = create_empty_zip_tempfile(@asset.title)
      send_file tempfile.path,
        type: 'application/zip',
        disposition: 'attachment',
        filename: "#{@asset.title}.zip"
    end
  end

  # Downloads a single file from an asset
  def download_file
    @asset = current_user.assets.find(params[:id])
    @file = find_descendant(@asset, params[:file_id])

    # Ensure it's actually a file, not a directory
    if @file.is_directory? || !@file.file.attached?
      redirect_to asset_path(@asset), alert: "File not available for download"
      return
    end

    # Download with the renamed filename
    send_data @file.file.download,
      type: @file.file.content_type,
      disposition: 'attachment',
      filename: @file.download_filename
  end

  # Downloads a folder from an asset
  def download_folder
    @asset = current_user.assets.find(params[:id])
    @folder = find_descendant(@asset, params[:folder_id])

    # Ensure it's a directory
    unless @folder.is_directory?
      redirect_to asset_path(@asset), alert: "Not a folder"
      return
    end

    # Create ZIP using temp file (low memory)
    tempfile = create_folder_zip_tempfile(@folder)

    send_file tempfile.path,
      type: 'application/zip',
      disposition: 'attachment',
      filename: "#{@folder.original_filename}.zip"
  end

  def create_folder
    @asset = current_user.assets.build(
      title: params[:folder_name],
      is_directory: true,
      asset_type: "folder"
    )

    if @asset.save
      redirect_to root_path
    else
      redirect_to root_path, alert: "Could not create folder"
    end
  end

  # Duplicates an asset (creates a copy with " (copy)" or " (copy N)" suffix)
  def duplicate
    @asset = current_user.assets.find(params[:id])

    # Create new asset with copied attributes
    new_asset = current_user.assets.build(
      title: generate_copy_name(@asset.title),
      original_filename: @asset.original_filename,
      asset_type: @asset.asset_type,
      is_directory: @asset.is_directory?
    )

    # Copy the attached file if present
    if @asset.file.attached?
      new_asset.file.attach(
        io: StringIO.new(@asset.file.download),
        filename: @asset.file.filename.to_s,
        content_type: @asset.file.content_type
      )
    end

    if new_asset.save
      # If original had children, trigger extraction for the copy too
      if @asset.children.any?
        AssetExtractionJob.perform_later(new_asset.id)
      end
      redirect_to root_path
    else
      redirect_to root_path, alert: "Could not duplicate"
    end
  end

  # Renames a root-level asset
  def rename
    @asset = current_user.assets.find(params[:id])

    if @asset.update(title: params[:title])
      respond_to do |format|
        format.html { redirect_to root_path }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Could not rename" }
        format.json { render json: { success: false, error: "Could not rename" }, status: :unprocessable_entity }
      end
    end
  end

  # Renames a child file/folder within an asset
  def rename_file
    @asset = current_user.assets.find(params[:id])
    @file = find_descendant(@asset, params[:file_id])

    new_name = params[:title].to_s.strip
    return render json: { success: false, error: "Name cannot be blank" }, status: :unprocessable_entity if new_name.blank?

    # Update original_filename and rebuild path
    old_filename = @file.original_filename
    @file.original_filename = new_name
    @file.title = new_name
    @file.path = @file.path.sub(/#{Regexp.escape(old_filename)}$/, new_name) if @file.path.present?

    if @file.save
      render json: { success: true }
    else
      render json: { success: false, error: @file.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "File not found" }, status: :not_found
  end

  # Uploads files to an existing asset
  def upload_files
    @asset = current_user.assets.find(params[:id])

    # Determine parent folder
    parent_id = params[:parent_id].presence
    if parent_id.nil?
      skipped = detect_skipped_root_folder
      parent_id = skipped&.id || @asset.id
    end

    uploaded_files = []
    errors = []

    # Handle multiple files
    files = params[:files] || []
    files = [files] unless files.is_a?(Array)

    files.each do |file|
      next unless file.is_a?(ActionDispatch::Http::UploadedFile) || file.is_a?(ActiveStorage::Blob)

      filename = file.respond_to?(:original_filename) ? file.original_filename : file.filename.to_s

      # Create child Asset for this upload
      child_asset = @asset.user.assets.build(
        title: filename,
        original_filename: filename,
        is_directory: false,
        parent_id: parent_id,
        path: build_file_path(parent_id, filename)
      )

      # Attach the file
      child_asset.file.attach(file)

      if child_asset.save
        uploaded_files << child_asset
      else
        errors << "#{filename}: #{child_asset.errors.full_messages.join(', ')}"
      end
    end

    # Handle signed blob IDs (from Direct Upload)
    if params[:signed_id].present?
      blob = ActiveStorage::Blob.find_signed(params[:signed_id])
      if blob
        child_asset = @asset.user.assets.build(
          title: blob.filename.to_s,
          original_filename: blob.filename.to_s,
          is_directory: false,
          parent_id: parent_id,
          path: build_file_path(parent_id, blob.filename.to_s)
        )
        child_asset.file.attach(blob)

        if child_asset.save
          uploaded_files << child_asset
        else
          errors << "#{blob.filename}: #{child_asset.errors.full_messages.join(', ')}"
        end
      end
    end

    respond_to do |format|
      format.html do
        if errors.any?
          redirect_back fallback_location: asset_path(@asset), alert: errors.join("; ")
        else
          redirect_back fallback_location: asset_path(@asset), notice: "#{uploaded_files.count} file(s) uploaded successfully"
        end
      end
      format.json do
        if errors.any?
          render json: { success: false, errors: errors }, status: :unprocessable_entity
        else
          render json: { success: true, files: uploaded_files.map { |f| { id: f.id, filename: f.original_filename } } }
        end
      end
    end
  end

  # Creates a folder inside an asset (as a child Asset)
  def create_subfolder
    @asset = current_user.assets.find(params[:id])

    # Determine parent folder
    parent_id = params[:parent_id].presence
    if parent_id.nil?
      skipped = detect_skipped_root_folder
      parent_id = skipped&.id || @asset.id
    end

    @folder = @asset.user.assets.build(
      title: params[:folder_name],
      original_filename: params[:folder_name],
      is_directory: true,
      parent_id: parent_id,
      path: build_folder_path(parent_id, params[:folder_name])
    )

    if @folder.save
      # Redirect back to where they were
      if params[:parent_id].present?
        redirect_to asset_path(@asset, folder_id: params[:parent_id])
      else
        redirect_to asset_path(@asset)
      end
    else
      redirect_back fallback_location: asset_path(@asset), alert: "Could not create folder"
    end
  end

  def move_file
    @asset = current_user.assets.find(params[:id])

    file_ids = params[:file_ids] || [params[:file_id]]
    target_id = params[:target_id]
    merge_with_id = params[:merge_with_id]
    create_folder = params[:create_folder]

    @files = file_ids.map { |id| find_descendant(@asset, id) }

    if @files.empty?
      render json: { success: false, error: "No files found" }, status: :not_found
      return
    end

    # Get the parent of the first file (they should all be in the same location)
    common_parent_id = @files.first.parent_id

    if create_folder
      # Create a new folder and move all files into it
      folder_name = generate_untitled_folder_name(common_parent_id)
      new_folder = @asset.user.assets.create!(
        title: folder_name,
        original_filename: folder_name,
        is_directory: true,
        parent_id: common_parent_id,
        path: build_file_path(common_parent_id, folder_name)
      )

      @files.each { |file| move_to_parent(file, new_folder) }
      render json: { success: true, folder_id: new_folder.id }

    elsif merge_with_id.present?
      # Merging files into a new folder
      @other_file = find_descendant(@asset, merge_with_id)
      folder_name = generate_untitled_folder_name(common_parent_id)

      new_folder = @asset.user.assets.create!(
        title: folder_name,
        original_filename: folder_name,
        is_directory: true,
        parent_id: common_parent_id,
        path: build_file_path(common_parent_id, folder_name)
      )

      @files.each { |file| move_to_parent(file, new_folder) }
      move_to_parent(@other_file, new_folder)

      render json: { success: true, folder_id: new_folder.id }

    elsif target_id == "library"
      # Moving to library root level
      @files.each { |file| move_to_library(file) }
      render json: { success: true, redirect: root_path }

    else
      # Simple move to folder or root
      if target_id == "root"
        skipped = detect_skipped_root_folder
        new_parent = skipped || @asset
      else
        new_parent = find_descendant(@asset, target_id)
      end

      @files.each { |file| move_to_parent(file, new_parent) }
      render json: { success: true }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "File not found" }, status: :not_found
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  # Find a descendant asset (child, grandchild, etc.) of the root asset
  def find_descendant(root_asset, id)
    # For now, just find by ID but ensure it belongs to the same user
    root_asset.user.assets.find(id)
  end

  def move_to_parent(file, new_parent)
    file.parent_id = new_parent&.id
    file.path = new_parent ? "#{new_parent.path}/#{file.original_filename}" : file.original_filename
    file.save!

    # Recursively update children paths if it's a folder
    rebuild_children_paths(file) if file.is_directory?
  end

  def move_to_library(file)
    # Move file to library root level (becomes a top-level asset)
    file.parent_id = nil
    file.path = file.original_filename
    # Set title from original_filename if not already set
    file.title = file.original_filename if file.title.blank?
    file.save!

    # Recursively update children paths if it's a folder
    rebuild_children_paths(file) if file.is_directory?
  end

  def rebuild_children_paths(folder)
    folder.children.each do |child|
      child.path = "#{folder.path}/#{child.original_filename}"
      child.save!
      rebuild_children_paths(child) if child.is_directory?
    end
  end

  def generate_untitled_folder_name(parent_id)
    existing = Asset.where(parent_id: parent_id, is_directory: true)
                    .where("original_filename LIKE 'untitled folder%'")
                    .pluck(:original_filename)

    return "untitled folder" unless existing.include?("untitled folder")

    numbers = existing.map { |n| n[/\d+$/]&.to_i }.compact
    next_num = numbers.empty? ? 2 : numbers.max + 1
    "untitled folder #{next_num}"
  end

  # Detects if asset has a single root folder that should be auto-skipped
  def detect_skipped_root_folder
    root_files = @asset.children.visible.order(:original_filename)

    if root_files.count == 1 && root_files.first.is_directory?
      root_files.first
    else
      nil
    end
  end

  # Builds the full path for a new folder
  def build_folder_path(parent_id, folder_name)
    if parent_id.present?
      parent = Asset.find(parent_id)
      "#{parent.path}/#{folder_name}"
    else
      folder_name
    end
  end

  # Builds the full path for a new file
  def build_file_path(parent_id, filename)
    if parent_id.present?
      parent = Asset.find(parent_id)
      "#{parent.path}/#{filename}"
    else
      filename
    end
  end

  # Generates a unique copy name like "title (copy)", "title (copy 2)", etc.
  def generate_copy_name(original_title)
    # Strip any existing " (copy)" or " (copy N)" suffix to get base name
    base_name = original_title.sub(/\s*\(copy(?:\s+\d+)?\)\s*$/i, "").strip

    # Find all existing copies of this base name
    existing = current_user.assets.root_level
      .where("LOWER(title) LIKE ?", "#{base_name.downcase} (copy%")
      .pluck(:title)

    # If no copies exist yet, use "base (copy)"
    return "#{base_name} (copy)" if existing.empty?

    # Check if "base (copy)" exists (without number)
    has_simple_copy = existing.any? { |t| t.downcase == "#{base_name.downcase} (copy)" }

    # Extract all existing copy numbers
    numbers = existing.map do |title|
      if title.match(/\(copy\s+(\d+)\)/i)
        $1.to_i
      elsif title.downcase == "#{base_name.downcase} (copy)"
        1  # Treat "(copy)" as copy 1
      else
        nil
      end
    end.compact

    # Find the next available number
    next_num = has_simple_copy ? (numbers.max || 1) + 1 : 2
    next_num = 2 if next_num < 2

    # Return numbered copy name
    "#{base_name} (copy #{next_num})"
  end

  # Strong parameters - only allow these fields from the form
  def asset_params
    params.require(:asset).permit(:title, :file)
  end

  # Creates ZIP of asset children using temp file (low memory for Heroku)
  def create_zip_tempfile(asset)
    require 'zip'
    require 'tempfile'

    tempfile = Tempfile.new(['download', '.zip'])
    tempfile.binmode

    Zip::OutputStream.open(tempfile.path) do |zio|
      asset.children.visible.each do |child|
        if child.is_directory?
          add_children_to_zip(zio, child, child.original_filename)
        elsif child.file.attached?
          zio.put_next_entry(child.original_filename)
          child.file.open { |file| zio.write(file.read) }
        end
      end
    end

    tempfile
  end

  # Creates ZIP of a folder using temp file (low memory for Heroku)
  def create_folder_zip_tempfile(folder)
    require 'zip'
    require 'tempfile'

    tempfile = Tempfile.new(['download', '.zip'])
    tempfile.binmode

    Zip::OutputStream.open(tempfile.path) do |zio|
      add_children_to_zip(zio, folder, "")
    end

    tempfile
  end

  # Recursively adds folder contents to ZIP
  def add_children_to_zip(zio, folder, path_prefix)
    folder.children.visible.each do |child|
      child_path = path_prefix.empty? ? child.original_filename : "#{path_prefix}/#{child.original_filename}"

      if child.is_directory?
        add_children_to_zip(zio, child, child_path)
      elsif child.file.attached?
        zio.put_next_entry(child_path)
        child.file.open { |file| zio.write(file.read) }
      end
    end
  end

  # Creates an empty ZIP using temp file
  def create_empty_zip_tempfile(folder_name)
    require 'zip'
    require 'tempfile'

    tempfile = Tempfile.new(['download', '.zip'])
    tempfile.binmode

    Zip::OutputStream.open(tempfile.path) do |zio|
      zio.put_next_entry("#{folder_name}/")
    end

    tempfile
  end
end
