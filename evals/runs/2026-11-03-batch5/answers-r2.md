# Batch 5 re-run (r2) — answers

Notes that apply to every section below:

- Files read: `skills/nkp/SKILL.md` (router) and `skills/_shared/RULES.md` (rules block) for all 11 prompts. The per-section list shows the skill files that each job needs on top of these two.
- Every block starts with the mark line and then the `source` line. Blocks that use a cluster-file variable source `~/nkp-<cluster>.env`; the other blocks source `~/nkp-site.env`.
- A `<cluster>` in a path stays in the block only when you did not name the cluster. When you name it, I use the real path (for example `~/nkp-flow-01.env`).
- No append line (`echo "export VAR='value'" >> ...`) appears before you give or confirm the value. When the value is only a copy of a variable that is already in your file, the block copies the variable and prints no value.
- "Just run it" is not "yes". Every CHANGES block stops for the plan and the word "yes".

---

## nkp-flow-cni L2

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-flow-cni/SKILL.md`, `skills/nkp-flow-cni/references/install.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`.

**What the job is:** a workload cluster `flow-01` in workspace namespace `team-a-xyz`, created with Flow CNI (path A) in place of Cilium, connected site. I use path A. Path B (`clusterConfig.addons.cni.provider: Flow`) is not tested and has no Nutanix support statement (UNKNOWN F-02). `nkp create cluster` has no CNI flag. [live 2.19.0]

**Questions I would ask first (ask_user_question):**

1. "The connected-site HCP needs the Nutanix Docker Hub pull account for the Flow CNI images. Do you have it?"
   - "Yes, `FLOW_CNI_PULL_USERNAME` and `FLOW_CNI_PULL_TOKEN` are already in `~/nkp-site.env` (Recommended)"
   - "No. I make the token on a connected host in the portal first (Downloads → Flow Networking and security → Flow Container Interface → Generate Access Token)"
   - "Stop. I will use Cilium in place of Flow CNI" (I stop and do not go on without your word)
2. "The pod and service CIDRs cannot change after the create, and they must not overlap a VPC range. Which CIDRs do we use?"
   - "The NKP defaults: pods `192.168.0.0/16`, services `10.96.0.0/12` (Recommended)"
   - "Other CIDRs. I give them, and you add `--kubernetes-pod-network-cidr` and `--kubernetes-service-cidr` to the script"
3. "How is `flow-01` an image and node source? Your message says the Rocky image and the VLAN Basic subnet are ready. Which node sizes?"
   - "CLI defaults: 3 control-plane (4 vCPU, 16 GiB), 4 workers (8 vCPU, 32 GiB) (Recommended)"
   - "The Starter minimums (`--control-plane-vcpus 2 --control-plane-memory 6 --worker-replicas 2 --worker-vcpus 3 --worker-memory 6`)"
   - "Other sizes. I give them"
4. "`CP_VIP` and the LB range are in `~/nkp-flow-01.env`. Do I use them as they are?"
   - "Yes, use the file values as they are (Recommended)"
   - "No, they change" (then the change is a new line in the same file, last line wins)

**Plan and blocks**

Step A — check what the cluster can show (SKILL.md step 1). You confirmed the Prism Central, AOS, AHV, Network Controller and subnet items. These checks stay, because the skill says to read the parts that NKP can show.

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
echo "VM_IMAGE=$VM_IMAGE"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get clusterclass -o custom-columns='NAME:.metadata.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get --raw "/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy/v2/charts/nutanix-flow-cni/tags/list"; echo
```

Done when: the image name has `rocky`, the namespace has `nkp-nutanix-v2.19.0`, the ConfigMap prints `ChartName: nutanix-flow-cni` with a `ChartVersion`, and the tag list has the same version. The HCP takes the version from this ConfigMap, so I do not write a version by hand. If the ConfigMap and the tag list disagree, I stop (UNKNOWN F-01).

Step B — env file checks (nutanix.md N2, every case):

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && bash -n ~/nkp-flow-01.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

```bash
# READ-ONLY  (case 5, connected with a site mirror)
source ~/nkp-site.env 2>/dev/null
for v in MGMT_KUBECONFIG REGISTRY_URL REGISTRY_CA_FILE; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

If the last block prints `MISSING: REGISTRY_URL`, the site has no mirror and the create uses the management cluster's Docker Hub credentials (nutanix.md N5 step 3). If it prints `set:`, the script adds the mirror flags. The mirror credentials are allowed to be empty:

```bash
# READ-ONLY  (mirror credentials)
source ~/nkp-site.env 2>/dev/null
for v in REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
```

Step C — `yq` must be mikefarah v4 (install.md I2 says the bundle has no `yq`):

```bash
# READ-ONLY
command -v yq && yq --version
```

If the line does not contain `mikefarah` and `version v4`, I stop and tell you. I do not use another YAML tool in its place.

Step D — the create script (nutanix.md N5 step 3). For a connected site I remove the `--airgapped` line, as N5 step 3 says. **Plan: this writes `~/nkp-flow-01-create.sh`, mode 700, on the operator host. It creates nothing. Result: a script that creates `flow-01` in `team-a-xyz` with no `--self-managed`. I run it only after you type "yes".**

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-flow-01.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster nutanix \
  --kubeconfig "$MGMT_KUBECONFIG" \
  --namespace "$WORKSPACE_NS" \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL" --registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  ${NTP_SERVERS:+--ntp-servers "$NTP_SERVERS"} \
  ${PC_PROJECT:+--pc-project "$PC_PROJECT"} \
  ${PC_CA_FILE:+--additional-trust-bundle "$(base64 < "$PC_CA_FILE" | tr -d '\n')"} \
  "$@"
EOF
)
```

Two more items for I1: I do not add `--onboard-to-prism-central=false` (Flow CNI needs the cluster in Prism Central), and if you chose other CIDRs I add their two lines before `"$@"`. The mirror password and the Docker Hub token go in as flags, so other users on the host can see them in the process list.

Step E — the dry run (nutanix.md N4D, first block). **Plan: it writes `$PWD/flow-01-dryrun.yaml`, mode 600. The file holds Secrets and I never print it. Result: the objects of the cluster, and no cluster. Then I stop for the create, but the create is not the N4D block: this dry-run file replaces it (install.md I2).**

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-flow-01.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Then these lines only (they show no Secret values):

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
grep -n -E '^kind:|^  name:|image:|host:|addressRanges:|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Step F — remove `addons.cni` from the dry-run file (install.md I3). The guide's own `yq` command has no input file and empties the file. I use the skill's block, which covers both kinds (`NKPCluster` and `Cluster`). **Plan: it edits `$PWD/flow-01-dryrun.yaml` on the operator host and keeps a `.orig` copy. Result: no `addons.cni` in the `clusterConfig` variable, so the cluster gets no Cilium. It changes no cluster. I run it only after "yes".**

```bash
# CHANGES  (edits the dry-run file on the operator host: removes addons.cni; changes no cluster)
source ~/nkp-flow-01.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-dryrun.yaml"; test -s "$f" || { echo "no dry-run file"; exit 1; }
cp -p "$f" "$f.orig"
yq -i 'del(select(.kind == "NKPCluster") | .spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni) | del(select(.kind == "Cluster") | .spec.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni)' "$f"
```

Check (prints kinds, addon names, CIDRs, kube-proxy mode only):

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-dryrun.yaml"
yq '.kind + " " + .metadata.name' "$f"
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value | "addons: " + (.addons | keys | join(",")) + "  kubeProxy: " + (.kubeProxy.mode // "none"))' "$f"
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork) | "pods: " + .pods.cidrBlocks[0] + "  services: " + .services.cidrBlocks[0]' "$f"
```

Done when: an `addons:` line shows, no `addons:` line has `cni`, the other addons (`csi`, `serviceLoadBalancer`, `konnectorAgent`, …) are still there, and the CIDRs are the ones you agreed to. If `cni` stays, I restore the copy (`cp -p "$f.orig" "$f"`, CHANGES) and stop. The `kubeProxy` value that this block prints is the value the cluster keeps. UNKNOWN (F-06): whether `disabled` is correct with Flow CNI. The check comes after the create.

Step G — write the Flow CNI HelmChartProxy (install.md I4). Mode `connected`, `hostprefix` 24, chart version read from the management cluster, CIDRs read from the dry-run file. **Plan: it writes `$PWD/flow-01-flow-cni-hcp.yaml` on the operator host. In connected mode the file holds the Docker Hub pull token as Base64. Result: one HCP `flow-01-flow-cni` in namespace `team-a-xyz`, selector label `cluster.x-k8s.io/cluster-name: flow-01`, chart `nutanix-flow-cni` from `oci://helm-repository.caren-system.svc/charts`, `k8sAPIServer` = `https://$CP_VIP:6443`. It changes no cluster. I run it only after "yes".**

```bash
# CHANGES  (writes the Flow CNI HelmChartProxy file on the operator host; connected mode puts the pull token in it; changes no cluster)
source ~/nkp-flow-01.env 2>/dev/null
mode='connected'; hostprefix='24'
case "$mode" in connected|darksite) ;; *) echo "set mode to connected or darksite"; exit 1;; esac
f="$PWD/$CLUSTER_NAME-dryrun.yaml"; out="$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
ver=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}' | awk '/ChartVersion/{print $2}'); : "${ver:?no Flow chart version on the management cluster}"
pod=$(yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork).pods.cidrBlocks[0]' "$f" | head -n 1)
svc=$(yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork).services.cidrBlocks[0]' "$f" | head -n 1)
[ -n "$pod" ] && [ "$pod" != null ] && [ -n "$svc" ] && [ "$svc" != null ] || { echo "no CIDRs in the dry-run file"; exit 1; }
: "${CP_VIP:?}" "${CLUSTER_NAME:?}" "${WORKSPACE_NS:?}"
if [ "$mode" = connected ]; then [ -n "$(printenv FLOW_CNI_PULL_TOKEN)" ] && [ -n "$(printenv FLOW_CNI_PULL_USERNAME)" ] || { echo "MISSING: FLOW_CNI_PULL_USERNAME or FLOW_CNI_PULL_TOKEN"; exit 1; }; fi
umask 077
cat > "$out" <<EOF
apiVersion: addons.cluster.x-k8s.io/v1alpha1
kind: HelmChartProxy
metadata:
  name: $CLUSTER_NAME-flow-cni
  namespace: $WORKSPACE_NS
spec:
  clusterSelector:
    matchLabels:
      cluster.x-k8s.io/cluster-name: $CLUSTER_NAME
  repoURL: oci://helm-repository.caren-system.svc/charts
  tlsConfig:
    caSecret:
      name: helm-repository-tls
      namespace: caren-system
  chartName: nutanix-flow-cni
  version: "$ver"
  namespace: flow-cni-system
  options:
    wait: true
    waitForJobs: true
    timeout: 30m
    install:
      createNamespace: true
  valuesTemplate: |
    nutanix-core-flow-ovn-kubernetes:
      k8sAPIServer: "https://$CP_VIP:6443"
      podNetwork: "$pod/$hostprefix"
      serviceNetwork: "$svc"
EOF
if [ "$mode" = connected ]; then
auth=$(printf '%s:%s' "$(printenv FLOW_CNI_PULL_USERNAME)" "$(printenv FLOW_CNI_PULL_TOKEN)" | base64 | tr -d '\n')
cat >> "$out" <<EOF
    global:
      dockerConfigSecret:
        registry: docker.io
        auth: "$auth"
        create: true
      imagePullSecretName: flow-cni-secret
    imagePullSecrets:
      - name: flow-cni-secret
EOF
fi
echo "written: $out"
```

You must know this before you say "yes": the HCP spec on the management cluster holds the pull token as Base64, and each user who can read HelmChartProxies in `team-a-xyz` can read it. I never read this file, the HCP, or its HelmReleaseProxy with `-o yaml`, `-o json`, or `describe`. The check shows the file without the token line:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
grep -v -E '^ +auth:' "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
```

Step H — server dry run of both files (install.md I5, READ-ONLY, changes nothing). The mutating webhooks `addons-defaulter.caren.nutanix.com`, `cluster-defaulter.caren.nutanix.com` and `nkp-cluster-defaulting` run here. If a webhook adds `cni` back, I stop and do not create.

```bash
# READ-ONLY  (server dry run: the API server and the webhooks check the objects and change nothing)
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
```

```bash
# READ-ONLY  (server dry run: changes nothing; prints only the addon key names after the webhooks)
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o yaml | yq '(.items // [.]) | .[] | select(.kind == "NKPCluster" or .kind == "Cluster") | .kind + " " + .metadata.name + "  addons: " + ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value.addons | keys | join(","))'
```

Step I — create. **Plan: on the management cluster, in namespace `team-a-xyz`, this creates the workload cluster object and the HCP `flow-01-flow-cni`. Prism Central creates the VMs. The cluster starts with no Cilium; the Flow CNI chart installs from the CAREN chart server. Result: `flow-01` in `team-a-xyz` with Flow CNI. This is the create. I run it only after you type "yes".**

```bash
# CHANGES  (creates the workload cluster and its Flow CNI HelmChartProxy; Prism Central creates the VMs)
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
```

Step J — the kubeconfig of the workload cluster (nkp-install, "Set the kubeconfig variables"). **Plan: it writes `$PWD/flow-01.conf` and appends `CLUSTER_KUBECONFIG` to `~/nkp-flow-01.env`. Result: a kubeconfig file for the new cluster. I never print it. I run it only after "yes".**

```bash
# CHANGES  (writes a local kubeconfig file and appends its path to the cluster env file)
source ~/nkp-flow-01.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-flow-01.env
```

Step K — the Flow CNI checks (SKILL.md step 4):

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmchartproxy "$CLUSTER_NAME-flow-cni" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CLUSTER:.spec.clusterRef.name,CHART:.spec.chartName,VERSION:.spec.version,READY:.status.conditions[?(@.type=="Ready")].status'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'flow-cni|flow-cns|ovn'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ds -A | grep -E 'cilium|kube-proxy|ovn|flow'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get pods
```

Done when: HCP conditions `Ready=True`, one HelmReleaseProxy for `flow-01` with chart `nutanix-flow-cni` and READY `True`, all nodes `Ready`, all Flow CNI and OVN pods Running, no `cilium` DaemonSet, and `konnector-agent` Running in `ntnx-system`. Then `nkp install` "Verify". The nodes stay `NotReady` until the Flow CNI pods run — that is normal here, not a fault.

Step L — after the checks pass, the local files hold Secrets. **Plan: `rm` of the dry-run file, its `.orig` copy, and the HCP file, on the operator host. Result: no local copy of the pull token. I run it only after "yes", or you keep them for a later re-create (mode 600)**

```bash
# CHANGES  (deletes the three local files of this cluster on the operator host)
source ~/nkp-flow-01.env 2>/dev/null
rm -f "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml.orig" "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
```

Two risks to say now: the HCP has a fixed chart version, so an NKP upgrade needs a check before and after (UNKNOWN N-34); and the HCP of path A has no owner, so it can stay after a cluster delete (cleanup block is in SKILL.md).

---

## nkp-flow-cni L5

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-flow-cni/SKILL.md`, `skills/nkp-flow-cni/references/egress-vpc.md` (E1, E2).

**What the job is:** one fixed source IP for the pods with `app=payments` in namespace `payments`, on `flow-01`. There are two objects for this job:

| Object | Source IP | Use it when |
|---|---|---|
| `EgressIP` (`k8s.ovn.org/v1`) | a free IP of your choice, from the node subnet, outside the IPAM pool, `CP_VIP`, and `LB_IP_RANGE` | the app does not already have a `LoadBalancer` Service, or you want one IP for several namespaces (Recommended) |
| `EgressService` (`k8s.ovn.org/v1`) | the `LoadBalancer` IP of one Service | the app has a `LoadBalancer` Service, and that IP must be the source IP |

The default egress is SNAT to the node IP, the same for all VPCs of the cluster, so it changes when a pod moves. Both objects below replace it for the selected pods. [portal]

**Questions I would ask first (ask_user_question):**

1. "`EgressIP` or `EgressService`?"
   - "`EgressIP`: one fixed IP that I choose (Recommended)"
   - "`EgressService`: the source IP must be the `LoadBalancer` IP of the `payments` Service. Note: the Service gets a new IP from a new pool, so its clients must change"
2. "Which free IP for the egress? It must be in the node subnet, outside the IPAM pool, `CP_VIP`, and `LB_IP_RANGE`." (free text — I do not propose a value)
3. "Which nodes can hold the egress IP? Use two or more workers, not control-plane nodes."
   - "All worker nodes (Recommended)"
   - "A subset. I give the node names"
4. "Object name?"
   - "`payments-egress` (Recommended)"
   - "Other name"

**Plan and blocks**

First the facts I read from the cluster, READ-ONLY:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crds -o name | grep -i -E 'ovn|flow|nutanix'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n payments get pods -l app=payments -o wide
```

The `EgressIP`/`EgressService` kind must show in the CRD list. If it does not, the cluster has no Flow CNI and I stop there.

Step A — write the file (E1 item 2). `name`, `eip`, `ns`, `app` stay empty with their `:?` guards until you give them. **Plan: it writes `$PWD/flow-01-egressip-payments-egress.yaml` on the operator host. Result: one `EgressIP` with `egressIPs: [<your IP>]`, `podSelector: {matchLabels: {app: payments}}`, and `namespaceSelector` on the namespace label `kubernetes.io/metadata.name: payments`. No cluster change. I run it only after "yes".**

```bash
# CHANGES  (writes the EgressIP file on the operator host; changes no cluster)
source ~/nkp-flow-01.env 2>/dev/null
name=''; eip=''; ns=''; app=''
: "${name:?}" "${eip:?}" "${ns:?}"
podsel='{}'; [ -n "$app" ] && podsel="{matchLabels: {app: $app}}"
printf -- 'apiVersion: k8s.ovn.org/v1\nkind: EgressIP\nmetadata:\n  name: %s\nspec:\n  egressIPs:\n  - %s\n  podSelector: %s\n  namespaceSelector:\n    matchLabels:\n      kubernetes.io/metadata.name: %s\n' "$name" "$eip" "$podsel" "$ns" > "$PWD/$CLUSTER_NAME-egressip-$name.yaml"
```

Step B — server dry run (READ-ONLY, changes nothing):

```bash
# READ-ONLY  (server dry run of the EgressIP file; changes nothing)
source ~/nkp-flow-01.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-egressip-$name.yaml"
```

`no matches for kind` means the cluster has no Flow CNI. I stop.

Step C — apply. **Plan: on `flow-01` this labels the egress worker nodes `k8s.ovn.org/egress-assignable=""` and creates one `EgressIP`. Result: the pods with `app=payments` in `payments` leave the cluster with your fixed IP; the other pods keep SNAT on the node IP. I run it only after "yes".**

```bash
# CHANGES  (labels the egress nodes and creates the EgressIP; the selected pods use the new source IP)
source ~/nkp-flow-01.env 2>/dev/null
name=''; nodes=''
: "${name:?}" "${nodes:?set one or more node names, space separated}"
for n in $nodes; do kubectl --kubeconfig "$CLUSTER_KUBECONFIG" label node "$n" k8s.ovn.org/egress-assignable="" --overwrite; done
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-egressip-$name.yaml"
```

Step D — check:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get egressip -o wide
```

Done when: the `EgressIP` shows your IP and an assigned node, and a test from an external host shows that IP as the source. You run that test; I cannot.

Two limits to know: a replaced node loses a `kubectl label` label. The guide puts the labels in the MachineDeployment template (`node.cluster.x-k8s.io/egress-assignable: ""`, `node.cluster.x-k8s.io/egressnode: "true"`), and that is a node-pool label change (skill `nkp-cluster-lifecycle`). UNKNOWN (N-33): whether that pool label is enough for OVN, which reads `k8s.ovn.org/egress-assignable`. Check after a node replacement with `kubectl get nodes -L k8s.ovn.org/egress-assignable,node.cluster.x-k8s.io/egress-assignable`. If you chose `EgressService`, the flow is E2 and its plan says: the Service takes a new IP from a new pool, and the clients of the old IP stop working.

---

## nkp-vpc V1

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md`, `skills/nkp-vpc/references/layouts.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`.

**Answers to the two questions in your message**

1. **Two floating IPs** (table "Step 1", row "exposed, NAT external subnet"):
   - `FIP_API` → the private IP `CP_VIP`. This is the API endpoint for kubectl from the corp LAN.
   - `FIP_UI` → the first IP of `LB_IP_RANGE`, which is the Traefik IP that serves the NKP UI.
   - The bastion is in the same VPC, so it needs no floating IP for the cluster. You need a third floating IP only if users on the corp LAN also reach the bastion itself, and one more (`+1`) for each additional `LoadBalancer` Service that the corp LAN must reach. [portal]
   - `CP_VIP` and `LB_IP_RANGE` are Layer 2 (kube-vip uses ARP, MetalLB uses ARP), so they must be inside the overlay subnet `tenant-a-nodes` and outside its IPAM pool. From the corp LAN they are reachable only through the floating IPs. [portal][pdf p.720-721]
2. **What you add to the create** — two lines, before `"$@"`:
   - `--control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT"`
   - `--cluster-hostname "$UI_HOSTNAME"`
   - Do not add `--extra-sans` for a third floating IP: the external endpoint already puts `FIP_API` in the API certificate. [live 2.19.0]

**Questions I would ask first (ask_user_question):**

1. "Is the external subnet NAT (your message says NAT)? And do the corp-LAN users use an IP or a DNS name?"
   - "NAT, and we use two DNS names with A records to `FIP_API` and `FIP_UI` (Recommended — a name survives a certificate change better than a bare IP)"
   - "NAT, and we use the two floating IPs directly as addresses"
   - "No-NAT. The overlay range is routed to the corp LAN" (then outside users can reach `CP_VIP` and the LB IPs directly, and no floating IP is needed — I ask the network team)
2. "Which VPC class is this management cluster for? It is a self-managed management cluster in the VPC, so the corp LAN must reach both kubectl and the UI — that is the exposed layout."
   - "Exposed, self-managed management cluster (Recommended)"
   - "No — only VMs inside the VPC use it" (isolated layout, 0 floating IPs, no extra flags — this cancels your requirement)
3. "`~/nkp-nkp-a.env` does not exist yet — do I make it? And is `nkp-a` the cluster name?"
   - "Yes: cluster name `nkp-a`, make the cluster env file (Recommended)"
   - "The name is different" (I ask for it and use the real path in every block)
4. "Four values are not in your message: `CP_VIP`, `LB_IP_RANGE`, `FIP_API`, `FIP_UI` — and the two names for `API_EXTERNAL_ENDPOINT` and `UI_HOSTNAME`. Also the VPC CIDR, for the overlap check." (free text — I write each line only after you give the value)

**Plan and blocks**

Order: Prism Central objects first, then the values, then the operator host and its MTU, then the create, then the checks. The bastion is a VM on the overlay subnet with MTU 1442, so step 3 is not optional here.

Step A — make the env files (rules 3-4). Both blocks are CHANGES; I show the plan and stop for "yes" for each.

```bash
# CHANGES  (makes ~/nkp-site.env with mode 600 if it does not exist)
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
```

```bash
# CHANGES  (makes the cluster env file with mode 600 if it does not exist)
test -e ~/nkp-nkp-a.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-nkp-a.env); }
```

The values go to two files: this is a management cluster, so `SUBNET` is a site value. `VPC_NAME` is a cluster value.

```bash
# CHANGES  (appends SUBNET to the site env file; the overlay subnet name you gave: tenant-a-nodes)
source ~/nkp-site.env 2>/dev/null
echo "export SUBNET='tenant-a-nodes'" >> ~/nkp-site.env
```

```bash
# CHANGES  (appends VPC_NAME to the cluster env file; the VPC name you gave: tenant-a)
source ~/nkp-nkp-a.env 2>/dev/null
echo "export VPC_NAME='tenant-a'" >> ~/nkp-nkp-a.env
```

Answer question 4 first. Then, in the next reply, one block for each value, in this form (one value in one line, last line wins):

```bash
# CHANGES  (appends one value to the cluster env file — shown for one variable, repeated for each value you give)
source ~/nkp-nkp-a.env 2>/dev/null
echo "export CP_VIP='the value you give'" >> ~/nkp-nkp-a.env
```

The same for `LB_IP_RANGE`, `FIP_API`, `FIP_UI`, `API_EXTERNAL_ENDPOINT`, `UI_HOSTNAME`. A DNS name needs its A record to the floating IP first. [portal]

Step B — the Prism Central plan. These are your steps in Prism Central (Infrastructure → Network); NKP has no object for a VPC, a subnet, or a floating IP, so I cannot make them for you. I show the list, you confirm each item. [portal][pdf p.709-710]

1. External subnet on the VLAN, "External Connectivity for VPCs" on, NAT. Its pool must hold the SNAT IPs and both floating IPs. A VPC can have one NAT external subnet only. [portal]
2. VPC on that external subnet, with the default route that the nodes need.
3. Overlay subnet `tenant-a-nodes` in the VPC, IPAM on. Free IPs outside its pool for `CP_VIP` and `LB_IP_RANGE`.
4. `FIP_API` associated with the private IP `CP_VIP`, and `FIP_UI` associated with the first IP of `LB_IP_RANGE` — **before the create**, because the nodes join through `FIP_API`. [live 2.19.0] (UNKNOWN N-43 covers the other order.)
5. From the overlay subnet, the nodes reach Prism Central on TCP 9440 and the registry on TCP 443. [portal]
6. Pod CIDR `192.168.0.0/16` and service CIDR `10.96.0.0/12` must not overlap any VPC range that the nodes route to. This is the check below.

Step C — the CIDR overlap check. Put your VPC CIDR list in `vpc_cidrs` (I keep it empty with its `:?` guard until you give it):

```bash
# READ-ONLY  (needs python3)
source ~/nkp-site.env 2>/dev/null
vpc_cidrs=''; pod_cidr='192.168.0.0/16'; svc_cidr='10.96.0.0/12'
: "${vpc_cidrs:?}"
python3 -c 'import ipaddress,sys; k=[ipaddress.ip_network(c) for c in sys.argv[1:3]]; v=[ipaddress.ip_network(c.strip()) for c in sys.argv[3].split(",")]; bad=[(str(a),str(b)) for a in k for b in v if a.overlaps(b)]; print("OVERLAP", bad) if bad else print("no overlap")' "$pod_cidr" "$svc_cidr" "$vpc_cidrs"
```

Done when it prints `no overlap`. On `OVERLAP` we choose free CIDRs and add `--kubernetes-pod-network-cidr` and `--kubernetes-service-cidr` to the create script. The CIDRs cannot change later.

Step D — the operator host. Your bastion is in the VPC, so its NIC has MTU 1442 and the kind bootstrap cluster must not use 1500. This is the first thing that fails on a VPC bastion. [portal]

```bash
# READ-ONLY  (needs jq)
source ~/nkp-site.env 2>/dev/null
dev=$(ip route show default | awk '{print $5; exit}'); echo "nic $dev mtu $(cat "/sys/class/net/$dev/mtu")"
docker network inspect bridge --format 'bridge mtu {{index .Options "com.docker.network.driver.mtu"}}'
docker network inspect kind --format 'kind mtu {{index .Options "com.docker.network.driver.mtu"}} containers {{len .Containers}}' 2>/dev/null || echo "no kind network"
if sudo -n test -e /etc/docker/daemon.json; then sudo -n cat /etc/docker/daemon.json | jq -r '"daemon.json mtu: " + ((.mtu // "none")|tostring)'; else echo "daemon.json: none, or no sudo"; fi
echo "running: $(docker ps --format '{{.Names}}' | tr '\n' ' ')"
curl -sk -o /dev/null -m 10 -w 'pc %{http_code}\n' "$PC_ENDPOINT"
[ -z "$REGISTRY_URL" ] || curl -sk -o /dev/null -m 10 -w 'registry %{http_code}\n' "$REGISTRY_URL/v2/"
```

Done when the NIC, the bridge and the kind network show the same MTU, and `pc` (and `registry`, if there is one) print a code that is not `000`. If the MTUs differ, the fix is the next block in this skill (step 3): it writes `mtu` in `/etc/docker/daemon.json`, keeps a `.bak` copy, and restarts Docker. **That restart stops all containers**, so I show it only when the check shows a difference, and only after "yes". If `running:` shows a name, I stop and ask you first.

Step E — the create. The script is nutanix.md N4A/N4C/N4B for this site (connected or mirror), with your two VPC lines before `"$@"`:

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
  --cluster-hostname "$UI_HOSTNAME" \
```

`--self-managed` stays, because this is a management cluster. Then the dry run (N4D), then this check (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-nkp-a.env 2>/dev/null
grep -n -E '^ +host:|^ +address:|^ +hostname:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Done when a `host:` line shows `API_EXTERNAL_ENDPOINT` and an `address:` line shows `CP_VIP`. Then the CHANGES create block, plan and "yes" as usual.

Step F — the VPC checks (step 5, READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-nkp-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}api={.value.nutanix.controlPlaneEndpoint.host} vip={.value.nutanix.controlPlaneEndpoint.virtualIP.configuration.address}{"\n"}{end}ui={.spec.kommanderCluster.spec.ingress.hostname}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get svc kommander-traefik -o jsonpath='traefik={.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" config view --minify -o jsonpath='server={.clusters[0].cluster.server}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
curl -sk -o /dev/null -m 10 -w 'api %{http_code}\n' "https://${API_EXTERNAL_ENDPOINT:-$CP_VIP}:6443/version"
curl -sk -o /dev/null -m 10 -w 'ui %{http_code}\n' "https://${UI_HOSTNAME:-${LB_IP_RANGE%%-*}}/dkp/kommander/dashboard"
```

Done when: `api=` is `API_EXTERNAL_ENDPOINT`, `vip=` is `CP_VIP`, `ui=` is `UI_HOSTNAME`, `server=` uses the external endpoint, `traefik=` is the first IP of `LB_IP_RANGE`, `api 200`, `ui 302`. Then you run `nkp get dashboard` in your own terminal (it shows the admin password; USER-TERMINAL, I do not run it).

Two things to know now: `https://CP_VIP:6443` with TLS checks fails from inside the VPC, because the certificate names hold the external endpoint and not `CP_VIP`; add `CP_VIP` to the API certificate names at create time only (skill `nkp-networking`). And a later change of `FIP_API`/`API_EXTERNAL_ENDPOINT` is not supported (layouts L7, UNKNOWN N-42) — choose `CP_VIP` and the names before the create.

---

## nkp-vpc V2

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md` ("Common failures", step 3), `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md` (N7).

**Diagnosis:** the cause is the MTU, not Prism Central and not TLS. The bastion is in the VPC, so its NIC is 1442. The kind bootstrap cluster makes containers on the Docker bridge, at 1500 by default. `curl` from the bastion works because `curl` uses the NIC MTU and the kernel does the fragmentation. The CAPX pod inside kind sends a 1500-byte packet with DF set on a 1442 path: the large TLS packets are dropped, so the TLS handshake to Prism Central times out. [portal] This exact symptom is the first row of the "Common failures" table in the skill.

This is a diagnosis from the symptom table. I confirm it before I change anything — that is the first block, and it is READ-ONLY.

**Questions I would ask first (ask_user_question):**

1. "What is the cluster name and the env file? It is not in your message, and I cannot take a name from an example."
   - "I give you the name" (free text; I then use `~/nkp-<name>.env` in every block)
   - "Use the site env file only for this fix — the MTU blocks need no cluster variable" (Recommended for speed: the check and the fix use `~/nkp-site.env`)
2. "Is the create still running, or did it stop?"
   - "It is still running and hangs (Recommended first check: read the CAPX log)"
   - "It stopped with an error"
3. "May I restart Docker on the bastion? That stops every container on it."
   - "Yes, if `docker ps` shows no bootstrap cluster and no registry (Recommended)"
   - "No — only show me the commands, I run them in my own window"
4. "Was kind's network made before or after the Docker MTU was set? If it exists with MTU 1500 and holds containers, it keeps 1500."
   - "I do not know — check it (Recommended)"
   - "It was made by this failed create"

**Plan and blocks**

Step A — confirm the cause (READ-ONLY, needs `jq`; if the block needs sudo, it tells you):

```bash
# READ-ONLY  (needs jq)
source ~/nkp-site.env 2>/dev/null
dev=$(ip route show default | awk '{print $5; exit}'); echo "nic $dev mtu $(cat "/sys/class/net/$dev/mtu")"
docker network inspect bridge --format 'bridge mtu {{index .Options "com.docker.network.driver.mtu"}}'
docker network inspect kind --format 'kind mtu {{index .Options "com.docker.network.driver.mtu"}} containers {{len .Containers}}' 2>/dev/null || echo "no kind network"
if sudo -n test -e /etc/docker/daemon.json; then sudo -n cat /etc/docker/daemon.json | jq -r '"daemon.json mtu: " + ((.mtu // "none")|tostring)'; else echo "daemon.json: none, or no sudo"; fi
echo "running: $(docker ps --format '{{.Names}}' | tr '\n' ' ')"
curl -sk -o /dev/null -m 10 -w 'pc %{http_code}\n' "$PC_ENDPOINT"
[ -z "$REGISTRY_URL" ] || curl -sk -o /dev/null -m 10 -w 'registry %{http_code}\n' "$REGISTRY_URL/v2/"
```

Done when: `nic ... mtu 1442` and `bridge mtu 1500` (or `kind mtu 1500`). That pair is the cause. The `pc 200` line is the point: Prism Central answers from the host, so the path itself is good.

Step B — stop the failed bootstrap cluster (CHANGES, plan, "yes"). A new create with a new kind network is the reliable way:

```bash
# CHANGES  (deletes the kind bootstrap cluster on the operator host)
nkp delete bootstrap
```

Step C — set the Docker MTU. **Plan: this writes `mtu` = the NIC MTU into `/etc/docker/daemon.json`, keeps `daemon.json.bak`, keeps all other keys, the owner and the mode, and restarts Docker. Result: the default bridge and new kind networks use 1442. The restart stops every container on the bastion, and this is why I stop here for your "yes". This block needs `jq` and sudo without a password prompt; if not, you run it.**

```bash
# CHANGES  (sets the Docker MTU to the NIC MTU in /etc/docker/daemon.json, keeps a .bak copy, restarts Docker)
dev=$(ip route show default | awk '{print $5; exit}'); mtu=$(cat "/sys/class/net/$dev/mtu"); : "${mtu:?}"
sudo -n true || { echo "needs sudo without a password"; exit 1; }
f=/etc/docker/daemon.json; t=$(mktemp); trap 'rm -f "$t"' EXIT
if sudo test -s "$f"; then sudo cp -p "$f" "$f.bak" && sudo cat "$f" | jq --argjson m "$mtu" '.mtu = $m' > "$t"; else echo '{}' | jq --argjson m "$mtu" '.mtu = $m' > "$t"; fi && [ -s "$t" ] && sudo tee "$f" < "$t" > /dev/null && sudo systemctl restart docker
```

If `jq` fails, nothing changes (the file was not valid JSON). I show you the error.

Step D — the `kind` network. The `mtu` key changes only the default bridge. An existing `kind` network keeps its MTU, unless it holds no containers. **Plan: it removes and makes the `kind` network with the NIC MTU, only when `containers 0`. Result: the bootstrap containers get 1442. I run it only after "yes".**

```bash
# CHANGES  (makes the kind network again with the NIC MTU)
dev=$(ip route show default | awk '{print $5; exit}'); mtu=$(cat "/sys/class/net/$dev/mtu"); : "${mtu:?}"
[ "$(docker network inspect kind --format '{{len .Containers}}' 2>/dev/null || echo 0)" = 0 ] && { docker network rm kind 2>/dev/null; docker network create -o "com.docker.network.driver.mtu=$mtu" kind; }
```

Step E — run the READ-ONLY block of step A again. Done when `nic`, `bridge` and `kind` show the same MTU and `pc`/`registry` are not `000`. Then the create again (skill `nkp-install`, nutanix.md N4D). The first create left nothing to keep: the bootstrap cluster is a kind cluster, and the node VMs either do not exist or come again with the same names. If node VMs do exist in Prism Central from the failed run, I stop and we look at them before the second create.

I do not touch Proxy, TLS trust (`PC_CA_FILE`), or the CAPX log here. If the cause check shows the same MTU on all three, the cause is different: then the next READ-ONLY step is the CAPX controller log on the bootstrap cluster (skill `nkp-troubleshooting`), and a proxy or `PC_CA_FILE` question follows.

---

## nkp-vpc V3

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md` (step 6, "Common failures"), `skills/nkp-networking/references/ingress-certs.md` (I1, I2, I3, I4).

**Diagnosis:** `nkp get dashboard` shows the private `172.x` address because the KommanderCluster ingress `hostname` is empty and falls back to the Traefik IP. The fix is a patch of the **NKPCluster** (the KommanderCluster is owned by it) with the hostname. Your `FIP_UI` and `UI_HOSTNAME` are already in the env file, so no new value is needed.

**About "just run it":** I do not run a CHANGES block on your word "just run it". Rule 2: I show the command, the target and the result, and I stop for "yes". The blocks below are the shortest path, and there are only two of them that change anything. Say "yes" to the plan and they run at once.

**Questions I would ask first (ask_user_question):**

1. "Do you use the certificate that NKP made (`kommander-ca`), or your own certificate?"
   - "NKP's certificate: hostname only. The certificate gets the new name from `kommander-ca` (Recommended — no file work, no renewal work for you)"
   - "Our own certificate for `UI_HOSTNAME`: a TLS Secret on the cluster, then the hostname and the Secret together" (then I need the three PEM files, and status `ready` only after I3 steps 1-4)
2. "Is `FIP_UI` already associated with the Traefik IP (the first IP of `LB_IP_RANGE`) in Prism Central?"
   - "Yes (Recommended)"
   - "No / I do not know — check it first" (the `ui 000` row of the failure table; I show the Service IP check below)
3. "Does `UI_HOSTNAME` resolve to `FIP_UI` from your laptop?"
   - "Yes (Recommended)"
   - "No — a DNS change comes first, else the certificate and the URL are useless"
4. "May I add `INGRESS_HOSTNAME` to `~/nkp-nkp-a.env` with the same value as your `UI_HOSTNAME`? The networking blocks read that name. The block copies your variable, so no value shows in the chat."
   - "Yes (Recommended)"
   - "No — use `UI_HOSTNAME` in the patch instead" (I then use `UI_HOSTNAME` in place of `INGRESS_HOSTNAME` in the same blocks)

**Plan and blocks**

Step A — read the state (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-nkp-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.kommanderCluster.spec.ingress}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommandercluster "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[?(@.type=="IngressAddressReady")]}{.type}={.status} {.reason}{"\n"}{end}{range .status.conditions[?(@.type=="IngressCertificateReady")]}{.type}={.status} {.reason}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get svc kommander-traefik -o go-template='{{with index .status.loadBalancer.ingress 0}}{{or .hostname .ip}}{{end}}{{"\n"}}'
getent hosts "$UI_HOSTNAME"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,IP:.status.loadBalancer.ingress[0].ip
```

Done when: `IngressAddressReady=True IngressServiceAddressFound`, the Traefik address is the first IP of `LB_IP_RANGE` (the same private IP that `FIP_UI` must point to), and `getent hosts "$UI_HOSTNAME"` prints an address. The first `jsonpath` shows the empty `hostname` — that is the fault. UNKNOWN (N-26): whether the KommanderCluster of a workload cluster has the same name as the NKPCluster. For a management cluster it has [live 2.19.0], and this is a management cluster. If the second command prints nothing, I check the name with `get kommanderclusters -A` and do not guess.

Step B — add `INGRESS_HOSTNAME` (only if you answered "yes" to question 4). **Plan: one appended line in `~/nkp-nkp-a.env`; the value is a copy of your existing `UI_HOSTNAME`, so nothing new is decided and no value is printed. Result: the networking blocks can read `INGRESS_HOSTNAME`. I run it only after "yes".**

```bash
# CHANGES  (appends INGRESS_HOSTNAME with the value of the existing UI_HOSTNAME; no value is printed)
source ~/nkp-nkp-a.env 2>/dev/null
: "${UI_HOSTNAME:?}"
echo "export INGRESS_HOSTNAME='$UI_HOSTNAME'" >> ~/nkp-nkp-a.env
```

Step C — preview the patch with a server dry run (READ-ONLY, changes nothing; the NKP webhooks have `sideEffects: None` [live 2.19.0]). This is the hostname-only patch of ingress-certs.md I3:

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-nkp-a.env 2>/dev/null
p=$(printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s"}}}}}\n' "$INGRESS_HOSTNAME")
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type merge -p "$p" --dry-run=server -o jsonpath='{.spec.kommanderCluster.spec.ingress}{"\n"}'
```

Done when the dry run prints the new `hostname` and no error.

Step D — apply. **Plan: this patches the NKPCluster `nkp-a` in namespace `$WORKSPACE_NS` on the management cluster. It sets `spec.kommanderCluster.spec.ingress.hostname` to your `UI_HOSTNAME`. Result: `nkp get dashboard` shows `https://<UI_HOSTNAME>`, the UI certificate `kommander-traefik-tls` gets that name from `kommander-ca`, and the UI URL changes — the old `https://<ip>/dkp/kommander/dashboard` URL stops being the one the CLI prints. Nothing else changes: the Service IPs, the floating IP and the nodes stay as they are. I run it only after you type "yes".**

```bash
# CHANGES  (sets the hostname of the cluster ingress on the NKPCluster)
source ~/nkp-nkp-a.env 2>/dev/null
p=$(printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s"}}}}}\n' "$INGRESS_HOSTNAME")
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type merge -p "$p"
```

Step E — verify (ingress-certs.md I4, then nkp-vpc step 5):

```bash
# READ-ONLY
source ~/nkp-nkp-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommandercluster "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[?(@.type=="IngressAddressReady")]}{.type}={.status} {.reason}{"\n"}{end}{range .status.conditions[?(@.type=="IngressCertificateReady")]}{.type}={.status} {.reason}{"\n"}{end}'
echo | openssl s_client -connect "$INGRESS_HOSTNAME:443" -servername "$INGRESS_HOSTNAME" 2>/dev/null | openssl x509 -noout -subject -issuer -enddate
curl -sk -o /dev/null -m 10 -w 'ui %{http_code}\n' "https://${UI_HOSTNAME}/dkp/kommander/dashboard"
```

Done when: `IngressAddressReady=True`, `IngressCertificateReady=True Ready`, the certificate names include your hostname, the issuer is `kommander-ca` (or your CA, if you chose your own certificate), and `ui 302`. Then you run the dashboard command in your terminal (it prints the admin password, so it is USER-TERMINAL):

```bash
# USER-TERMINAL
source ~/nkp-nkp-a.env 2>/dev/null
nkp get dashboard --kubeconfig "$MGMT_KUBECONFIG"
```

If `ui` prints `000` while `api` answers, the cause is either the `FIP_UI` association (question 2) or Cilium DSR in the VPC (skill `nkp-networking`, `cni.md` C4, N-01). I check the association first, because that is the cheap one.

---

## nkp-vpc V7

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md`, `skills/nkp-vpc/references/layouts.md` (L1-L6), `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md` (N5).

**Answer: the mixed layout (layouts L1, row "Mixed").** The management cluster stays on the enterprise VLAN. Each tenant gets one VPC, and the workload cluster stands in the tenant VPC. The CNI stays Cilium.

**What you need — the list**

| Item | Detail |
|---|---|
| Layout | Mixed: management cluster on the VLAN, workload cluster in team X's VPC. The management cluster reaches the workload API through `FIP_API`. [portal] |
| Two floating IPs | `FIP_API` → the workload `CP_VIP`, `FIP_UI` → the first IP of the workload `LB_IP_RANGE`. The management cluster uses `FIP_API` also for CAPI. [portal] |
| Prism Central objects (you make them) | External subnet with "External Connectivity for VPCs" on (NAT or no-NAT); the tenant VPC; the overlay subnet (the node subnet, `SUBNET`); the two floating IPs. NKP has no object for any of these. [portal] |
| Unique overlay range | The team X overlay range must not overlap the VLAN subnet, the management cluster pod/service CIDRs, or another VPC. A pod or service CIDR that overlaps a routed VPC range loses packets. [portal] |
| Per-cluster env file | This cluster's `SUBNET` (the overlay subnet) goes in **its own** `~/nkp-<cluster>.env`, not in `~/nkp-site.env` — a second subnet in the site file breaks the other clusters. Same for `PE_CLUSTER` and `STORAGE_CONTAINER` if they differ. (step 2, step 5 of layouts is not touched) |
| Network paths | From the overlay subnet: Prism Central TCP 9440 and the registry TCP 443. [portal] The management cluster's CAPI controllers must reach Prism Central and `FIP_API`. [portal] |
| Registry place | In the tenant VPC on the overlay (no NAT, no floating IP), in a transit VPC (shared), or on the external VLAN through the external subnet. [portal] |
| MTU | The workload nodes have overlay NICs at 1442. The `nkp` host that runs this create must use the NIC MTU in Docker (same fix as V2) — do not skip it. |
| Versions in TN-2207 | AOS and Prism Central 7.5+, Network Controller 7.0.0+, NKP 2.17+. Your message does not give these, so I ask. |

**Questions I would ask first (ask_user_question):**

1. "Is the tenant's external subnet NAT or no-NAT, and is the overlay range routed to the VLAN?"
   - "NAT (Recommended: it works with any VLAN reachability; the two floating IPs do the work)"
   - "No-NAT: we route the overlay range and set the externally routable prefixes" (then outside hosts reach `CP_VIP` and the LB IPs directly and no floating IP is needed — layouts L2)
2. "Which Prism Central and Network Controller versions, and which license tier?"
   - "PC 7.5+, AOS 7.5+, NC 7.0.0+, Ultimate (Recommended: Ultimate is needed for many providers, and platform apps need Pro at minimum)"
   - "Pro"
   - "Starter" (then: one provider only, Rocky Linux image only, no monitoring apps)
3. "Where does the registry live for the team X nodes?"
   - "In the team X VPC, on the overlay (Recommended: no floating IP, no NAT)"
   - "In a transit VPC, shared by all tenants"
   - "On the external VLAN, through the external subnet"
4. "Which host runs the create — a bastion in the team X VPC, or the VLAN host you use now?"
   - "The existing VLAN operator host (Recommended if it reaches Prism Central and the registry; UNKNOWN N-41 covers a full create from outside the VPC)"
   - "A bastion in the tenant VPC (matches TN-2207, which wants the builder host in the same VPC)"

**Plan and blocks**

Step A — read what the management cluster already has (READ-ONLY, site env only, no cluster name needed):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{.items[*].spec.kommanderCluster.spec.ociRegistry.mirrorURL}{"\n"}'
```

Done when: I know the workspace (and its namespace) for team X, the clusters that exist, and the mirror URL that the workload cluster will use. An empty mirror URL means the site has a connected create or the internal mirror case (UNKNOWN A-06) — then I ask you before the create.

Step B — the Prism Central plan (you confirm each item, I do not have an object for these): external subnet with NAT and a pool that holds all SNAT and floating IPs; the tenant VPC on it; the overlay subnet with IPAM on and free IPs outside the pool for `CP_VIP` and `LB_IP_RANGE`; `FIP_API` associated with `CP_VIP` and `FIP_UI` with the Traefik IP **before the create**; routes from the overlay to Prism Central 9440 and the registry 443.

Step C — the env file for this cluster. I make the file, then I append each value in a later reply, after you give it (rule 4). The file gets: `CLUSTER_NAME`, `WORKSPACE_NS`, `CP_VIP`, `LB_IP_RANGE`, `VPC_NAME`, `FIP_API`, `FIP_UI`, `API_EXTERNAL_ENDPOINT`, `UI_HOSTNAME`, and `SUBNET` (this cluster's overlay subnet). `~/nkp-site.env` does not change.

```bash
# CHANGES  (makes the cluster env file with mode 600 if it does not exist; replace <cluster> with the name you give)
test -e ~/nkp-<cluster>.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-<cluster>.env); }
```

Step D — the CIDR overlap check, with the two CIDRs of the new cluster and the list of all VPC ranges it routes to:

```bash
# READ-ONLY  (needs python3)
source ~/nkp-site.env 2>/dev/null
vpc_cidrs=''; pod_cidr='192.168.0.0/16'; svc_cidr='10.96.0.0/12'
: "${vpc_cidrs:?}"
python3 -c 'import ipaddress,sys; k=[ipaddress.ip_network(c) for c in sys.argv[1:3]]; v=[ipaddress.ip_network(c.strip()) for c in sys.argv[3].split(",")]; bad=[(str(a),str(b)) for a in k for b in v if a.overlaps(b)]; print("OVERLAP", bad) if bad else print("no overlap")' "$pod_cidr" "$svc_cidr" "$vpc_cidrs"
```

I keep `vpc_cidrs` empty with its guard until you give the list. Done when it prints `no overlap`.

Step E — the create. The script is nutanix.md N5 (workload cluster: `--kubeconfig "$MGMT_KUBECONFIG"`, `--namespace "$WORKSPACE_NS"`, no `--self-managed`) with the two VPC lines before `"$@"`:

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
  --cluster-hostname "$UI_HOSTNAME" \
```

Then the dry run (N4D) and this READ-ONLY check:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^ +host:|^ +address:|^ +hostname:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Done when a `host:` line shows `API_EXTERNAL_ENDPOINT` and an `address:` line shows `CP_VIP`. Then the create (CHANGES, plan, "yes"), then the kubeconfig block for a workload cluster, then nkp-vpc step 5.

Step F — the checks that close the job, in order: `api 200` and `ui 302` through the floating IPs from a VLAN host; `server=` in the workload kubeconfig uses `API_EXTERNAL_ENDPOINT`; `get nodes` on the workload cluster shows `Ready` nodes with overlay IPs; the KommanderCluster conditions are `True` (skill `nkp-platform-apps-gitops`, step 4). The last one matters: if the management cluster cannot reach `FIP_API`, the app deployment fails and the cluster is not `Joined`.

Two limits to say now: no VM in a VPC can also have a plain VLAN NIC [field], so the tenant separation is the VPC and not a second NIC; and UNKNOWN (N-44) — whether a management cluster outside the VPC can create this workload cluster with only `FIP_API` and no route to the overlay. The first check after the create answers it: the `Available` condition of the CAPI `Cluster`.

---

## nkp-vpc V8

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md` (steps 1-2, 4), `skills/nkp-vpc/references/layouts.md` (L1, L2, L3, L4), `skills/nkp-install/references/nutanix.md` (N1, N5).

**Answer: the env files.** One rule decides everything: `~/nkp-site.env` holds the site values that every cluster uses; `~/nkp-<cluster>.env` holds the values of one cluster, and its first line sources the site file. A second subnet, a second VPC, or a second registry in the site file silently changes the clusters that already work. So team Y gets **one new cluster env file** and the site file stays as it is. (layouts L1: "in every layout with more than one subnet … the `SUBNET` of a workload cluster goes in its cluster env file, not in `~/nkp-site.env`")

team-x is unchanged. For team-y you need, per cluster:

| File | Variables | Note for team-y |
|---|---|---|
| `~/nkp-team-y.env` (name follows the cluster name) | `CLUSTER_NAME`, `WORKSPACE_NS`, `CP_VIP`, `LB_IP_RANGE`, `VPC_NAME`, `FIP_API`, `FIP_UI`, `API_EXTERNAL_ENDPOINT`, `UI_HOSTNAME`, `SUBNET` | all new values except the ones you confirm; `SUBNET` is `vpc-y-nodes`; `VPC_NAME` is `vpc-y` |
| same file, only when they differ | `PE_CLUSTER`, `STORAGE_CONTAINER` | you said the same PE cluster, so these lines are **not** added — the site values apply |
| `~/nkp-site.env` | — | **no change at all** |

Why every value must be new: `CP_VIP`, `LB_IP_RANGE` and the floating IPs are Layer 2 objects inside `vpc-y-nodes`, and floating IPs belong to one VPC. Two VPCs may map their floating IPs to the same private IP, but never use one private IP as a name across VPCs. [portal] The overlay range of `vpc-y` must also be unique in the mixed layout (layouts L1), and the pod/service CIDRs must not overlap it.

**Questions I would ask first (ask_user_question):**

1. "What is the cluster name for team Y? I will not guess it, and the file name follows it."
   - "`team-y` and `~/nkp-team-y.env` (Recommended only if that is the real cluster name — say so)"
   - "Another name (free text)"
2. "Which values are already decided for team Y: `CP_VIP`, `LB_IP_RANGE`, `FIP_API`, `FIP_UI`, and the two names?" (free text; one block per value in my next reply)
3. "Is `vpc-y-nodes` in `vpc-y` made, with the two floating IPs associated **before** the create?"
   - "Yes (Recommended)"
   - "Not yet — I show the Prism Central list first, as in V1 step 2"
4. "Does team Y reuse the site registry mirror, or does it need its own route or mirror?"
   - "The same site mirror `REGISTRY_URL`, reachable from the `vpc-y` overlay on 443 (Recommended)"
   - "A registry in `vpc-y` or in the transit VPC" (then `REGISTRY_URL` goes in the cluster env file for this cluster only, as a new line in `~/nkp-team-y.env`)

**Plan and blocks**

Step A — read the two existing records so the new values are not a copy of team X (READ-ONLY). This shows the cluster names, their workspace namespaces, and their control-plane endpoints; it prints no Secrets:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"  api="}{.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.nutanix.controlPlaneEndpoint.host}{"  vip="}{.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.nutanix.controlPlaneEndpoint.virtualIP.configuration.address}{"\n"}{end}'
```

Done when: the `api=` of team-x is its `FIP_API` and not `CP_VIP`, and no line has the values we plan for team Y. (`SUBNET` and `VPC_NAME` do not come out of this jsonpath; you check those two in the tenant VPC list in Prism Central, because NKP has no object for a VPC or a subnet.)

Step B — make the new cluster env file. Replace `<cluster>` with the name from question 1, and then use the real path in every later block. **Plan: it writes a file with one line, `source ~/nkp-site.env 2>/dev/null`, mode 600. Result: an empty cluster file that inherits the site values. I run it only after "yes".**

```bash
# CHANGES  (makes the cluster env file with mode 600 if it does not exist)
test -e ~/nkp-<cluster>.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-<cluster>.env); }
```

Step C — the values. Two of them are in your message; the rest are not, so I show only the two blocks, and one block for each value you give in your answer:

```bash
# CHANGES  (appends VPC_NAME to the cluster env file; the VPC name you gave: vpc-y)
source ~/nkp-<cluster>.env 2>/dev/null
echo "export VPC_NAME='vpc-y'" >> ~/nkp-<cluster>.env
```

```bash
# CHANGES  (appends SUBNET to the cluster env file — this cluster only; the overlay subnet you gave: vpc-y-nodes)
source ~/nkp-<cluster>.env 2>/dev/null
echo "export SUBNET='vpc-y-nodes'" >> ~/nkp-<cluster>.env
```

For each value from question 2, in a later reply, this same shape with that value in the line: `CP_VIP`, `LB_IP_RANGE`, `FIP_API`, `FIP_UI`, `API_EXTERNAL_ENDPOINT`, `UI_HOSTNAME`, and `WORKSPACE_NS`. I do not write a line with an empty value or a placeholder.

Step D — check the files (READ-ONLY; prints names, never values):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && bash -n ~/nkp-<cluster>.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS VPC_NAME FIP_API FIP_UI API_EXTERNAL_ENDPOINT UI_HOSTNAME SUBNET MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
echo "PE_CLUSTER from the site file: ${PE_CLUSTER:-(empty)}"; echo "STORAGE_CONTAINER from the site file: ${STORAGE_CONTAINER:-(empty)}"
```

Done when every line is `set:` and the last two print the site values (same PE cluster — nothing to add). `MISSING: MGMT_KUBECONFIG` means the site file has no management kubeconfig and the workload create cannot run.

Step E — the create. nutanix.md N5 for the workload cluster, with the two VPC lines before `"$@"`:

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
  --cluster-hostname "$UI_HOSTNAME" \
```

then the dry run, then the READ-ONLY grep of `host:`, `address:`, `hostname:` in the dry-run file, then the create (plan, "yes"), then the kubeconfig block, then nkp-vpc step 5. The team-x cluster is not touched at any point: no applied object names it and the site file does not change.

One check that is often forgotten, and that `vpc-y` makes more likely: the pod and service CIDRs of team Y must not overlap the `vpc-y` range or the `vpc-x` range. If they do, and the ranges are routed, the packets go to the pod network and are lost [portal]:

```bash
# READ-ONLY  (needs python3)
source ~/nkp-<cluster>.env 2>/dev/null
vpc_cidrs=''; pod_cidr='192.168.0.0/16'; svc_cidr='10.96.0.0/12'
: "${vpc_cidrs:?}"
python3 -c 'import ipaddress,sys; k=[ipaddress.ip_network(c) for c in sys.argv[1:3]]; v=[ipaddress.ip_network(c.strip()) for c in sys.argv[3].split(",")]; bad=[(str(a),str(b)) for a in k for b in v if a.overlaps(b)]; print("OVERLAP", bad) if bad else print("no overlap")' "$pod_cidr" "$svc_cidr" "$vpc_cidrs"
```

---

## nkp-ndk K1

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-ndk/SKILL.md` (steps 1-5), `skills/nkp-platform-apps-gitops/SKILL.md` (step 2), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O2, O3, O6), `skills/nkp-airgap/SKILL.md` (step 4, extra bundle), `skills/nkp-airgap/references/catalogs.md` (C1), `skills/nkp-airgap/references/prestage.md` (P6, P7).

**The shape of the job on this site:** NDK 2.3.0 is the only version in the 2.19.0 product catalog bundle, and it is a catalog app with workspace scope, Pro and Ultimate, Nutanix infrastructure only. [live 2.19.0][pdf p.337] Your license is Ultimate, so it qualifies. On a dark site the images come through the Harbor mirror, so **no** `NDK_PULL_USERNAME`/`NDK_PULL_TOKEN` and **no** `ndk-image-pull-secret`. [field] The chart needs cert-manager ≥ 1.13 and Nutanix CSI ≥ 3.7.1. Your own CA and certificate mean TLS mode `SECRET` (or `ISSUER` if you have an Issuer in `ntnx-system`) — not `SELF_SIGNED` and not `none`, because this is production.

**Questions I would ask first (ask_user_question):**

1. "TLS mode for NDK service-to-service traffic. You have a CA, so:"
   - "`SECRET`: a TLS Secret in `ntnx-system` on `prod-01`, made from our certificate (Recommended for production: no `clusterName` in the values, the chart uses the certificate SAN)"
   - "`ISSUER`: an Issuer in `ntnx-system` issues the certificate through cert-manager, plus `clusterName`"
   - "`SELF_SIGNED` with mTLS later" (not for production; [portal] says so)
2. "What is the workspace namespace of workspace `prod`? I read it from `get workspaces` and do not assume `prod`."
   - "Use the namespace that `get workspaces` shows (Recommended)"
   - "I give the namespace" (free text)
3. "Which names and paths: the DNS name in the certificate SAN (the name the peer will use), and the three PEM files for the Secret?"
   - "The certificate DNS name is the cluster name `prod-01` with the site DNS suffix, and the files are on the bastion (Recommended if that is what your CA issued)"
   - "Other name and paths" (free text)
4. "Is the NDK part of the bundle already in Harbor? Your mirror has the 2.19.0 bundle; the catalog bundle is a separate file (`container-images/nkp-nutanix-product-catalog-image-bundle-2.19.tar`)."
   - "I do not know — run the HEAD check first (Recommended)"
   - "Yes, the whole bundle including the product catalog is pushed"
   - "No — push it now" (then I need the file path, and the push account lines in the site file)

**Plan and blocks**

Step A — read the state (SKILL.md step 1, READ-ONLY). This is the tier, the CSI and cert-manager versions, the catalog app, and whether NDK already runs:

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get apps,appdeployments | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get csidrivers csi.nutanix.com --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd referencegrants.gateway.networking.k8s.io
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd | grep -E 'dataservices.nutanix.com|scheduler.nutanix.com'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|ndk|cert-manager'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy,svc | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclusters,remotes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get applications.dataservices.nutanix.com,replicationtargets,appprotectionplans -A
```

Done when: the tier is `Ultimate` (or `Pro`/`Full Stack`), the CSIDriver label shows ≥ 3.7.1, a `cert-manager` line shows ≥ 1.13, and the catalog app `ndk-2.3.0` appears — or it does not, and then step C makes the catalog. A `Starter` line stops the job: NDK is not available. [live 2.19.0]

Step B — the prerequisites that only you or the node can show (SKILL.md step 2): Prism Central 7.5+ and AOS 7.5+ (7.5.1 for NearSync or multi-namespace), the Prism Central user is admin or has the Prism Admin role (NDK uses the CSI credentials), an iSCSI data-services VIP on the Prism Element cluster, one free MetalLB IP on `prod-01`, and `iscsi-initiator-utils` on each worker:

```bash
# USER-TERMINAL  (on each worker node of prod-01, over SSH)
rpm -q iscsi-initiator-utils
```

Step C — the catalog on the dark site. First this HEAD request for the catalog artifact; it prints only the HTTP code and reads the pull account from the file (step 3 item 1):

```bash
# READ-ONLY  (HEAD request for the NDK catalog artifact with the pull account on stdin; prints only the HTTP code)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; : "${h:?REGISTRY_URL is empty}"; p=''; case "$h" in */*) p="${h#*/}/" ;; esac
u=$(printenv REGISTRY_MIRROR_USERNAME); w=$(printenv REGISTRY_MIRROR_PASSWORD); w=${w//\\/\\\\}; w=${w//\"/\\\"}; { [ -n "$u" ] && printf 'user = "%s:%s"\n' "$u" "$w"; } | curl -K - -s -I -o /dev/null -w '%{http_code}\n' --cacert "$REGISTRY_CA_FILE" -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json' "https://${h%%/*}/v2/${p}nutanix-cloud-native/nkp-nutanix-product-catalog/collection/manifests/2.19"
```

`200`: the catalog artifact is in Harbor, and I go to step D. `404`: push the catalog bundle. `401`: a wrong pull account, or a registry that wants a token login — you check the project in the Harbor UI. `000`: no connection or a CA error.

If it is `404`: **plan — push one extra bundle file into the Harbor mirror. Result: the NDK catalog artifact and its images are in the registry; no cluster changes. `EXTRA_BUNDLE` holds the catalog bundle path, which I append after you confirm the path (rule 4).** The push needs `REGISTRY_PUSH_USERNAME` and `REGISTRY_PUSH_PASSWORD` in the site file (rule 5, your editor); the CLI takes the password as a flag, so other users on the host can see it in the process list.

```bash
# CHANGES  (appends EXTRA_BUNDLE to the site env file — one path, after your confirmation)
source ~/nkp-site.env 2>/dev/null
echo "export EXTRA_BUNDLE='the path you confirm'" >> ~/nkp-site.env
```

```bash
# CHANGES  (pushes the images of one extra bundle file into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$EXTRA_BUNDLE" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

Then the catalog object, in workspace `kommander-workspace` so that it is in every workspace (C1 step 3). **Plan: it creates one OCIRepository catalog on the management cluster. Result: `ndk-2.3.0` becomes visible in workspace `prod`. CHANGES — I stop for "yes".**

```bash
# CHANGES  (creates an OCIRepository catalog in the kommander-workspace; it goes to all workspaces)
source ~/nkp-site.env 2>/dev/null
repo='nutanix-cloud-native/nkp-nutanix-product-catalog/collection'; tag='2.19'; : "${REGISTRY_URL:?REGISTRY_URL is empty, see A-07}"
nkp create catalog-app --url "oci://${REGISTRY_URL#*://}/$repo" --tag "$tag" --workspace kommander-workspace --kubeconfig "$MGMT_KUBECONFIG"
```

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get ocirepositories
```

Done when the new OCIRepository shows READY `True`. An `A-07` "not found" means the push did not keep the repository path.

Step D — the TLS Secret on `prod-01`. Mode `SECRET` has no `clusterName`; the chart fails with `clusterName cannot be provided` if you set it. [live 2.19.0] The Secret must exist before the HelmRelease runs. **Plan: it creates the TLS Secret in `ntnx-system` on `prod-01` from three PEM files. Result: the NDK intercom certificate; the private key is in the cluster and I never print it. I run it only after "yes", and the certificate names must include the DNS name from question 3.**

```bash
# CHANGES  (creates the NDK TLS Secret in ntnx-system on prod-01)
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system create secret tls ndk-intercom-tls --cert="$NDK_CERT_FILE" --key="$NDK_KEY_FILE"
```

(`NDK_CERT_FILE`, `NDK_KEY_FILE` and `NDK_CA_FILE` are the file paths you give; I append them to `~/nkp-prod-01.env` after you give them, and the private key file stays mode 600.)

Step E — the values file (SKILL.md step 3 item 3). `mode='SECRET'`, `secret` = the Secret name, `mtls=''` for now, `metrics=true` so the ServiceMonitor exists if you later want the alerts. **Plan: it writes `~/prod-01-ndk-values.yaml` on the operator host and prints it. Result: the NDK values for the app override. No cluster change. I run it only after "yes".**

```bash
# CHANGES  (writes the NDK values file on the operator host; changes no cluster)
source ~/nkp-prod-01.env 2>/dev/null
mode='SECRET'; tls_name=''; issuer=''; secret='ndk-intercom-tls'; mtls=''; metrics='true'
case "$mode" in SELF_SIGNED|ISSUER|SECRET) ok=1 ;; *) ok='' ;; esac; : "${ok:?set mode to SELF_SIGNED, ISSUER, or SECRET}"
[ "$mode" = SECRET ] && : "${secret:?}" || : "${tls_name:?}"; [ "$mode" = ISSUER ] && : "${issuer:?}"
f="$HOME/$CLUSTER_NAME-ndk-values.yaml"
{ printf 'tls:\n  server:\n    enable: true\n    mode: %s\n' "$mode"
  case "$mode" in
    SELF_SIGNED) printf '    clusterName: %s\n' "$tls_name" ;;
    ISSUER) printf '    issuer:\n      issuerName: %s\n    clusterName: %s\n' "$issuer" "$tls_name" ;;
    SECRET) printf '    secretName: %s\n' "$secret" ;;
  esac
  if [ "$mtls" = true ]; then printf '    enableMTLS: true\n'; fi
  if [ "$metrics" = true ]; then printf 'prometheus:\n  enable: true\nserviceMonitor:\n  customLabels:\n    prometheus.kommander.d2iq.io/select: "true"\n'; fi
} > "$f" && cat "$f"
```

Step F — the override ConfigMap (overrides.md O3, `APP_ID` `ndk`). Use the name `$APP_ID-overrides-ws` and **not** `ndk-overrides` (O1, slot 2). Check the YAML, then the server dry run, then apply. The apply is CHANGES with its plan and "yes". Here I create the ConfigMap **before** the AppDeployment, because `nkp create appdeployment --config-overrides` names it, and an AppDeployment that names a missing ConfigMap waits. [pdf p.350]

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
: "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

Wait — the O3 item 2 check reads the values file with the `APP_ID` name, and step E wrote `prod-01-ndk-values.yaml`. For `APP_ID=ndk` the names agree. Then:

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-prod-01.env 2>/dev/null
cm='ndk-overrides-ws'; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

```bash
# CHANGES  (creates the override ConfigMap on the management cluster)
source ~/nkp-prod-01.env 2>/dev/null
cm='ndk-overrides-ws'; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
```

Step G — enable the app (gitops step 2). Preview with `--dry-run` first (it prints the object and creates nothing), then the real create. **Plan: this creates the AppDeployment `ndk` for ClusterApp `ndk-2.3.0` in workspace `prod`, with `--config-overrides ndk-overrides-ws`. Result: Kommander installs NDK in `ntnx-system` on `prod-01` and takes one MetalLB IP for `ndk-intercom-service`. I run it only after "yes".**

```bash
# CHANGES  (client dry run only: prints the AppDeployment; creates nothing)
source ~/nkp-prod-01.env 2>/dev/null
name='ndk'; app='ndk-2.3.0'; ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --config-overrides ndk-overrides-ws --kubeconfig "$MGMT_KUBECONFIG" --dry-run
```

```bash
# CHANGES  (creates the AppDeployment; NKP installs NDK on the target clusters)
source ~/nkp-prod-01.env 2>/dev/null
name='ndk'; app='ndk-2.3.0'; ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --config-overrides ndk-overrides-ws --kubeconfig "$MGMT_KUBECONFIG"
```

`app='ndk-2.3.0'` above is only a placeholder for the run: the real value is the App name that step A prints (a ClusterApp name is `<app-id>-<catalog version>`). If step A prints another name, I use that name and change nothing else.

Step H — check (SKILL.md step 3 item 5 + O6), READ-ONLY:

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment ndk -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy,svc,pods | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get configmap ndk-manager-config -o yaml | grep -E 'enableTLS|enableMTLS|clusterName|port:'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get events --field-selector reason=Failed
```

Done when: `AppDeploymentEnabled=True AppDeploymentInstanceSynced=True`, the HelmRelease `ndk` is READY `True`, `ndk-controller-manager` is `1/1`, `ndk-intercom-service` has an `EXTERNAL-IP` (not `<pending>`), and the configmap shows TLS on with no `clusterName`. The last command answers UNKNOWN (D-50): on a dark site with no pull Secret, a `Failed` event with `ImagePullBackOff` means the mirror does not serve the images, and the fix is step C.

Step I — the `StorageCluster` (step 4). Two UUIDs, from your side:

```bash
# USER-TERMINAL  (once on a CVM of the Prism Element cluster, once on the Prism Central VM, over SSH)
ncli cluster info | grep -i 'cluster uuid'
```

**Plan: it writes `~/prod-01-ndk-storagecluster.yaml` with a name and the two UUIDs. Result: one StorageCluster that binds NDK to your Prism Element and Prism Central. No cluster change yet. I run it only after "yes"; then SKILL.md step 5 does the dry run, the plan, and the apply.** The name is lowercase, and I ask for it (a name such as the Prism Element name in DNS form is a suggestion, not a value I write).

```bash
# CHANGES  (writes the StorageCluster file on the operator host; changes no cluster)
source ~/nkp-prod-01.env 2>/dev/null
name=''; pe_uuid=''; pc_uuid=''
: "${name:?}" "${pe_uuid:?}" "${pc_uuid:?}"
f="$HOME/$CLUSTER_NAME-ndk-storagecluster.yaml"
printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: StorageCluster\nmetadata:\n  name: %s\nspec:\n  storageServerUuid: %s\n  managementServerUuid: %s\n' "$name" "$pe_uuid" "$pc_uuid" > "$f" && cat "$f"
```

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-prod-01.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
```

Done for the install when `kubectl get storageclusters` shows AVAILABLE `true` and the `ndk-intercom-service` IP is stable. After that: NDK alerts are the K5 job, and `ndkcli`, the recipes image and the KB-16326 script are **not** in the 2.19.0 bundle — you need the portal NDK bundle (P7) before the site closes, or you do without failover recipes and the support script.

---

## nkp-ndk K4

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-ndk/SKILL.md` (steps 4-5), `skills/nkp-ndk/references/replication.md` (R0-R5, R7), `skills/nkp-ndk/references/protect.md` (P1, P6).

**The shape of the job:** async, hourly, one target, keep 5, app `inventory` in namespace `inv`, from east-01 to west-01. Both sites are `SELF_SIGNED`, so the peer `Remote` uses `tls: skip` (TLS, no CA check) and `clusterName` must be the DNS name in the peer certificate — that is the value in `ndk-manager-config` on west-01. Async gives RPO = the schedule, WAN is fine, and the failover is a restore on west-01 (R7), not a failover object. Prerequisites: the same StorageClass names and the same storage container names on both sites, and TCP 2021 both ways between the two `ndk-intercom-service` IPs.

**Questions I would ask first (ask_user_question):**

1. "Which namespace on west-01 gets the copies?"
   - "`inv` on west-01 as well (Recommended: the restore and the `ReplicationTarget` are simpler, and the namespace must exist there)"
   - "Another namespace on west-01 (I give it)"
2. "Which label selects the `inventory` application in `inv`? The `Application` object needs one label selector."
   - "`app=inventory` (Recommended only if that label is on the workload, Service and PVCs)"
   - "Another label (I give it)"
3. "The `JobScheduler` needs a time zone and a start time."
   - "`UTC`, no `startTime`, interval 60 minutes (Recommended: hour 0 of UTC; the first snapshot starts immediately)"
   - "Our local IANA zone (I give it)"
4. "Names: the `Remote`, the `ReplicationTarget`, the `ProtectionPlan`?"
   - "`Remote` `west-01`, `ReplicationTarget` `west-inv`, `ProtectionPlan` `inv-hourly` (Recommended: names that say what they are)"
   - "Other names (free text)"

**Plan and blocks**

Order: R1 → R2 → R3 → P1 → R5 → checks. Each object has its own gate, and none of them can be changed after the create — a wrong value means delete and make again.

Step A — R1, on **west-01** (the replication cluster). Read its intercom IP and its TLS name (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-west-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get svc ndk-intercom-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get configmap ndk-manager-config -o yaml | grep -E 'enableTLS|enableMTLS|clusterName'
```

Also confirm on both sites that a `StorageCluster` shows AVAILABLE `true`, and that `inv` exists on west-01:

```bash
# READ-ONLY
source ~/nkp-west-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclusters
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns inv
```

Done when: you have the intercom IP of west-01 and the `clusterName` from its configmap, and you ask your network team to open TCP 2021 between the two intercom IPs in both directions. [field] The `clusterName` must be the DNS name in west-01's certificate — with `SELF_SIGNED` it is the value the chart put there, not the cluster object name.

Step B — R2, on **east-01** (the primary): write the `Remote`. `tls='skip'`, `peer_ip` = the R1 IP, `peer_name` = the R1 `clusterName`. **Plan: it writes `~/east-01-ndk-remote-west-01.yaml` on the operator host. Result: one cluster-scoped `Remote` on east-01 that points at west-01 on 2021 with TLS and no CA check. No cluster change yet. I run it only after "yes"; then step 5 does the dry run, the plan, and the apply.**

```bash
# CHANGES  (writes the Remote file on the operator host; changes no cluster)
source ~/nkp-east-01.env 2>/dev/null
name=''; peer_name=''; peer_ip=''; tls=''; ca_file=''; mtls_secret=''
: "${name:?}" "${peer_name:?}" "${peer_ip:?}" "${tls:?off, skip, or ca}"
case "$tls" in off|skip) ;; ca) : "${ca_file:?}"; [ -s "$ca_file" ] || { echo "no CA file: $ca_file"; exit 1; } ;; *) echo "bad tls: off, skip, or ca"; exit 1 ;; esac
if [ -n "$mtls_secret" ] && [ "$tls" = off ]; then echo "mTLS needs TLS"; exit 1; fi
f="$HOME/$CLUSTER_NAME-ndk-remote-$name.yaml"
{ printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: Remote\nmetadata:\n  name: %s\nspec:\n  clusterName: %s\n  ndkServiceIp: "%s"\n  ndkServicePort: 2021\n' "$name" "$peer_name" "$peer_ip"
  case "$tls" in
    off) ;;
    skip) printf '  tlsConfig:\n    skipTLSVerify: true\n' ;;
    ca) printf '  tlsConfig:\n    skipTLSVerify: false\n    caBundle: %s\n' "$(base64 < "$ca_file" | tr -d '\n')" ;;
  esac
  if [ -n "$mtls_secret" ]; then printf '    enableMTLS: true\n    mTLSClientConfig:\n      secretName: %s\n      secretNamespace: ntnx-system\n' "$mtls_secret"; fi
} > "$f" && cat "$f"
```

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-east-01.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
```

Check after the apply: `kubectl get remotes` shows AVAILABLE `True`. Not `True`: read REASON and operations.md X5. A wrong `clusterName` or a closed 2021 is the usual pair. The spec cannot change: delete and make again.

Step C — R3, on east-01: the `ReplicationTarget` in namespace `inv`. **Plan: it writes `~/east-01-ndk-rt-inv-west-inv.yaml`. Result: one `ReplicationTarget` in `inv` that names `Remote` `west-01` and the namespace `inv` on west-01. I run it only after "yes"; then dry run, plan, apply.**

```bash
# CHANGES  (writes the ReplicationTarget file on the operator host; changes no cluster)
source ~/nkp-east-01.env 2>/dev/null
ns='inv'; target=''; remote=''; dst_ns='inv'
: "${ns:?}" "${target:?}" "${remote:?}" "${dst_ns:?}"
f="$HOME/$CLUSTER_NAME-ndk-rt-$ns-$target.yaml"
printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: ReplicationTarget\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  remoteName: %s\n  namespaceName: %s\n' "$target" "$ns" "$remote" "$dst_ns" > "$f" && cat "$f"
```

Check: `kubectl get replicationtargets` in `inv` shows AVAILABLE `True`.

Step D — P1, on east-01: the `Application` for `inventory`. First read the namespace, because the selector must be real (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-east-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n inv get deploy,sts,pvc,svc,cm --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n inv get pvc -o custom-columns='NAME:.metadata.name,SC:.spec.storageClassName,STATUS:.status.phase'
```

Done when every PVC uses a `csi.nutanix.com` StorageClass (NDK protects only Nutanix CSI volumes) and you name the one label. **Plan: it writes `~/east-01-ndk-app-inv-inventory.yaml`. Result: one `Application` in `inv` that selects the objects with your label. I run it only after "yes"; then dry run, plan, apply. Check: ACTIVE `True`.**

```bash
# CHANGES  (writes the Application file on the operator host; changes no cluster)
source ~/nkp-east-01.env 2>/dev/null
ns='inv'; name=''; sel=''
: "${ns:?}" "${name:?}" "${sel:?set one label as key=value}"
f="$HOME/$CLUSTER_NAME-ndk-app-$ns-$name.yaml"
cat > "$f" <<EOF
apiVersion: dataservices.nutanix.com/v1alpha1
kind: Application
metadata:
  name: $name
  namespace: $ns
spec:
  applicationSelector:
    resourceLabelSelectors:
    - labelSelector:
        matchLabels:
          ${sel%%=*}: "${sel#*=}"
EOF
cat "$f"
```

Step E — R5, on east-01: the async plan, hourly, keep 5. **Plan: it writes `~/east-01-ndk-plan-inv-inv-hourly.yaml` with three objects: a `JobScheduler` (interval 60 minutes, your time zone), a `ProtectionPlan` (`protectionType: async`, `scheduleName` = the plan, `retentionPolicy.retentionCount: 5`) and an `AppProtectionPlan` that joins them to the `Application`. Result: one snapshot each hour, five copies kept on west-01, and each copy replicates to the target. I run it only after "yes"; then dry run, plan, apply.**

```bash
# CHANGES  (writes the replication plan file on the operator host; changes no cluster)
source ~/nkp-east-01.env 2>/dev/null
ns='inv'; app=''; plan=''; type='async'; targets=''; interval_min='60'; tz=''; keep='5'; rpo=''
: "${ns:?}" "${app:?}" "${plan:?}" "${type:?async, sync, or nearSyncDR}" "${targets:?}"
f="$HOME/$CLUSTER_NAME-ndk-plan-$ns-$plan.yaml"
{ if [ "$type" = async ]; then printf 'apiVersion: scheduler.nutanix.com/v1alpha1\nkind: JobScheduler\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  interval:\n    minutes: %s\n  timeZoneName: "%s"\n---\n' "$plan" "$ns" "${interval_min:?}" "${tz:?}"; fi
  printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: ProtectionPlan\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  protectionType: %s\n' "$plan" "$ns" "$type"
  case "$type" in
    async) printf '  scheduleName: %s\n  retentionPolicy:\n    retentionCount: %s\n' "$plan" "${keep:?}" ;;
    nearSyncDR) printf '  rpo: %s\n' "${rpo:?}" ;;
  esac
  printf '  replicationConfigs:\n'; for t in $targets; do printf '  - replicationTargetName: %s\n' "$t"; done
  printf -- '---\napiVersion: dataservices.nutanix.com/v1alpha1\nkind: AppProtectionPlan\nmetadata:\n  name: %s-%s\n  namespace: %s\nspec:\n  applicationName: %s\n  protectionPlanNames:\n  - %s\n' "$app" "$plan" "$ns" "$app" "$plan"
} > "$f" && cat "$f"
```

Step F — check (R5, READ-ONLY), after about one hour:

```bash
# READ-ONLY
source ~/nkp-east-01.env 2>/dev/null
ns='inv'; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get protectionplans,appprotectionplans,applicationsnapshotreplications
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applicationsnapshots --sort-by=.metadata.creationTimestamp
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get jobschedulers
```

```bash
# READ-ONLY
source ~/nkp-west-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n inv get applicationsnapshots --sort-by=.metadata.creationTimestamp
```

Done when: a new `applicationsnapshotreplications` line reaches PROGRESS `100`, the `ProtectionPlan` and `AppProtectionPlan` are AVAILABLE `True` and not DEGRADED, the `JobScheduler` shows a NEXTACTIVATION, and the snapshots appear in `inv` on west-01. Retention: NDK keeps at most **15** copies on the replication cluster, so 5 is inside the limit. [portal]

Two things to say now: async has **no** failover object. A recovery is a restore of the newest replicated snapshot on west-01 (protect.md P3), which brings the app up there but does not stop east-01 and does not reverse the replication. The recipe jobs that do a real async failover (`migrate`, `failover`, `reset-replication`) are in the portal NDK bundle (`ndk-2.3.0-recipes.tar` + image `ndk/recipes:2.3.0`), which is not in the 2.19.0 bundle, and their config keys are UNKNOWN (D-52). Also, no lab run of these steps exists (D-04) — the first hour is the test.

---

## nkp-ndk K5

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-ndk/SKILL.md`, `skills/nkp-ndk/references/operations.md` (X1, X5), `skills/nkp-observability/references/monitoring.md` (M0, M2), `skills/nkp-airgap/references/prestage.md` (P6, "Use an asset").

**The important fact first:** the NDK alert rules read `kube_event_unique_events_total{container="prometheus-k8s-events-exporter"}`. That metric comes from a Kubernetes event exporter, and **NKP 2.19.0 has no event exporter app**. So the rules load and then never fire. UNKNOWN (D-54): which exporter gives that metric on 2.19. I tell you this before I write anything, because "alerts installed" and "alerts working" are two different results here. The rule file is `assets/ndk-alert-config.yaml` of the `nkp-airgap` skill (P6: the upstream file is not valid YAML; this copy is fixed). Do not copy it from anywhere else.

**Questions I would ask first (ask_user_question):**

1. "The rules cannot fire without an events exporter, and NKP 2.19.0 has none in the bundle. Do I install the rules now, or wait?"
   - "Install the rule object now; it is ready when an exporter exists (Recommended — it is harmless and it is one object)"
   - "Stop until we have an exporter" (then I only give you the D-54 check)
   - "We have an exporter already; check it first" (the D-54 check decides)
2. "Which namespace of the stack? On the management cluster it is `kommander`, and `ntnx-system` must be selected by `ruleNamespaceSelector`."
   - "Read it from the cluster with M0 and use what it shows (Recommended)"
   - "I know it; I give it" (free text)
3. "Do you want the NDK controller metrics too (the ServiceMonitor from `metrics=true` in the NDK values)?"
   - "Yes — add `metrics=true` to the existing NDK override (Recommended)"
   - "No, only the event rules"

**Plan and blocks**

Step A — the exporter check (UNKNOWN D-54, READ-ONLY). This decides the honest result:

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -i event
```

Step B — M0, the stack namespace and the selectors (READ-ONLY). The two selectors that matter are `ruleSelector` and `ruleNamespaceSelector`:

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAMESPACE|kube-prometheus-stack'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  serviceMonitorSelector={.spec.serviceMonitorSelector}{"\n"}  serviceMonitorNamespaceSelector={.spec.serviceMonitorNamespaceSelector}{"\n"}  ruleSelector={.spec.ruleSelector}{"\n"}  ruleNamespaceSelector={.spec.ruleNamespaceSelector}{"\n"}  retention={.spec.retention}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get alertmanagers -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  configSelector={.spec.alertmanagerConfigSelector}{"\n"}  configNamespaceSelector={.spec.alertmanagerConfigNamespaceSelector}{"\n"}  matcherStrategy={.spec.alertmanagerConfigMatcherStrategy}{"\n"}{end}'
```

Done when: I know one label from `ruleSelector` (`lkey`/`lval`) and that `ruleNamespaceSelector` selects `ntnx-system`. If it does not select `ntnx-system`, I stop and tell you — the rule object would sit there and Prometheus would ignore it.

Step C — check the asset body (P6 "Use an asset", READ-ONLY). `dir` is the only edit of this block: the `nkp-airgap` skill folder.

```bash
# READ-ONLY
dir='/tmp/nkp-eval-b5r/skills/nkp-airgap'; : "${dir:?}"
for f in "$dir"/assets/*.yaml; do want="$(sed -n 's/^# Body SHA-256: //p' "$f")"; got="$(grep -v '^# ' "$f" | sha256sum | cut -d' ' -f1)"; [ "$want" = "$got" ] && echo "OK $f" || echo "FAILED $f"; done
```

Every line must say `OK`. A `FAILED` line stops the job: do not apply that file.

Step D — write the labelled copy. **Plan: it writes `~/mgmt-01-ndk-alert-config.yaml` on the operator host: the asset with one NKP rule label added under `labels`. Result: a `PrometheusRule` that `ruleSelector` selects and that sits in `ntnx-system`. No cluster change. I run it only after "yes".**

```bash
# CHANGES  (writes a copy of the NDK alert rules with the NKP rule label on the operator host; changes no cluster)
source ~/nkp-mgmt-01.env 2>/dev/null
dir=''; lkey=''; lval=''
: "${dir:?}" "${lkey:?}" "${lval:?}"
f="$HOME/$CLUSTER_NAME-ndk-alert-config.yaml"
awk -v k="$lkey" -v v="$lval" '{print} /^  labels:$/ && !d {print "    " k ": \"" v "\""; d=1}' "$dir/assets/ndk-alert-config.yaml" > "$f" && grep -v '^# ' "$f" | head -10
```

`lkey` and `lval` come from M0, and `dir` is the skill folder. The asset has 12 rules in one `PrometheusRule` `ndk-event-rules` (snapshot, replication, retention, remote cluster, Prism Central authentication), with the upstream labels `prometheus: k8s` and `role: alert-rules` — those are not NKP labels, which is why the copy is necessary. [live 2.19.0 asset]

Step E — preview, then apply. Both on `ntnx-system` of `mgmt-01`:

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-mgmt-01.env 2>/dev/null
name='ndk-event-rules'; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$HOME/$CLUSTER_NAME-ndk-alert-config.yaml"
```

**Plan: it creates one `PrometheusRule` named `ndk-event-rules` in `ntnx-system` on `mgmt-01`. Result: Prometheus loads 12 NDK rules; they evaluate against `kube_event_unique_events_total` and, without an events exporter, they stay inactive. I run it only after "yes".**

```bash
# CHANGES  (creates or updates one PrometheusRule)
source ~/nkp-mgmt-01.env 2>/dev/null
name='ndk-event-rules'; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$HOME/$CLUSTER_NAME-ndk-alert-config.yaml"
```

Step F — check (READ-ONLY): the rule object is there, and Prometheus loaded it:

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get prometheusrules ndk-event-rules --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system logs -c prometheus -l app.kubernetes.io/name=prometheus --tail=100 2>/dev/null | grep -i -E 'rule|error' | tail -5
```

Done when the rule shows your `ruleSelector` label and the Prometheus UI (Alerts page of the cluster Grafana) lists the NDK group — the skill's done-when names the group `ndk-snapshot-failure-rules`, and the object is `ndk-event-rules`; I read the group names from the object we applied and check them in the UI. A PromQL error means the rule is not loaded.

If you also want the controller metrics (question 3), the change is the NDK values file with `metrics=true` (the `prometheus.enable` + top-level `serviceMonitor` keys, else the chart fails with `nil pointer evaluating interface {}.customLabels`), then overrides.md O3 items 3-4 for `APP_ID` `ndk` — same ConfigMap `ndk-overrides-ws` that K1 made.

---

## nkp-ndk K6

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-ndk/SKILL.md` (step 2 footnote, "The NDK parts").

**Answer: not in the skills.** For both questions the skills say so directly:

- Scale limits: SKILL.md step 2 ends with "The Kubernetes versions that NDK supports and the NDK scale limits (applications, snapshots, targets) are not in the skills (open item **D-03**, no check command)." So I have no maximum number of protected applications, and no maximum number of replication targets, per NKP cluster. I will not give a number from general knowledge.
- Kubernetes versions of NDK 2.3: the same open item. The skills hold one adjacent fact, and it is a different fact: the NDK catalog app in the 2.19.0 bundle supports **NKP** versions `>=2.18.0 <2.20.0`, and needs cert-manager ≥ 1.13 and Nutanix CSI ≥ 3.7.1. [live 2.19.0] That is the NKP range, not a Kubernetes range.

**Questions I would ask first (ask_user_question):**

1. "Do you want the real limits, or the current usage?"
   - "Current usage on our clusters, from the cluster itself (Recommended — it is the only thing I can prove offline)"
   - "The vendor limits. These are in the NDK 2.3 documentation and in Nutanix support; the skills do not have them"
   - "Both"
2. "Which cluster is the question about — one cluster, or per-cluster across the estate?"
   - "One cluster (I give the name) (Recommended)"
   - "Every cluster: run the same count on each"
3. "Do you have a support case or the portal NDK 2.3 guide in the air gap?"
   - "Yes, I have the guide/support answer and I will give it to you, so you can put it in the notes (Recommended)"
   - "No — then the question stays open, marked D-03"

**Plan and blocks**

What I can show, READ-ONLY, is the count of objects that exist now and the versions that run. That is not the vendor limit — it is your current position:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get applications.dataservices.nutanix.com -A --no-headers | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get replicationtargets -A --no-headers | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get remotes --no-headers | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get applicationsnapshots -A --no-headers | wc -l
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
nkp version
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get --raw /version
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy ndk-controller-manager -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\t"}{.image}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get csidrivers csi.nutanix.com --show-labels
```

The NDK image tag shows the NDK version (2.3.0 here); `get --raw /version` shows the Kubernetes version the cluster runs. The correlation of that Kubernetes version with "NDK 2.3 supports it" is exactly the fact that is missing.

To close D-03 you need one of these, both outside the air gap: the NDK 2.3 documentation (portal), or a Nutanix support answer. If you have that text in the site, give it to me and I will write it into the answer with its tag; if not, the honest status stays "not in the skills, open item D-03". I do not make up an ID or a fact (rule 6).
