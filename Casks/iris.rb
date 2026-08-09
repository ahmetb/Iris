cask "iris" do
  version "0.3.0"
  sha256 "f3aa924ac2b447f1dc88a648b75cd16a460ca733bdbdd32c79a7705a13f4791a"

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
