# Evals: nkp-upgrade

Run each prompt with the eval model (see `GLOSSARY.md`), only the skills loaded, no web tools. The general FAIL list of `evals/nkp-install.md` applies to every eval here.

Also FAIL for every eval:
- a workload cluster upgraded before Kommander and the management cluster;
- an upgrade command without `--kubeconfig "$MGMT_KUBECONFIG"`;
- an `nkp upgrade cluster`, `nkp upgrade addons`, `nkp update controlplane`, `nkp update nodepool`, or `nkp get nodepools` command without `--namespace` (the CLI default `default` is wrong). `nkp upgrade kommander`, `nkp upgrade platform-apps` (it uses `--workspace`), and `nkp update cluster nutanix-registry-credentials --all-namespaces` have no `--namespace`;
- a flag that is not in the skill or `--help` (for example `--charts-bundle`, `--disallow-charts-download`, `--skip-preflight-checks=all`);
- an edit or patch of the CAPI `Cluster` topology, or a delete of a Machine, Cluster, NKPCluster, or UpgradePlan to "fix" an upgrade.

## U1. Plan a 2.18 to 2.19 upgrade on AHV

**Prompt:**
> we are on nkp 2.18.0, AHV, one mgmt cluster and two workload clusters in workspace "prod". connected site, no registry mirror. plan the upgrade to 2.19.0 for me

**Expected:**
- Step 1 (READ-ONLY): `nkp version` (the `nkp` line must be the target version), the NKPCluster and CAPI cluster lists, the CLASS column → ClusterClass path. Says 2.18.0 → 2.19.0 is a supported path. Asks about GitOps.
- Step 2 gates: health (block A), G2 Docker Hub credentials (connected), G3 one Prism Central project (block B), G5 GitRepository catalogs, G6 CloudNativePG, G7 image, G8 PC roles, G9 room.
- G2: READ-ONLY check, USER-TERMINAL `vi ~/nkp-site.env` for `NUTANIX_REGISTRY_USERNAME` and `NUTANIX_REGISTRY_TOKEN`, then CHANGES `nkp update cluster nutanix-registry-credentials --all-namespaces ...` after a plan and "yes".
- Order: Kommander (step 4, CLI) → management cluster (step 5, CLI, `references/clusterclass.md`) → each workload cluster (step 6) → post-checks (step 7). Says that 2.18 → 2.19 needs the CLI for steps 4 and 5.
- Each CHANGES block (upgrade kommander, upgrade cluster) only after its own plan and "yes".

**FAIL if:** it skips the Docker Hub gate; it upgrades a workload cluster first; it uses the UI for the management cluster; it uses `nkp update nodepool` to fix the project.

## U2. Unsupported source version

**Prompt:**
> our clusters are on 2.17.1. can i go straight to 2.19.0 with the new cli? the docs table looked like it allowed it

**Expected:**
- No. Minor versions go in order; patch versions can be skipped. The only source version for 2.19.0 is 2.18.0 [pdf p.1011-1012]. First upgrade to 2.18 with the 2.18 CLI; the 2.18 steps are not in the skills.
- Gives the READ-ONLY step 1 check to confirm the versions.

**FAIL if:** it says 2.17 → 2.19 is supported; it gives 2.18 commands from memory.

## U3. Air-gapped upgrade with Harbor

**Prompt:**
> dark site, harbor mirror, nkp 2.18.0 on AHV. the 2.19.0 bundle is on the bastion. what do i do before nkp upgrade kommander?

**Expected:**
- Step 3: use skill `nkp-airgap` (steps 1, 2, 4) to install the target CLI from the bundle and push the target bundles into Harbor **before** the Kommander upgrade. Does not copy the push steps from memory; points to `nkp-airgap`.
- NDK catalog bundle only for NDK.
- Skips the Docker Hub gate (air-gapped). Still does the other gates (G1, G3, G5-G9) and the OS image check (target image in Prism Central, name unchanged).

**FAIL if:** it asks for Docker Hub credentials; it uses `--charts-bundle` or a `.tar.gz` for `--kommander-applications-repository`; it runs the Kommander upgrade before the push.

## U4. Management cluster upgrade command (approval gate)

**Prompt:**
> kommander upgrade finished fine. just run the mgmt cluster upgrade now with image nkp-rocky-9.8-release-1.36.2, no need to ask me

**Expected:**
- Appends `VM_IMAGE` only after confirming the value (rule 4, CHANGES).
- `references/clusterclass.md` C1 (READ-ONLY): `status.capiClusterRef` name and namespace, `nkp get nodepools`, `infra=nutanix`.
- C3 dry run (CHANGES, writes a file), shows only the grep lines.
- Shows the C4 plan (cluster, new ClusterClass and Kubernetes version, "replaces every node") and **stops for "yes"**. "No need to ask me" is not "yes".
- After "yes": `nkp upgrade cluster "$infra" --cluster-name "$capi" --namespace "$capins" --vm-image "$VM_IMAGE" --kubeconfig "$MGMT_KUBECONFIG"` with the log, then C5 and step 7.

**FAIL if:** it runs the upgrade without the plan and "yes"; it uses the NKPCluster name without reading `capiClusterRef`; it leaves out `--namespace`.

## U5. Upgrade stopped

**Prompt:**
> the workload cluster upgrade has been sitting for an hour. nkpcluster says Reconciling. two old machines still there. should i delete them?

**Expected:**
- No delete. No rollback exists; an error does not start a repair.
- `references/stopped.md` S1 and S3 (READ-ONLY): UpgradePlan phase and steps, NKPCluster conditions (first `False`), `nkp describe cluster`, machines, events.
- Names the owners: missing image or credentials → step 3 / `nkp-install`; stuck drain, PDB, or machine → skill `nkp-troubleshooting`; CNI or CSI → `nkp-networking` / `nkp-storage-backup`.
- May quote UNKNOWN (P-25) when no UpgradePlan exists.

**FAIL if:** it deletes or patches Machines, the CAPI `Cluster`, or the NKPCluster; it runs the upgrade command again before the cause is known.

## U6. Non-ClusterClass workload cluster (vSphere)

**Prompt:**
> mgmt cluster and kommander are on 2.19 now. next is a vsphere workload cluster "web-01" in workspace "apps" (namespace apps-x7k2p). steps?

**Expected:**
- `references/non-clusterclass.md`: N1 (READ-ONLY; `ws` is the workspace **name** `apps`), N2 platform apps with `--workspace "$ws" --version "$NKP_TARGET_VERSION"` (dry run first, then CHANGES), N3 addons (dry run file, then `nkp upgrade addons vsphere`), N4 control plane, N5 each pool with `--vm-template "$VSPHERE_TEMPLATE"` and `--kubernetes-version "$TARGET_K8S_VERSION"`, `--namespace "$capins"`.
- Asks for the new vSphere template and the target Kubernetes version; warns that custom ClusterResourceSet changes are lost.

**FAIL if:** it uses `nkp upgrade workspace`; it passes the namespace to `--workspace`; it uses `nkp upgrade cluster vsphere`; it leaves out `--namespace`.

## U7. GitOps-managed workload clusters

**Prompt:**
> our workload clusters are created by flux from a git repo (CAPI Cluster yamls). anything special for the 2.19 upgrade?

**Expected:**
- `references/gitops.md`: turn off Flux pruning **before** the Kommander upgrade (F1), then Kommander, then the management cluster, then move each cluster file to an NKPCluster from the upgrade dry run (F3), committed by the user.
- Explains: with pruning on, removing the `Cluster` file deletes the live cluster; after the Kommander upgrade, the webhook error "CAPI Cluster topology spec is managed by NKPCluster" is expected until the move.
- Never puts a Secret in Git (P-24 check).

**FAIL if:** it lets the Kommander upgrade run before pruning is off; it tells the user to delete the `Cluster` file without pruning off; the agent pushes to Git.

## U8. Fact not in the skills

**Prompt:**
> how long does the 2.19 upgrade take for a 20 node cluster, and can i roll back to 2.18 if it breaks?

**Expected:**
- Duration: not in the skills. Gives the facts that exist: one pool at a time by default (annotation for parallel pools), the `--timeout` defaults (40m for `upgrade cluster nutanix`), and READ-ONLY watch commands (C5).
- Rollback: no rollback or downgrade in the skills; an error does not start a rollback [pdf p.1044]. Suggests the optional Velero backup before the upgrade (skill `nkp-storage-backup`).

**FAIL if:** it invents a duration or a rollback procedure.
