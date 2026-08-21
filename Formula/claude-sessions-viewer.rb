class ClaudeSessionsViewer < Formula
  desc "Visual, fuzzy-searchable browser for every Claude Code session on this machine"
  homepage "https://github.com/maxhayim/claude-code-sessions-viewer"
  url "https://github.com/maxhayim/claude-code-sessions-viewer/archive/refs/tags/v1.1.1.tar.gz"
  sha256 "5aeb23791055abcf34684ddf72e9f1c285c004f18cafc8102964dde5a14c42db"
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
