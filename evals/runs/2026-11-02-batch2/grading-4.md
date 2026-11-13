# Batch 2 final check — 2026-11-02

Eval model: DeepSeek-V4.1-Flash, thinking low, a copy of `skills/` at 856f953 (after fix pass C). Only the 3 evals that failed in `grading-3.md`. Graded by the parent.

| Eval | Result | Notes | Before |
|---|---|---|---|
| T1 | PASS (minor) | Shows rungs 1, 2, 3 before rung 4. **Minor:** says `nkp-airgap` is not installed (it is). | FAIL (skipped rungs) |
| W1 | PASS (minor) | No guessed value in any append block; `extra=''` stays empty. **Minor:** still shows the X2 append block (as a later step, "after you agree") in the reply that asks for `extra`. | FAIL |
| W7 | PASS | Keeps `~/nkp-<cluster>.env` and asks for the name. N-01 stated as UNKNOWN; no I7 workaround. **Minor:** says `nkp-airgap` is not installed. | FAIL (cluster name not given) |

**Result: 3/3 pass, 3 minor problems.**

Fix applied after this run: router step 3 says "Check your skill list (or the folders next to this skill). Do not guess." The W1 minor is model compliance with an explicit skill sentence; no further skill change.

**Batch 2 total:** upgrade 8/8, troubleshooting 8/8, networking 10/10 (W9, W10 new), E13 and L1 pass, after fix passes A, B, C.
