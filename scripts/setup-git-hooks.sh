#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chmod +x "$ROOT/.githooks/commit-msg"
git -C "$ROOT" config core.hooksPath .githooks
echo "Git hooks enabled (core.hooksPath=.githooks)"
