---
name: proofreel
description: Install and configure ProofReel — write proofreel.yml, .proofreel/*.yml, and the GitHub Actions workflow. Use when adding or fixing video proof specs or the ProofReel workflow.
---

# Write or fix ProofReel specs and workflow

## When to use

Use this skill when the task adds or changes any of:

- `proofreel.yml` (repository root)
- `.proofreel/<slug>.yml` (per-feature specs)
- `.github/workflows/proofreel.yml` (CI workflow)

## Non-negotiables

1. **`service-url`** — Default is `https://api.proofreel.dev`. Do not set it empty or point at a self-hosted URL; without the hosted service there is no recording pass and nothing is recorded.
2. **`runs-on: ubuntu-latest`** — The Action needs apt packages (ffmpeg, tesseract, xvfb).
3. **`permissions`** — Required block:
   - `id-token: write` (OIDC; no secrets)
   - `contents: read`
   - `pull-requests: write` (fallback PR comment if the GitHub App is not installed)
4. **Action version** — `uses: azelaya6/proofreel-action@v1`
5. **Fixture data only** — Record against seeded or demo data. Never show production data, real customer records, or secrets on screen.
6. **Selectors and OCR** — Prefer `data-testid` attributes. `expect.text` must appear visibly in the marked key frame (OCR reads the video).
7. **Plan limits** — Public repos: free, watermarked, **≤ 3 claims per spec**. Private repos: **3 free watermarked proofs**, then **ProofReel Pro** ($9.99/month per repo or **$69.99/month org-wide**). Extra claims on the free tier are skipped, not failures.
8. **YAML quoting** — Quote any scalar that contains `:` (for example captions or text with colons).

## GitHub Actions workflow (copy-paste)

Adapt dependency install steps to the project (delete Node steps for static sites with no `package.json`).

```yaml
name: ProofReel

on:
  pull_request:

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  video-proof:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Install dependencies so the spec's `pre` can start the app.
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
      - run: npm ci

      - uses: azelaya6/proofreel-action@v1
```

`service-url` defaults to `https://api.proofreel.dev`; leave it unset unless documenting it explicitly.

## Spec shape

Config lives on the **PR branch** in either:

| File | Purpose |
| --- | --- |
| `proofreel.yml` | One spec for the whole repository |
| `.proofreel/<slug>.yml` | One spec per feature; output under `docs/videos/<slug>/` |

Each file is a **complete** spec (no inheritance). Required top-level fields: `version: 1`, `name`, `slug`, `claims` (at least one claim).

Each claim needs: `id`, `caption`, `recorder` (`browser` or `terminal`), `steps`, and usually `expect` for verification.

For **browser** claims, set `baseUrl` and optionally `pre` — commands started in the background until `baseUrl` responds (recommended way to start the app under test).

### Good claim pattern (browser)

Flow: **goto → act → wait → mark → expect**

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

Terminal claims use `run`, `pause`, and `expect.text` on terminal output instead of `goto`/`click`.

With no `spec` input, the Action records every spec it finds. Set `spec: <slug>` on the Action step to record only `.proofreel/<slug>.yml`.

Full field and step reference: [ProofReel Action README](https://github.com/azelaya6/proofreel-action) (Spec reference section).

## Agent procedure

1. **Read the UI or CLI** — Identify 1–3 user-visible behaviors worth proving (free tier cap). Add or reuse `data-testid` in the app if selectors are brittle.
2. **Write the spec** — Match `baseUrl` and `pre` to how the repo actually starts locally and in CI. Use fixture/seed data only.
3. **Add or update the workflow** — Include checkout, dependency install if needed, then `azelaya6/proofreel-action@v1` with the permissions above.
4. **Tell the human to install the GitHub App** (required for the best PR experience): https://github.com/apps/proofreel/installations/new
5. **Private repositories** — After 3 free proofs, share Pro checkout links (replace placeholders):
   - Per repo: `https://api.proofreel.dev/billing/checkout?scopeKind=repo&scopeId=OWNER/REPO`
   - Per org: `https://api.proofreel.dev/billing/checkout?scopeKind=org&scopeId=ORG`

Setup errors (missing spec, invalid YAML, app never answers at `baseUrl`) **do not** fail the job; the PR comment explains fixes. Only **failed frame checks** turn the **Video proof** check red.

## Optional local CLI

From the repository root (Node 22+, system deps on Linux — see README):

```bash
npx -y github:azelaya6/proofreel-action#v1 login   # once per machine
npx -y github:azelaya6/proofreel-action#v1 init    # stack-aware proofreel.yml + .github/workflows/proofreel.yml
npx -y github:azelaya6/proofreel-action#v1 record
npx -y github:azelaya6/proofreel-action#v1 verify
```

## Support and docs

- Full spec reference and behavior tables: https://github.com/azelaya6/proofreel-action
- Website: https://proofreel.dev
- Support: support@proofreel.dev
