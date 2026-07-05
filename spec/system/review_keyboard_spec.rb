require "rails_helper"

RSpec.describe "Reviewing via keyboard shortcuts", type: :system do
  let(:user) { create(:user) }

  before do
    create(:user_learning, user: user, state: "learning",
           next_due: 1.day.ago, last_interval: 3)
    sign_in_via_browser(user)
  end

  it "renders the summary page after rating the final card with a keyboard shortcut" do
    visit review_path

    expect(page).to have_css("[data-controller~='card-flip']")

    find("body").send_keys(" ")
    expect(page).to have_css("[data-card-flip-target='back']:not(.hidden)")

    find("body").send_keys("3")

    expect(page).to have_content("Session complete")
    expect(page).to have_content("1")
    expect(page).to have_content("cards reviewed")
  end
end
