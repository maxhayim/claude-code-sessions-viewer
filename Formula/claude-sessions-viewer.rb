class ClaudeSessionsViewer < Formula
  desc "Visual, fuzzy-searchable browser for every Claude Code session on this machine"
  homepage "https://github.com/maxhayim/claude-code-sessions-viewer"
  url "https://github.com/maxhayim/claude-code-sessions-viewer/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "caf94a7f8eb74f96baa8079b5e13e00eda953c52832f35e701b0f0390fd274e2"
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
