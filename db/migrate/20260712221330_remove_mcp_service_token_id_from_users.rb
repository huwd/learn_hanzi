class RemoveMcpServiceTokenIdFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :mcp_service_token_id, :string
  end
end
