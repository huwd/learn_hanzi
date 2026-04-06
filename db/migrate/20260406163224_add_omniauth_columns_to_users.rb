class AddOmniauthColumnsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string, null: false, default: ""
    add_column :users, :uid, :string, null: false, default: ""
    add_index :users, %i[provider uid], unique: true
    remove_column :users, :password_digest, :string
  end
end
