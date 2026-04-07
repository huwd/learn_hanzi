require "rails_helper"

RSpec.describe "Admin::Tasks", type: :request do
  let(:user)       { create(:user) }
  let(:admin_user) { create(:user, admin: true) }

  describe "POST /admin/tasks" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        post admin_tasks_path, params: { task_type: "cc_cedict" }
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated as a non-admin" do
      before { sign_in user }

      it "redirects to root" do
        post admin_tasks_path, params: { task_type: "cc_cedict" }
        expect(response).to redirect_to(root_path)
      end
    end

    context "when authenticated as an admin" do
      before do
        sign_in admin_user
        allow(Admin::ProvisioningJob).to receive(:perform_later)
      end

      it "creates an AdminTask record" do
        expect {
          post admin_tasks_path, params: { task_type: "cc_cedict" }
        }.to change { AdminTask.count }.by(1)
      end

      it "enqueues the provisioning job" do
        expect(Admin::ProvisioningJob).to receive(:perform_later)
        post admin_tasks_path, params: { task_type: "cc_cedict" }
      end

      it "redirects to admin root" do
        post admin_tasks_path, params: { task_type: "cc_cedict" }
        expect(response).to redirect_to(admin_root_path)
      end

      context "when task_type is not in the allowlist" do
        it "does not create a task" do
          expect {
            post admin_tasks_path, params: { task_type: "drop_database" }
          }.not_to change { AdminTask.count }
        end

        it "redirects with an alert" do
          post admin_tasks_path, params: { task_type: "drop_database" }
          follow_redirect!
          expect(response.body).to include("Unknown task type")
        end
      end

      context "when the task type is already locked" do
        before { create(:admin_task, task_type: "cc_cedict", state: "running") }

        it "does not create a second task" do
          expect {
            post admin_tasks_path, params: { task_type: "cc_cedict" }
          }.not_to change { AdminTask.count }
        end

        it "does not enqueue a job" do
          expect(Admin::ProvisioningJob).not_to receive(:perform_later)
          post admin_tasks_path, params: { task_type: "cc_cedict" }
        end

        it "redirects with an alert" do
          post admin_tasks_path, params: { task_type: "cc_cedict" }
          expect(response).to redirect_to(admin_root_path)
          follow_redirect!
          expect(response.body).to include("already running")
        end
      end
    end
  end

  describe "POST /admin/tasks/:id/retry" do
    context "when authenticated as an admin" do
      before do
        sign_in admin_user
        allow(Admin::ProvisioningJob).to receive(:perform_later)
      end

      context "when the task is failed" do
        let!(:failed_task) do
          create(:admin_task, task_type: "cc_cedict", state: "failed",
                 error_message: "something went wrong", summary: '{"entries_before":0}')
        end

        it "resets the task to pending" do
          post retry_admin_task_path(failed_task)
          expect(failed_task.reload.state).to eq("pending")
        end

        it "clears error_message, summary, and timestamps" do
          post retry_admin_task_path(failed_task)
          task = failed_task.reload
          expect(task.error_message).to be_nil
          expect(task.summary).to be_nil
          expect(task.started_at).to be_nil
          expect(task.completed_at).to be_nil
        end

        it "enqueues the provisioning job" do
          expect(Admin::ProvisioningJob).to receive(:perform_later).with(failed_task.id)
          post retry_admin_task_path(failed_task)
        end

        it "redirects to admin root" do
          post retry_admin_task_path(failed_task)
          expect(response).to redirect_to(admin_root_path)
        end
      end

      context "when another task of the same type becomes active before retry" do
        let!(:failed_task) { create(:admin_task, task_type: "hsk_tags", state: "failed") }

        before do
          allow(Admin::ProvisioningJob).to receive(:perform_later)
          create(:admin_task, task_type: "hsk_tags", state: "pending")
        end

        it "redirects with an alert" do
          post retry_admin_task_path(failed_task)
          follow_redirect!
          expect(response.body).to include("already running or pending")
        end
      end

      context "when the task is not failed" do
        let!(:running_task) { create(:admin_task, task_type: "cc_cedict", state: "running") }

        it "does not re-enqueue" do
          expect(Admin::ProvisioningJob).not_to receive(:perform_later)
          post retry_admin_task_path(running_task)
        end

        it "redirects with an alert" do
          post retry_admin_task_path(running_task)
          follow_redirect!
          expect(response.body).to include("Only failed")
        end
      end
    end
  end
end
