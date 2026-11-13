# Create a workload cluster with Flow CNI (path A)

Use this file from skill `nkp-flow-cni`, step 3. Do the sections in order. Start a section only after the "Done when" check of the section before it passes. Path A is the method of the Flow guide: make the dry-run YAML of the create, remove the CNI addon (that removes Cilium), add a `HelmChartProxy` for the chart `nutanix-flow-cni`, then apply both files on the management cluster. [portal]

No lab test of this file exists yet. The guide procedure is `[portal]`. The changes from the guide are marked: they come from the live 2.19.0 management cluster `[live 2.19.0]`.

| File | Site variables |
|---|---|
| `~/nkp-site.env` secrets | `FLOW_CNI_PULL_USERNAME` `FLOW_CNI_PULL_TOKEN` |

- `FLOW_CNI_PULL_USERNAME` and `FLOW_CNI_PULL_TOKEN`: the Docker Hub user name and "Access Token 1" for the private Flow CNI images on `docker.io/nutanix`. The user makes them on a connected host in the Nutanix portal: Downloads, "Flow Networking and security", component "Flow Container Network Interface (Flow CNI)", "Generate Access Token", then "Manage Docker Hub Access Token". [portal] A connected site needs them. A dark site does not use them (I4).

## I1. Write the create script

1. Do skill `nkp-install`, its file `nutanix.md`, section N5, steps 1 to 3 (workload cluster: env file, checks, create script). Do not run the create.
2. Before you write the script, check these values with the user. They cannot change after the create. [live 2.19.0]
   - `VM_IMAGE` is a Rocky Linux image (SKILL.md step 1).
   - The pod CIDR and the service CIDR do not overlap any other cluster, any node subnet, or any VPC CIDR in Prism Central. [portal] For new CIDRs, add `--kubernetes-pod-network-cidr` and `--kubernetes-service-cidr` lines before `"$@"` in the script (skill `nkp-install`, N4).
   - Do not add `--onboard-to-prism-central=false`. Flow CNI needs the cluster in Prism Central. [portal]

Done when: the create script exists and the user agrees with the CIDRs.

## I2. Make the dry-run file

Run the dry-run block of skill `nkp-install`, N4D (the first CHANGES block). It writes `$PWD/<cluster>-dryrun.yaml` with mode 600. The file holds Secrets. Never print it. Do **not** run the create block of N4D: this file replaces it.

Check that `yq` (mikefarah v4) is on the operator host. The bundle has no `yq`. [live 2.19.0]

```bash
# READ-ONLY
command -v yq && yq --version
```

- The version line must contain `mikefarah` and `version v4`. If not, stop and tell the user. The guide uses `yq`. [portal]

Done when: the dry-run file exists and `yq` is v4.

## I3. Remove the CNI addon from the dry-run file

The guide command for this step has no input file, so it empties the file. It also selects only `kind: Cluster` and `variables[0]`. [portal] The 2.19 dry run can print an `NKPCluster`, with the topology under `spec.capiCluster`. [live 2.19.0] The block below removes `addons.cni` from the `clusterConfig` variable of both kinds.

Show the plan (the file, the change: remove `addons.cni`) and stop for "yes".

```bash
# CHANGES  (edits the dry-run file on the operator host: removes addons.cni; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-dryrun.yaml"; test -s "$f" || { echo "no dry-run file"; exit 1; }
cp -p "$f" "$f.orig"
yq -i 'del(select(.kind == "NKPCluster") | .spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni) | del(select(.kind == "Cluster") | .spec.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni)' "$f"
```

Check the result. The block prints only kinds, names, addon names, CIDRs, and the kube-proxy mode.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-dryrun.yaml"
yq '.kind + " " + .metadata.name' "$f"
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value | "addons: " + (.addons | keys | join(",")) + "  kubeProxy: " + (.kubeProxy.mode // "none"))' "$f"
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork) | "pods: " + .pods.cidrBlocks[0] + "  services: " + .services.cidrBlocks[0]' "$f"
```

Done when all these are true:
- An `addons:` line shows, and no `addons:` line has `cni`.
- The other addons (`csi`, `serviceLoadBalancer`, `konnectorAgent`, …) are still there.
- The CIDRs are the ones that the user agreed to in I1.

If `cni` is still there, or no `addons:` line shows, stop. Restore the file with `cp -p "$f.orig" "$f"` (CHANGES) and tell the user. UNKNOWN (N-31): the object kind and the variable path of the 2.19 Nutanix workload dry run, and whether a webhook adds the Cilium addon back. Find out with: `yq '.kind' "$PWD/$CLUSTER_NAME-dryrun.yaml"`.

The kube-proxy mode stays as the dry run made it. You cannot change it after the create. UNKNOWN (F-06): whether `kubeProxy.mode: disabled` (the Cilium default) is correct for Flow CNI. Find out with: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get ds kube-proxy` after the create.

## I4. Write the HelmChartProxy file

The HelmChartProxy (HCP) tells the management cluster to install the Flow CNI chart on the new cluster. Rules from the guide [portal]:
- The HCP namespace is the cluster namespace (`WORKSPACE_NS`). The selector is the label `cluster.x-k8s.io/cluster-name`.
- `k8sAPIServer` is the control-plane endpoint. `podNetwork` has three parts: `<pod CIDR>/<per-node prefix>`, for example `192.168.0.0/16/24` (one `/24` for each node). It is not a typo. `serviceNetwork` is the service CIDR.

Changes from the guide:
- The HCP name is `<cluster>-flow-cni`, so that two Flow clusters in one workspace do not use the same name.
- The chart comes from the CAREN chart server of the management cluster, not from the public Nutanix Helm repository of the guide. NKP 2.19.0 serves `nutanix-flow-cni` 1.1.0 there, with the CA Secret `caren-system/helm-repository-tls`. All NKP addon HCPs use this server. [live 2.19.0] So a dark site needs no chart push. UNKNOWN (N-32): whether a user HCP that uses the CAREN chart server installs the chart. Find out with: `kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmreleaseproxies` after I6.
- The guide sets no MTU. The CAREN Flow values template sets no MTU too. [live 2.19.0] UNKNOWN (F-05): whether the values must set an MTU. Find out with: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ovn-kubernetes get configmaps -o yaml | grep -i mtu` after the create.

Set `mode` to `connected` or `darksite`. `hostprefix` is the per-node prefix of the guide (`24`). Change it only when the user asks. The block reads the chart version from the management cluster and the CIDRs from the dry-run file.

- `connected`: the values add the Docker Hub pull secret `flow-cni-secret` from `FLOW_CNI_PULL_USERNAME` and `FLOW_CNI_PULL_TOKEN`. [portal] First check them: `[ -n "$(printenv FLOW_CNI_PULL_TOKEN)" ]`. If they are not set, give the user the editor block of skill `nkp-install` (rule 5).
- `darksite`: the values add no pull secret. The nodes pull the images through the registry mirror of the cluster, like the CAREN Flow template, which adds a pull secret only when one is set. [live 2.19.0] Push the images first (SKILL.md step 2). UNKNOWN (F-03): whether the Flow CNI pods pull through the registry mirror without a pull secret. Find out with: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n flow-cni-system get pods` after the create (no `ImagePullBackOff`).

Show the plan (the file path `$PWD/<cluster>-flow-cni-hcp.yaml`, the mode, the chart version, the CIDRs, that the file holds the pull token in connected mode) and stop for "yes".

```bash
# CHANGES  (writes the Flow CNI HelmChartProxy file on the operator host; connected mode puts the pull token in it; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
mode=''; hostprefix='24'
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

In connected mode, the HCP spec on the management cluster holds the pull token as Base64 text. Each user who can read HelmChartProxies in the workspace namespace can read it. Tell the user this. Never read the HCP or its HelmReleaseProxy with `-o yaml`, `-o json`, or `describe`: the values hold the token (rule 5). Show the user only the lines of the file without the token:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -v -E '^ +auth:' "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
```

Done when: the user agrees with the shown HCP (name, namespace, selector, version, `k8sAPIServer`, `podNetwork`, `serviceNetwork`).

## I5. Server dry run

The API server checks both files and changes nothing. A webhook that can have side effects makes the dry run fail; it does not run. The management cluster has mutating webhooks on clusters (`addons-defaulter.caren.nutanix.com`, `cluster-defaulter.caren.nutanix.com`, `nkp-cluster-defaulting`). [live 2.19.0] A webhook default is not in the schema, so block 2 reads the addon names after the webhooks.

```bash
# READ-ONLY  (server dry run: the API server and the webhooks check the objects and change nothing)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
```

Block 2 prints only the kind, the name, and the addon key names of each cluster object. The output of `-o yaml` holds the Secrets, so never print it without the `yq` filter. The filter works when `kubectl` returns the objects one by one, and when it returns one `List` (`.items[]`).

```bash
# READ-ONLY  (server dry run: changes nothing; prints only the addon key names after the webhooks)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o yaml | yq '(.items // [.]) | .[] | select(.kind == "NKPCluster" or .kind == "Cluster") | .kind + " " + .metadata.name + "  addons: " + ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value.addons | keys | join(","))'
```

Done when all these are true:
- Block 1: every object prints its name and no error shows. For an error, show it to the user, fix the file (I3 or I4), and run the dry run again.
- Block 2: one `addons:` line shows for each cluster object, and no `addons:` line has `cni`.

If an `addons:` line has `cni`, a webhook added the CNI back (N-31). Stop. Do not do I6: the create would install Cilium and Flow CNI together. Tell the user. If block 2 prints no `addons:` line, stop and tell the user.

## I6. Create the cluster

Show the plan: the management cluster, the namespace `WORKSPACE_NS`, the new cluster `CLUSTER_NAME` with Flow CNI and without Cilium, the VMs that Prism Central creates. Stop for "yes".

```bash
# CHANGES  (creates the workload cluster and its Flow CNI HelmChartProxy; Prism Central creates the VMs)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
```

Done when: the command prints the objects without an error. Then go to SKILL.md step 4.

## I7. Clean up the local files

The dry-run file, its `.orig` copy, and the HCP file hold Secrets. After SKILL.md step 4 passes, ask the user: keep them (mode 600) for a later re-create, or delete them. If the user wants to delete them, show the plan (the three files), and stop for "yes":

```bash
# CHANGES  (deletes the three local files of this cluster on the operator host)
source ~/nkp-<cluster>.env 2>/dev/null
rm -f "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml.orig" "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
```
