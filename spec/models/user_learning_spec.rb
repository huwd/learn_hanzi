RSpec.describe UserLearning, type: :model do
  let(:user) { User.create(email_address: "e@mail.com", password: "password") }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:dictionary_entry) }
  end

  describe 'validations' do
    it { should validate_presence_of(:state) }
    it { should validate_inclusion_of(:state).in_array([ 'new', 'learning', 'mastered' ]) }

    it "validates uniqueness of user scoped to dictionary_entry" do
      entry = create(:dictionary_entry)
      create(:user_learning, user: user, dictionary_entry: entry, state: 'learning')

      duplicate = build(:user_learning, user: user, dictionary_entry: entry)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user]).to include("already has a learning record for this entry")
    end
  end

  describe 'scopes' do
    before do
      create(:user_learning, state: 'new', user_id: user.id)
      create(:user_learning, state: 'learning', user_id: user.id)
      create(:user_learning, state: 'mastered', user_id: user.id)
      create(:user_learning, state: 'suspended', user_id: user.id)
    end

    it "filters new learnings" do
      expect(UserLearning.new_learnings.count).to eq(1)
    end

    it "filters in-progress learnings" do
      expect(UserLearning.in_progress.count).to eq(1)
    end

    it "filters mastered learnings" do
      expect(UserLearning.mastered.count).to eq(1)
    end

    it "filters suspended learnings" do
      expect(UserLearning.suspended.count).to eq(1)
    end
  end
end
