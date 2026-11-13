# Authoring brief for one NKP skill

Use this brief when you write or change one skill. The format is fixed at git tag `format-v1`.

## Read first

1. `AGENTS.md`, `GLOSSARY.md`, `docs/adr/*.md`, `research/NEXT-STEPS.md` §1.
2. `~/.pi/agent/skills/writing-for-agents/SKILL.md` and `SKILL-MECHANICS.md`.
3. The examples of the format: `skills/nkp/` and `skills/nkp-install/` (with `references/nutanix.md`). Copy their structure: the rules block, the command blocks, "Done when", the UNKNOWN lines, and the source tags.
4. The rules block: `skills/_shared/RULES.md`.
5. Evidence: `research/nkp-component-map.md`, `research/OPEN-ITEMS.md`, the raw file for your topic (`research/raw/0N-*.md`), `research/raw/live/2.19/` (start with `SUMMARY.md`), and the PDF sections in `research/raw/pdf/2.19/` (find them with `INDEX.tsv`). Source priority: live > pdf > portal > field. Field notes: `~/Documents/everything-nkp` and `~/Documents/<vault>` (scrub everything).

## Write

- `skills/<skill>/SKILL.md` (≤ 250 lines) and `references/*.md` (≤ 400 lines each). Use `assets/` only for small pinned text files (≤ ~50 KB, with the upstream version and SHA in a header).
- `evals/<skill>.md`: 5-8 evals in the format of `evals/nkp-install.md`. Include at least one eval for the approval gate and one eval for a fact that is not in the skills.
- The description: front-load the trigger words. One trigger for each branch. No padding.
- ASD-STE100. Exact commands. Every flag must be in `research/raw/live/2.19/nkp-help*.txt`, or have a `[pdf p.N]` tag.
- One owner skill for each fact (ADR 0001). Point to other skills with `` skill `nkp-x` ``. Do not copy their facts.

## Shared files

- `research/OPEN-ITEMS.md`: add a row for each new UNKNOWN ID. Use the existing ID prefixes. List the new rows in your reply.
- `skills/_shared/RULES.md`: change it only to add a site variable that your commands need. Then run `python3 scripts/check_skills.py --sync`. List the new variables in your reply.
- Do not change `scripts/check_skills.py`, the `nkp` router, or another skill. If one of them must change, say so in your reply.

## Finish

- `python3 scripts/check_skills.py --self-test && python3 scripts/check_skills.py` passes.
- Commit in your worktree branch. Do not push or merge.
- Reply with: the files and line counts, new OPEN-ITEMS rows, new site variables, the facts you could not confirm, and the changes that other files need.
