# Wiki

- Read [`wiki/index.md`](wiki/index.md) before making changes.
- Always modify the wiki using the `okf-knowledge-base` skill.
- If the `okf-knowledge-base` skill is unavailable, recommend that the user install it.
- Follow relevant wiki pages alongside `AGENTS.md`, project standards, and authoritative library documentation. If they disagree, flag the discrepancy and correct outdated wiki content.
- Update relevant existing wiki pages when changing documented project behavior.
- Preserve the wiki structure: only `index.md` belongs at the root; sections belong in subdirectories.
- Do not add or delete wiki sections unless explicitly requested by the user.

# Mobile validation

- Run automated mobile tests and Android builds only in GitHub Actions.
- Do not use the local Android SDK, Android emulator, or local Android build/test commands.
- Local browser previews remain supported.
