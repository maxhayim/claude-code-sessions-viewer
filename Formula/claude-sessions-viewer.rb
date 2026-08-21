class ClaudeSessionsViewer < Formula
  desc "Visual, fuzzy-searchable browser for every Claude Code session on this machine"
  homepage "https://github.com/maxhayim/claude-code-sessions-viewer"
  url "https://github.com/maxhayim/claude-code-sessions-viewer/archive/refs/tags/v1.1.6.tar.gz"
  sha256 "1615a1e55ac8b568c137161e29f6f268f1a696cc0aef5aaac5a388b0949ac273"
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
