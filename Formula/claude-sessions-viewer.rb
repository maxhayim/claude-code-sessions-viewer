class ClaudeSessionsViewer < Formula
  desc "Visual, fuzzy-searchable browser for every Claude Code session on this machine"
  homepage "https://github.com/maxhayim/claude-code-sessions-viewer"
  url "https://github.com/maxhayim/claude-code-sessions-viewer/archive/refs/tags/v1.1.3.tar.gz"
  sha256 "cc5fe8c9b279ed3794c578eedfe6e3c0ddd8a56503ef7bb1c7c5a3febfd9f333"
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
