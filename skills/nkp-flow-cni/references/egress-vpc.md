# Flow CNI: namespaces in VPCs, egress IP, egress service

Use this file from skill `nkp-flow-cni`, table "Job → section". All facts are from the Flow guide 7.6 [portal], unless a tag says other. No lab test exists yet. Run every block on the workload cluster (`CLUSTER_KUBECONFIG`).

## V1. Namespaces and VPCs (facts)

- Flow CNI makes a **Shared Services VPC** (SSVPC) for each cluster at the create. Its pod CIDR is `podNetwork` of the install. Cluster services (CoreDNS) run there. A namespace that is not mapped to another VPC stays in the SSVPC.
- More VPCs (container-only or hybrid) are Prism Central objects. You make them in the Prism Central UI or with the v4 API, not with Kubernetes objects. The VPC form has: the Kubernetes cluster, the namespace scope (`Manually selected namespaces` or `All namespaces`), the namespace labels (`key=value`), the gateway nodes (node labels; select more than one worker), and the pod CIDR.
- Each VPC of a cluster needs its own pod CIDR. The service CIDR is the same for all VPCs of the cluster.
- One model for each cluster: map all namespaces to one VPC, **or** map sets of namespaces to VPCs. Not both.
- The mapping uses namespace labels. A namespace that is mapped to a VPC cannot go to a second VPC.
- **Pods that exist before the mapping stay in the SSVPC.** Map a namespace before you deploy pods in it.
- Traffic: a VPC can reach the SSVPC. The SSVPC cannot reach an isolated VPC. Pod-to-pod traffic between two VPCs goes out through the external gateway (north-south). Ingress comes only through `LoadBalancer` or `NodePort` Services. Flow CNI gives no LoadBalancer IPs; MetalLB does (skill `nkp-networking`).
- Default egress: SNAT to the node IP, the same for all VPCs of the cluster. For a fixed source IP, use E1 or E2.
- The Kubernetes objects that Flow CNI writes for a VPC are not named in the guide. Do not change them. UNKNOWN (F-04): the CRD names of Flow CNI and its port list. Find out with: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crds -o name | grep -i -E 'ovn|flow|nutanix'`.
- The cluster nodes stay on VLAN Basic subnets. Nodes on a VPC overlay subnet: skill `nkp-vpc` (N-04).

Before the user maps a namespace in Prism Central, check that it has no pods and read its labels:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns "$ns" --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pods --no-headers | wc -l
```

- Each namespace has the label `kubernetes.io/metadata.name=<namespace>`. The user can use it in the VPC form.
- If the pod count is not `0`, tell the user that these pods stay in the SSVPC. To move them, delete and re-create them after the mapping (CHANGES, with the plan of the app owner).

## E1. Egress IP (one source IP for some pods)

`EgressIP` (`k8s.ovn.org/v1`) gives selected pods one source IP. Nodes with the label `k8s.ovn.org/egress-assignable=""` can hold the IP. Use one `EgressIP` for each VPC that needs its own source IP.

1. Ask the user for: the object name, the egress IP (a free IP in the node subnet, outside the IPAM pool, `CP_VIP`, and `LB_IP_RANGE`), the namespace, an optional pod label value for `app`, and the egress nodes.
2. Show the plan (file `$PWD/<cluster>-egressip-<name>.yaml`, the values). Stop for "yes". Write the file:

```bash
# CHANGES  (writes the EgressIP file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; eip=''; ns=''; app=''
: "${name:?}" "${eip:?}" "${ns:?}"
podsel='{}'; [ -n "$app" ] && podsel="{matchLabels: {app: $app}}"
printf -- 'apiVersion: k8s.ovn.org/v1\nkind: EgressIP\nmetadata:\n  name: %s\nspec:\n  egressIPs:\n  - %s\n  podSelector: %s\n  namespaceSelector:\n    matchLabels:\n      kubernetes.io/metadata.name: %s\n' "$name" "$eip" "$podsel" "$ns" > "$PWD/$CLUSTER_NAME-egressip-$name.yaml"
```

3. Server dry run:

```bash
# READ-ONLY  (server dry run of the EgressIP file; changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-egressip-$name.yaml"
```

   A "no matches for kind" error means that the cluster has no Flow CNI. Stop.
4. Show the plan (the cluster, the nodes, the IP). Stop for "yes":

```bash
# CHANGES  (labels the egress nodes and creates the EgressIP; the selected pods use the new source IP)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; nodes=''
: "${name:?}" "${nodes:?set one or more node names, space separated}"
for n in $nodes; do kubectl --kubeconfig "$CLUSTER_KUBECONFIG" label node "$n" k8s.ovn.org/egress-assignable="" --overwrite; done
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-egressip-$name.yaml"
```

5. Check: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get egressip -o wide` (READ-ONLY) shows the IP and an assigned node. Ask the user to test the source IP from an external host.

A replaced node loses a label that you set with `kubectl label`. The guide adds the labels `node.cluster.x-k8s.io/egress-assignable: ""` and `node.cluster.x-k8s.io/egressnode: "true"` to the MachineDeployment template. To change pool labels, use skill `nkp-cluster-lifecycle` (pool `metadata/labels`). UNKNOWN (N-33): whether the pool label `node.cluster.x-k8s.io/egress-assignable` lets OVN use the node; OVN reads `k8s.ovn.org/egress-assignable`. Find out with: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L k8s.ovn.org/egress-assignable,node.cluster.x-k8s.io/egress-assignable` after a node replacement.

Done when: the `EgressIP` shows an assigned node and the external test shows the egress IP.

## E2. Egress service (source IP = the LoadBalancer IP of a Service)

`EgressService` (`k8s.ovn.org/v1`) makes the pods of a `LoadBalancer` Service use the Service IP as source IP. It works only with MetalLB in Layer 2 mode. The MetalLB objects are `metallb.io/v1beta1` in `metallb-system`. [portal][live 2.19.0] Do not edit the default pool `metallb` or the L2Advertisement `metallb` (skill `nkp-networking`, file `metallb.md`).

1. Ask the user for: the app namespace, the Service name (it exists, type `LoadBalancer`), one free IP for the egress pool (outside `LB_IP_RANGE`), a pool name, and the worker nodes for egress.
2. Show the plan (file `$PWD/<cluster>-egress-svc-<svc>.yaml`, the values). Stop for "yes". Write the file:

```bash
# CHANGES  (writes the egress service file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; svc=''; ip=''; pool=''
: "${ns:?}" "${svc:?}" "${ip:?}" "${pool:?}"
printf -- 'apiVersion: metallb.io/v1beta1\nkind: IPAddressPool\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  autoAssign: false\n  addresses:\n  - %s/32\n---\napiVersion: metallb.io/v1beta1\nkind: L2Advertisement\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  ipAddressPools:\n  - %s\n  nodeSelectors:\n  - matchLabels:\n      egress-service.k8s.ovn.org/%s-%s: ""\n---\napiVersion: k8s.ovn.org/v1\nkind: EgressService\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  sourceIPBy: LoadBalancerIP\n  nodeSelector:\n    matchLabels:\n      egressnode: "true"\n' "$pool" "$ip" "$pool" "$pool" "$ns" "$svc" "$svc" "$ns" > "$PWD/$CLUSTER_NAME-egress-svc-$svc.yaml"
```

- The `EgressService` name and namespace are the same as the Service. OVN puts the label `egress-service.k8s.ovn.org/<namespace>-<service>` on the egress node itself; the L2Advertisement uses it.
3. Server dry run:

```bash
# READ-ONLY  (server dry run of the egress service file; changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
svc=''; : "${svc:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-egress-svc-$svc.yaml"
```

4. The Service must take its IP from the new pool. It asks for the pool with the annotation `metallb.io/address-pool` (skill `nkp-networking`, file `metallb.md`). The guide name `metallb.io/ipaddresspool` has no effect on MetalLB 0.15.3. [portal][field: MetalLB v0.15.3 source]
5. Show the plan (the cluster, the nodes, the objects, the Service annotation). Tell the user: the Service gets a new IP from the pool, and clients of the old IP stop working. Stop for "yes":

```bash
# CHANGES  (labels the egress nodes, creates the pool, the L2Advertisement, and the EgressService, and annotates the Service)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; svc=''; pool=''; nodes=''
: "${ns:?}" "${svc:?}" "${pool:?}" "${nodes:?set one or more worker node names, space separated}"
for n in $nodes; do kubectl --kubeconfig "$CLUSTER_KUBECONFIG" label node "$n" egressnode=true --overwrite; done
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-egress-svc-$svc.yaml"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" annotate svc "$svc" metallb.io/address-pool="$pool" --overwrite
```

- MetalLB usually does not announce from control-plane nodes. Use workers. [portal]
- A Service that has an IP from another pool loses it: MetalLB gives it a new IP from the requested pool (skill `nkp-networking`, file `metallb.md`). Tell the app owner before step 5.

6. Check:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get svc,egressservice
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L egressnode
```

   Ask the user to test the source IP from an external host.

Done when: the Service EXTERNAL-IP is the pool IP, and the external test shows that IP as the source.

## E3. Remove egress

Show the plan and stop for "yes". `kubectl delete -f` on the file of E1 or E2 removes its objects (CHANGES). Then remove the node labels with `kubectl label node <node> k8s.ovn.org/egress-assignable-` or `egressnode-` (CHANGES). The pods go back to SNAT on the node IP.
