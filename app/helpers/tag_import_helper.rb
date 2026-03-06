module TagImportHelper
  def find_or_create_tag(tag_name, category, parent_id = nil)
    Tag.find_or_create_by(
      name: tag_name,
      category: category,
      parent_id: parent_id
    )
  end

  def batch_associate_entries_to_tag(texts, tag)
    raise "No tag provided" if tag.nil?

    texts = texts.compact.reject(&:empty?)
    entry_id_map = DictionaryEntry.where(text: texts).pluck(:text, :id).to_h

    rows = texts.filter_map do |text|
      id = entry_id_map[text]
      { dictionary_entry_id: id, tag_id: tag.id } if id
    end

    DictionaryEntryTag.insert_all(rows) if rows.any?

    texts.count - rows.count
  end

  def associate_dictionary_entry_to_tag(text, tag)
    raise "No tag provided" if tag.nil?
    dictionary_entry = DictionaryEntry.find_by_text(text)
    raise "No entry found for #{text}" if dictionary_entry.nil?
    dictionary_entry.add_tag(tag)
  end
end
