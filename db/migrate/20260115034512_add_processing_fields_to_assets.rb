class AddProcessingFieldsToAssets < ActiveRecord::Migration[7.1]
  def change
    add_column :assets, :processing_status, :string
    add_column :assets, :processing_progress, :integer
    add_column :assets, :processing_total, :integer
  end
end
