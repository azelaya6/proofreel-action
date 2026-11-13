# ProofReel Action

ProofReel records short, verified MP4 videos that prove each feature in a pull request works, and posts them to the PR as a **Video proof** comment with a player page.

- **Public repositories:** free. Videos are watermarked, with up to 3 claims per spec.
- **Private repositories:** **3 free video proofs** per repository (watermarked, same limits as public), then **ProofReel Pro** — **$9.99/month per repository**, or **ProofReel Pro Org at $69.99/month** for every private repo in a GitHub organization. Pro has no watermark, unlimited proofs and claims, and two-context recordings.

Website: https://proofreel.dev · Support: support@proofreel.dev

This repository publishes the prebuilt GitHub Action and CLI. Development happens in the private ProofReel product repo; maintainers cut releases here. For bugs or feature requests, please [open an issue](https://github.com/azelaya6/proofreel-action/issues) rather than an unfinished pull request.

## GitHub Marketplace

Browse and install from **[ProofReel on GitHub Marketplace](https://github.com/marketplace/actions/proofreel)** (once the maintainer has published the first GitHub Release with Marketplace enabled). **Install it** adds the workflow snippet to your repository.

You can also reference the Action directly — no Marketplace install required:

```yaml
- uses: azelaya6/proofreel-action@v1
```

Install the [ProofReel GitHub App](https://github.com/apps/proofreel/installations/new) on the repositories where you want PR video proofs.

## Quick start

1. **Install the GitHub App** on the repositories you want proofs for: https://github.com/apps/proofreel/installations/new
2. **Private repositories:** the first 3 proofs are free. To keep recording after that (or to drop the watermark), subscribe to Pro:
   - **One repository** ($9.99/month): open this link, replace `OWNER/REPO`, and complete checkout:
     `https://api.proofreel.dev/billing/checkout?scopeKind=repo&scopeId=OWNER/REPO`
   - **Whole GitHub organization** ($69.99/month, every private repo under the org): org admin required; App installed on the org:
     `https://api.proofreel.dev/billing/checkout?scopeKind=org&scopeId=ORG`
3. **Add a spec.** Put `proofreel.yml` at the repository root, or one `.proofreel/<slug>.yml` per feature, in the branch you open the PR from. See [Configure ProofReel](#configure-proofreel). With **no spec at all**, the job stays green and the **Video proof** check is **neutral** (not proof) while the PR comment explains how to start. With **PR coverage** (`change-only` / `change-plus-regression`), a spec this PR adds or edits must validate: the job **fails**, names every file and field error, and never shows green proof without an MP4. Other invalid specs you did not touch are ignored in change-only mode. Failed frame checks also turn the check red.
4. **Add the workflow** below as `.github/workflows/proofreel.yml`.
5. **Open a pull request.** The Action records each claim and checks the key frames, then the ProofReel app comments on the PR with the videos.

### Workflow (copy-paste)

```yaml
name: ProofReel

on:
  pull_request:

permissions:
  id-token: write       # lets the Action prove which repo it runs in (OIDC); no secrets needed. Also signs error telemetry reports (see Error telemetry)
  contents: read
  pull-requests: write  # only used for the fallback comment if the app is not installed

jobs:
  video-proof:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Install your app's dependencies so the spec's `pre` command can start it.
      # Static site with no package.json? Delete the setup-node and npm ci steps.
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
      - run: npm ci

      - uses: azelaya6/proofreel-action@v1
```

`service-url` defaults to `https://api.proofreel.dev`, so you don't have to set it.

## Configure ProofReel

ProofReel reads its config from the branch the pull request comes from. There are two places, and both use the same spec format:

| File | Use it for |
| --- | --- |
| `proofreel.yml` at the repository root | The main config: one spec for the whole repo. |
| `.proofreel/<slug>.yml` | Per-feature config: one spec per feature or PR. Any number of files. |

With no `spec` input the Action records every spec it finds (`proofreel.yml` plus each `.proofreel/*.yml` / `.yaml`). Set `spec: <slug>` for one spec, `spec: slug-a,slug-b` for several, or `spec: auto` to record specs when the pull request touches a path listed in that spec's **`paths:`** globs (or edits that spec's file under `.proofreel/`). Specs without `paths:` are not selected by globs alone.

**PR coverage (recommended):** add `.proofreel/project.yml` so pull requests only record proof that belongs to the diff, with optional explicit regression specs. Coverage does not apply on `schedule` / `push` unless you set the `coverage` input — so a scheduled workflow can still use `spec: ""` for the full suite. See [PR coverage](#pr-coverage).

Without PR coverage, when `auto` matches nothing, ProofReel records specs you edited under `.proofreel/`, then specs marked `always: true`, otherwise it passes without recording (legacy behavior). Run a full suite on a schedule with an empty `spec` input instead of on every push.

### Main config file

`proofreel.yml` at the repository root. The smallest useful spec:

```yaml
version: 1
name: Counter
slug: counter
baseUrl: http://127.0.0.1:4173
pre:
  - npm run build && npm run preview -- --port 4173
claims:
  - id: increment
    caption: Clicking +1 increments the counter
    recorder: browser
    steps:
      - goto: /
      - wait: "[data-testid=count]"
      - click: "[data-testid=increment]"
      - wait:
          locator: "[data-testid=count]"
          text: "Count: 1"
      - mark: after
    expect:
      text: "Count: 1"
      at: after
```

Required: `version: 1`, `name`, `slug`, and `claims` with at least one claim. Every claim needs `id`, `caption`, `recorder` (`browser` or `terminal`) and at least one step. All fields: [Spec reference](#spec-reference).

### Per-feature config

Each feature is a **claim** (one video). Put the claims for one feature in their own file, `.proofreel/<slug>.yml`. A per-feature file is a complete spec with the same fields as `proofreel.yml` (`version`, `name`, `slug`, `claims`, and `baseUrl`/`pre` for browser claims); there is no partial or inherited config. Output goes to `docs/videos/<slug>/`.

```yaml
# .proofreel/checkout.yml
version: 1
name: Checkout
slug: checkout
baseUrl: http://127.0.0.1:4173
pre:
  - npm run build && npm run preview -- --port 4173
claims:
  - id: add-to-cart
    caption: Adding an item shows it in the cart
    recorder: browser
    steps:
      - goto: /products/1
      - click: "[data-testid=add-to-cart]"
      - wait:
          locator: "[data-testid=cart-count]"
          text: "1"
      - mark: after
    expect:
      text: "1 item"
      at: after
  - id: cli-version
    caption: The CLI prints its version
    recorder: terminal
    steps:
      - run: node cli.js --version
      - pause: 1500
    expect:
      text: "1.0.0"
```

On the free plan a spec records up to 3 claims; Pro has no claim limit.

### Setup errors and the Video proof check

If there is **no ProofReel config** in the branch, nothing is recorded or charged, the job exits 0, the **Video proof** check is **neutral** (`action_required`), and the PR comment has copy-paste setup steps — that is onboarding, not proof.

With **PR coverage**, a spec **this PR changed** that fails validation makes the job **fail** (`exit 1`) and the check **red**, listing each file and field (for example `mark` and `expect.at` must be `before`, `action`, or `after`). Green proof without a video is never shown.

When valid specs **were** selected but nothing was stored (for example `baseUrl` never came up`), the **Video proof** check is **not green** by default (`on-setup-needed: fail`). Use `on-setup-needed: pass` to restore legacy behaviour. The job still posts one PR comment with copy-paste instructions:

| Problem | What the comment shows |
| --- | --- |
| No `proofreel.yml` and no `.proofreel/*.yml` | Where the main config goes, a minimal `proofreel.yml`, and the per-feature format. |
| Invalid YAML, or a field with the wrong value | Each file and field path, for example `.proofreel/checkout.yml` → `claims[0].recorder`: must be one of 'browser', 'terminal' (got "web"), then the per-feature format. |
| A spec with no claims | The file, and an example `claims:` list. |
| The `spec` input names a spec that doesn't exist | The specs that do exist. |
| The app never answers at `baseUrl` | How `pre`, `baseUrl` and `preTimeoutMs` work. |

The comment comes from the ProofReel app; if the app isn't installed, the Action posts it with the workflow token (`pull-requests: write`). An internal ProofReel error (a crash in ProofReel itself, or the service being unreachable) is handled the same way: warning, exit 0, a green check and a comment saying it was not your config. Run `proofreel verify` locally to see the same errors; the CLI still exits non-zero.

### When the check is red

Failed frame checks turn the **Video proof** check red and fail the job: OCR didn't find the expected text, a key frame shows a disallowed error pattern (terminal recordings by default), a key frame was black or blank, a key-like secret was visible, the video is older than the files it covers, or a claim has no video. Invalid specs the PR changed under PR coverage, recorder failures with no MP4, and internal ProofReel errors also fail the job. The PR comment says exactly what was missing.

A red check only blocks merging if you make **Video proof** a required check in branch protection.

## Starting the app under test

ProofReel opens `baseUrl` in a headless Chromium. Something has to serve it. You have two options:

- **Recommended: `pre` in the spec.** ProofReel starts each `pre` command in the background from the repository root, waits until `baseUrl` answers any HTTP request, records, then stops the commands. The wait is `preTimeoutMs` (default 120000). If every `pre` command exits before the URL answers, or the timeout passes, nothing is recorded and the PR comment explains how to fix `pre` and `baseUrl` (the job stays green). Logs go to `.proofreel/tmp/pre/<slug>-N.log`.
- **An earlier workflow step.** Start the server in the background before `uses: azelaya6/proofreel-action@v1`, for example `nohup npm run preview &`. If `baseUrl` already answers, ProofReel skips `pre`.

A static site can use `pre: ["python3 -m http.server 8080 --bind 127.0.0.1"]` with `baseUrl: http://127.0.0.1:8080`.

Record against seeded or fixture data only, never production. The verifier fails the frame check if a key-like secret is visible in a frame, and the PR comment says so.

## Spec reference

Specs live in `proofreel.yml` at the repository root or in `.proofreel/<slug>.yml` (see [Configure ProofReel](#configure-proofreel)). With no `spec` input, the Action records every spec it finds. See [Setup errors and the Video proof check](#setup-errors-and-the-video-proof-check) for missing config, neutral checks, and change-only validation.

**Top-level fields**

| Field | Required | Meaning |
| --- | --- | --- |
| `version` | yes | Always `1`. |
| `name` | yes | Human name shown in the comment. |
| `slug` | yes | Folder name for output: `docs/videos/<slug>/`. |
| `title` | no | Heading for the proof section. |
| `baseUrl` | browser claims | Base for every `goto`, and the URL `pre` waits for. |
| `pre` | no | Commands started in the background before recording (see above). |
| `preTimeoutMs` | no | How long to wait for `baseUrl` after starting `pre`. Default 120000. |
| `defaults.device` | no | `desktop` (default), `iphone-14`, `pixel-7`, `ipad`. |
| `defaults.pauseMs` | no | Pause after every step, so viewers can follow. |
| `defaults.recorder` | no | `browser` or `terminal`. |
| `seed.description`, `seed.files` | no | Documents the fixture data a recording relies on. |
| `paths` | no | Repo-relative globs. With `spec: auto`, the Action records this spec when the PR touches any matching path (or this spec file). |
| `always` | no | With `spec: auto`, record this spec when nothing else matched (smoke set). |
| `claims` | yes | One or more claims, one video each. |
| `notProven` | no | Things a headless recording can't prove. They're listed in the comment. |
| `honesty` | no | A sentence shown under the videos. |

**Claim fields**

| Field | Meaning |
| --- | --- |
| `id` | Unique id within the spec. |
| `caption` | Text overlaid on the video and listed in the comment. |
| `recorder` | `browser` (Playwright) or `terminal` (xterm). |
| `device` | Overrides `defaults.device`. |
| `steps` | The actions to perform (below). |
| `expect.text` | Text that OCR must find in the key frame. |
| `expect.locator` | A selector that must be visible at the end of the recording. |
| `expect.nth` | Which match of `expect.locator` to check (default first). |
| `expect.count`, `expect.min`, `expect.max` | Assert how many elements match `expect.locator` (exact `count` cannot mix with `min`/`max`). |
| `expect.at` | Which key frame to check: `before`, `action`, or `after` (default `after`). |
| `sourceGlobs` | Files the claim covers. Their hash is stored so `verify` can flag stale videos. |
| `contexts` | Pro: two side-by-side browser contexts (`name`, `role: left/right`, `device`, `storageState`). Steps choose one with `context:`. |
| `cwd`, `cols`, `rows` | Terminal claims: working directory and terminal size. |

**Steps (browser):** `goto: /path`, `click: <selector>` (or `{locator, text?, nth?}`), `fill: {locator, text}`, `type: {locator, text}` (types each key), `press: Enter` (optional `locator`), `hover: <selector>`, `wait: <selector>` or `wait: {locator, text, url, timeoutMs}`, `scroll: <selector>` or `scroll: {locator?, nth?, y?, hold?}` (scroll into view or wheel by pixels), `tour: {locator, hold?}` (reveal every match on camera), `assert: {text, locator, nth?, count?, min?, max?}`, `pause: <ms>` (max 12000), `mark: before|action|after`.

**Prove every item you claim.** If the caption says "six images" or "three errors", do not rely on a single always-visible word for OCR. Assert the count (`assert: { locator, count: 6 }`), use `nth` on locators when you need a specific row, `scroll` or `tour` so each item appears in the video, and put `expect.text` on copy that only shows when the claim is true (for example the last panel's label). See `docs/how-to/prove-every-claimed-item.md` in the main repo.

`wait.url` accepts an absolute `http(s)` URL, a Playwright glob (`**/dashboard`), or a **path-only / relative** value such as `/dashboard`. Path-only values resolve against the claim/spec `baseUrl` origin and match that pathname (query/hash ignored), so `wait: { url: /dashboard }` succeeds after navigation to `{baseUrl}/dashboard`.

**Steps (terminal):** `run: <command>` (optional `expectFail: true` when the step must show a failure on camera), `env: {KEY: value}`, `pause: <ms>`, `mark: ...`. Use `set -e` or `&&` in demo scripts so success markers print only after every step succeeds. Optional claim fields: `allowErrors` (patterns that may appear), `errorGuard: false` to disable the default terminal error guard (browser: set `errorGuard: true` to fail on page errors or visible error text).

If you don't add `mark` steps, the key frames are set automatically: `before` after the first `goto`, `action` at the first click or fill, and `after` at the end.

## What happens when...

| Situation | Result |
| --- | --- |
| App installed, public repo | Free plan: watermarked videos, up to 3 claims per spec. The app posts or updates one **Video proof** comment, linking `https://api.proofreel.dev/proof/OWNER/REPO/PR`. |
| App installed, private repo with Pro | Same, without the watermark or claim limit. |
| Private repo **without** Pro, free proofs left | Works like the public free plan (watermarked). The comment and the **Video proof** check say "Free proof 2 of 3" with a checkout link. One successful run counts once, however many clips; failed runs and re-runs of the same commit are not charged. |
| Pro or public repo, frame checks fail | The video is hosted as usual. The **Video proof** check is red and the job fails (Action 1.1.7+); the PR comment says "Frame check failed" with what was missing, and the check title says "frame check failed". |
| Private repo **without** Pro, frame checks fail | Not charged. The **Video proof** check is red and the job fails. The comment, proof page and check say "Frame check failed — not counted". The watermarked video is hosted for 7 days so you can see what went wrong (the comment shows when it expires), for up to 10 failed runs per repository each calendar month (UTC). Past that, the video is only in the workflow run's artifacts and the comment says so. Fix the claim and push again. |
| Private repo **without** Pro, 3 free proofs used | Nothing is recorded, hosted or charged, and nothing turns red: the job stays green with a warning, the **Video proof** check is green ("Video proof · ProofReel Pro required"), and the PR comment asks you to subscribe with the checkout link. Subscribing unblocks the next run immediately. (Action versions before 1.1.3 failed the job here.) |
| App **not** installed | Videos still upload and the proof page works. The app can't comment, so the Action posts the comment itself with the workflow token (needs `pull-requests: write`). It warns you to install the app. |
| No `id-token: write` permission | Public repos (Action 1.1.8+): no service session, so no recording pass and nothing is recorded; the job stays green with a "ProofReel setup needed" comment that shows the `permissions:` block to add. Private repos: nothing is recorded; the job stays green with a "ProofReel Pro required" warning and the Action comments with the workflow token (the service tracks private free proofs). |
| `service-url: ""` | Same as above: without the hosted service there is no recording pass, so nothing is recorded (green job, setup comment). |
| `service-url` pointing at a self-hosted service | Sessions work, but only passes signed by `https://api.proofreel.dev` are trusted, so nothing is recorded. |
| No spec in the branch, an invalid spec, or a spec with no claims | Nothing is recorded or charged. The job stays green with a warning, the **Video proof** check is green ("Video proof · ProofReel setup needed"), and the PR comment has copy-paste setup instructions for the exact problem. (Action versions before 1.1.4 failed the job here.) |
| ProofReel itself crashes, or the service is down | Same: warning, exit 0, green check, and a comment saying it was an internal error. |
| Free plan records 3 claims and skips the rest | Green (if the 3 recorded claims pass). The comment lists the skipped claims under "Skipped" with the Pro link; a skipped claim is not a frame-check failure. |

Videos are always uploaded as the `proofreel-videos` workflow artifact too.

**Tip:** On pull requests use `spec: auto` with PR coverage so only affected specs (plus any regression list you choose) record. Add a second workflow on `schedule` or `workflow_dispatch` with `spec: ""` to re-prove the full suite without queueing every spec on each push.

## PR coverage

Use **`.proofreel/project.yml`** for the repository default and the Action **`coverage`** / **`regression`** inputs for a one-off override on a single workflow run.

| Mode | Records | Change vs regression in the PR comment |
| --- | --- | --- |
| `change-only` | Specs whose `paths:` (or spec file) match the PR diff only | No `always: true` smoke; if nothing matches, the run passes with a clear **no change-specific proof** notice |
| `change-plus-regression` | Change-associated specs **plus** an explicit regression slug list | Regression clips are labeled separately and do **not** count as proof of the current diff |
| `all` | Every spec | Specs tied to the PR diff appear under **Change evidence**; everything else under **Regression checks** |

Each section is tied to **PR HEAD** (`pull_request.head.sha`). Passing regression specs never imply the current change is proven.

**Repository default** (`.proofreel/project.yml`):

```yaml
version: 1
prCoverage:
  mode: change-only
```

**Change + explicit regression specs:**

```yaml
version: 1
prCoverage:
  mode: change-plus-regression
  regression:
    - checkout-smoke
    - auth-smoke
```

**Per-PR workflow override:**

```yaml
      - uses: azelaya6/proofreel-action@v1
        with:
          spec: auto
          coverage: change-plus-regression
          regression: checkout-smoke,auth-smoke
```

**Migration:** Repositories with no `.proofreel/project.yml` keep today's `spec` behavior (`auto` still uses `always: true` when nothing matches). Adding `project.yml` opts pull requests into explicit coverage; scheduled jobs without `coverage:` stay on legacy `spec: ""` → all specs.

**Deterministic change association:** only `paths:` globs and edits to the spec file under `.proofreel/` (not claim `sourceGlobs`). Unknown regression slugs and regression lists on `change-only` fail the run with a setup comment. Overlapping slugs are deduplicated.

**Spec layout:** place per-feature files under `.proofreel/` or nested folders (`.proofreel/auth/login.yml` and `.yaml` are loaded). `project.yml` / `project.yaml` are config only, not specs.

**Changed files on pull requests:** ProofReel lists the PR diff with `git diff base...head` when `actions/checkout` has enough history, otherwise via the GitHub pull files API using the `github-token` input (same token as the fallback comment; needs `pull-requests: read`). **Recommend `fetch-depth: 0`** on checkout so git can always see the merge base. If neither git nor the API can determine changed paths, the run **fails closed** with setup instructions — it does not treat “unknown” as “nothing changed”. A real empty diff still passes green with **no specs selected** (nothing recorded or charged). **Fork PRs** and **`pull_request_target`** workflows that check out the base branch need extra care: specs added only on the head ref may not exist on the checkout; prefer `pull_request` with a normal checkout of the head ref.

Dry-run locally: `npx proofreel select --spec auto --file src/foo.ts` (add `--coverage` / `--regression` to match the Action).

## Inputs

| Input | Default | Meaning |
| --- | --- | --- |
| `spec` | `""` (all) | `""` records every spec. One slug records that spec. Comma-separated slugs record that list. `auto` picks specs from the PR diff using each spec's `paths:` (see above). |
| `coverage` | `""` | On pull requests, overrides `.proofreel/project.yml`: `change-only`, `change-plus-regression`, or `all`. Empty uses the repo file when present; otherwise legacy `spec` behavior. |
| `regression` | `""` | Comma-separated regression spec slugs for this run (requires `change-plus-regression`). Overrides the list in `project.yml`. |
| `service-url` | `https://api.proofreel.dev` | Hosted service. It signs the recording pass for each run; without it nothing is recorded. |
| `oidc-audience` | service-url | OIDC audience. Leave it unset. |
| `attach-mode` | `auto` | Fallback comment media: `auto`, `gh-attach`, `gif-fallback`, `none`. |
| `github-token` | `${{ github.token }}` | Fallback PR comment when the App does not post one; on pull requests also lists changed files via the GitHub API when git cannot diff `base...head`. Prefer `fetch-depth: 0` on checkout. |
| `pr` | from event | Pull request number override. |
| `telemetry` | `true` | **On by default.** Sends a scrubbed error report to ProofReel when the Action hits an internal error, a setup problem or a failed upload. Set `false` to opt out. See [Error telemetry](#error-telemetry).

## Error telemetry

Error telemetry is **on by default**. When the Action itself fails in your repository (an internal error, a setup problem such as a missing or invalid spec, or a failed upload) it sends **one small JSON report** to `https://api.proofreel.dev/v1/telemetry/action-error` so we can find and fix ProofReel bugs without you filing an issue. It never changes your job's result.

```yaml
      - uses: azelaya6/proofreel-action@v1
        with:
          telemetry: false   # opt out of scrubbed error reports
```

You can also opt out in the workflow env: `PROOFREEL_TELEMETRY=0` (or `false`, `no`, `off`).

- **What is sent:** repository name, workflow run id and attempt, Action version, the stage that failed (`setup`, `session`, `record`, `verify`, `upload`, `publish`, `comment`, `internal`), the error class (or setup-problem kind), the first line of the error message (scrubbed, at most 300 characters), and the runner OS/arch.
- **What is never sent:** secrets, environment variables, tokens, email addresses, URL query strings or fragments, file or spec contents, stack traces, or your user name from home paths (`/Users/…`, `/home/…`, `C:\Users\…`). `key=value` and `key: value` secrets such as `token`, `tok`, `secret`, `password`, `passwd` and `pwd` are redacted in any case. The message is scrubbed on the runner with the same secret masks the Action uses for logs, and scrubbed again by the service.
- **How it is authenticated:** with a short-lived GitHub Actions OIDC token (audience `proofreel-telemetry`), so it needs the same `permissions: id-token: write` the Action already uses. The service only accepts the run named in that token. There is no API key or DSN in the Action. Without the permission the Action logs one line and sends nothing.
- **Fire and forget:** short timeouts (a few seconds); a failed or slow report is ignored.
- **Opt out:** with `telemetry: false` or `PROOFREEL_TELEMETRY=0` nothing is requested or sent. `service-url: ""` also sends nothing.

Reports are kept for 90 days and rate-limited per repository. Questions: support@proofreel.dev.

The Action runs on **Linux or macOS** GitHub Actions runners. You choose `runs-on` in your workflow.

## Runners

| Runner | `runs-on` example | System deps |
| --- | --- | --- |
| GitHub-hosted Linux (default) | `ubuntu-latest` | Installed by the Action via `apt` (ffmpeg, tesseract, xvfb, xterm, DejaVu fonts). Playwright Chromium is cached under `~/.cache/ms-playwright`. |
| Self-hosted or GitHub-hosted macOS | Your labels, e.g. `[self-hosted, macOS, ARM64, proofreel]` | When **Homebrew** is on the runner, the Action runs `brew install ffmpeg tesseract` automatically if either tool is missing. Optional for terminal fallback rendering: `brew install --cask font-dejavu`. If Homebrew is not installed, the job fails and the PR comment explains how to install Homebrew and the packages. The Action does **not** run `apt` on macOS. |

Optional workflow env **`PROOFREEL_INSTALL_DEPS=0`** (or `false`): skip automatic Homebrew installs on macOS and fail when `ffmpeg` or `tesseract` is missing (for locked-down runners). Default is automatic install when Homebrew is available.

**Browser claims** (`recorder: browser`) work on both Linux and macOS — Playwright records headless Chromium with no Xvfb.

**Terminal claims** (`recorder: terminal`): on Linux, the Action's xvfb + xterm path captures a real terminal when available. On **macOS**, Xvfb is not available (Linux-only); ProofReel falls back to running your steps and rendering the log with ffmpeg (needs ffmpeg + a readable font). Live xterm capture on Mac would require XQuartz and is not supported out of the box — use browser claims or a Linux runner for full terminal capture.

```yaml
jobs:
  video-proof:
    runs-on: ubuntu-latest   # or your self-hosted macOS labels
```

## Running the CLI locally

Needs Node 22+, ffmpeg, and tesseract on `PATH`. **Linux:** also install xvfb, xterm, and DejaVu fonts for terminal recording — `sudo apt-get install -y ffmpeg tesseract-ocr tesseract-ocr-eng xterm xvfb fonts-dejavu-core`. **macOS:** `brew install ffmpeg tesseract` and optionally `brew install --cask font-dejavu`.

```bash
npx -y github:azelaya6/proofreel-action#v1 login         # GitHub sign-in (device flow), once per machine
npx -y github:azelaya6/proofreel-action#v1 init          # stack-aware proofreel.yml + workflow + gitignore
npx -y github:azelaya6/proofreel-action#v1 record        # docs/videos/<slug>/NN-*.mp4
npx -y github:azelaya6/proofreel-action#v1 verify        # OCR key frames, secret and black-frame checks
npx -y github:azelaya6/proofreel-action#v1 report --print
```

The first time, run `npx -y playwright@1.64.1 install chromium`.

**Sign in first.** Recording needs a short-lived pass signed by the ProofReel service. Run `npx -y github:azelaya6/proofreel-action#v1 login` once: it shows a code to enter at https://github.com/login/device and stores your credentials in `~/.config/proofreel/credentials` (mode 600). `whoami` shows the account and `logout` removes it.

- **Public repos** you can push to record on the Free tier: the ProofReel Free watermark and at most 3 claims per spec. Claims beyond 3 are skipped, with a message that links to Pro checkout.
- **Private repos** need ProofReel Pro after the 3 free proofs:
  - **Per repository** ($9.99/month): `https://api.proofreel.dev/billing/checkout?scopeKind=repo&scopeId=OWNER/REPO`
  - **Per GitHub organization** ($69.99/month, all private repos in the org): `https://api.proofreel.dev/billing/checkout?scopeKind=org&scopeId=ORG`
  With Pro (repo or org) there is no watermark and no claim cap, on your laptop too.
- Without a pass (not signed in, no push access, private repo without Pro) nothing is recorded and the CLI says what to do. `verify` and `report` need no account. No env var, flag or config option unlocks recording or removes the watermark.

## License

Source-available under the [ProofReel Action License](LICENSE). You may use it with ProofReel. You may not redistribute it, resell it, or use it to build a competing service.
