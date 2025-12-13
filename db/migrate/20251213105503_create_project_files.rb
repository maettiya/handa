class CreateProjectFiles < ActiveRecord::Migration[7.1]
  def change
    create_table :project_files do |t|
      t.string :file_type
      t.string :original_filename
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
