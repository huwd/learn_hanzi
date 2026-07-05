class AddMcpServiceTokenIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :mcp_service_token_id, :string
    add_index :users, :mcp_service_token_id, unique: true, where: "mcp_service_token_id IS NOT NULL"
  end
end
