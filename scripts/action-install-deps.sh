#!/usr/bin/env bash
# Install Playwright Chromium and media tools for the ProofReel composite Action.
# Linux (GitHub-hosted ubuntu-latest): apt packages + playwright --with-deps.
# macOS (self-hosted or GitHub-hosted): auto-install ffmpeg/tesseract with Homebrew when available.
set -euo pipefail

runner_os="${RUNNER_OS:-Linux}"
install_deps="${PROOFREEL_INSTALL_DEPS:-}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

playwright_install() {
  if [[ "$runner_os" == "Linux" ]]; then
    npx --no-install playwright install --with-deps chromium
  else
    npx --no-install playwright install chromium
  fi
}

linux_install() {
  sudo apt-get update -qq
  playwright_install
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ffmpeg tesseract-ocr tesseract-ocr-eng xterm xvfb fonts-dejavu-core
}

post_runner_deps_comment() {
  local missing_csv="$1"
  local action_path="${GITHUB_ACTION_PATH:-}"
  [[ -n "$action_path" ]] || return 0
  export PROOFREEL_MISSING_RUNNER_TOOLS="$missing_csv"
  if [[ -f "$action_path/dist/runner-deps-comment.js" ]]; then
    node "$action_path/dist/runner-deps-comment.js" || echo "::warning::Could not post ProofReel runner setup comment on the pull request."
  elif [[ -f "$action_path/src/action-runner-deps-comment.ts" ]]; then
    npx --yes tsx "$action_path/src/action-runner-deps-comment.ts" || echo "::warning::Could not post ProofReel runner setup comment on the pull request."
  fi
}

fail_macos_missing_tools() {
  local -a missing=("$@")
  local missing_csv="${missing[*]}"
  echo "::error title=ProofReel setup on macOS::Missing required tools on PATH: ${missing_csv}. Install Homebrew (https://brew.sh), then: brew install ffmpeg tesseract"
  post_runner_deps_comment "$missing_csv"
  exit 1
}

brew_install_missing() {
  local -a missing=("$@")
  echo "ProofReel: installing missing macOS media tools via Homebrew (${missing[*]})…"
  local cmd
  for cmd in "${missing[@]}"; do
    brew list "$cmd" >/dev/null 2>&1 || brew install "$cmd"
  done
}

macos_collect_missing() {
  local -a out=()
  local cmd
  for cmd in ffmpeg tesseract; do
    need_cmd "$cmd" || out+=("$cmd")
  done
  if [[ ${#out[@]} -gt 0 ]]; then
    printf '%s\n' "${out[@]}"
  fi
}

macos_install() {
  local -a missing=()
  local line
  while IFS= read -r line; do
    missing+=("$line")
  done < <(macos_collect_missing)

  if [[ ${#missing[@]} -eq 0 ]]; then
    playwright_install
    return
  fi

  if [[ "$install_deps" == "0" || "$install_deps" == "false" ]]; then
    fail_macos_missing_tools "${missing[@]}"
  fi

  if need_cmd brew; then
    brew_install_missing "${missing[@]}"
    missing=()
    while IFS= read -r line; do
      missing+=("$line")
    done < <(macos_collect_missing)
    if [[ ${#missing[@]} -gt 0 ]]; then
      echo "::error::Homebrew install finished but tools are still missing on PATH: ${missing[*]}"
      exit 1
    fi
    playwright_install
    return
  fi

  fail_macos_missing_tools "${missing[@]}"
}

case "$runner_os" in
  Linux) linux_install ;;
  macOS) macos_install ;;
  *)
    echo "::error::ProofReel Action supports Linux and macOS runners (RUNNER_OS=$runner_os)."
    exit 1
    ;;
esac
