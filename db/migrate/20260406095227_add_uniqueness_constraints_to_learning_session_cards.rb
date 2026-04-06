class AddUniquenessConstraintsToLearningSessionCards < ActiveRecord::Migration[8.1]
  def change
    add_index :learning_session_cards, [ :learning_session_id, :position ],
              unique: true, name: "index_learning_session_cards_on_session_and_position"
    add_index :learning_session_cards, [ :learning_session_id, :user_learning_id ],
              unique: true, name: "index_learning_session_cards_on_session_and_user_learning"
  end
end
