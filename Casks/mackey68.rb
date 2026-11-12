cask "mackey68" do
  version "0.9.0"
  sha256 "e840b9e933ce6f86429e1c50d660ffa5485530a549006da609c4b8de3bb67a5d"

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
