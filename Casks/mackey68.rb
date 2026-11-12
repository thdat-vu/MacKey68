cask "mackey68" do
  version "0.8.0"
  sha256 "334182ca2c4a2b46a623acaad256ff64fea2dcfa6cd8b36da0f2ed3a0b1fbd75"

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
