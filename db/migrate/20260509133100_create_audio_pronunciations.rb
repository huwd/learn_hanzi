class CreateAudioPronunciations < ActiveRecord::Migration[8.1]
  def change
    create_table :audio_pronunciations do |t|
      t.references :dictionary_entry, null: false, foreign_key: true
      t.string :source, null: false
      t.string :locale, null: false

      t.timestamps
    end

    add_index :audio_pronunciations,
              [ :dictionary_entry_id, :source, :locale ],
              unique: true,
              name: "index_audio_pronunciations_on_entry_source_locale"
  end
end
