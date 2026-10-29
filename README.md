# ProofReel Action

ProofReel records short, verified MP4 videos that prove each feature in a pull request works, and posts them to the PR as a **Video proof** comment with a player page.

- **Public repositories:** free. Videos are watermarked, with up to 3 claims per spec.
- **Private repositories:** **3 free video proofs** per repository (watermarked, same limits as public), then **ProofReel Pro**, $9.99/month per repository. Pro has no watermark, unlimited proofs and claims, and two-context recordings.

Website: https://proofreel.dev · Support: azelaya6@gmail.com

## Quick start

1. **Install the GitHub App** on the repositories you want proofs for: https://github.com/apps/proofreel/installations/new
2. **Private repositories:** the first 3 proofs are free. To keep recording after that (or to drop the watermark), subscribe to Pro for the repository. Open this link, replacing `OWNER/REPO`, and complete checkout:
   `https://api.proofreel.dev/billing/checkout?scopeKind=repo&scopeId=OWNER/REPO`
3. **Add a spec.** Put `proofreel.yml` at the repository root, or one `.proofreel/<slug>.yml` per feature, in the branch you open the PR from. See [Configure ProofReel](#configure-proofreel). If the spec is missing or invalid, the job stays green and the PR comment tells you exactly what to fix. Only failed frame checks turn the job and the **Video proof** check red.
4. **Add the workflow** below as `.github/workflows/proofreel.yml`.
5. **Open a pull request.** The Action records each claim and checks the key frames, then the ProofReel app comments on the PR with the videos.

### Workflow (copy-paste)

```yaml
name: ProofReel

on:
  pull_request:

permissions:
  id-token: write       # lets the Action prove which repo it runs in (OIDC); no secrets needed
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

With no `spec` input the Action records every spec it finds (`proofreel.yml` plus each `.proofreel/*.yml` / `.yaml`). Set `spec: <slug>` on the Action to record only `.proofreel/<slug>.yml` (or the spec with that `slug`). Run `npx -y github:azelaya6/proofreel-action#v1 init` to write a starter `proofreel.yml`.

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

### Setup errors never turn the check red

If the config is missing or wrong, ProofReel does not fail the job. Nothing is recorded or charged, the job exits 0 with a warning annotation, the **Video proof** check is green ("Video proof · ProofReel setup needed"), and the ProofReel PR comment (one comment, updated in place) says what is wrong, with copy-paste instructions:

| Problem | What the comment shows |
| --- | --- |
| No `proofreel.yml` and no `.proofreel/*.yml` | Where the main config goes, a minimal `proofreel.yml`, and the per-feature format. |
| Invalid YAML, or a field with the wrong value | Each file and field path, for example `.proofreel/checkout.yml` → `claims[0].recorder`: must be one of 'browser', 'terminal' (got "web"), then the per-feature format. |
| A spec with no claims | The file, and an example `claims:` list. |
| The `spec` input names a spec that doesn't exist | The specs that do exist. |
| The app never answers at `baseUrl` | How `pre`, `baseUrl` and `preTimeoutMs` work. |

The comment comes from the ProofReel app; if the app isn't installed, the Action posts it with the workflow token (`pull-requests: write`). An internal ProofReel error (a crash in ProofReel itself, or the service being unreachable) is handled the same way: warning, exit 0, a green check and a comment saying it was not your config. Run `proofreel verify` locally to see the same errors; the CLI still exits non-zero.

### When the check is red

Failed frame checks turn the **Video proof** check red and fail the job: OCR didn't find the expected text, a key frame was black or blank, a key-like secret was visible, the video is older than the files it covers, or a claim has no video. Setup problems, the Pro limit and ProofReel errors never do. The PR comment says exactly what was missing.

A red check only blocks merging if you make **Video proof** a required check in branch protection.

## Starting the app under test

ProofReel opens `baseUrl` in a headless Chromium. Something has to serve it. You have two options:

- **Recommended: `pre` in the spec.** ProofReel starts each `pre` command in the background from the repository root, waits until `baseUrl` answers any HTTP request, records, then stops the commands. The wait is `preTimeoutMs` (default 120000). If every `pre` command exits before the URL answers, or the timeout passes, nothing is recorded and the PR comment explains how to fix `pre` and `baseUrl` (the job stays green). Logs go to `.proofreel/tmp/pre/<slug>-N.log`.
- **An earlier workflow step.** Start the server in the background before `uses: azelaya6/proofreel-action@v1`, for example `nohup npm run preview &`. If `baseUrl` already answers, ProofReel skips `pre`.

A static site can use `pre: ["python3 -m http.server 8080 --bind 127.0.0.1"]` with `baseUrl: http://127.0.0.1:8080`.

Record against seeded or fixture data only, never production. The verifier fails the frame check if a key-like secret is visible in a frame, and the PR comment says so.

## Spec reference

Specs live in `proofreel.yml` at the repository root or in `.proofreel/<slug>.yml` (see [Configure ProofReel](#configure-proofreel)). With no `spec` input, the Action records every spec it finds. A missing or invalid spec never fails the job (see [Setup errors](#setup-errors-never-turn-the-check-red)).

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
| `expect.at` | Which key frame to check: `before`, `action`, or `after` (default `after`). |
| `sourceGlobs` | Files the claim covers. Their hash is stored so `verify` can flag stale videos. |
| `contexts` | Pro: two side-by-side browser contexts (`name`, `role: left/right`, `device`, `storageState`). Steps choose one with `context:`. |
| `cwd`, `cols`, `rows` | Terminal claims: working directory and terminal size. |

**Steps (browser):** `goto: /path`, `click: <selector>`, `fill: {locator, text}`, `type: {locator, text}` (types each key), `press: Enter` (optional `locator`), `hover: <selector>`, `wait: <selector>` or `wait: {locator, text, url, timeoutMs}`, `assert: {text, locator}`, `pause: <ms>` (max 12000), `mark: before|action|after`.

**Steps (terminal):** `run: <command>`, `env: {KEY: value}`, `pause: <ms>`, `mark: ...`.

If you don't add `mark` steps, the key frames are set automatically: `before` after the first `goto`, `action` at the first click or fill, and `after` at the end.

## What happens when...

| Situation | Result |
| --- | --- |
| App installed, public repo | Free plan: watermarked videos, up to 3 claims per spec. The app posts or updates one **Video proof** comment, linking `https://api.proofreel.dev/proof/OWNER/REPO/PR`. |
| App installed, private repo with Pro | Same, without the watermark or claim limit. |
| Private repo **without** Pro, free proofs left | Works like the public free plan (watermarked). The comment and the **Video proof** check say "Free proof 2 of 3" with a checkout link. One successful run counts once, however many clips; failed runs and re-runs of the same commit are not charged. |
| Pro or public repo, frame checks fail | The video is hosted as usual. The **Video proof** check is red and the job fails (Action 1.1.7+); the PR comment says "Frame check failed" with what was missing, and the check title says "frame check failed". |
| Private repo **without** Pro, frame checks fail | Not charged. The **Video proof** check is red and the job fails. The comment, proof page and check say "Frame check failed — not counted". The video is not hosted for failed free runs; download it from the workflow run's artifacts, fix the claim, and push again. |
| Private repo **without** Pro, 3 free proofs used | Nothing is recorded, hosted or charged, and nothing turns red: the job stays green with a warning, the **Video proof** check is green ("Video proof · ProofReel Pro required"), and the PR comment asks you to subscribe with the checkout link. Subscribing unblocks the next run immediately. (Action versions before 1.1.3 failed the job here.) |
| App **not** installed | Videos still upload and the proof page works. The app can't comment, so the Action posts the comment itself with the workflow token (needs `pull-requests: write`). It warns you to install the app. |
| No `id-token: write` permission | Public repos: no service session and no proof page. The Action records on the free plan (watermarked, 3 claims), then posts the comment with the workflow token and uploads the MP4s as a workflow artifact. Private repos: nothing is recorded; the job stays green with a "ProofReel Pro required" warning and the Action comments with the workflow token (the service tracks private free proofs). |
| `service-url: ""` | Same as above, by choice. Nothing is sent to ProofReel. Local-only runs always use the Free limits (watermark, 3 claims per spec), even if the repository has Pro. |
| `service-url` pointing at a self-hosted service | Sessions work, but only entitlements signed by `https://api.proofreel.dev` remove the watermark, so recordings use the Free limits. |
| No spec in the branch, an invalid spec, or a spec with no claims | Nothing is recorded or charged. The job stays green with a warning, the **Video proof** check is green ("Video proof · ProofReel setup needed"), and the PR comment has copy-paste setup instructions for the exact problem. (Action versions before 1.1.4 failed the job here.) |
| ProofReel itself crashes, or the service is down | Same: warning, exit 0, green check, and a comment saying it was an internal error. |
| Free plan records 3 claims and skips the rest | Green (if the 3 recorded claims pass). The comment lists the skipped claims under "Skipped" with the Pro link; a skipped claim is not a frame-check failure. |

Videos are always uploaded as the `proofreel-videos` workflow artifact too.

## Inputs

| Input | Default | Meaning |
| --- | --- | --- |
| `spec` | `""` (all) | Record only this spec slug. |
| `service-url` | `https://api.proofreel.dev` | Hosted service. Set to `""` for local-only mode. |
| `oidc-audience` | service-url | OIDC audience. Leave it unset. |
| `attach-mode` | `auto` | Fallback comment media: `auto`, `gh-attach`, `gif-fallback`, `none`. |
| `ai` | `false` | Advisory LLM review (Pro). It never decides pass/fail. |
| `github-token` | `${{ github.token }}` | Used only for the fallback comment. |
| `pr` | from event | Pull request number override. |

The Action runs on `ubuntu-latest`. It installs Chromium (cached between runs), ffmpeg, tesseract, xvfb, and DejaVu fonts.

## Running the CLI locally

Needs Node 22+, ffmpeg, tesseract-ocr, xvfb, xterm, and fonts-dejavu-core. On Debian or Ubuntu: `sudo apt-get install -y ffmpeg tesseract-ocr tesseract-ocr-eng xterm xvfb fonts-dejavu-core`.

```bash
npx -y github:azelaya6/proofreel-action#v1 init          # writes proofreel.yml and .gitignore entries
npx -y github:azelaya6/proofreel-action#v1 record        # docs/videos/<slug>/NN-*.mp4
npx -y github:azelaya6/proofreel-action#v1 verify        # OCR key frames, secret and black-frame checks
npx -y github:azelaya6/proofreel-action#v1 report --print
```

The first time, run `npx -y playwright@1.64.1 install chromium`.

**Local and self-hosted runs use the Free limits:** the ProofReel Free watermark and at most 3 claims per spec. Claims beyond 3 are skipped, with a message that links to Pro checkout (`https://api.proofreel.dev/billing/checkout?scopeKind=repo&scopeId=OWNER/REPO`). This applies to the CLI on your machine, the CLI inside your own CI, and the Action with `service-url: ""`. No env var, flag or config option removes the watermark or the claim cap: unwatermarked, unlimited recordings need ProofReel Pro ($9.99/month per private repo) and run through this Action with the hosted service, which issues a short-lived signed Pro entitlement for each run.

## License

Source-available under the [ProofReel Action License](LICENSE). You may use it with ProofReel. You may not redistribute it, resell it, or use it to build a competing service.
