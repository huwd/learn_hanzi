{ pkgs, lib, ... }:

{
  # Ruby version comes from .ruby-version, resolved to an exact release by
  # nixpkgs-ruby (see devenv.yaml).
  languages.ruby = {
    enable = true;
    versionFile = ./.ruby-version;
  };

  # Headers/tools for gems with native extensions (stackprof, psych, ...)
  # and the runtime tools CI installs with apt (curl, sqlite3, jemalloc).
  packages = with pkgs; [
    curl
    jemalloc
    libyaml
    openssl
    pkg-config
    sqlite
    zlib
  ];

  # Selenium Manager downloads a prebuilt chromedriver, a dynamically linked
  # binary. NixOS runs those through nix-ld, whose default library set lacks
  # what chromedriver needs, so extend it (no-op on other platforms).
  enterShell = ''
    export NIX_LD_LIBRARY_PATH="${lib.makeLibraryPath (with pkgs; [ glib nss nspr libxcb dbus ])}''${NIX_LD_LIBRARY_PATH:+:$NIX_LD_LIBRARY_PATH}"
  '';

  dotenv.disableHint = true;
}
