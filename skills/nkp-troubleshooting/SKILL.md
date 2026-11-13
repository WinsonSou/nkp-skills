---
name: nkp-troubleshooting
description: >
  NKP troubleshooting: something is broken or stuck and the cause is not known. Debug ladder,
  nkp diagnose support bundle (also air-gapped, pre-pivot, API down), symptom → skill index,
  stuck rollout of Machines, MachineDeployments, or KubeadmControlPlane, stuck delete and finalizers,
  HelmRelease or Kustomization not Ready, CAPX and CAREN controller logs, failed kind bootstrap cluster.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-02"
  sources: "live 2.19.0, pdf 2.19, field"
---

# NKP troubleshooting

<!-- RULES:BEGIN -->
## Rules for every NKP skill

1. **Marks.** Line 1 of each command block is `# READ-ONLY`, `# CHANGES`, or `# USER-TERMINAL`. CHANGES: it changes a cluster, the infrastructure, a registry, the container engine, or a file on the operator host. USER-TERMINAL: it shows a secret on the screen, or it runs on another host (the text after the mark names the host). Give it to the user to run in their own terminal. Do not run it.
2. **Approval.** Before a CHANGES block, show the command, the target, and the result. Stop. Run it only after the user types "yes" to that plan. "Just run it" is not "yes". If the user answers with another word (for example "proceed" or "ok"), ask them to type "yes".
3. **Env files.** Run blocks with bash. `~/nkp-site.env` holds the site values and the secrets. `~/nkp-<cluster>.env` holds the values of one cluster. Its first line is `source ~/nkp-site.env 2>/dev/null`. Line 2 of a block is `source ~/nkp-<cluster>.env 2>/dev/null` when the block uses a cluster-file variable. Otherwise line 2 is `source ~/nkp-site.env 2>/dev/null`. Before you run a block, replace `<cluster>` in `~/nkp-<cluster>.env` with the cluster name. If the user has not named the cluster, keep `~/nkp-<cluster>.env` in the block and ask for the name. Do not take a name from an example or another conversation. After the cluster env file exists, use its real name (for example `~/nkp-dev-01.env`) in every block that you show. Commands use the variables as `"$VAR"`.
4. **Values.** When you know a value, append one line to its file: `echo "export VAR='value'" >> ~/nkp-site.env` (CHANGES). Write a line only after the user gives or confirms the value. Ask first, and write the line in a later reply, after the answer. If the user has not given the value, do not show the append block. Do not put an example or a guessed value in it. Never write an empty value or a placeholder such as `<ip>`. A shell value inside a block (for example `obj=''`) stays empty, with its `:?` guard, until the user gives it. Never put `<...>` text in it. To change a value, append a new line. The last line wins. Some skill files add a `| File | Site variables |` table with more variables. For a value with no variable in these tables, make an UPPER_SNAKE name and ask the user. If `~/nkp-site.env` does not exist, make it: `touch ~/nkp-site.env && chmod 600 ~/nkp-site.env` (CHANGES).
5. **Secrets.** The user types the secret lines into `~/nkp-site.env` with an editor. Do not repeat or use a secret from the chat, and do not write it into an example line. Tell the user to put it in the file and to change it. Check a secret only with `printenv VAR >/dev/null` or `[ -n "$(printenv VAR)" ]`. Never print an env file, `env`, `set`, a kubeconfig, or Secret data.
6. **Unknowns.** Use only the UNKNOWN lines in the skills: `UNKNOWN (<id>): <what>. Find out with: <command>`. Run the check or ask the user. For a fact that is not in the skills, say "not in the skills" and give a READ-ONLY check. Never make up an ID or a fact.
7. **Offline.** Use only these skills, the bundle, `--help`, and the cluster. Read versions from the cluster or from `nkp version`.
8. **Tags.** `[live 2.19.0]` live cluster · `[pdf p.N]` NKP 2.19 guide · `[portal]` Nutanix portal · `[field]` not confirmed. Trust them in this order.

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `MGMT_KUBECONFIG` `BUNDLE_DIR` `IMAGE_BUNDLES` `REGISTRY_URL` `REGISTRY_CA_FILE` `PC_ENDPOINT` `PC_CA_FILE` `PC_PROJECT` `PE_CLUSTER` `SUBNET` `STORAGE_CONTAINER` `VM_IMAGE` `SSH_PUBKEY_FILE` `NTP_SERVERS` `NKP_HTTP_PROXY` `NKP_HTTPS_PROXY` |
| `~/nkp-site.env` secrets | `NUTANIX_USER` `NUTANIX_PASSWORD` `REGISTRY_MIRROR_USERNAME` `REGISTRY_MIRROR_PASSWORD` `NUTANIX_REGISTRY_USERNAME` `NUTANIX_REGISTRY_TOKEN` |
| `~/nkp-<cluster>.env` | `CLUSTER_NAME` `CP_VIP` `LB_IP_RANGE` `WORKSPACE_NS` `CLUSTER_KUBECONFIG` `NO_PROXY_LIST` |
<!-- RULES:END -->

## What this skill does

This skill finds the broken layer and the failing object. Then it names the owner skill of the fix. It owns the debug ladder, `nkp diagnose`, and the generic playbooks: stuck rollouts, stuck deletes and finalizers, Flux diagnosis, controller logs, and bootstrap (kind) cluster failures.

- Do the ladder from the top. Show rungs 1, 2, and 3 before rung 4, also when the symptom points to a lower rung. Stop at the first rung that is not healthy. The cause is usually there or one rung lower.
- All ladder commands are READ-ONLY. A fix is a CHANGES command in the owner skill. Do not make a change to "try" a fix.
- `Cluster`, `MachineDeployment`, `KubeadmControlPlane`, and `MachineHealthCheck` belong to the NKPCluster topology. Read them. Change them only with skill `nkp-cluster-lifecycle`. [live 2.19.0]
- Do not assume an automatic rollback. [pdf p.1044]

| Job | Where |
|---|---|
| Find what is broken | step 1, then the ladder (step 2) |
| Symptom is known | step 3 (symptom → skill) |
| Machine, pool, or control plane stuck in a rollout, a scale, or a node replace | [references/rollouts.md](references/rollouts.md) |
| Object stuck in `Terminating` or deleting; finalizers | [references/deletes.md](references/deletes.md) |
| HelmRelease, Kustomization, AppDeployment, or source not Ready | [references/flux.md](references/flux.md) |
| CAPX, CAREN, CAPI, CAAPH, NKP controller logs; bootstrap (kind) cluster | [references/controllers.md](references/controllers.md) |
| Support bundle for Nutanix support: `nkp diagnose` | [references/diagnose.md](references/diagnose.md) |

## Step 1: Select the cluster

Ask the user: which cluster, what changed last (create, upgrade, scale, app change, infrastructure change), and when the problem started.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,PLATFORM:.status.platformVersion'
```

- `get nodes` fails or times out: the management API does not answer. Go to [references/diagnose.md](references/diagnose.md), section "API server down".
- Before the pivot (the first create still runs), the objects are on the bootstrap cluster. Go to [references/controllers.md](references/controllers.md), section "Bootstrap cluster".
- A healthy NKPCluster has PHASE `Reconciled`. The other phases are `Reconciling Platform Applications` and `Reconciling Kubernetes and Cluster Infrastructure`. [live 2.19.0]

Check the cluster env file of the cluster. If it does not exist, make it with skill `nkp-cluster-lifecycle`, step 1.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when: `get nodes` answers and the block prints `set:` for all four names.

## Step 2: The debug ladder

**Rung 1. NKPCluster.** Print the phase and every condition that is not in its healthy state.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='phase={.status.phase}{"\n"}{range .status.conditions[*]}NKP {.type}={.status} {.reason}: {.message}{"\n"}{end}{range .status.capiCluster.conditions[*]}CAPI {.type}={.status} {.reason}: {.message}{"\n"}{end}' \
  | awk -F'[= ]' 'NR==1 || (($2 ~ /^(RollingOut|ScalingUp|ScalingDown|Remediating|Paused|Deleting)$/) ? $3!="False" : $3!="True")'
```

- Healthy: only the `phase=Reconciled` line. The types `RollingOut`, `ScalingUp`, `ScalingDown`, `Remediating`, `Paused`, and `Deleting` are healthy when `False`. All other types are healthy when `True`. Each line that the block prints is a problem. [live 2.19.0]
- `TopologyReconciled` not `True`: the message names the topology or CAREN patch error. Read the CAREN log ([references/controllers.md](references/controllers.md)).
- The guide gives two common causes of a long `Reconciling`: a missing credential Secret, or an image that is not in the infrastructure. [pdf p.1048]

**Rung 2. CAPI objects.**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplanes,machinedeployments,machines,machinehealthchecks -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
```

- Healthy: every `Machine/` row of `nkp describe cluster` has READY `True`. The `Cluster/` and `ControlPlane` rows can have an empty READY column. [live 2.19.0] All machines are PHASE `Running`, READY `True`, UP-TO-DATE `True`. [live 2.19.0]
- A machine that is not `Running`, or DESIRED ≠ READY on a pool or the control plane: [references/rollouts.md](references/rollouts.md).
- A machine with PHASE `Deleting` for more than 15 minutes: [references/deletes.md](references/deletes.md).

**Rung 3. Cluster addons (CAREN through CAAPH).** CNI, CSI, CCM, MetalLB, autoscaler, and the other addons are `HelmReleaseProxy` objects in the cluster namespace on the management cluster. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmreleaseproxies -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
```

Healthy: READY `True`, STATUS `deployed`. [live 2.19.0] If not, read the CAAPH log ([references/controllers.md](references/controllers.md)). The addon itself has an owner skill (step 3).

**Rung 4. Platform apps (Kommander and Flux).**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.kommanderCluster.conditions[?(@.status!="True")]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -v -w True
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get kustomizations -A | grep -v -w True
```

Healthy: the first command prints nothing, and the other two print only the header line. [live 2.19.0] The HelmReleases and Kustomizations of a cluster are on that cluster. [pdf p.1047] A line that is not `True`: [references/flux.md](references/flux.md).

**Rung 5. Workloads and nodes in the cluster.**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | awk 'NR==1 || ($4!="Completed" && ($4!="Running" || substr($3,1,index($3,"/")-1)!=substr($3,index($3,"/")+1)))'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -30
```

The pod list shows each pod that is not `Running` and ready (for example `CrashLoopBackOff`, or READY `0/1`), except `Completed`. For each such pod, run `kubectl describe pod` and `kubectl logs --previous` on it. Find the namespace or the error text in step 3. A general Kubernetes problem (a user app, a probe, a quota): skill `kubernetes-core`.

**Rung 6. Node.** A node that is `NotReady`, or a machine with no node: [references/rollouts.md](references/rollouts.md), section "Node-level checks". These run on the node (USER-TERMINAL).

**Rung 7. Support bundle.** When the cause is still not known, or Nutanix support asks for it: [references/diagnose.md](references/diagnose.md).

Done when: you can name the failing object, its message, and the owner skill from step 3. Or the user has a support bundle.

## Step 3: Symptom → skill

Find the first column that matches the message or the object. Load the owner skill for the fix. The middle column is the first check here.

| Symptom (message, object, or namespace) | First check | Owner of the fix |
|---|---|---|
| Preflight fails on `nkp create cluster`; bootstrap cluster does not start | [references/controllers.md](references/controllers.md), "Bootstrap cluster" | `nkp-install` |
| Machine stays `Provisioning`; `NutanixMachine` `VMProvisioned` not `True` | CAPX log | `nkp-install` (values), the Prism Central admin |
| Machine `Provisioned` but no node; node `NotReady` after create | [references/rollouts.md](references/rollouts.md) | the row of the error that you find |
| Rollout, scale, or node replace does not end | [references/rollouts.md](references/rollouts.md) | `nkp-cluster-lifecycle` |
| Delete does not end; object `Terminating`; finalizers | [references/deletes.md](references/deletes.md) | `nkp-cluster-lifecycle` (cluster delete) |
| `ImagePullBackOff`, `ErrImagePull`, `x509` from a registry, `manifest unknown` | `kubectl describe pod` | `nkp-airgap` |
| `nkp diagnose` node collector does not start (air-gapped) | [references/diagnose.md](references/diagnose.md) | `nkp-airgap` |
| `cilium`, `kube-vip`, `metallb-system`, `nutanix-cloud-controller-manager`, Traefik, cert-manager, proxy, MTU, `LoadBalancer` `<pending>`, DNS | rung 3 and rung 5 | `nkp-networking` |
| Pod `Pending` with an unbound PVC; `ntnx-system` CSI pods; `VolumeSnapshot`; Velero; Rook Ceph `dkp-object-store` | `kubectl describe pvc` | `nkp-storage-backup` |
| HelmRelease, Kustomization, AppDeployment not Ready; `exhausted`; `another rollback/release in progress` | [references/flux.md](references/flux.md) | `nkp-platform-apps-gitops` |
| `admission webhook "validation.gatekeeper.sh" denied`; Dex or login fails; `403 Forbidden` for a user; license | `kubectl describe` on the denied object | `nkp-identity-security` |
| `spec.topology: Forbidden: CAPI Cluster topology spec is managed by NKPCluster` | which tool wrote the `Cluster` (a Flux Kustomization, a script) | `nkp-cluster-lifecycle`; during an upgrade `nkp-upgrade` [pdf p.1048] |
| `nkp upgrade` fails or times out; version mismatch; `docker.io/nutanix credentials are missing` | rerun with `-v 6` [pdf p.1047] | `nkp-upgrade` |
| MachineHealthCheck does not replace an unhealthy node | [references/rollouts.md](references/rollouts.md) | `nkp-cluster-lifecycle` |
| Control-plane certificates expire or expired | NKPCluster `certificatesExpiryDate` | `nkp-cluster-lifecycle` |
| Prometheus, Grafana, alerts, logging, Loki | rung 4 | `nkp-observability` |
| GPU not visible, `nvidia-*` or `amd-*` pods fail | rung 5 | `nkp-gpu-ai` |
| Flow CNI pods; cluster in a Flow VPC (floating IP, overlay subnet); NDK | rung 5 | `nkp-flow-cni`, `nkp-vpc`, `nkp-ndk` |
| `konnector-agent` stays in `Init` | `kubectl describe pod` in `ntnx-system` | `nkp-install` |

If no row matches, give the user the failing object and its message. Say "not in the skills". Offer the support bundle.

## Related skills

Architecture and names: skill `nkp`. Cluster changes: skill `nkp-cluster-lifecycle`. Bundle, registry, and pre-staged images: skill `nkp-airgap`.
