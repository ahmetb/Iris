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

  zap trash: [
    "~/Library/Preferences/com.iris.app.plist",
  ]
end
