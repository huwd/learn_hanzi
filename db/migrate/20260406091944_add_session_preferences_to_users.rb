class AddSessionPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :session_size, :integer, default: 20, null: false
    add_column :users, :new_cards_per_session, :integer, default: 5, null: false
  end
end
