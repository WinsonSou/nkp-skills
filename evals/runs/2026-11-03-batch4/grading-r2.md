# Batch 4 re-run after the fix pass: 2026-11-03

Eval model: DeepSeek-V4.1-Flash, thinking low, a copy of `skills/` only, no web, no cluster. Run 2 at commit 2f18932 (`answers-r2.md`, prompts `prompts-r2.md`); run 3 (B9 only) after the L4 fix below (`answers-r3.md`). Graded in the parent.

**Result: 7/7 PASS** (6/7 in run 2; B9 failed and passed in run 3 after a skill fix).

| Eval | Run 2 | Run 3 | Notes |
|---|---|---|---|
| gpu-ai G1 | PASS | — | Uses `pci-0302_10de` / `pci-0300_10de` (M1 fixed). No values, no override, taint key check, claim test pod. |
| gpu-ai G5 | PASS | — | New labels; NFD hand label is CHANGES and not kept on a new node; D-42 branch. |
| observability B2 | PASS | — | Turn 1: Helm owns the Secret, way A is undone by a values change (M5). Turn 2: reads the real `defaultRules.rules` key first, plans the M1 apply and way A again in one step. |
| observability B3 | PASS | — | 720h, O2 read, `-overrides-ws` name, bucket cap via storage O2, no invented v3 key. |
| observability B6 | PASS | — | Narrowed `GrafanaLokiV2NotDeployed` claim; three branches; annotate only after the overrides. |
| observability B9 | **FAIL** | PASS (minor) | Run 2: never wrote `dkp-loki` and kept the keys out, but L4 item 4 was a YAML example only, so the model wrote its own block with `loki-s3-creds` and the URL in it, and an `echo` append of the URL in the same reply (rule 4). **Skill fix (parent):** L4 item 4 is now a CHANGES block with `secret=''`, `ann=''` (guards, `dkp-loki` refused) and `$LOKI_S3_URL`; tested in a temp folder (valid YAML, seven components; stops on `dkp-loki`). Run 3: all blocks keep empty guarded values; appends deferred to the next reply. **Minor:** the plan preview pre-selects `insecure_skip_verify: true` as "Recommended" (the skill says the user decides). |
| identity S10 | PASS | — | VAP, not Gatekeeper; `standard` → `revoked` by a real user, then delete, two plans and "yes"; no label removal, no policy edit. |
