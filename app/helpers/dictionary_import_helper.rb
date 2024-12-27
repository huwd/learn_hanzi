module DictionaryImportHelper
  def find_or_create_cc_cedict_source(source_name, source_url)
    source = Source.find_or_create_by(name: source_name, url: source_url).tap do |source|
      source.update(date_accessed: Date.today) if source.date_accessed != Date.today
    end
    source.save!
    source
  end
end
