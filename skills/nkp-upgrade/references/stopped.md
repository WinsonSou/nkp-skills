# If the upgrade stops

Use this file from skill `nkp-upgrade`. All blocks here are READ-ONLY. They find the stage that stopped and the skill that owns the fix. The debug ladder, `nkp diagnose`, and stuck rollouts are in skill `nkp-troubleshooting`.

Rules:
- An error does not start a repair or a rollback. [pdf p.1044] There is no downgrade in the skills.
- Do not delete Machines, Clusters, NKPClusters, or UpgradePlans. Do not edit the CAPI `Cluster`. [pdf p.1048]
- A warning that clears without action is normal while a part reconciles. [pdf p.1043] Wait 10 minutes, then check again.
- Record the stage, the part, and the message before you fix anything. [pdf p.1044]

## S1. Find the stage

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
tail -n 40 "$HOME/nkp-upgrade-kommander.log" "$HOME/nkp-upgrade-$CLUSTER_NAME.log" 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get managementplanes
kubectl --kubeconfig "$MGMT_KUBECONFIG" get upgradeplans -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.phase}{"\n"}{range .status.steps[*]}{"  "}{.name}{"\t"}{.state}{"\t"}{.error}{"\n"}{end}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
```

| What you see | Stage | Go to |
|---|---|---|
| `nkp upgrade kommander` failed; `nkp-platform` VERSION ≠ CURRENT VERSION | Kommander (step 4) | S2 |
| UpgradePlan phase `UpgradingManagementPlane`, `UpgradingKommander`, or `UpgradingPlatformApplications`, or a step with an `error` | platform apps | S2 |
| UpgradePlan phase `UpgradingKubernetes`, or NKPCluster `Reconciling` for a long time, or `nkp upgrade cluster` timed out | Kubernetes and infrastructure | S3 |
| `Check:` and `Message:` lines in the log | preflight check (nothing changed) | S4 |
| `docker.io/nutanix credentials are missing` | gate G2 | [dockerhub.md](dockerhub.md) |
| GitRepository catalog apps found | gate G5 | skill `nkp-platform-apps-gitops`, file `catalogs.md` K4 |
| Flux webhook error, or a deleted `Cluster` | GitOps | [gitops.md](gitops.md), "Failures" |

UpgradePlan phases: `ValidatingInputs`, `UpgradingManagementPlane`, `UpgradingKommander`, `UpgradingPlatformApplications`, `UpgradingKubernetes`, `Upgraded`, `Failed`. [live 2.19.0]

## S2. Kommander and platform apps

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get managementplanes -o jsonpath='{range .items[*].status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.message}{"\n"}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmreleases -A | awk 'NR==1 || $4!="True"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kustomizations -A | awk 'NR==1 || $4!="True"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pods -A | grep -E 'ImagePull|ErrImage|CrashLoop|Pending'
```

| Symptom | Owner of the fix |
|---|---|
| HelmRelease `exhausted` or "another rollback/release in progress" [pdf p.1047] | skill `nkp-platform-apps-gitops`, step 3 |
| HelmRelease "version not found" for a kommander chart: a run again of the same upgrade command fixed it [field] | ask the user, then run the step 4 block again |
| `ImagePullBackOff` or `ErrImagePull` (air-gapped) | an image of the target bundle is missing in the registry: skill `nkp-airgap` (step 4, then step 5) |
| A ManagementPlane condition is `False` | skill `nkp-troubleshooting` |
| Time-out, apps still progressing | ask the user. Run the step 4 block again with `--platform-apps-timeout 2h` (or longer) and `-v 6` [pdf p.1047][live 2.19.0] |

Run an upgrade command again only after the cause is fixed and the user agrees. The guide does this for the Kommander upgrade and after a failed preflight check. [pdf p.1017, p.1021]

## S3. Kubernetes and infrastructure

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}'
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o wide
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get events --sort-by=.lastTimestamp | tail -n 30
```

- The NKPCluster conditions on a healthy cluster are all `True`: `CAPIClusterAdopted`, `CAPIClusterTopologyUpToDate`, `CAPIClusterStatusSynced`, `CAPITopologyReconciled`, `KommanderClusterReady`, `KommanderClusterStatusSynced`, `PlatformAppsReconciled`, `KommanderClusterSynced`. [live 2.19.0] The first `False` condition shows the part that stopped.
- The control plane rolls first, then the pools. [pdf p.1043] Machines with the old version and one `Provisioning` machine are normal during the roll.

| Symptom | Owner of the fix |
|---|---|
| NKPCluster `Reconciling` with a credential or image message: missing credential Secret, or the image is not in Prism Central [pdf p.1048] | image: step 3 of skill `nkp-upgrade` (the user uploads the image). Credentials: skill `nkp-install` |
| A machine stays `Provisioning` or `Deleting`; a drain does not end (PDB) | skill `nkp-troubleshooting` |
| A new node is not `Ready` (CNI, CSI) | skill `nkp-networking` (CNI), skill `nkp-storage-backup`, file `csi.md` C8 (CSI) |
| Prism Central: no room for a new VM or IP | the infrastructure admin (gate G9) |
| `nkp update controlplane` "timed out waiting for the condition" | the machines may still roll. Check the versions (non-clusterclass.md, N4) before any action. [pdf p.1029] |

## S4. Preflight check failed

The preflight check runs before any change. [pdf p.1020] Read the `Check:`, `Message:`, and `Flag:` lines. Fix the value. Then run the dry run and the upgrade again. [pdf p.1021] Common causes: the image is not in Prism Central, or its name does not have the Kubernetes version. [pdf p.726] Use `--skip-preflight-checks=<name>` only when the user confirms that the check itself is wrong. Never use `all`.

## S5. Data for support

Use skill `nkp-troubleshooting` for `nkp diagnose`. Give support: the stage, the log file of the upgrade (`$HOME/nkp-upgrade-*.log`), and the S1 output.
