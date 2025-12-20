class ProjectsController < ApplicationController

  def show

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
end
