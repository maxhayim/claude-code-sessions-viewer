class ClaudeSessionsViewer < Formula
  desc "Visual, fuzzy-searchable browser for every Claude Code session on this machine"
  homepage "https://github.com/maxhayim/claude-code-sessions-viewer"
  url "https://github.com/maxhayim/claude-code-sessions-viewer/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "3e3f73300b57c8fb2c90b580988b1b5714009064361304a77551979b3f87bdc3"
  license "MIT"

  depends_on "fzf"
  depends_on "python@3.12"

  def install
    libexec.install "bin", "plugins"
    bin.install_symlink libexec/"bin/claude-sessions"
  end

  test do
    system "python3", libexec/"plugins/sessions-viewer/scripts/list_sessions.py", "--tsv"
  end
end
