require 'rails_helper'

RSpec.describe DictionaryEntry, type: :model do
  describe "associations" do
    it { should have_many(:dictionary_entry_tags).dependent(:destroy) }
    it { should have_many(:tags).through(:dictionary_entry_tags) }
    it { should have_many(:meanings).dependent(:destroy) }
    it { should have_many(:user_learnings).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:text) }
    it { should validate_numericality_of(:frequency_rank).only_integer.is_greater_than(0).allow_nil }

    it 'requires at least one associated meaning' do
      dictionary_entry = build(:dictionary_entry, meanings_count: 0)
      expect(dictionary_entry).to_not be_valid
      expect(dictionary_entry.errors[:dictionary_entry]).to include('must have at least one associated meaning')
    end
  end

  describe "nested attributes" do
    it { should accept_nested_attributes_for(:meanings).allow_destroy(true) }
  end

  describe '#add_tag' do
    let(:dictionary_entry) { create(:dictionary_entry) }
    let(:tag) { create(:tag) }

    it 'adds a tag to the dictionary entry' do
      dictionary_entry.add_tag(tag)
      expect(dictionary_entry.tags).to include(tag)
    end

    it 'does not add the same tag twice' do
      dictionary_entry.add_tag(tag)
      dictionary_entry.add_tag(tag)
      expect(dictionary_entry.tags.where(id: tag.id).count).to eq(1)
    end
  end

  describe '#user_learning_for' do
    let(:dictionary_entry) { create(:dictionary_entry) }
    let(:user) { create(:user) }
    let!(:user_learning) { create(:user_learning, user: user, dictionary_entry: dictionary_entry) }

    it 'returns the user learning for the given user' do
      expect(dictionary_entry.user_learning_for(user)).to eq(user_learning)
    end

    it 'returns nil if no user learning exists for the given user' do
      other_user = create(:user)
      expect(dictionary_entry.user_learning_for(other_user)).to be_nil
    end
  end

  describe '.find_with_associations' do
    let(:dictionary_entry) { create(:dictionary_entry) }
    let(:user) { create(:user) }
    let!(:user_learning) { create(:user_learning, user: user, dictionary_entry: dictionary_entry) }

    before do
      # Ensure there's a meaning to be found
      create(:meaning, dictionary_entry: dictionary_entry) if dictionary_entry.meanings.empty?
    end

    it 'returns the dictionary entry with associated tags, meanings, and user learning' do
      result = DictionaryEntry.find_with_associations(dictionary_entry.id, user)
      expect(result[:entry]).to eq(dictionary_entry)
      expect(result[:meanings]).to include(dictionary_entry.meanings.first)
      expect(result[:user_learning]).to eq(user_learning)
    end
  end

  describe '#flashcard_meanings' do
    let(:entry) { create(:dictionary_entry) }
    let(:cedict_source) do
      create(:source,
             name: 'CC-CEDICT',
             priority: 20,
             url: 'https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip')
    end

    before { entry.meanings.destroy_all }

    it 'keeps CL senses out of flashcard meanings' do
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'CL:個|个[ge4]', pinyin: 'gè')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'to look', pinyin: 'kàn')

      expect(entry.reload.flashcard_meanings.map(&:text)).to eq([ 'to look' ])
    end

    it 'de-prioritises obscure CC-CEDICT senses when a plain sense exists' do
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'surname Li', pinyin: 'Lǐ')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'plum', pinyin: 'lǐ')

      expect(entry.reload.flashcard_primary_meaning.text).to eq('plum')
      expect(entry.flashcard_primary_meaning.pinyin).to eq('lǐ')
      expect(entry.flashcard_meanings.map(&:text)).to eq([ 'plum', 'surname Li' ])
    end

    it 'applies graded deprioritisation for CC-CEDICT senses' do
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'to look', pinyin: 'kàn')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'classifier for phrases', pinyin: 'kàn')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'literary usage', pinyin: 'kàn')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'surname Kan', pinyin: 'Kàn')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'variant of 看', pinyin: 'kàn')

      expect(entry.reload.flashcard_meanings.map(&:text)).to eq([
        'to look',
        'classifier for phrases',
        'literary usage',
        'variant of 看',
        'surname Kan'
      ])
    end

    it 'prefers pinyin groups with richer plain senses' do
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'convenient', pinyin: 'biàn yí')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'cheap', pinyin: 'pián yi')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'inexpensive', pinyin: 'pián yi')

      expect(entry.reload.flashcard_primary_meaning.text).to eq('cheap')
      expect(entry.flashcard_primary_pinyin).to eq('pián yi')
    end

    it 'preserves order when only obscure CC-CEDICT senses are available' do
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'surname Zhao', pinyin: 'Zhào')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'variant of 趙|赵', pinyin: 'Zhào')

      expect(entry.reload.flashcard_meanings.map(&:text)).to eq([ 'surname Zhao', 'variant of 趙|赵' ])
      expect(entry.flashcard_primary_meaning.text).to eq('surname Zhao')
    end

    it 'does not reorder non-CC-CEDICT meanings' do
      custom_source = create(:source, name: 'Custom Dictionary')
      create(:meaning, dictionary_entry: entry, source: custom_source, text: 'surname Wu', pinyin: 'Wú')
      create(:meaning, dictionary_entry: entry, source: custom_source, text: 'martial', pinyin: 'wǔ')

      expect(entry.reload.flashcard_meanings.map(&:text)).to eq([ 'surname Wu', 'martial' ])
    end

    it 'prioritises meanings from lower-priority-number sources' do
      wiktionary_source = create(:source, name: 'Wiktionary', priority: 10)
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'surname Li', pinyin: 'Lǐ')
      create(:meaning, dictionary_entry: entry, source: wiktionary_source, text: 'plum', pinyin: 'lǐ')

      expect(entry.reload.flashcard_primary_meaning.source.name).to eq('Wiktionary')
      expect(entry.flashcard_primary_meaning.text).to eq('plum')
    end

    it 'keeps CC-CEDICT heuristics within the same source priority band' do
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'surname Zhao', pinyin: 'Zhào')
      create(:meaning, dictionary_entry: entry, source: cedict_source, text: 'to surpass', pinyin: 'zhào')

      expect(entry.reload.flashcard_primary_meaning.text).to eq('to surpass')
      expect(entry.flashcard_meanings.map(&:text)).to eq([ 'to surpass', 'surname Zhao' ])
    end
  end
end
