class AddCimdMetadataToOauthApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :oauth_applications, :metadata_url, :string
    add_index :oauth_applications, :metadata_url, unique: true
    add_column :oauth_applications, :metadata_fetched_at, :datetime
  end
end
