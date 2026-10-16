module RealOidcHelpers
  def sign_in_via_real_oidc
    visit sign_in_path
    click_until(find_button("Sign in with PocketID")) { |wait| page.has_field?("username", wait: wait) }
    fill_until("username", with: "test-user")
    fill_until("password", with: "test-password")
    click_until(find_button("Sign In")) { |wait| page.has_link?("Review", wait: wait) }

    # The stub redirects back through a separate server (a real cross-origin
    # hop, unlike the single-process OmniAuth-mocked flow sign_in_via_browser
    # uses), so wait for a definitely-authenticated marker before returning —
    # otherwise callers can race the final callback -> dashboard redirect and
    # query the DB before the write has landed.
    expect(page).to have_link("Review")
  end

  # Native (Selenium) input is intermittently dropped in this tier: the
  # driver reports success but the page receives no pointer or key events
  # at all, so a click or keystrokes never take effect (the page itself is
  # rendering, focused and visible). It happens at random points in the
  # sign-in/sign-out flow, and repeating the native click does not help.
  # In-page actions always land, so act natively first and fall back to
  # one if the expected result does not appear. For click_until that is the
  # block, given a wait in seconds.
  def click_until(element, wait: 2, &landed)
    element.click
    return if landed.call(wait)

    page.execute_script("arguments[0].click()", element)
  end

  # fill_in, verified: if the typed text did not land, set the value in-page.
  def fill_until(locator, with:)
    field = find_field(locator)
    field.set(with)
    return if field.value == with

    page.execute_script(<<~JS, field, with)
      arguments[0].value = arguments[1];
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }));
    JS
  end
end
