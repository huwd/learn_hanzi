module RealOidcHelpers
  def sign_in_via_real_oidc
    visit sign_in_path
    click_button "Sign in with PocketID"
    fill_in "username", with: "test-user"
    fill_in "password", with: "test-password"
    click_button "Sign In"

    # The stub redirects back through a separate server (a real cross-origin
    # hop, unlike the single-process OmniAuth-mocked flow sign_in_via_browser
    # uses), so wait for a definitely-authenticated marker before returning —
    # otherwise callers can race the final callback -> dashboard redirect and
    # query the DB before the write has landed.
    expect(page).to have_link("Review")
  end
end
