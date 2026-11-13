# Batch 5 fix pass: nkp-flow-cni (and its cross-skill rows)

Date 2026-11-03. Scope: `review.md` M1, minors 7, 8, 9, 10, 11 (the flow `egress-vpc.md` parts), 12, the section 5 `metallb.md` row, and `grading.md` minor 1.
Checks: `check_skills.py --self-test` and `check_skills.py` pass (16 skills, 0 errors). `bash -n` passes on all command blocks of `nkp-flow-cni` (SKILL.md 3, install.md 9, egress-vpc.md 8), `nkp-networking/references/metallb.md` (9), and `nkp-upgrade/SKILL.md` (9). Line counts: SKILL.md 182, install.md 203, egress-vpc.md 131, metallb.md 140, nkp-upgrade SKILL.md 227.
Lab: no lab check. The M1 check needs a server dry run of a Nutanix workload cluster with a real Prism Central (N-23, N-31). That is not a 10-minute check. N-31 stays open. I tested the new `yq` filter with mikefarah yq v4.47.1 on the synthetic review file (`/tmp/rvb5/c1-dryrun.yaml`: a Secret, an NKPCluster, a Cluster), as single objects and wrapped in one `List`. Both forms print only `<kind> <name>  addons: <keys>`, and no Secret line.

## review.md

- M1 fixed (skills/nkp-flow-cni/references/install.md, I5). I5 now has two READ-ONLY blocks. Block 1 is the `-o name` dry run. Block 2 is the same dry run with `-o yaml`, piped into a `yq` filter that prints only the kind, the name, and the addon key names. The filter uses `(.items // [.]) | .[]`, so it works for the object-by-object output and for the `List` form. The text names the three mutating webhooks [live 2.19.0] and says never to print `-o yaml` without the filter (it holds the Secrets). "Done when": no `addons:` line has `cni`. A `cni` line means a webhook added the CNI back (N-31): stop, do not do I6. No `addons:` line: stop. OPEN-ITEMS N-31 notes the new check and stays open.
- minor 7 fixed (references/egress-vpc.md, E2 steps 4-5). The annotate command sets only `metallb.io/address-pool`. Step 4 says that the guide name `metallb.io/ipaddresspool` has no effect on MetalLB 0.15.3 `[portal][field: MetalLB v0.15.3 source]` and points to `metallb.md` for the annotation. The step 5 plan tells the user that the Service gets a new IP and that clients of the old IP stop working. The wrong line "keeps it" is replaced. N-35 is closed (UNKNOWN line removed, OPEN-ITEMS row closed).
- minor 8 fixed (install.md, I4). After the two `yq` reads: `[ -n "$pod" ] && [ "$pod" != null ] && [ -n "$svc" ] && [ "$svc" != null ] || { echo "no CIDRs in the dry-run file"; exit 1; }`, then `: "${CP_VIP:?}" "${CLUSTER_NAME:?}" "${WORKSPACE_NS:?}"`. Tested with `pod=null`: the guard stops.
- minor 9 fixed (install.md, I4). New line before the safe `grep -v` block: never read the HCP or its HelmReleaseProxy with `-o yaml`, `-o json`, or `describe`; the values hold the token (rule 5).
- minor 10 fixed (SKILL.md, Common failures, `ImagePullBackOff` row). The fix writes the HCP file again (I4), then applies only the HCP file, with "CHANGES, plan, "yes"" and the exact command.
- minor 11 fixed (egress-vpc.md). Line 3 points to the SKILL.md "Job → section" table, not to "step 5". The inline commands with shell values (E1 step 3 dry run, E2 step 3 dry run, E2 step 6 check) are now READ-ONLY blocks with the empty value and its `:?` guard. The E1 step 5 check and the N-33 check use no shell value and stay inline. The `replication.md:190` part is not in my scope (owner nkp-ndk).
- minor 12 fixed. install.md I7: "show the plan (the three files), and stop for "yes"" before the delete block. SKILL.md "Delete": the inline `delete helmchartproxy` is now a block with `# CHANGES` on line 1 and the `source` line on line 2, after "show the plan (the HCP name and namespace), stop for "yes"".

## Section 5 (cross-skill)

- `metallb.md` row fixed (skills/nkp-networking/references/metallb.md:81). The annotation `metallb.io/address-pool` (and the old `metallb.universe.tf/address-pool`) has `[field: MetalLB v0.15.3 source]`. New sentence: when the annotation names another pool than the pool of the current IP, MetalLB gives a new IP from the requested pool, and clients of the old IP stop working.
- nkp-upgrade (skills/nkp-upgrade/SKILL.md, step 2, under the gate table): one line that points to skill `nkp-flow-cni`, section "What changes on a Flow CNI cluster" (N-34), before the upgrade of a Flow CNI workload cluster. No Flow facts are copied.
- research/nkp-component-map.md §6: new row "Flow CNI chart and images": chart `nutanix-flow-cni` 1.1.0 is served by the CAREN chart server; the images are not in the NKP bundle [live].

## grading.md

- Minor 1 (L7) fixed with a text change (SKILL.md step 1): the ports that Flow CNI needs between the nodes are UNKNOWN F-04, with a pointer to `egress-vpc.md` V1. Do not give a port list or firewall advice from general OVN, Geneve, or MetalLB knowledge. Eval L7 is not changed.

## OPEN-ITEMS

- N-31: still open. The row notes that I5 block 2 now checks the addon keys after the webhooks.
- N-35: closed (MetalLB v0.15.3 source, `controller/service.go`).
- F-*, N-30, N-32, N-33, N-34, N-36: no change.
- The "Last updated" line is not changed (the parent does it).

## Not done, and changes other files need

- Re-run evals L2, L4, and L7 (not run in this pass). Eval IDs are kept.
- M1 lab check: not done (needs a real Prism Central, N-23). Do it at the first Flow CNI lab test, and check that block 2 prints `addons:` lines on the real output.
- `replication.md:190` (`$ns` inline): owner nkp-ndk (minor 11, last part).
