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
      # Extract ZIP contents after save
      ProjectExtractionService.new(@project).extract!

      redirect_to root_path, notice: "Project uploaded successfully!"
    else
      redirect_to root_path, alert: "Upload failed: #{@project.errors.full_messages.join(', ')}"
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
    @file = @project.project_files.find(params[:id])

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
    @file = @project.project_files.find(params[:folder_id])

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

  private

  # Strong parameters - only allow these fields from the form
  def project_params
    params.require(:project).permit(:title, :file)
  end

  # Collects all files in a folder and creates a ZIP
  def create_folder_zip
    # Load RubyZip library
    require 'zip'

    # Create StringIO (memory buffer). Gives us 'zio' (zip input/outputstream) to add files to
    stringio = Zip::OutputStream.write.buffer do |zio|
      add_folder_to_zip(zio, folder, "")
    end

    stringio.rewind
    stringio.read
  end

  # Adds files and sub-folders to the ZIP


end
