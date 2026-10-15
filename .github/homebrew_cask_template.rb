cask "funclash" do
  version "VERSION"

  on_macos do
    arch arm: "arm64", intel: "amd64"

    sha256 arm:   "ARM_SHA256",
           intel: "AMD_SHA256"

    url "https://github.com/farfarfun/funclash/releases/download/v#{version}/FunClash-#{version}-macos-#{arch}.dmg"
  end

  name "FunClash"
  desc "Multi-platform proxy client based on ClashMeta"
  homepage "https://github.com/farfarfun/funclash"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  app "FunClash.app"

  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-rd", "com.apple.quarantine", "{{appdir}}/FunClash.app"],
        writable_paths: ["FunClash.app"],
        writable_base:  :appdir
  end

  uninstall quit: "com.farfarfun.funclash"

  zap trash: [
    "~/Library/Application Support/com.farfarfun.funclash",
    "~/Library/Caches/com.farfarfun.funclash",
    "~/Library/Preferences/com.farfarfun.funclash.plist",
    "~/Library/Saved Application State/com.farfarfun.funclash.savedState",
  ]
end
