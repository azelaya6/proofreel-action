# ProofReel Action

ProofReel records short, verified MP4 videos that prove each feature in a pull request works, and posts them to the PR as a **Video proof** comment with a player page.

- **Public repositories:** free. Videos are watermarked, with up to 3 claims per spec.
- **Private repositories:** **3 free video proofs** per repository (watermarked, same limits as public), then **ProofReel Pro**, $19/month per repository. Pro has no watermark, unlimited proofs and claims, and two-context recordings.

Website: https://proofreel.dev · Support: azelaya6@gmail.com

## Quick start

1. **Install the GitHub App** on the repositories you want proofs for: https://github.com/apps/proofreel/installations/new
2. **Private repositories:** the first 3 proofs are free. To keep recording after that (or to drop the watermark), subscribe to Pro for the repository. Open this link, replacing `OWNER/REPO`, and complete checkout:
   `https://api.proofreel.dev/billing/checkout?scopeKind=repo&scopeId=OWNER/REPO`
3. **Add a spec.** Put `proofreel.yml` at the repository root, or one `.proofreel/<slug>.yml` per feature, in the branch you open the PR from. A minimal example is below.
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

### Minimal spec (`proofreel.yml`)

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

## Starting the app under test

ProofReel opens `baseUrl` in a headless Chromium. Something has to serve it. You have two options:

- **Recommended: `pre` in the spec.** ProofReel starts each `pre` command in the background from the repository root, waits until `baseUrl` answers any HTTP request, records, then stops the commands. The wait is `preTimeoutMs` (default 120000). The run fails if every `pre` command exits before the URL answers, or if the timeout passes. Logs go to `.proofreel/tmp/pre/<slug>-N.log`.
- **An earlier workflow step.** Start the server in the background before `uses: azelaya6/proofreel-action@v1`, for example `nohup npm run preview &`. If `baseUrl` already answers, ProofReel skips `pre`.

A static site can use `pre: ["python3 -m http.server 8080 --bind 127.0.0.1"]` with `baseUrl: http://127.0.0.1:8080`.

Record against seeded or fixture data only, never production. The verifier fails the run if a key-like secret is visible in a frame.

## Spec reference

Specs live in `proofreel.yml` at the repository root or in `.proofreel/<slug>.yml`. With no `spec` input, the Action records every spec it finds. The Action fails if it finds no spec.

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
| Private repo **without** Pro, 3 free proofs used | The job fails before recording: "ProofReel Pro required: this private repo has used its 3 free video proofs. Subscribe: &lt;checkout link&gt;". The **Video proof** check fails with the same link. Subscribing unblocks the next run immediately. |
| App **not** installed | Videos still upload and the proof page works. The app can't comment, so the Action posts the comment itself with the workflow token (needs `pull-requests: write`). It warns you to install the app. |
| No `id-token: write` permission | Public repos: no service session and no proof page. The Action records on the free plan (watermarked, 3 claims), then posts the comment with the workflow token and uploads the MP4s as a workflow artifact. Private repos: the job fails with "ProofReel Pro required" (the service tracks private free proofs). |
| `service-url: ""` | Same as above, by choice. Nothing is sent to ProofReel. |
| No spec in the branch | The job fails with "No proofreel.yml or .proofreel/*.yml specs found". |

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

The first time, run `npx -y playwright@1.64.1 install chromium`. Locally you get the free plan. Set `PROOFREEL_PLAN=pro` to try Pro features, for example in a private repo.

## License

Source-available under the [ProofReel Action License](LICENSE). You may use it with ProofReel. You may not redistribute it, resell it, or use it to build a competing service.
