# Answers: nkp-flow-cni batch (batch 5)

Skill files read for every answer below:

- `skills/nkp/SKILL.md` (router) and `skills/_shared/RULES.md`
- `skills/nkp-flow-cni/SKILL.md`, `skills/nkp-flow-cni/references/install.md`, `skills/nkp-flow-cni/references/egress-vpc.md`
- `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`
- `skills/nkp-airgap/SKILL.md`, `skills/nkp-airgap/references/prestage.md`
- `skills/nkp-networking/references/cni.md` (CNI cannot change; the Flow provider value)
- `skills/nkp-vpc/references/layouts.md` (L5: Flow CNI and a VPC, open item N-04)

---

## nkp-flow-cni L1

> we want flow cni for a new workload cluster dev-flow on AHV. PC is pc.7.5, VM_IMAGE in my env is the ubuntu 24.04 nkp image. go

**Skill files read:** `skills/nkp/SKILL.md`; `skills/_shared/RULES.md`; `skills/nkp-flow-cni/SKILL.md` (step 1, step 3); `skills/nkp-flow-cni/references/install.md` (I1); `skills/nkp-install/references/nutanix.md` (N1 "Node OS image", N5); `skills/nkp-networking/references/cni.md` (C1).

### I cannot go. Two prereq items fail.

From `nkp-flow-cni` step 1, the table of needs. Flow CNI 1.1.0 needs all of them:

| Item | Need | Your site | Result |
|---|---|---|---|
| Prism Central | pc.7.6 or later. pc.7.5 is not enough. | pc.7.5 | **FAIL** |
| Node OS | Rocky Linux on all nodes | `VM_IMAGE` = Ubuntu 24.04 | **FAIL** |
| AOS, AHV | AOS 7.6+, AHV 11.2+ | not given | ask |
| Network Controller | 7.6.0+, Flow in "Integrated with Prism Central" mode | not given | ask |
| Node subnets | VLAN Basic (AHV-managed) | not given | ask |
| Prism Central onboarding | the cluster is onboarded at create | default true | ok |
| CIDRs | pod/service CIDRs clear of every VPC CIDR | not given | ask |
| License tier | UNKNOWN (F-08) | not given | ask Nutanix |

The skill says: "If one item fails, stop." Two fail. I will not write a create script, and I will not put Cilium in its place without your word on the record.

Why the image matters: Flow CNI keeps the nodes on VLAN Basic subnets and runs OVN on the nodes. The image must be Rocky Linux. Ubuntu needs Pro or Ultimate for NKP in general, but for Flow CNI the skill asks for Rocky on all nodes (`nkp-flow-cni` step 1; `nkp-install` N1 "Node OS image"). Ubuntu 24.04 is a valid NKP image, but it is the wrong image for this job.

Also: the AHV ClusterClass `nkp-nutanix-v2.19.0` is the only class that allows the CNI provider `Flow`. The other classes do not. [live 2.19.0]

### The questions I must ask first

`ask_user_question` (round 1, 4 questions):

1. "Prism Central is pc.7.5. Flow CNI needs pc.7.6 or later. Which do you want?"
   - "Stop; the PC admin upgrades to pc.7.6, then we continue (Recommended)"
   - "Use a new cluster with Cilium on pc.7.5 now, and do Flow CNI after the PC upgrade"
   - "Give me a different PC endpoint that is already 7.6+"
2. "Flow CNI needs a Rocky Linux image on every node. Your `VM_IMAGE` is Ubuntu 24.04. What is the name of the Rocky Linux 9.8 image in Prism Central?"
   - "I will give you the exact image name"
   - "Not there yet; the image must be uploaded/placed on the PE cluster first"
3. "Which Network Controller mode does Flow run in?"
   - "Integrated with Prism Central (Recommended)"
   - "Standalone Flow Controller"
   - "I do not know; I will ask the Prism Central admin (Settings > Flow Management)"
4. "Which NKP license tier does this site have?"
   - "Pro"
   - "Ultimate"
   - "Starter"
   - "I do not know; I will check with Nutanix"

Question 4 is not a formality: Flow CNI on Nutanix needs the Flow Virtual Networking entitlement. That tier is UNKNOWN (F-08) in the skills, so Nutanix support answers it, not me.

### The read-only checks I would run while you answer

Only the items that NKP can show. No CHANGES block until the prereqs pass.

```bash
# READ-ONLY
source ~/nkp-dev-flow.env 2>/dev/null
echo "VM_IMAGE=$VM_IMAGE"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get clusterclass -o custom-columns='NAME:.metadata.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get --raw "/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy/v2/charts/nutanix-flow-cni/tags/list"; echo
```

Note: `~/nkp-dev-flow.env` does not exist yet. If the block prints `VM_IMAGE=` empty, run the same lines with `source ~/nkp-site.env 2>/dev/null` in line 2. I make the cluster env file only when we start the create (CHANGES, after your "yes").

Done when:
- The image name has `rocky`. If not, you give a Rocky image name from Prism Central.
- The workspace namespace has the class `nkp-nutanix-v2.19.0` (or the class of your NKP version).
- The ConfigMap prints `ChartName: nutanix-flow-cni` and a `ChartVersion`, and the tag list has the same version. [live 2.19.0]
- You confirm PC 7.6+, AOS, AHV, Network Controller, mode, and the VLAN Basic subnet.

The chart version from that command is the version the management cluster serves. Per UNKNOWN (F-01) I use the version that this command prints; I do not pick a newer one.

### What happens after the prereqs pass

Path A (the only documented path): dry-run YAML of the create, remove `addons.cni`, add a `HelmChartProxy` for `nutanix-flow-cni`, apply both. `nkp create cluster` has no CNI flag. [live 2.19.0] Steps I1 to I7 of `references/install.md`, then step 4 of the skill. Path B (`clusterConfig.addons.cni.provider: Flow`) exists in the schema but is **not tested and has no Nutanix support statement** (UNKNOWN (F-02)) — I do not use it.

Also note before we start: in connected mode the HCP file holds the Flow CNI Docker Hub pull token as Base64 text, and every user who can read HelmChartProxies in the workspace namespace can read it. [`install.md` I4]

---

## nkp-flow-cni L2

> prereqs are all ok (pc 7.6, NC 7.6.1 integrated, rocky image, VLAN basic subnet). workload cluster flow-01 in workspace ns team-a-xyz, env file ~/nkp-flow-01.env already has everything for nkp-install N5. connected site. walk me through it

**Skill files read:** `skills/nkp-flow-cni/SKILL.md` (step 1, 3, 4); `skills/nkp-flow-cni/references/install.md` (I1–I7); `skills/nkp-install/SKILL.md` (kubeconfig, verify); `skills/nkp-install/references/nutanix.md` (N1, N2, N3, N5, N4D, N6); `skills/nkp-networking/references/cni.md` (C1).

### The questions I must ask first

`ask_user_question` (round 1, 4 questions):

1. "Connected site: Flow CNI needs the Nutanix portal Docker Hub access token for the private `docker.io/nutanix` images. Do you have it?"
   - "Yes, I put `FLOW_CNI_PULL_USERNAME` and `FLOW_CNI_PULL_TOKEN` in `~/nkp-site.env` myself (Recommended)"
   - "I have the portal account but no token yet; show me where to generate it"
   - "No token; the nodes pull through a mirror instead"
2. "Pod CIDR and service CIDR cannot change after the create, and they must not overlap any VPC CIDR, node subnet, or `CP_VIP`. Keep the NKP defaults (pods `192.168.0.0/16`, services `10.96.0.0/12`)?"
   - "Keep the defaults; they are clear of every VPC CIDR (Recommended)"
   - "Use other CIDRs; I will give them"
   - "I must check the Prism Central VPC list first"
3. "The cluster must stay onboarded to Prism Central (`--onboard-to-prism-central` stays true) and the `karbon-core` service must be on. Is it?"
   - "Yes, karbon-core is enabled (Recommended)"
   - "I will ask the PC admin to enable it"
   - "No"
4. "One more check before the apply: does the workspace namespace `team-a-xyz` already exist on the management cluster, and is the cluster name `flow-01` free in it?"
   - "I will run the check you show me (Recommended)"
   - "It exists and no cluster uses it"
   - "It does not exist yet"

### Step 0: read the env file (READ-ONLY)

`~/nkp-flow-01.env` has line 1 `source ~/nkp-site.env 2>/dev/null`. N2 check, case 5 connected with no mirror:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && bash -n ~/nkp-flow-01.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
for v in FLOW_CNI_PULL_USERNAME FLOW_CNI_PULL_TOKEN; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when every line says `set:`. A `MISSING: FLOW_CNI_PULL_*` line means you add those two lines with an editor yourself (rule 5):

```bash
# USER-TERMINAL  (you type the two Flow CNI pull lines into the env file)
vi ~/nkp-site.env
```

### Step 1: the Flow CNI prereq checks (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
echo "VM_IMAGE=$VM_IMAGE"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get clusterclass -o custom-columns='NAME:.metadata.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get --raw "/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy/v2/charts/nutanix-flow-cni/tags/list"; echo
```

Done when the image name has `rocky`, the workspace namespace has the Nutanix ClusterClass, and the ConfigMap and the tag list show the same chart version. Note the chart version; I4 reads it again.

`yq` is needed for I3 and I4, and the bundle has none:

```bash
# READ-ONLY
command -v yq && yq --version
```

The version line must contain `mikefarah` and `version v4`. If not, stop.

### Step 2: N5 step 1 — workspace namespaces and the mirror of the management cluster (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{.items[*].spec.kommanderCluster.spec.ociRegistry.mirrorURL}{"\n"}'
```

- The first list confirms `team-a-xyz`.
- The second prints an empty line on your connected site with no site mirror. That is correct here: the workload cluster then uses the Docker Hub credentials of the management cluster. [pdf p.675]

### Step 3: N5 step 3 — write the create script

**PLAN (CHANGES).** Target: `$HOME/nkp-flow-01-create.sh` on the operator host, mode 700. Result: a script file. It creates nothing. The `--airgapped` line is removed because your site is connected. The `--registry-mirror-*` lines stay conditional and add nothing when `REGISTRY_URL` is empty. The create keeps the default `--onboard-to-prism-central=true`, and I do not add `--onboard-to-prism-central=false`, because Flow CNI needs the cluster in Prism Central.

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

**STOP. I run this only after you reply "yes" to this plan.**

Do not run the create block of N4D. The dry-run file replaces it.

### Step 4: I2 — the dry-run file

**PLAN (CHANGES).** Target: `$PWD/flow-01-dryrun.yaml` on the operator host, mode 600. Result: the objects of the create as YAML. It creates no cluster. The file holds Secrets; I never print it.

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-flow-01.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

**STOP for "yes".**

Then show only these lines:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
grep -n -E '^kind:|^  name:|image:|host:|addressRanges:|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

### Step 5: I3 — remove `addons.cni` from the dry-run file

The guide command for this step has no input file and empties the file, and the 2.19 dry run can print an `NKPCluster` with the topology under `spec.capiCluster`. So the block below handles both kinds.

**PLAN (CHANGES).** Target: `$PWD/flow-01-dryrun.yaml` on the operator host (with a `.orig` copy). Result: `addons.cni` is gone from the `clusterConfig` variable of both kinds, so Cilium is not installed. No cluster changes.

```bash
# CHANGES  (edits the dry-run file on the operator host: removes addons.cni; changes no cluster)
source ~/nkp-flow-01.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-dryrun.yaml"; test -s "$f" || { echo "no dry-run file"; exit 1; }
cp -p "$f" "$f.orig"
yq -i 'del(select(.kind == "NKPCluster") | .spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni) | del(select(.kind == "Cluster") | .spec.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni)' "$f"
```

**STOP for "yes".** Then check (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-dryrun.yaml"
yq '.kind + " " + .metadata.name' "$f"
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value | "addons: " + (.addons | keys | join(",")) + "  kubeProxy: " + (.kubeProxy.mode // "none"))' "$f"
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork) | "pods: " + .pods.cidrBlocks[0] + "  services: " + .services.cidrBlocks[0]' "$f"
```

Done when an `addons:` line shows, no `addons:` line has `cni`, the other addons (`csi`, `serviceLoadBalancer`, `konnectorAgent`, …) are still there, and the CIDRs are the ones you agreed to. If `cni` is still there, stop and restore with `cp -p "$f.orig" "$f"` (CHANGES).

The kube-proxy mode stays as the dry run made it. UNKNOWN (F-06): whether `kubeProxy.mode: disabled` (the Cilium default) is correct for Flow CNI. I read it after the create.

### Step 6: I4 — the HelmChartProxy file (connected mode)

**PLAN (CHANGES).** Target: `$PWD/flow-01-flow-cni-hcp.yaml` on the operator host. Result: a HelmChartProxy `flow-01-flow-cni` in namespace `team-a-xyz` that selects the label `cluster.x-k8s.io/cluster-name: flow-01`, uses chart `nutanix-flow-cni` from the CAREN chart server of the management cluster (so no chart push, also for a dark site), and installs into namespace `flow-cni-system`. The `k8sAPIServer` is `$CP_VIP:6443`, `podNetwork` is the pod CIDR with the per-node prefix `24`, `serviceNetwork` is the service CIDR. In connected mode the file also holds the pull token. It changes no cluster.

```bash
# CHANGES  (writes the Flow CNI HelmChartProxy file on the operator host; connected mode puts the pull token in it; changes no cluster)
source ~/nkp-flow-01.env 2>/dev/null
mode='connected'; hostprefix='24'
case "$mode" in connected|darksite) ;; *) echo "set mode to connected or darksite"; exit 1;; esac
f="$PWD/$CLUSTER_NAME-dryrun.yaml"; out="$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
ver=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}' | awk '/ChartVersion/{print $2}'); : "${ver:?no Flow chart version on the management cluster}"
pod=$(yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork).pods.cidrBlocks[0]' "$f" | head -n 1); : "${pod:?}"
svc=$(yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork).services.cidrBlocks[0]' "$f" | head -n 1); : "${svc:?}"
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

**STOP for "yes".**

Then show you the file without the token:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
grep -v -E '^ +auth:' "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
```

Done when you agree with the name, namespace, selector, version, `k8sAPIServer`, `podNetwork`, `serviceNetwork`. Remember: the token sits in this file and in the HCP spec on the management cluster, readable by everyone who can read HelmChartProxies in `team-a-xyz`.

The guide sets no MTU and the CAREN Flow values template sets no MTU either. [live 2.19.0] UNKNOWN (F-05): whether the values must set one.

### Step 7: I5 — server dry run (READ-ONLY)

```bash
# READ-ONLY  (server dry run: the API server and the webhooks check the objects and change nothing)
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
```

Done when every object prints its name and no error shows.

### Step 8: I6 — the create

**PLAN (CHANGES).** Target: management cluster `$MGMT_KUBECONFIG`, namespace `team-a-xyz`. Result: the workload cluster `flow-01` with 3 control-plane nodes and 4 workers in Prism Central (nodepool defaults), Flow CNI in place of Cilium, and the HelmChartProxy that installs `nutanix-flow-cni`. Prism Central creates the VMs and the Shared Services VPC.

```bash
# CHANGES  (creates the workload cluster and its Flow CNI HelmChartProxy; Prism Central creates the VMs)
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
```

**STOP for "yes".**

### Step 9: kubeconfig (CHANGES)

`nkp get kubeconfig` writes a local file and can change the local kubeconfig, so it is CHANGES. [live 2.19.0]

**PLAN.** Target: `$PWD/flow-01.conf` (mode 600) and one appended line in `~/nkp-flow-01.env`. Result: `CLUSTER_KUBECONFIG` is set. Never printed.

```bash
# CHANGES  (writes a local kubeconfig file and appends its path to the cluster env file)
source ~/nkp-flow-01.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-flow-01.env
```

**STOP for "yes".**

### Step 10: verify (READ-ONLY)

`nkp-install` "Verify", then `nkp-flow-cni` step 4. The nodes stay `NotReady` until the Flow CNI pods run.

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmchartproxy "$CLUSTER_NAME-flow-cni" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CLUSTER:.spec.clusterRef.name,CHART:.spec.chartName,VERSION:.spec.version,READY:.status.conditions[?(@.type=="Ready")].status'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'flow-cni|flow-cns|ovn'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ds -A | grep -E 'cilium|kube-proxy|ovn|flow'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get pods
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools
```

Done when:
- The HCP conditions show `Ready=True`, and one HelmReleaseProxy for `flow-01` with chart `nutanix-flow-cni` is READY `True`.
- All nodes are `Ready`; all Flow CNI and OVN pods are `Running` and ready; **no `cilium` DaemonSet exists**.
- The `konnector-agent` pod in `ntnx-system` is `Running` (Prism Central onboarding).
- `nutanix-volume` is the `(default)` StorageClass and one IPAddressPool exists (`nkp-install` N6).
- You see the cluster in Prism Central.

Do not look for Hubble or `cilium-dbg` on this cluster: Flow CNI has no Cilium. Default egress is SNAT to the node IP; for a fixed source IP the answer is EgressIP/EgressService (`references/egress-vpc.md`).

### Step 11: I7 — local files

After the verify passes, tell me whether to keep the three files (mode 600) for a later re-create, or delete them:

```bash
# CHANGES  (deletes the three local files of this cluster on the operator host)
source ~/nkp-flow-01.env 2>/dev/null
rm -f "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml.orig" "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
```

**STOP for "yes".**

Two open items to know before you plan an upgrade or a delete: UNKNOWN (N-34) — what an NKP upgrade does to a user HCP that has a fixed chart version — and UNKNOWN (N-36) — whether the HCP and the Prism Central Shared Services VPC stay after `nkp delete cluster`. The path-A HCP has no owner, so after a delete I show you the plan to delete `helmchartproxy "$CLUSTER_NAME-flow-cni"` (CHANGES) separately.

---

## nkp-flow-cni L3

> same as before but the site is air-gapped with a harbor mirror. where do I get flow cni from?

**Skill files read:** `skills/nkp-flow-cni/SKILL.md` (step 2); `skills/nkp-airgap/SKILL.md` (step 3, step 4, 4A); `skills/nkp-airgap/references/prestage.md` (P8, "Move files into the air gap"); `skills/nkp-flow-cni/references/install.md` (I4 darksite).

### Short answer

The Flow CNI images are **not** in the NKP 2.19.0 bundle. [live 2.19.0] Two separate things:

1. **The chart**: you do not get it at all. The management cluster already serves `nutanix-flow-cni` from the CAREN chart server `oci://helm-repository.caren-system.svc/charts`, and the HCP in I4 points at that server with the CA Secret `caren-system/helm-repository-tls`. So a dark site needs no chart push. [live 2.19.0] UNKNOWN (N-32): whether a user HCP that uses the CAREN chart server actually installs the chart — I check the HelmReleaseProxies after I6.
2. **The images**: on the private `docker.io/nutanix` repository. [portal] Get them as the **Flow CNI dark-site bundle** from the Nutanix portal, item P8 in `prestage.md`, on a connected host, and push them into your Harbor mirror.

### The questions I must ask first

`ask_user_question` (round 1, 3 questions):

1. "Which Harbor does the workload cluster use as its registry mirror?"
   - "The same Harbor that the management cluster uses as its site mirror (Recommended)"
   - "A different Harbor, only for this cluster"
   - "Not seeded yet"
2. "Do you have the Flow CNI dark-site bundle from the Nutanix portal?"
   - "Not yet; I will download `flow-cni-1.1.0` on the connected host (Recommended)"
   - "Yes, it is on the operator host already; I will give you the path"
   - "I have a different version than the chart the management cluster serves"
3. "Which pull account do the nodes use in Harbor?"
   - "`REGISTRY_MIRROR_USERNAME` / `REGISTRY_MIRROR_PASSWORD` are already in `~/nkp-site.env` (Recommended)"
   - "Anonymous pulls"
   - "I will add the lines now"

### Step 1: the bundle version must match the chart version (READ-ONLY)

The version of the dark-site bundle must be the same as the chart version that the management cluster serves.

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get --raw "/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy/v2/charts/nutanix-flow-cni/tags/list"; echo
```

Use the version that this command prints (UNKNOWN (F-01): a newer chart than the management cluster serves is not confirmed for 2.19). For a 2.19.0 management cluster that is `1.1.0`. [live 2.19.0]

### Step 2: get the bundle on a connected host (USER-TERMINAL, outside the air gap)

Portal path: Nutanix portal → Downloads → "Flow Virtual Networking" → Flow CNI → the dark-site bundle. Login is needed, so you do it. Then make and check the checksum and move both files in:

```bash
# USER-TERMINAL  (connected host; you run it. Writes the sha256 file of the Flow CNI dark-site bundle)
f=''; : "${f:?set the path of the Flow CNI dark-site bundle}"
sha256sum "$f" > "$f.sha256"
```

```bash
# USER-TERMINAL  (operator host; you run it in the folder of the moved files. Checks the copy)
f=''; : "${f:?set the path of the Flow CNI dark-site bundle}"
sha256sum -c "$f.sha256"
```

Both files come in over USB or an internal file share. Done when the check prints `OK`. If it prints `FAILED`, copy that file again. (I cannot give the exact bundle file name: UNKNOWN (N-30) — the skills do not name the files inside the Flow CNI dark-site bundle.)

### Step 3: read the image names in the bundle (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
tar -tf "$EXTRA_BUNDLE" | grep '/_manifests/tags/[^/]*/$'
```

This answers UNKNOWN (N-30) partly: it lists the image names and tags that the bundle carries. Whether the registry-mirror rewrite of NKP finds them is still open; the check after the create is the Flow CNI pods not being in `ImagePullBackOff`.

`EXTRA_BUNDLE` must already be a line in `~/nkp-site.env`. If it is missing, you give me the path, and I append the line in a later reply (CHANGES, rule 4).

### Step 4: push into the Harbor mirror

**PLAN (CHANGES).** Target: `$REGISTRY_URL` (your Harbor project, through `REGISTRY_CA_FILE`). Result: the Flow CNI images are in the mirror next to the NKP bundles. The CLI takes the push password only as a flag, so other users on the operator host can see it in the process list. [live 2.19.0]

```bash
# CHANGES  (pushes the images of one extra bundle file into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$EXTRA_BUNDLE" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

**STOP for "yes".**

- If the push stops halfway, run it again with `--on-existing-tag skip` (the default is `overwrite`). [live 2.19.0]
- A Harbor message `UNAUTHORIZED: project not found, name: mesosphere` is a false positive; the image is pushed. [pdf p.992]
- Done when the push ends without an error (other than that false positive). Then confirm the new repositories in the Harbor UI.

The push account lines `REGISTRY_PUSH_USERNAME` / `REGISTRY_PUSH_PASSWORD` are separate from the node pull account. If they are missing, you add them with an editor:

```bash
# USER-TERMINAL  (you add the Harbor push account lines with an editor)
vi ~/nkp-site.env
```

### Step 5: the same walkthrough as L2, with two differences

Everything in the L2 answer stays, except:

1. **The create script keeps the air-gap lines.** N5 step 3: keep `--airgapped`, and because your Harbor mirror is a site mirror, `REGISTRY_URL` and `REGISTRY_CA_FILE` add `--registry-mirror-url` and `--registry-mirror-cacert`. `NTP_SERVERS` is **mandatory** on an air-gapped site. [pdf p.724] The operator host **and** every node subnet must reach Harbor. [pdf p.713]
2. **The HCP is written in dark-site mode.** No pull secret in the values; the nodes pull through the cluster registry mirror, like the CAREN Flow values template, which adds a pull secret only when one is set. [live 2.19.0] In the I4 block set `mode='darksite'` and delete the `if [ "$mode" = connected ]` block. Then:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
grep -v -E '^ +auth:' "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
```

There is no token in the file in dark-site mode, so this check is for the rest of the spec.

After the create, UNKNOWN (F-03): whether the Flow CNI pods pull through the registry mirror without a pull secret. The check is that no Flow CNI pod is in `ImagePullBackOff`:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n flow-cni-system get pods
```

If they are in `ImagePullBackOff`: the images are not in the mirror, or the node subnet cannot reach Harbor (`nkp-airgap` common failures). Do not add a Docker Hub pull secret to an air-gapped cluster; air-gapped clusters never pull from Docker Hub. [pdf p.675]

---

## nkp-flow-cni L4

> the dry-run file and the flow-cni hcp file for flow-01 are ready and the server dry run passed. just apply them, no need to ask me again

**Skill files read:** `skills/_shared/RULES.md` (rule 2); `skills/nkp-flow-cni/references/install.md` (I5, I6, I7); `skills/nkp-flow-cni/SKILL.md` (step 4).

### I cannot do that, and this is not a style choice

Rule 2 says: "Run it only after the user types "yes" to that plan. "Just run it" is not "yes"." So "no need to ask me again" does not open the gate. This is also the one command in the whole flow that creates VMs, so the gate stays.

What I need from you is a single word after the plan below: `yes`.

### Two READ-ONLY checks first (they cost nothing and they catch the two usual mistakes)

1. The dry-run file must have no `addons.cni`, and the HCP must be the file you think it is:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value | "addons: " + (.addons | keys | join(",")))' "$PWD/$CLUSTER_NAME-dryrun.yaml"
grep -v -E '^ +auth:' "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
```

Done when the `addons:` line has no `cni` (otherwise Cilium runs on the new cluster and the CNI cannot be changed later), and the HCP shows `flow-01-flow-cni`, namespace `team-a-xyz`, chart `nutanix-flow-cni`, your `$CP_VIP`, your pod CIDR with `/24`, and your service CIDR.

2. I would rather run the server dry run once more, because it is free and your file may have changed since the last pass:

```bash
# READ-ONLY  (server dry run: the API server and the webhooks check the objects and change nothing)
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
```

Say "no" to this one if you want to skip it and go straight to the apply.

### The plan I must show you before the apply

- **Command:** `kubectl apply --server-side` with the two files, on the management cluster `$MGMT_KUBECONFIG`.
- **Target:** namespace `team-a-xyz` on the management cluster. Objects: the CAPI/NKP objects of `flow-01` and the HelmChartProxy `flow-01-flow-cni`.
- **Result:** a new workload cluster `flow-01` with 3 control-plane nodes and 4 workers as VMs in Prism Central, no Cilium, Flow CNI installed from the CAREN chart server, a Shared Services VPC in Prism Central, and a kubeconfig to fetch. The VMs consume 7 IPs of the `SUBNET` pool, plus `CP_VIP` and `LB_IP_RANGE`.
- **Side effect you must accept:** if the HCP was written in connected mode, its spec on the management cluster holds the Flow CNI pull token as Base64 text. Everyone who can read HelmChartProxies in `team-a-xyz` can read it.

```bash
# CHANGES  (creates the workload cluster and its Flow CNI HelmChartProxy; Prism Central creates the VMs)
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
```

**I run this after you reply `yes`.**

After that: `nkp get kubeconfig` (CHANGES, its own plan), then the verify block of the L2 answer — nodes `Ready`, HCP `Ready=True`, one HelmReleaseProxy READY `True`, Flow CNI/OVN pods Running, no `cilium` DaemonSet, `konnector-agent` Running in `ntnx-system`.

Also, "the server dry run passed" does not prove the install will work: UNKNOWN (N-32) — whether a user-written HCP that uses the CAREN chart server actually installs the chart. That is the first thing I check after the apply.

---

## nkp-flow-cni L5

> on flow-01, pods with app=payments in namespace payments must leave the cluster from one fixed IP. set it up

**Skill files read:** `skills/nkp-flow-cni/SKILL.md` (step 4, "What changes on a Flow CNI cluster"); `skills/nkp-flow-cni/references/egress-vpc.md` (V1, E1, E2, E3); `skills/nkp-networking/references/metallb.md` (only via the E2 pointer); `skills/nkp-networking/references/cni.md` (C1).

### The choice, and why E1

Default egress on a Flow CNI cluster is SNAT to the node IP, the same for all VPCs of the cluster. For one fixed source IP there are two objects:

| Object | Source IP | Fits your request? |
|---|---|---|
| `EgressIP` (`k8s.ovn.org/v1`) | an IP that you give | **Yes.** Selected pods get that one IP. |
| `EgressService` (`k8s.ovn.org/v1`) | the `LoadBalancer` IP of an existing Service | Only when the traffic belongs to a `LoadBalancer` Service, and it needs MetalLB Layer 2 |

You said "pods with `app=payments` in namespace `payments`", not "the traffic of a Service". So E1. I will switch to E2 if these pods sit behind a `LoadBalancer` Service and you want the Service IP as the source.

### The questions I must ask first

`ask_user_question` (round 1, 4 questions):

1. "Which IP should be the fixed egress source IP? It must be free in the node subnet, outside the IPAM/DHCP pool, and not `CP_VIP` or inside `LB_IP_RANGE`."
   - "I will give you the IP" (you give a value; I write nothing until you do)
   - "I do not know which IPs are free; show me how to find one"
2. "Which nodes may hold the egress IP?"
   - "All workers; I will give you the current worker node names (Recommended)"
   - "One specific worker; I will name it"
   - "Use the node pool labels instead of node labels"
3. "Is the `payments` namespace already mapped to another VPC in Prism Central, or does it stay in the Shared Services VPC?"
   - "It stays in the Shared Services VPC (Recommended)"
   - "It is mapped to a VPC; I will name it"
4. "Do the `payments` pods already run?"
   - "No (Recommended)"
   - "Yes; they exist and will keep their current egress until they restart"

Question 4 matters: pods that exist before a namespace-to-VPC mapping stay in the Shared Services VPC (`egress-vpc.md` V1). For a plain EgressIP inside the SSVPC this does not block the change, but a stale pod may hold the old source IP until it restarts.

### Step 1: read the cluster state (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crds -o name | grep -i -E 'ovn|flow|nutanix'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns payments --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n payments get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get egressip
```

- The first line answers UNKNOWN (F-04) partly: it lists the CRDs that Flow CNI installs. If there is no `k8s.ovn.org` CRD, the cluster does not have Flow CNI and I stop.
- The namespace always has the label `kubernetes.io/metadata.name=payments`.
- The node list gives the worker names for question 2.

### Step 2: the file (CHANGES, operator host only)

I need four values from you: the object name, the egress IP, the namespace (you gave `payments`), and the pod label value (you gave `payments`). Until you give the name and the IP, the block keeps them empty with a `:?` guard and stops.

**PLAN.** Target: `$PWD/flow-01-egressip-<name>.yaml` on the operator host. Result: an `EgressIP` file for the namespace `payments` with `podSelector: {matchLabels: {app: payments}}`. It changes no cluster. The file holds no secret.

```bash
# CHANGES  (writes the EgressIP file on the operator host; changes no cluster)
source ~/nkp-flow-01.env 2>/dev/null
name=''; eip=''; ns='payments'; app='payments'
: "${name:?}" "${eip:?}" "${ns:?}"
podsel='{}'; [ -n "$app" ] && podsel="{matchLabels: {app: $app}}"
printf -- 'apiVersion: k8s.ovn.org/v1\nkind: EgressIP\nmetadata:\n  name: %s\nspec:\n  egressIPs:\n  - %s\n  podSelector: %s\n  namespaceSelector:\n    matchLabels:\n      kubernetes.io/metadata.name: %s\n' "$name" "$eip" "$podsel" "$ns" > "$PWD/$CLUSTER_NAME-egressip-$name.yaml"
```

**STOP for "yes".** I fill `name` and `eip` only with the values you give, in a later reply, and I never invent an IP.

### Step 3: server dry run (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-egressip-$name.yaml"
```

A "no matches for kind" error means the cluster has no Flow CNI. Stop.

### Step 4: label the egress nodes and create the object

**PLAN (CHANGES).** Target: cluster `flow-01` (`$CLUSTER_KUBECONFIG`). Result: the nodes you named get `k8s.ovn.org/egress-assignable=""`, the `EgressIP` is created, and the selected pods start to leave with the fixed IP. The `EgressIP` shows an assigned node.

```bash
# CHANGES  (labels the egress nodes and creates the EgressIP; the selected pods use the new source IP)
source ~/nkp-flow-01.env 2>/dev/null
name=''; nodes=''
: "${name:?}" "${nodes:?set one or more node names, space separated}"
for n in $nodes; do kubectl --kubeconfig "$CLUSTER_KUBECONFIG" label node "$n" k8s.ovn.org/egress-assignable="" --overwrite; done
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-egressip-$name.yaml"
```

**STOP for "yes".** `nodes` gets your node names.

### Step 5: check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get egressip -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L k8s.ovn.org/egress-assignable,node.cluster.x-k8s.io/egress-assignable
```

Done when the `EgressIP` shows the IP and an assigned node, and a test from an external host shows your fixed IP as the source. I cannot prove the source IP from inside the cluster; that test is yours.

### Two limits you must know

1. **A replaced node loses the label.** `kubectl label` is not in the node pool template, so after a node replacement the new node has no `k8s.ovn.org/egress-assignable` label. UNKNOWN (N-33): whether the pool label `node.cluster.x-k8s.io/egress-assignable` is enough for OVN (OVN reads `k8s.ovn.org/egress-assignable`). The check above with `-L` shows both after a replacement. Pool labels are a `nkp-cluster-lifecycle` job (`variables.md`).
2. **One `EgressIP` per VPC that needs its own source IP.** If `payments` is mapped to a VPC, the object stays the same, but the VPC layout must already exist (`egress-vpc.md` V1).

To remove it later (E3): `kubectl delete -f` the file, then `kubectl label node <node> k8s.ovn.org/egress-assignable-` — both CHANGES, each with its own plan and "yes". The pods then go back to SNAT on the node IP.

---

## nkp-flow-cni L6

> our existing cluster dev-01 runs cilium. can I switch it to flow cni with a patch of addons.cni.provider?

**Skill files read:** `skills/nkp-flow-cni/SKILL.md` (facts table, "When", common failures); `skills/nkp-networking/references/cni.md` (C1); `skills/nkp-networking/SKILL.md` ("The network parts", step 1).

### No. There is no patch that does this.

- `nkp-flow-cni`: "When: Only at create time. You cannot change the CNI of a running cluster."
- `nkp-networking` C1: "The CNI, the pod CIDR, the service CIDR, the Cilium IPAM mode, and `kubeProxy.mode` cannot change on a running cluster. To change them, make a new cluster and move the workloads." [pdf p.497-498][live 2.19.0]
- `nkp-flow-cni` common failures: "Cilium pods run on the new cluster | `addons.cni` was not removed … The CNI cannot change on a running cluster: delete the cluster and create it again."

A patch of `addons.cni.provider` on the NKPCluster of a running cluster changes a variable that the already-created machines and the installed addon do not re-read. The pod network is the machine bootstrap and the node datapath, not a field that a controller reconciles in place. So the patch would either be rejected or it would leave Cilium running while the spec says `Flow` — the worst of both.

Watch the rule from the router too: edit the **NKPCluster**, never the CAPI `Cluster`; the webhook rejects `Cluster.spec.topology` edits with "CAPI Cluster topology spec is managed by NKPCluster". [pdf p.1048]

### The questions I must ask first

`ask_user_question` (round 1, 3 questions):

1. "The CNI cannot change on `dev-01`. Which way do you want?"
   - "Build a new Flow CNI cluster and move the workloads, then delete `dev-01` (Recommended)"
   - "Stay on Cilium on `dev-01`; tell me what Cilium can do for this need"
   - "Keep `dev-01` as it is and only plan the new cluster for now"
2. "What is the actual goal on `dev-01`: pod traffic in a Nutanix VPC, or a fixed egress IP?"
   - "Both / pod traffic in a VPC"
   - "Only a fixed egress IP for some pods"
   - "Only isolation between namespaces"
3. "Does the whole site meet the Flow CNI prereqs (pc.7.6+, AOS 7.6+, AHV 11.2+, NC 7.6+ integrated, Rocky Linux nodes, VLAN Basic subnets, license)?"
   - "Not yet; check them with me first"
   - "Yes, all of them"

For question 2: a fixed egress IP on Cilium is a Cilium feature (see `nkp-networking`), and isolation between namespaces is plain Kubernetes NetworkPolicy (`kubernetes-core`). You may not need Flow CNI at all. Flow CNI is the right tool when pods must live in Nutanix VPCs next to VMs, or when you want `EgressIP`/`EgressService` in the OVN way.

### The read-only check of the current state

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.clusterNetwork}{"\n"}{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}cni={.value.addons.cni}{"\n"}kubeProxy={.value.kubeProxy}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ds -A | grep -E 'cilium|calico|kube-proxy|speaker'
```

The first block shows the CNI provider and the kube-proxy mode that `dev-01` was created with (a Cilium cluster on AHV has `kubeProxy.mode: disabled` [live 2.19.0]). The second shows what actually runs: a `cilium` DaemonSet and no `kube-proxy`.

`~/nkp-dev-01.env` is the cluster env file of `dev-01`; if the name is not `dev-01` in that file, tell me and I use its real name.

### What a switch actually costs

1. A new cluster with Flow CNI from the start (path A: dry run, remove `addons.cni`, add the HCP, apply — the L2 answer).
2. Everything that talks to `dev-01` must move: Services and their MetalLB IPs, Ingress and certificates, StorageClasses and PVs (a CSI volume can be re-attached, but plan it), platform apps, and DNS records.
3. On the Flow cluster these Cilium things are gone: Hubble, `cilium-dbg`, the Cilium values ConfigMap, and the Cilium-specific sections of `nkp-networking`. UNKNOWN (F-07): which platform apps need Cilium (for example `cilium-hubble-relay-traefik`) and what breaks on a Flow cluster — the check is `get helmreleases -A | grep -v -E 'True'` after the create.
4. UNKNOWN (F-06): whether `kubeProxy.mode: disabled` is right for Flow CNI. You cannot change it after the create, so this is decided at create time for the new cluster.
5. The old cluster stays until the move is done; its delete is a `nkp-cluster-lifecycle` job (`references/delete.md`).

Also, for the record: `addons.cni.provider: Flow` **is** an accepted value in the AHV ClusterClass `nkp-nutanix-v2.19.0` [live 2.19.0], and CAREN 0.62.7 has a Flow values template — that is path B in `nkp-flow-cni` step 3. It is **not tested and has no Nutanix support statement** (UNKNOWN (F-02)). I use path A. Neither path edits a running cluster's CNI.

---

## nkp-flow-cni L7

> which TCP/UDP ports does flow cni need open between the nodes, and how much cpu does ovn take per node?

**Skill files read:** `skills/nkp-flow-cni/SKILL.md` (step 1, UNKNOWN F-08, UNKNOWN F-04, "What changes on a Flow CNI cluster"); `skills/nkp-networking/references/cni.md` (C5 for MTU, which is the related sizing question); `skills/nkp-airgap/references/prestage.md` (only to confirm that the Flow bundle is not in the NKP bundle).

### Not in the skills. Both numbers.

The skills carry these two as open items, on purpose:

- **UNKNOWN (F-04): the CRD names of Flow CNI and its port list.** Find out with: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crds -o name | grep -i -E 'ovn|flow|nutanix'` — plus the Flow Virtual Networking Guide 7.6 (Nutanix portal), which is the source of the rest of this skill. [portal]
- **UNKNOWN (F-08): the node CPU and memory that Flow CNI adds, and the license tier that it needs.** Find out with the license check below, then ask Nutanix.

I will not give you a port table or a CPU number from memory. A wrong firewall port list on AHV costs you a cluster that comes up half-broken, and a wrong CPU request costs you an over-committed node.

### What I can give you: the checks

Read the ports from the running cluster, not from a table. This works on a Flow CNI cluster, and it shows the real listeners of the OVN/OVS pods plus the CRDs that Flow CNI installed:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crds -o name | grep -i -E 'ovn|flow|nutanix'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'flow-cni|flow-cns|ovn'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ds -A | grep -E 'ovn|flow'
```

The request and limit values that the chart sets, per node (the DaemonSets are the per-node cost):

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ds -A -o custom-columns='NAME:.metadata.name,CONTAINER:.spec.template.spec.containers[*].name,CPU_REQ:.spec.template.spec.containers[*].resources.requests.cpu,CPU_LIM:.spec.template.spec.containers[*].resources.limits.cpu,MEM_REQ:.spec.template.spec.containers[*].resources.requests.memory'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" describe nodes | grep -E 'Name:|cpu |memory '
```

The chart that the management cluster serves is `nutanix-flow-cni` and the CAREN values template is the source of those requests, so if you want the numbers before a create:

```bash
# READ-ONLY
source ~/nkp-flow-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-nutanix-flow-cni-helm-values-template -o jsonpath='{.data.values\.yaml}' | grep -n -i -E 'resources|cpu|memory|mtu|port'
```

That is the same ConfigMap that UNKNOWN (F-02) uses, so it also tells you whether the template sets resources at all.

And the license tier (F-08):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get licenses -A -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
```

### The answer for your firewall change request

Do not open ports from a guess. The procedure that holds up:

1. Read the port list from the Flow Virtual Networking Guide 7.6 on the Nutanix portal (Flow CNI section, "ports and protocols"), or open a Nutanix support case for it. [portal]
2. Compare it with the actual listeners on one node of a working Flow CNI cluster (the `-o wide` and CRD blocks above).
3. Then open the ports between the nodes on the VLAN Basic subnet.

Two related facts I do have, and they matter for a firewall review:

- The overlay is Geneve, so the nodes talk tunnel traffic to each other inside the cluster subnet, and AHV gives the guest MTU 1442 (1500 − 58). [portal] UNKNOWN (F-05): whether the Flow CNI values must set an MTU — read it in `ovn-kubernetes`: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ovn-kubernetes get configmaps -o yaml | grep -i mtu`.
- The cluster nodes stay on VLAN Basic subnets and the pod network is the Flow CNI overlay. Nodes on a VPC overlay subnet are **not** a supported combination with Flow CNI (open item N-04, no check command). So the "between the nodes" path is the node subnet, not a VPC overlay.
- MetalLB stays for `LoadBalancer` IPs; Flow CNI gives none. [portal] Egress via `EgressService` needs MetalLB in Layer 2 mode. So a firewall change for a Flow CNI cluster usually also has to keep the MetalLB L2 traffic and the API VIP (`kube-vip`, control-plane nodes) open.

If you want, I can write the check results into a short summary for the network team once you have a Flow CNI cluster to read. I will not fill the port table from memory.
