cask "mackey68" do
  version "0.12.1"
  sha256 "5c2472090dd7e0923e9b86b320e4bde5657119fd5594c9b0fcd6085a96cfa260"

  url "https://github.com/thdat-vu/MacKey68/releases/download/v#{version}/MacKey68-#{version}.dmg"
  name "MacKey68"
  desc "Menu-bar keyboard remapper with per-app profiles"
  homepage "https://github.com/thdat-vu/MacKey68"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "MacKey68.app"

  zap trash: [
    "~/.config/mackey",
    "~/Library/LaunchAgents/com.mackey68.app.plist",
    "~/Library/Logs/MacKey68.log",
  ]
end
