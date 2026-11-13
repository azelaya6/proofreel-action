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

playwright_browsers() {
  local raw="${PROOFREEL_PLAYWRIGHT_BROWSERS:-chromium}"
  local IFS=,
  local -a browsers=()
  for part in $raw; do
    part="${part//[[:space:]]/}"
    if [[ "$part" == "chromium" || "$part" == "webkit" ]]; then
      browsers+=("$part")
    fi
  done
  if [[ ${#browsers[@]} -eq 0 ]]; then
    browsers=(chromium)
  fi
  browsers+=(ffmpeg)
  printf '%s\n' "${browsers[@]}"
}

playwright_install() {
  local -a browsers=()
  while IFS= read -r browser; do
    browsers+=("$browser")
  done < <(playwright_browsers | sort -u)
  if [[ "$runner_os" == "Linux" ]]; then
    npx --no-install playwright install --with-deps "${browsers[@]}"
  else
    npx --no-install playwright install "${browsers[@]}"
  fi
}

ensure_tesseract_spa() {
  if need_cmd tesseract && tesseract --list-langs 2>/dev/null | grep -qx spa; then
    return 0
  fi
  if [[ "$runner_os" == "Linux" ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tesseract-ocr-spa \
      || echo "::warning::Could not install tesseract-ocr-spa; Spanish OCR falls back to English only."
    return 0
  fi
  if [[ "$runner_os" == "macOS" ]] && need_cmd brew; then
    brew install tesseract-lang 2>/dev/null \
      || echo "::warning::Could not install tesseract-lang; Spanish OCR falls back to English only."
  fi
}

linux_install() {
  sudo apt-get update -qq
  playwright_install
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ffmpeg tesseract-ocr tesseract-ocr-eng xterm xvfb fonts-dejavu-core
  ensure_tesseract_spa
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
  if [[ -n "${PROOFREEL_TEST_FORCE_MISSING_TOOLS:-}" ]]; then
    local item
    local IFS=,
    for item in $PROOFREEL_TEST_FORCE_MISSING_TOOLS; do
      [[ -n "$item" ]] && out+=("$item")
    done
    if [[ ${#out[@]} -gt 0 ]]; then
      printf '%s\n' "${out[@]}"
    fi
    return
  fi
  local cmd
  for cmd in ffmpeg tesseract; do
    need_cmd "$cmd" || out+=("$cmd")
  done
  if [[ ${#out[@]} -gt 0 ]]; then
    printf '%s\n' "${out[@]}"
  fi
}

ensure_macos_ffmpeg_drawtext() {
  if need_cmd ffmpeg && ffmpeg -hide_banner -filters 2>/dev/null | grep -q ' drawtext '; then
    return 0
  fi
  if ! need_cmd brew; then
    return 0
  fi
  echo "ProofReel: ffmpeg on PATH lacks drawtext; installing ffmpeg-full via Homebrew…"
  brew list ffmpeg-full &>/dev/null || brew install ffmpeg-full
  local prefix
  prefix="$(brew --prefix ffmpeg-full)"
  export PATH="${prefix}/bin:${PATH}"
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "PATH=${prefix}/bin:${PATH}" >> "$GITHUB_ENV"
  fi
}

macos_install() {
  local -a missing=()
  local line
  while IFS= read -r line; do
    missing+=("$line")
  done < <(macos_collect_missing)

  if [[ ${#missing[@]} -eq 0 ]]; then
    ensure_macos_ffmpeg_drawtext
    ensure_tesseract_spa
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
    ensure_macos_ffmpeg_drawtext
    ensure_tesseract_spa
    if need_cmd ffmpeg && ! ffmpeg -hide_banner -filters 2>/dev/null | grep -q ' drawtext '; then
      echo "::error::ffmpeg on PATH does not include drawtext. On macOS run: brew install ffmpeg-full"
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
