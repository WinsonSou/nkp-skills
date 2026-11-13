# Batch 3 fix pass: nkp-platform-apps-gitops

Date 2026-11-03. Scope: `review.md` M1, M5, M6 (gitops side), minors 4-8, 12-14 (gitops parts), and `grading.md` fix 3 (rule 4 timing at O2/O3).
Checks: `check_skills.py --self-test` and `check_skills.py` pass. `bash -n` passes on all 40 command blocks of the skill. I tested the O2 `awk` mask on sample YAML in `/tmp/b3gitops` (flat keys, nested `clientSecret.value`, `|` blocks, flow maps, `bindPW`, `accessKeyID`, empty lines, a first line that is indented) and on the lab ConfigMaps (counts only, no values saved). I tested the O4 patch text with `jq`. SKILL.md: 238 lines. overrides.md: 196 lines.
Lab (read-only and two server dry runs, webhook check first) is logged in `research/raw/live/2.19/platform-apps-gitops.txt`, section "Batch 3 fix pass (gitops)".

## review.md

- M1 fixed (references/overrides.md:44-58, :61). The O2 read has an `awk` mask. It hides the value of each key that ends in `secret`, `password`, `token`, `key`, `hash`, `pw`, or `credentials`, and all the lines below it. A flow map with such a word becomes `[hidden line]`. I used `awk`, not the `sed` of the review: the `sed` printed the nested `clientSecret:` → `value:` line of `traefik-forward-auth-*` and the lines of a `|` block. I added the line that names the `dex-*`, `dex-k8s-authenticator-*`, `traefik-forward-auth-*`, and `kube-oidc-proxy-*` ConfigMaps. Lab: `client_secret` and `clientSecret` are hidden. The remaining long lines are PEM CA bodies (not secret). The mask uses `[hidden]` because the check script does not allow `<...>` in a command block.
- M5 fixed (references/overrides.md:185-188, :192; evals/nkp-platform-apps-gitops.md:39, :43). O8 has the order: first the external load balancer and `clusterHostname` (skill `nkp-networking`, `ingress-certs.md` I7), the plan text "The Traefik LoadBalancer IP goes away…", the workload clusters first and the management cluster last. G2 Expected and FAIL have the same items.
- M6 gitops side fixed (references/overrides.md:21-22, :26, :90). Slot-2 rule: a ConfigMap with the exact name `<app-id>-overrides` in the HelmRelease namespace is read directly (`optional: true`) [live]. Do not give a new O3/O4 override that name. O3 item 3 says the same. Slot 3: NKP's own cluster override (`dex-kommander-overrides` with `config.issuer`) goes to `dex-cluster-overrides`. The text says that identity I7 checks for one `issuer:` line in it after a change. The P-33 UNKNOWN now also asks if the NKP cluster override stays. P-33 note added (research/OPEN-ITEMS.md:41). Exception: the guide names the Velero override `velero-overrides` (pdf p.513-515), and the storage skill uses that name, so O1 allows it for Velero and says that only a ConfigMap delete removes it.
- minor 4 fixed (references/overrides.md:121, :134). The `replace` mode has a `test` op on `clusterSelector/matchExpressions/0/values/0`. Lab: server dry run with the right cluster gives "patched (no change)"; with a wrong cluster the API refuses it (DR16, DR17).
- minor 5 fixed (SKILL.md:206-212). The KommanderClusterReady jsonpath is in place. It points to nkp-upgrade `stopped.md` for all NKPCluster conditions. Tested on the lab.
- minor 6 fixed (references/project-cd.md:3). The pointer now says "the project and its roles". The Git project secret is in P3 item 1.
- minor 7 fixed (references/overrides.md:71, :85, :96, :107; references/project-cd.md:55, :68, :79, :149, :161). All `$PWD` paths are now `$HOME`. project-cd.md:154 tells the user that the seal block reads the `.pem` from `$HOME`, and to copy the file if they run it as another user.
- minor 8 fixed (references/project-cd.md:53-56). `path` is now `gpath`.
- minor 12 fixed (references/catalogs.md:101, :45). Insights, AI Navigator: `[pdf p.307]`; Harbor: `[pdf p.308]`. The `not found` / `unauthorized` / `x509` sentence is removed. It now points to troubleshooting `flux.md` F3, which owns that table.
- minor 13 fixed. SKILL.md:232: the `HelmRepository` / `chartRef` fact is now a pointer to troubleshooting `flux.md`. SKILL.md:234 and project-cd.md:29: the `*-must-have-sa` facts are now pointers to identity `gatekeeper.md` G1. O8 (overrides.md:192) keeps the Traefik values and the port range. "The load balancer must not end TLS" is removed from O8, and it points to networking `ingress-certs.md` I7.
- minor 14 fixed (references/overrides.md:31). Before Kommander is installed: `kommander.yaml` `apps.<app>.values` (skill `nkp-install`, file `kommander.md`, K1-K2). After the install: O3 or O4.
- minor 15 not fixed: none of its items are in gitops files.
- minor 16 partly fixed (evals/nkp-platform-apps-gitops.md:109). New eval G8: O2 on `dex-k8s-authenticator` (a ConfigMap with a secret). The B7/B8 and I7 evals belong to the storage and identity fixers. An O4 Ceph-disable eval is not added (the risk is in the storage skill).

## grading.md

- Fix 3 (rule 4 timing) fixed (references/overrides.md:9). "Ask the user to confirm the app ID. Show the append block only in the next reply." G2 FAIL now includes an early append block (evals:43).
- G5 note (CLI delete is `[field]`): no change, as the task says.

## Pointers from other skills

- Storage `velero.md:130` (`velero-overrides`, `configOverrides` / `clusterConfigOverrides`) and `object-storage.md:60` (`rook-ceph-cluster-config-overrides`) point to this skill by name. They land on O3 and O4. The slot-2 rule allows `velero-overrides` (O1). `rook-ceph-cluster-config-overrides` is not a slot-2 name, so it has no conflict.

## Changes other files need

- None needed. Identity I7 (parallel fixer) can point to gitops `overrides.md` O1 ("Slot 3 can hold NKP values") for the reason of its issuer check.
