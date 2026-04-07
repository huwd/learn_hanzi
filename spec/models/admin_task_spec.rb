require "rails_helper"

RSpec.describe AdminTask, type: :model do
  subject { build(:admin_task) }

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:task_type).in_array(AdminTask::VALID_TASK_TYPES) }
    it { is_expected.to validate_inclusion_of(:state).in_array(AdminTask::VALID_STATES) }
    it { is_expected.to validate_presence_of(:task_type) }
    it { is_expected.to validate_presence_of(:state) }
  end

  describe "state predicate methods" do
    AdminTask::VALID_STATES.each do |s|
      it "responds to #{s}?" do
        task = build(:admin_task, state: s)
        expect(task.public_send(:"#{s}?")).to be true
        other = AdminTask::VALID_STATES.reject { |x| x == s }.first
        expect(build(:admin_task, state: other).public_send(:"#{s}?")).to be false
      end
    end
  end

  describe ".locked_for?" do
    let(:task_type) { "cc_cedict" }

    context "when no task exists" do
      it "returns false" do
        expect(AdminTask.locked_for?(task_type)).to be false
      end
    end

    context "when a pending task exists" do
      before { create(:admin_task, task_type: task_type, state: "pending") }

      it "returns true" do
        expect(AdminTask.locked_for?(task_type)).to be true
      end
    end

    context "when a running task exists" do
      before { create(:admin_task, task_type: task_type, state: "running") }

      it "returns true" do
        expect(AdminTask.locked_for?(task_type)).to be true
      end
    end

    context "when only a completed task exists" do
      before { create(:admin_task, task_type: task_type, state: "complete") }

      it "returns false" do
        expect(AdminTask.locked_for?(task_type)).to be false
      end
    end

    context "when only a failed task exists" do
      before { create(:admin_task, task_type: task_type, state: "failed") }

      it "returns false" do
        expect(AdminTask.locked_for?(task_type)).to be false
      end
    end
  end

  describe ".latest_for" do
    let(:task_type) { "hsk_tags" }

    it "returns the most recently created task of the given type" do
      older = create(:admin_task, task_type: task_type, state: "complete", created_at: 1.hour.ago)
      newer = create(:admin_task, task_type: task_type, state: "failed",   created_at: 1.minute.ago)
      expect(AdminTask.latest_for(task_type)).to eq(newer)
    end

    it "returns nil when no tasks of that type exist" do
      expect(AdminTask.latest_for(task_type)).to be_nil
    end
  end

  describe ".in_progress" do
    it "returns pending and running tasks" do
      pending_task = create(:admin_task, task_type: "cc_cedict",         state: "pending")
      running_task = create(:admin_task, task_type: "hsk_tags",          state: "running")
      create(:admin_task,                task_type: "custom_dictionary",  state: "complete")
      create(:admin_task,                task_type: "cc_cedict",          state: "failed")

      expect(AdminTask.in_progress).to contain_exactly(pending_task, running_task)
    end
  end
end
