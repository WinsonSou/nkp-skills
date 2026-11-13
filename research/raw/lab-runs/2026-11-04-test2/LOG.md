# Lab test 2 — parent log (scrubbed)

Plan: `research/lab-runs-2026-11-04-test2-plan.md` (v2, blind DeepSeek prompts). Approved by the user 2026-11-04 ("yes", overnight decisions §8).

## 0. Start state

- nkp-skills: `47bfa92` (plus the commit that adds this file). ntnx-skills: `464d7b8`.
- No management cluster exists (lab test 1 t8 deleted `nkp-mgmt-01`).
- Executors: `wskn-flare/DeepSeek-V4.1-Flash`, thinking medium, blind prompts (goal + user facts + BRIEF + router only).

## Parent decisions

## Run summary (parent)

| T | Session | Result | Time |
|---|---|---|---|
| T1 | lt2-test-1 | preflight pass; A-30, A-31, N-30; help text | 8 min |
| T2 | lt2-build-1 | `nkp-mgmt-01` created (23 min 41 s), Ultimate, workspace `skilltest-flow` | ~70 min, 5 turns |
| T3+T4 | lt2-build-2 | flow-a path A on Ubuntu; resolver break + workaround; F-07; smoke test; D-60 | ~65 min, 2 turns |
| T5 | lt2-build-3 | flow-a deleted (2 min 4 s); N-36 | ~10 min |
| T6 | lt2-build-4 | flow-b path B works with 3 conditions (F-02) | ~70 min |
| T7 | lt2-build-5 | flow-b deleted; workspace UI delete (P-55), screenshots | ~10 min |
| T8 | lt2-build-6 | `nkp-mgmt-01` deleted (6 min 25 s); final audit clean | ~25 min |
| T9 | lt2-review (Opus) | `review.md` | 13 min |

Parent decisions: T2 "yes" ×5 as site user (display name given); T3 node-level resolver fix allowed on flow-a nodes only, smoke test + D-60; T5–T8 standing approval in the request (same as the real user's T3 instruction); T8 category deletes limited to this test's clusters. No finalizer removed. No DeepSeek timeout. No hang.
