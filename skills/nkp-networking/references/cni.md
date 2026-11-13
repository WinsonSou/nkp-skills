# CNI: Cilium, Calico, CIDRs, MTU

Use this file from skill `nkp-networking` for the CNI choice, the pod and service CIDRs, custom Cilium values, Calico tuning, and MTU.

## C1. Choose at create time

| Provider | Default CNI | Other values in the ClusterClass |
|---|---|---|
| Nutanix AHV (`nkp-nutanix-v2.19.0`) | Cilium [live 2.19.0] | `Calico`, `Flow` [live 2.19.0] |
| EKS, AWS, host-agent (Metal, pre-provisioned) classes | Cilium on EKS, Calico on the others [pdf p.20] | `Calico`, `Cilium` [live 2.19.0] |

- `nkp create cluster` has no CNI flag. [live 2.19.0] To use another CNI or custom values, the create uses a dry-run YAML that you edit (C3). The create flags and the dry run: skill `nkp-install`.
- `addons.cni.strategy`: `HelmAddon` (default) or `ClusterResourceSet`. [live 2.19.0]
- The CNI, the pod CIDR, the service CIDR, the Cilium IPAM mode, and `kubeProxy.mode` cannot change on a running cluster. To change them, make a new cluster and move the workloads. [pdf p.497-498][live 2.19.0]
- Flow CNI: skill `nkp-flow-cni`.
- UNKNOWN (P-02): the Calico version that NKP 2.19 installs. The bundle has `calico/*` v3.32.1 and `tigera/operator` v1.42.3 [live 2.19.0]. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n calico-system get ds calico-node -o jsonpath='{.spec.template.spec.containers[0].image}'`.
- UNKNOWN (N-03): whether NKP supports Cilium ClusterMesh. The guide has no word about it. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get deploy clustermesh-apiserver`. A missing Deployment means ClusterMesh is not on. A ClusterMesh setup is not in the skills.

## C2. Pod and service CIDR

- Defaults: pods `192.168.0.0/16`, services `10.96.0.0/12`. [live 2.19.0] Create flags: `--kubernetes-pod-network-cidr`, `--kubernetes-service-cidr` (Nutanix and Metal), or edit `spec.clusterNetwork` in the dry-run YAML (other providers). [live 2.19.0][pdf p.678-679]
- Change them at create time when they overlap the node subnet, `CP_VIP`, or the LB range. [pdf p.678]
- Calico with a custom pod CIDR: also set `spec.calicoNetwork.ipPools[].cidr` in the Calico installation ConfigMap of the dry run. [pdf p.679]
- A proxy site: the no-proxy list must have the real CIDRs ([proxy.md](proxy.md), section X2).

## C3. Cilium with custom Helm values

Use this for WireGuard encryption, `loadBalancer.mode: snat` (C4), or other Cilium values. The values reach Cilium only when the cluster uses them from the create. An edit of the cluster spec or of the `cilium-config` ConfigMap later does not reach the installed Cilium. [pdf p.727]

How it works: the NKPCluster field `clusterConfig.addons.cni.values.sourceRef` names a ConfigMap (`kind: ConfigMap`) in the cluster namespace. The ConfigMap has two keys: `values.yaml` and `preflight-values.yaml`. [pdf p.727-729][live 2.19.0] The NKP default values are in the ConfigMap `default-cilium-cni-helm-values-template` in `caren-system`. [live 2.19.0]

1. Copy the default values. Run on the management cluster:

```bash
# CHANGES  (writes two values files on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-cilium-cni-helm-values-template -o jsonpath='{.data.values\.yaml}' > "$PWD/$CLUSTER_NAME-cilium-values.yaml"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-cilium-cni-helm-values-template -o jsonpath='{.data.preflight-values\.yaml}' > "$PWD/$CLUSTER_NAME-cilium-preflight-values.yaml"
```

The default file has Go template lines (`{{ ... }}`). CAREN fills them. Keep them. [live 2.19.0]

2. Show the user the file. Add the changes. Examples [pdf p.728]:

```yaml
encryption:
  enabled: true
  type: wireguard
```

```yaml
loadBalancer:
  mode: snat
```

For air-gapped sites, keep `useDigest: false` on every image. A digest breaks the registry mirror rewrite. [pdf p.727-728]

3. Create the ConfigMap in the cluster namespace before the create. The name in the guide is `<cluster>-cilium-cni-helm-values-template`. [pdf p.728]

```bash
# CHANGES  (creates the Cilium values ConfigMap in the workspace namespace of the new cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$CLUSTER_NAME-cilium-cni-helm-values-template" --from-file=values.yaml="$PWD/$CLUSTER_NAME-cilium-values.yaml" --from-file=preflight-values.yaml="$PWD/$CLUSTER_NAME-cilium-preflight-values.yaml"
```

4. In the dry-run YAML of the create (skill `nkp-install`), add under `clusterConfig.addons.cni` [pdf p.729]:

```yaml
cni:
  provider: Cilium
  strategy: HelmAddon
  values:
    sourceRef:
      kind: ConfigMap
      name: <cluster>-cilium-cni-helm-values-template
```

Then the guide applies the edited YAML with `kubectl apply -f`. [pdf p.729] A `--self-managed` YAML needs manual pivot steps. [pdf p.729] Use this path for a workload cluster. For a management cluster: not in the skills.

5. After the create, check the values:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get configmap cilium-config -o jsonpath='{.data.bpf-lb-mode}{" "}{.data.enable-wireguard}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep -E 'Encryption|KubeProxyReplacement|Routing'
```

Done when: the new values show in `cilium-config` and in `cilium-dbg status`.

UNKNOWN (N-25): whether the values ConfigMap also works for an existing cluster when you add `sourceRef` with a JSON patch. The guide says to set it before the create [pdf p.727]. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmchartproxies -o name | grep cilium` and compare its `spec.valuesTemplate` before and after.

## C4. Cilium defaults and the DSR problem

Default datapath on AHV [live 2.19.0]:

| Setting | Value |
|---|---|
| kube-proxy replacement | `true`, no kube-proxy DaemonSet |
| Routing | tunnel, protocol `geneve` |
| Service load balancing | `bpf-lb-mode: dsr`, DSR dispatch `geneve` |
| IPAM | `kubernetes` (pod CIDR per node from Kubernetes) |
| Masquerade | iptables, IPv4 only |
| Encryption | off |
| Hubble | on, relay with mTLS, certificates from a monthly CronJob (60 days validity) [pdf p.727] |
| BGP control plane, L2 announcements | off. MetalLB gives the LB IPs. |

Symptom: the UI and the LoadBalancer IPs do not answer, and the API VIP answers. On AHV subnets that the Network Controller manages, and on VPC overlay subnets, a node that does not own the Service IP can send the reply, and the network can drop it. The field fix is `loadBalancer.mode: snat` through the values ConfigMap (C3). [field]

On one lab cluster on a VPC overlay subnet (NAT floating IPs, DSR on), the UI LoadBalancer IP answered through its floating IP 6 of 6 times. [live 2.19.0] One cluster only: Network Controller VLANs and no-NAT subnets are not tested.

UNKNOWN (N-01): whether the default DSR mode breaks LoadBalancer replies on Network Controller VLANs and VPC subnets, and whether SNAT is the fix. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get configmap cilium-config -o jsonpath='{.data.bpf-lb-mode}'` and a test from a client outside the node subnet.

Because a running cluster ignores new values (C3), a fix needs a new cluster with SNAT. Tell the user this before any change.

For a management cluster, the fix is not in the skills. I7 (NodePort plus an external load balancer) is not a known fix for N-01. Do not offer it as a fix.

## C5. MTU

- AHV gives the VMs the MTU through DHCP option 26. The vSwitch default is 1500. With Geneve, Cilium sets the pod MTU 50 bytes lower (1450). [pdf p.711]
- Jumbo frames: set the MTU on the AHV vSwitch and on the subnet first (advanced and VPC subnets need an explicit MTU). Then the nodes get it from DHCP. [pdf p.711]
- An external DHCP server must send option 26 with the correct MTU. [pdf p.711]
- Nodes on a VPC overlay subnet: the MTU is in skill `nkp-vpc` (Facts, step 3).

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- ip -o link show | awk '{print $2, $4, $5}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status --verbose | grep -i mtu
```

The NIC MTU must be the same on all nodes, and it must be the same as the network MTU. If the NIC MTU is wrong, fix the subnet or DHCP side. Then replace the nodes (skill `nkp-cluster-lifecycle`).

## C6. Calico (other providers)

- Calico runs in `calico-system`, with `tigera-operator`. kube-proxy runs with Calico. [pdf p.593, p.784]
- CAREN Calico values on Nutanix: BGP `Enabled`, encapsulation `None`, `natOutgoing` `Enabled`, IP pools from the cluster pod CIDR. [live 2.19.0]
- The pre-provisioned guide uses IP-in-IP. Azure needs VXLAN. [pdf p.786]
- Node address autodetection uses the first interface. To use one NIC name on all nodes, set `spec.calicoNetwork.nodeAddressAutodetectionV4.interface` in the Installation `default`. [pdf p.784-785]
- To change the encapsulation, the guide deletes the IPPool `default-ipv4-ippool` and edits the Installation `default`. Do it after the create and before production. [pdf p.786] This stops pod traffic for a short time.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n calico-system get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get installation default -o jsonpath='{.spec.calicoNetwork}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ippools -o wide
```

Change the interface with a merge patch. Ask the user for the NIC name and put it in `nic`:

```bash
# CHANGES  (sets the Calico node address interface; calico-node pods restart)
source ~/nkp-<cluster>.env 2>/dev/null
nic=''; : "${nic:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" patch installation default --type merge -p "{\"spec\":{\"calicoNetwork\":{\"nodeAddressAutodetectionV4\":{\"interface\":\"$nic\"}}}}"
```

Done when: all `calico-node` pods are `Running` and `Ready`.
