cask "mackey68" do
  version "0.5.1"
  sha256 "4ed98bf5c5d4fa07929a951d721eb3f58edc919dbd7ded1c5cd46d2530c46b78"

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
