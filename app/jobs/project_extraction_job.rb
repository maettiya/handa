class ProjectExtractionJob < ApplicationJob
  queue_as :default

  def perform(project_id)
    project = Project.find(project_id)
    ProjectExtractionService.new(project).extract!
  rescue ActiveRecord::RecordNotFound
    # Project was deleted before extraction could run
    Rails.logger.warn "ProjectExtractionJob: Project #{project_id} not found"
  end
end
