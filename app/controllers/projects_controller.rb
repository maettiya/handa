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

  private

  # Strong parameters - only allow these fields from the form
  def project_params
    params.require(:project).permit(:title, :file)
  end

  # Collects all files in a folder and creates a ZIP
  def create_folder_zip

  end
end
