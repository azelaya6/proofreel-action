# Contributing to proofreel-action

Thank you for helping improve ProofReel. This document covers commit standards for this repository.

## Commit author identity

All commits on the default branch must use:

- **Name:** Alcides Zelaya
- **Email:** alcideszelaya@hotmail.com

Configure your local Git identity for this repo:

```bash
git config user.name "Alcides Zelaya"
git config user.email "alcideszelaya@hotmail.com"
```

Do **not** add `Co-authored-by: Cursor Agent <cursoragent@cursor.com>` or `Made-with: Cursor` lines to commit messages. Cursor and other tools must not appear as authors or co-authors on this public Action repo.

## Git hooks

This repo ships a `commit-msg` hook that removes Cursor Agent co-author and `Made-with: Cursor` trailers if they appear in a message.

Enable hooks after cloning:

```bash
./scripts/setup-git-hooks.sh
```

Or manually:

```bash
git config core.hooksPath .githooks
```

## Pull requests

Open PRs against `main`. Keep README marketing copy aligned with [proofreel.dev](https://proofreel.dev) unless the change is intentionally documentation-only.
