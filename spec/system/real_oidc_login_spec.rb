require "rails_helper"

RSpec.describe "Signing in via the real OIDC stub", type: :system, real_oidc: true do
  # Not using `expect { }.to change(User, :count)` here: the browser-driven
  # request runs on a different DB connection than this example's assertions
  # (the well-known system-spec-plus-transactional-fixtures split), so a
  # `count` query run both before and after can read a connection-local
  # query-cache hit from the "before" snapshot instead of the real post-write
  # value. A single fresh query after the fact doesn't have that problem.
  it "completes the real discovery -> redirect -> login -> callback flow" do
    sign_in_via_real_oidc

    user = User.find_by(provider: "oidc", uid: "test-user")
    expect(user).to be_present
    expect(user.email_address).to eq("oidc-stub@learn-hanzi.test")
  end

  it "reuses the same user on a second login rather than creating a duplicate" do
    sign_in_via_real_oidc
    # Drop the browser session's cookies rather than driving the Sign out UI:
    # this example is about the second OIDC login reusing the user, and
    # reset_sessions! is synchronous, so the next sign-in can't race an
    # in-flight sign-out request.
    Capybara.reset_sessions!
    sign_in_via_real_oidc

    expect(User.where(provider: "oidc", uid: "test-user").count).to eq(1)
  end
end
