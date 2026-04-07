require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  let(:user)       { create(:user) }
  let(:admin_user) { create(:user, admin: true) }

  describe "GET /admin" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        get admin_root_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated as a non-admin" do
      before { sign_in user }

      it "redirects to root with an alert" do
        get admin_root_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when authenticated as an admin" do
      before { sign_in admin_user }

      it "returns 200" do
        get admin_root_path
        expect(response).to have_http_status(:ok)
      end

      it "shows the provisioning dashboard" do
        get admin_root_path
        expect(response.body).to include("CC-CEDICT")
        expect(response.body).to include("HSK")
      end

      it "shows task history" do
        create(:admin_task, task_type: "cc_cedict", state: "complete",
               created_at: 1.hour.ago)
        get admin_root_path
        expect(response.body).to include("complete")
      end

      it "includes a meta refresh when a task is in progress" do
        create(:admin_task, task_type: "cc_cedict", state: "running")
        get admin_root_path
        expect(response.body).to include("http-equiv=\"refresh\"")
      end

      it "does not include a meta refresh when no tasks are in progress" do
        create(:admin_task, task_type: "cc_cedict", state: "complete")
        get admin_root_path
        expect(response.body).not_to include("http-equiv=\"refresh\"")
      end
    end
  end

  describe "POST /admin/provision_all" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        post admin_provision_all_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated as a non-admin" do
      before { sign_in user }

      it "redirects to root" do
        post admin_provision_all_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when authenticated as an admin" do
      before do
        sign_in admin_user
        allow(Admin::ProvisioningJob).to receive(:perform_later)
      end

      it "enqueues a job for each unlocked task type" do
        expect(Admin::ProvisioningJob).to receive(:perform_later).exactly(3).times
        post admin_provision_all_path
      end

      it "does not enqueue a job for a locked task type" do
        create(:admin_task, task_type: "cc_cedict", state: "running")
        expect(Admin::ProvisioningJob).to receive(:perform_later).twice
        post admin_provision_all_path
      end

      it "redirects to admin root" do
        post admin_provision_all_path
        expect(response).to redirect_to(admin_root_path)
      end
    end
  end
end
