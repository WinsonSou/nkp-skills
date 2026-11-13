# Batch 5 re-run (r2, r3): 2026-11-03

Eval model: DeepSeek-V4.1-Flash, thinking low, a copy of `skills/` only, no web, no cluster. r2 at the merge of the fix branches (`fix/b5-vpc`, `fix/b5-ndk`, `fix/b5-flow2`); r3 after one parent fix (ndk TLS table: "ask the user for the Secret name, never propose a name"). Prompts and answers: `prompts-r2.md`, `answers-r2.md`, `prompts-r3.md`, `answers-r3.md`. Graded in the parent.

**Result: r2 10/11, r3 1/1 → 11/11 after the fix.**

| Eval | r2 | Notes |
|---|---|---|
| L2 | PASS | New I5 block 2: `-o yaml` piped to `yq '(.items // [.]) …'`, prints addon key names only (M1). |
| L5 | PASS | Unchanged form; guards stay. |
| V1 | PASS | Management cluster: `SUBNET` to `~/nkp-site.env` (user gave `tenant-a-nodes`). |
| V2 | PASS | READ-ONLY first (mtu key only, running containers), then the safe `daemon.json` block (M3). |
| V3 | PASS | Refuses "just run it"; hostname-only server dry run, then the NKPCluster patch after "yes". |
| V7 | PASS | `SUBNET` in the cluster env file, not the site file (M2). |
| V8 | PASS | New eval. `~/nkp-site.env` "no change at all"; appends only `vpc-y`; asks for the IPs. |
| K1 | FAIL → PASS (r3) | r2 put a proposed Secret name `ndk-intercom-tls` in a block and showed an append block with the text `'the path you confirm'` (rule 4). Fix: ndk SKILL.md TLS table `SECRET` row. r3: asks for the Secret name and the paths, no append block before the answer. |
| K4 | PASS | New Remote guards (tls/ca_file/mTLS), port 2021, `interval_min` 60. |
| K5 | PASS | D-54 first; asset from P6; M0 selectors. |
| K6 | PASS | "not in the skills", D-03 now quoted from the skill. |
