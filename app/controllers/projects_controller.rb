class ProjectsController < ApplicationController
  def create
    @project = current_user.projects.build(project_params)

    if @project.save
      redirect_to root_path, notice: "Project uploaded successfully!"
    else
      redirect_to root_path, alert: "Upload failed: #{@project.errors.full_messages.join(', ')}"
    end
  end

  private

  def project_params
    params.require(:project).permit(:title, :file)
  end
end
