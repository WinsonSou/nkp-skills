# Batch 2 fix pass B (networking, nkp-install proxy pointers, router)

Date 2026-11-02. Scope: `review-2.md` (M1-M6, minors 1-16, section 4), `grading-2.md` fixes 2-4. Pass A work is kept.
Checks: `check_skills.py --self-test` and `check_skills.py` pass. `bash -n` passes on all 255 command blocks. I tested each shell fix with `bash -c` on scratch files in `/tmp/b2fixB` (credential check, inline no-proxy list, append to `"$HOME/nkp-$CLUSTER_NAME.env"`, 128-item count, `value="$(jq …)"`, `umask 077` file mode 600, length-only proxy print, `ns` guard).
Lab (read-only, server dry runs after the webhook check) is logged in `research/raw/live/2.19/networking-skill.txt`, section "Fix pass B" (dry runs 15-17).
Commits: `8bce976` (networking), `a7d0a6b` (nkp-install, lifecycle, router), and the last commit (this file).

## review-2.md: MAJOR

- M1 fixed. Credential check X0 with the USER-TERMINAL rule (skills/nkp-networking/references/proxy.md:7-20). Step 1 prints only `additionalNo` and the URL lengths (SKILL.md:69-73). X5 C uses `value="$(jq …)"` and prints nothing (proxy.md:234-242). Gatekeeper file in `(umask 077 && printf …)` (proxy.md:164). X6 line 1 prints only lengths (proxy.md:251). The N-23 check and lifecycle 3b are named USER-TERMINAL in X0.
- M2 fixed. AKS and EKS lines (proxy.md:124-126). Metal in N-23 (proxy.md:131; research/OPEN-ITEMS.md:64). Eval W9 (evals/nkp-networking.md:106). Help lines in networking-skill.txt.
- M3 fixed. See the nkp-install list below.
- M4 fixed. Server dry-run pod check (proxy.md:253), X4 Done-when (proxy.md:209). Flux env is not proof (proxy.md:259). Webhook check and dry run 16 logged.
- M5 fixed. `assets/no-proxy-base.txt` deleted. Literal `base` in both X2 blocks (proxy.md:65, :76). `dir` removed. The check script now allows the fixed guide entries 127.0.0.1, 169.254.169.254, 169.254.0.0/24, 10.0.0.0/16 (scripts/check_skills.py:32).
- M6 fixed. X4 step 2 is 2a write, 2b merge, 2c server dry run, 2d apply (proxy.md:155-187). Dry run 17 logged.

## review-2.md: MINOR

- 1 fixed (SKILL.md:38).
- 2 fixed (proxy.md:77, `"$HOME/nkp-$CLUSTER_NAME.env"`).
- 3 fixed: local table removed from proxy.md. The three proxy variables stay in the rules table.
- 4 fixed (references/ingress-certs.md:17, `[live 2.19.0]`, with the 2160h fact).
- 5 fixed: dry run 15 in networking-skill.txt. SKILL.md:128 has the split tags.
- 6 fixed: Hubble per-pod block (SKILL.md:106-116), renew block (ingress-certs.md:90-96), ACME dry run and apply blocks (ingress-certs.md:145-159), orders block (ingress-certs.md:169-175), M2 Done-when block (references/metallb.md:82-90).
- 7 fixed (metallb.md:98-128): N-20 check first, stop before the values.
- 8 fixed (proxy.md:228; N-22 row extended).
- 9 fixed (proxy.md:217, :58).
- 10 fixed (proxy.md:52 names `PC_ENDPOINT` and `REGISTRY_URL`; 128-item count at proxy.md:88-95).
- 11 fixed (proxy.md:128).
- 12 fixed (proxy.md:131).
- 13 fixed: W3 accepts the early stop (evals/nkp-networking.md:39-40), W9 (:106), W10 (:118).
- 14 fixed: cni.md:108 active voice, proxy.md:51-56 list, SKILL.md:128 and :131 split.
- 15 fixed (metallb.md:16-17).
- 16 fixed (proxy.md:27).

## review-2.md section 4: nkp-install

- 1 fixed (skills/nkp-install/references/cloud.md:67). `[pdf p.830]` removed.
- 2 fixed (references/nutanix.md:131).
- 3 fixed (references/metal.md:105).
- 4 fixed (references/preprovisioned.md:136).
- 5 fixed (references/nutanix.md:132).
- 6 fixed (references/cloud.md:40, C1 Done-when list).
- Note: the check script reads `` `references/x.md` `` as a local link, so the pointers use the house form "its file `proxy.md`".
- nkp-install SKILL.md is not changed (247 lines).

## Other scope items

- Lifecycle V5 fixed (skills/nkp-cluster-lifecycle/references/variables.md:104, :107).
- Router fixed (skills/nkp/SKILL.md:51-53). 148 lines.

## grading-2.md

- Fix 2 fixed for metallb.md: M2 plan and stop before the file write (metallb.md:50), M3 plan and stop before the file write (metallb.md:109). The nutanix.md part was done in pass A.
- Fix 3 fixed (references/cni.md:114).
- Fix 4: the skill changes for W3 (N-20 check output and early stop) are in minor 7. The rest is model behavior (name reuse, untagged facts). Not fixed.

## Not fixed

- The long step 1 jsonpath and the X5 A loop (review section 5, "risks"). A split adds lines and risk. The loop is one unit for the model.
- N-24 (where `gatekeeper-overrides` goes on a workload cluster) stays open. The X4 blocks now take `ns` from step 1.
- No eval run in this pass. Run W1, W2, W3, W9, W10 at the next eval run.

## OPEN-ITEMS

No new IDs. N-22 (host-agent controller) and N-23 (Metal) are extended.
