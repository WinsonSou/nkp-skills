---
name: nkp-flow-cni
description: >
  Nutanix Flow CNI on NKP (AHV only, OVN-Kubernetes): prerequisites, create a workload cluster with Flow CNI
  in place of Cilium (HelmChartProxy method), Flow CNI images on a dark site, check the Flow CNI pods,
  namespaces in Flow VPCs, EgressIP and EgressService.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-03"
  sources: "live 2.19.0, portal (Flow Virtual Networking Guide 7.6), field"
---

# NKP Flow CNI

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

Flow CNI is the Nutanix CNI on OVN-Kubernetes (OVN and OVS, Geneve overlay). It connects the pods to Nutanix VPCs, so pods and VMs can share one overlay. [portal] It replaces Cilium. The NKP 2.19 guide does not document it; the source is the Flow Virtual Networking Guide 7.6. [portal]

| Fact | Value |
|---|---|
| Where | Nutanix AHV clusters only. The AHV ClusterClass `nkp-nutanix-v2.19.0` allows the CNI providers `Calico`, `Cilium`, `Flow`; the other classes do not allow `Flow`. [live 2.19.0] |
| Default | Off. A default AHV cluster runs Cilium. [live 2.19.0] |
| When | Only at create time. You cannot change the CNI of a running cluster (skill `nkp-networking`, step 3). |
| Chart | `nutanix-flow-cni` 1.1.0. The management cluster serves it from the CAREN chart server `oci://helm-repository.caren-system.svc/charts`. [live 2.19.0] |
| Images | On the private `docker.io/nutanix` repository, with a token from the Nutanix portal. [portal] Not in the NKP 2.19.0 bundle. [live 2.19.0] |
| Namespaces | `flow-cni-system` [portal]; also `flow-cns-system` and `ovn-kubernetes` [field] |
| Egress objects | `EgressIP`, `EgressService` (`k8s.ovn.org/v1`) [portal] |
| LoadBalancer IPs | Flow CNI gives none. MetalLB stays (skill `nkp-networking`). [portal] |

This skill covers a **workload cluster** with Flow CNI. A management cluster with Flow CNI is not in the skills.

## Job → section

| Job | Where |
|---|---|
| Can this site use Flow CNI? | step 1 |
| Dark site: get the Flow CNI images | step 2 |
| Create a workload cluster with Flow CNI | step 3, then [references/install.md](references/install.md) |
| Check a Flow CNI cluster | step 4 |
| Put namespaces in a VPC, fixed egress source IP | [references/egress-vpc.md](references/egress-vpc.md) |
| Cilium or Calico, MetalLB pools, proxy, MTU of Cilium | skill `nkp-networking` |
| Cluster nodes on a VPC overlay subnet, floating IPs | skill `nkp-vpc` |

## Step 1: Check the prerequisites

Flow CNI 1.1.0 needs all of these. [portal] Ask the user for the items that the cluster cannot show (Prism Central, AOS, AHV, Network Controller).

| Item | Need |
|---|---|
| NKP | 2.18 or later |
| Node OS | **Rocky Linux** on all nodes. NKP 2.19 has a pre-built Rocky Linux 9.8 image (skill `nkp-install`, N1). |
| AOS, AHV | AOS 7.6 or later, AHV 11.2 or later |
| Prism Central | pc.7.6 or later. pc.7.5 is not enough. |
| Network Controller | 7.6.0 or later, Flow in **Integrated with Prism Central** mode |
| Node subnets | VLAN Basic (AHV-managed) subnets |
| Prism Central onboarding | the cluster is onboarded (the create default `--onboard-to-prism-central=true` [live 2.19.0]) |
| CIDRs | pod and service CIDRs do not overlap any VPC CIDR or other cluster |
| Egress service | MetalLB in Layer 2 mode (the AHV default [live 2.19.0]) |

- Use only the Integrated mode. Two guide pages disagree about the Standalone Flow Controller (open item F-09, no check command). Ask the Prism Central admin for the mode (Settings > Flow Management).
- UNKNOWN (F-08): the node CPU and memory that Flow CNI adds, and the license tier that it needs. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get licenses -A -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'`, then ask Nutanix.
- The ports that Flow CNI needs between the nodes are not known: UNKNOWN F-04 ([references/egress-vpc.md](references/egress-vpc.md), V1). Do not give a port list or firewall advice from general OVN, Geneve, or MetalLB knowledge.
- Nodes on a VPC overlay subnet do not meet the VLAN Basic need. Do not combine them with Flow CNI (open item N-04, no check command).

Check the parts that NKP can show:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
echo "VM_IMAGE=$VM_IMAGE"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get clusterclass -o custom-columns='NAME:.metadata.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get --raw "/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy/v2/charts/nutanix-flow-cni/tags/list"; echo
```

Done when all these are true:
- The image name has `rocky`. If not, ask the user for a Rocky image name in Prism Central (skill `nkp-install`, N1).
- The workspace namespace has a class `nkp-nutanix-v2.19.0` (or the class of the NKP version).
- The ConfigMap prints `ChartName: nutanix-flow-cni` and a `ChartVersion`. The tag list has the same version. [live 2.19.0]
- The user confirms the Prism Central, AOS, AHV, Network Controller, mode, and subnet items.

If one item fails, stop. Tell the user which item fails. Do not go on with Cilium in its place without the user's word.

UNKNOWN (F-01): whether a newer Flow CNI chart than the one that the management cluster serves is supported with NKP 2.19 (a field site used 1.3.0 on 2.18 [field]). Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}'`. Use the version that this command prints.

## Step 2: Dark site: the Flow CNI images

Skip this step on a connected site. A connected site uses the pull token (references/install.md, I4).

The chart is on the management cluster already (step 1). The images are not in the NKP bundle. [live 2.19.0]

1. The user gets the Flow CNI dark-site bundle (`flow-cni-1.1.0` in the guide [portal]) from the Nutanix portal: skill `nkp-airgap`, its file `prestage.md`, P8. The bundle version must be the same as the chart version of step 1.
2. Push it into the site registry mirror of the workload cluster: skill `nkp-airgap`, step 4, the "extra bundle" block (`EXTRA_BUNDLE`). The guide pushes it into a Harbor on the management cluster [portal]; use the registry that the cluster uses as its mirror (skill `nkp-install`, N5 step 1).

UNKNOWN (N-30): the image names and tags in the Flow CNI dark-site bundle, and whether the registry mirror rewrite of NKP finds them. Find out with: `source ~/nkp-site.env 2>/dev/null && tar -tf "$EXTRA_BUNDLE" | grep '/_manifests/tags/[^/]*/$'`.

Done when: the push ends without an error.

## Step 3: Choose the install path

| Path | How | Status |
|---|---|---|
| **A** (use this) | Dry-run YAML of the create, remove `addons.cni`, add a `HelmChartProxy` for `nutanix-flow-cni`, apply both. The method of the Flow guide. [portal] | Documented. No lab test yet. Follow [references/install.md](references/install.md). |
| B | `clusterConfig.addons.cni.provider: Flow` in the cluster YAML. The schema accepts it, with `strategy: HelmAddon`, `values.sourceRef` (a ConfigMap), and `imagePullCredentials.secretRef.name` (a Secret that CAREN copies to the cluster). CAREN 0.62.7 has a Flow values template. [live 2.19.0] | **Not tested, no Nutanix support statement.** Not in the skills. |

UNKNOWN (F-02): whether path B (`addons.cni.provider: Flow`) works and has Nutanix support. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-nutanix-flow-cni-helm-values-template -o jsonpath='{.data.values\.yaml}'`. Use path A until a lab test or Nutanix confirms path B.

`nkp create cluster` has no CNI flag. [live 2.19.0] The other create flags and the IP plan: skill `nkp-install`, its file `nutanix.md`, N1 to N5.

Done when: the user chose path A. Then do [references/install.md](references/install.md), I1 to I6.

## Step 4: Check the new cluster

1. Wait for the cluster and the kubeconfig: skill `nkp-install`, steps "Set the kubeconfig variables" (workload cluster) and "Verify". The nodes stay `NotReady` until the Flow CNI pods run.
2. Read the Flow CNI state:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmchartproxy "$CLUSTER_NAME-flow-cni" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CLUSTER:.spec.clusterRef.name,CHART:.spec.chartName,VERSION:.spec.version,READY:.status.conditions[?(@.type=="Ready")].status'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'flow-cni|flow-cns|ovn'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ds -A | grep -E 'cilium|kube-proxy|ovn|flow'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get pods
```

Done when all these are true:
- The HCP conditions show `Ready=True`, and one HelmReleaseProxy for the cluster with chart `nutanix-flow-cni` shows READY `True`.
- All nodes are `Ready`.
- All Flow CNI and OVN pods are `Running` and ready. No `cilium` DaemonSet exists.
- The `konnector-agent` pod in `ntnx-system` is `Running` (the Prism Central onboarding). [live 2.19.0]
- The user sees the cluster in Prism Central.

## What changes on a Flow CNI cluster

- No Cilium: no Hubble, no `cilium-dbg`, no Cilium values ConfigMap. Skill `nkp-networking` sections for Cilium (Hubble, DSR, custom Cilium values) do not apply.
- `kubeProxy.mode` stays as the create made it. UNKNOWN (F-06): whether `kubeProxy.mode: disabled` (the Cilium default) is correct for Flow CNI. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get ds kube-proxy`.
- UNKNOWN (F-07): which platform apps need Cilium (for example `cilium-hubble-relay-traefik`), and what breaks on a Flow cluster. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -v -E 'True'`.
- MTU: AHV gives a Geneve overlay guest MTU of 1442 (1500 − 58). [portal] UNKNOWN (F-05): whether the Flow CNI values must set an MTU. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ovn-kubernetes get configmaps -o yaml | grep -i mtu`.
- NKP upgrade: the HCP of path A has a fixed chart version. UNKNOWN (N-34): what an NKP upgrade does to the Flow CNI HCP, and whether the new CAREN chart server still has the old chart version. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get --raw "/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy/v2/charts/nutanix-flow-cni/tags/list"` before and after the upgrade. Tell the user this before an upgrade (skill `nkp-upgrade`).
- Delete: the HCP of path A has no owner, so it can stay after the cluster delete. After the delete (skill `nkp-cluster-lifecycle`), show the plan (the HCP name and namespace), stop for "yes", and run the block below. UNKNOWN (N-36): whether the HCP and the Prism Central objects of the cluster (the Shared Services VPC) stay after `nkp delete cluster`. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmchartproxies`, and ask the user to check the VPC list in Prism Central.

```bash
# CHANGES  (deletes the Flow CNI HelmChartProxy of a deleted cluster on the management cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete helmchartproxy "$CLUSTER_NAME-flow-cni"
```

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| The dry-run file is empty after the CNI edit | The guide `yq` command has no input file. [portal] | Make the dry run again (install.md, I2). Use the I3 block. |
| Cilium pods run on the new cluster | `addons.cni` was not removed. | Check with install.md I3. The CNI cannot change on a running cluster: delete the cluster (skill `nkp-cluster-lifecycle`) and create it again. |
| Nodes stay `NotReady`, no Flow CNI pods | The HCP does not select the cluster, or the chart install failed. | Step 4 block 2: read the HCP conditions and the HelmReleaseProxy. Check the HCP namespace and the `cluster.x-k8s.io/cluster-name` label. |
| Flow CNI pods in `ImagePullBackOff` | Connected: wrong or old pull token. Dark site: images not in the mirror (step 2). | Connected: the user makes a new token and changes the two lines in `~/nkp-site.env`; write the HCP file again (I4), then apply only the HCP file (CHANGES, plan, "yes"): `kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"`. Dark site: step 2. |
| Pods have no network, OVN pods crash | `podNetwork` or `serviceNetwork` does not match the cluster CIDRs, or a CIDR overlaps a VPC. | Compare install.md I3 output with the HCP. A CIDR cannot change: create the cluster again. |
| Pods in a namespace stay in the Shared Services VPC | The pods existed before the namespace mapping. | [references/egress-vpc.md](references/egress-vpc.md), V1. |

For other failures, use skill `nkp-troubleshooting`.

## Related skills

Create flags, IP plan, Rocky image: skill `nkp-install`. Dark-site bundle download and push: skill `nkp-airgap`. Cilium, MetalLB pools: skill `nkp-networking`. Node pools, node labels, delete a cluster: skill `nkp-cluster-lifecycle`. NKP upgrade: skill `nkp-upgrade`. Nodes in a VPC: skill `nkp-vpc`.
