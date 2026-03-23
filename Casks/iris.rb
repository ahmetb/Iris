cask "iris" do
  version "0.1.5"
  sha256 "10b15cbc08bb40b743cbbd82beb91f2be9769264d2c88899675e8e9b02e98fe6"

  url "https://github.com/ahmetb/Iris/releases/download/v#{version}/Iris-v#{version}.zip"
  name "Iris"
  desc "Floating webcam viewing window (a hand mirror)"
  homepage "https://github.com/ahmetb/Iris"

  livecheck do
    url :url
    strategy :github_latest
  end

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
