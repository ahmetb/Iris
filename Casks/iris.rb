cask "iris" do
  version "0.1.4"
  sha256 "823d0e8fc8e167c84f4c3395fd4496d2bef962e54897ffbdd59a584cc7d85d4b"

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
