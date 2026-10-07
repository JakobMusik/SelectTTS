cask "selecttts" do
  version "0.1.0"
  sha256 "f9375cc2e5f48413bb242f2d564e2d9d27bea8db08e4ea2ca073943129a435a1"

  url "https://github.com/JakobMusik/SelectTTS/releases/download/v#{version}/SelectTTS-#{version}.dmg"
  name "SelectTTS"
  desc "Reads selected text aloud with system or bring-your-own-key voices"
  homepage "https://github.com/JakobMusik/SelectTTS"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "SelectTTS.app"

  # SelectTTS is signed with the project's own certificate, not an Apple Developer ID, so
  # Gatekeeper would refuse to open a quarantined copy. macOS still checks the signature itself.
  postflight_steps do
    run "/usr/bin/xattr",
        args:         ["-dr", "com.apple.quarantine", "{{appdir}}/SelectTTS.app"],
        must_succeed: false
  end

  uninstall quit: "com.selecttts.app"

  zap trash: [
    "~/Library/Caches/com.selecttts.app",
    "~/Library/HTTPStorages/com.selecttts.app",
    "~/Library/Preferences/com.selecttts.app.plist",
  ]

  caveats <<~EOS
    SelectTTS reads your selection through the Accessibility API. Allow it in
      System Settings > Privacy & Security > Accessibility
    then relaunch SelectTTS.
  EOS
end
