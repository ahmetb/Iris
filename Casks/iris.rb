cask "iris" do
  version "0.3.1"
  sha256 "40410df661175ced0e362b624fa487f3a9dddbc8916d9df272d4ca0d922528d8"

  url "https://github.com/ahmetb/Iris/releases/download/v#{version}/Iris-v#{version}.zip"
  name "Iris"
  desc "Floating webcam viewing window (a hand mirror)"
  homepage "https://github.com/ahmetb/Iris"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true

  app "Iris.app"

  caveats <<~EOS
    Iris is not signed with an Apple Developer certificate.
    macOS will show a warning about an unsigned application on first launch.

    To allow Iris to run:
      1. Right-click (or Control-click) on Iris.app and select "Open"
      2. Click "Open" in the security dialog
      3. If that doesn't work, go to System Settings > Privacy & Security
         and look for an option to allow Iris under the "Security" section
  EOS

  zap trash: [
    "~/Library/Preferences/com.iris.app.plist",
  ]
end
