# Handles all project-related actions:
# - Viewing project contents (browse extracted files)
# - Uploading new projects (with automatic ZIP extraction)
# - Downloading original project files
class ProjectsController < ApplicationController

  def show
    # Find the project - scoped to current_user for security
    # (users can only view their own projects)
    @project = current_user.projects.find(params[:id])

    if params[:folder_id].present?
      # Browsing inside a subfolder
      # Find the folder and get its children
      @current_folder = @project.project_files.find(params[:folder_id])
      @files = @project.project_files
                        .where(parent_id: @current_folder.id)
                        .visible
                        .order(:original_filename)
    else
      # Root level - show top-level files (no parent)
      @current_folder = nil
      @files = @project.project_files
                        .where(parent_id: nil)
                        .visible
                        .order(:original_filename)
    end
  end

  # Handles file upload and triggers ZIP extraction
  def create
    @project = current_user.projects.build(project_params)

    if @project.save
      # Extract ZIP contents in background job (avoids Heroku 30s timeout)
      ProjectExtractionJob.perform_later(@project.id)

      redirect_to root_path, notice: "Project uploaded! Extraction in progress..."
    else
      redirect_to root_path, alert: "Upload failed: #{@project.errors.full_messages.join(', ')}"
    end
  end

  # Deletes an entire project and all it's children
  def destroy
    @project = current_user.projects.find(params[:id])
    @project.destroy

    redirect_to root_path, notice: "Project deleted successfully"
  end

  # Deletes a single file or folder (and all children if it's a folder)
  def destroy_file
    @project = current_user.projects.find(params[:id])
    @file = @project.project_files.find(params[:file_id])

    # Store parent folder to redirect back to current location
    parent_folder_id = @file.parent_id

    # If it's a folder, this will also destroy all the children
    @file.destroy

    # Redirect back to where they were
    if parent_folder_id
      redirect_to project_path(@project, folder_id: parent_folder_id), notice: "Deleted successfully"
    else
      redirect_to project_path(@project), notice: "Deleted successfully"
    end
  end

  # Downloads the original uploaded file
  def download
    @project = current_user.projects.find(params[:id])
    redirect_to rails_blob_path(@project.file, disposition: "attachment")
  end

  # Downloads a single file from a project
  def download_file
    @project = current_user.projects.find(params[:id])
    @file = @project.project_files.find(params[:file_id])

    # Ensure it's actually a file, not a directory
    if @file.is_directory? || !@file.file.attached?
      redirect_to project_path(@project), alert: "File not available for download"
      return
    end

    # The actual file download. Just download, ensures original file name (not Active Storage ID)
    redirect_to rails_blob_path(@file.file, disposition: "attachment", filename: @file.original_filename)
  end

  # Downloads a folder from a project
  def download_folder
    @project = current_user.projects.find(params[:id])
    @folder = @project.project_files.find(params[:folder_id])

    # Ensure it's a directory
    unless @folder.is_directory?
      redirect_to project_path(@project), alert: "Not a folder"
      return
    end

    # Create ZIP in memory (call private method below)
    zip_data = create_folder_zip(@folder)

    # Send the ZIP file (send_data -> Rails method to send raw bytes to the browser)
    send_data zip_data,
      type: 'application/zip',
      disposition: 'attachment',
      filename: "#{@folder.original_filename}.zip"
  end

  def create_folder
    @project = current_user.projects.build(
      title: params[:folder_name],
      project_type: "folder"
    )

    if @project.save
      redirect_to root_path
    else
      redirect_to root_path, alert: "Could not create folder"
    end
  end

  # Duplicates a project (creates a copy with " (copy)" suffix)
  def duplicate
    @project = current_user.projects.find(params[:id])

    # Create new project with copied attributes
    new_project = current_user.projects.build(
      title: "#{@project.title} (copy)",
      project_type: @project.project_type
    )

    # Copy the attached file if present
    if @project.file.attached?
      new_project.file.attach(
        io: StringIO.new(@project.file.download),
        filename: @project.file.filename.to_s,
        content_type: @project.file.content_type
      )
    end

    if new_project.save
      # If original had extracted files, trigger extraction for the copy too
      if @project.project_files.any?
        ProjectExtractionJob.perform_later(new_project.id)
      end
      redirect_to root_path
    else
      redirect_to root_path, alert: "Could not duplicate project"
    end
  end

  # Renames a project
  def rename
    @project = current_user.projects.find(params[:id])

    if @project.update(title: params[:title])
      redirect_to root_path
    else
      redirect_to root_path, alert: "Could not rename project"
    end
  end

  # Creates a folder inside a project (as a ProjectFile)
  def create_subfolder
    @project = current_user.projects.find(params[:id])

    # Determine parent folder (nil = root level of project)
    parent_id = params[:parent_id].presence

    @folder = @project.project_files.build(
      original_filename: params[:folder_name],
      is_directory: true,
      parent_id: parent_id,
      path: build_folder_path(parent_id, params[:folder_name])
    )

    if @folder.save
      # Redirect back to where they were
      if parent_id
        redirect_to project_path(@project, folder_id: parent_id)
      else
        redirect_to project_path(@project)
      end
    else
      redirect_back fallback_location: project_path(@project), alert: "Could not create folder"
    end
  end

  private

  # Builds the full path for a new folder
  def build_folder_path(parent_id, folder_name)
    if parent_id.present?
      parent = @project.project_files.find(parent_id)
      "#{parent.path}/#{folder_name}"
    else
      folder_name
    end
  end

  # Strong parameters - only allow these fields from the form
  def project_params
    params.require(:project).permit(:title, :file)
  end

  # Collects all files in a folder and creates a ZIP
  def create_folder_zip(folder)
    # Load RubyZip library
    require 'zip'

    # Create StringIO (memory buffer). Gives us 'zio' (zip input/outputstream) to add files to
    stringio = Zip::OutputStream.write_buffer do |zio|
      add_folder_to_zip(zio, folder, "")
    end

    stringio.rewind
    stringio.read
  end

  # Adds files and sub-folders to the ZIP (folders-within-folders handling)
  def add_folder_to_zip(zio, folder, path_prefix)
    folder.children.visible.each do |child|
      child_path = path_prefix.empty? ? child.original_filename : "#{path_prefix}/#{child.original_filename}"

      if child.is_directory?
        # Recurse into sub-folder
        add_folder_to_zip(zio, child, child_path)
      elsif child.file.attached?
        # Add file to ZIP
        zio.put_next_entry(child_path)
        zio.write(child.file.download)
      end
    end
  end

end
