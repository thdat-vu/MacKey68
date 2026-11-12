cask "mackey68" do
  version "0.6.0"
  sha256 "8e3f63be75c1b121fcd6c584a2aade03880b0a4c9bdfb50b5c8fd69e773f1098"

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
