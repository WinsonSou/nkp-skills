# MetalLB: LoadBalancer IPs, Layer 2 and BGP

Use this file from skill `nkp-networking` for Service `type: LoadBalancer` on Nutanix AHV, NKP Metal, pre-provisioned hosts, and vSphere. Cloud providers use the cloud load balancer. [pdf p.594]

| File | Site variables |
|---|---|
| `~/nkp-<cluster>.env` | `APP_LB_RANGE` `BGP_PEER_IP` `BGP_MY_ASN` `BGP_PEER_ASN` `BGP_PREFIX` |

- `APP_LB_RANGE`: a new range for apps, `<first-ip>-<last-ip>` or a CIDR.
- `BGP_PEER_IP`, `BGP_PEER_ASN`: the router that MetalLB peers with. `BGP_MY_ASN`: the AS number of MetalLB. `BGP_PREFIX`: the CIDR that MetalLB announces.

## Facts

- MetalLB 0.15.3 in `metallb-system`: Deployment `metallb-controller`, DaemonSet `metallb-speaker` on every node (containers `speaker`, `frr`, `reloader`, `frr-metrics`). The speaker uses FRR 9.1.3 for BGP (`METALLB_BGP_TYPE=frr`). [live 2.19.0]
- CAREN installs MetalLB as the addon `clusterConfig.addons.serviceLoadBalancer` (provider `MetalLB`, the only value). [live 2.19.0]
- On AHV, CAREN makes the IPAddressPool `metallb` from `addressRanges` (the create flag `--kubernetes-service-load-balancer-ip-range`) and the L2Advertisement `metallb`. [live 2.19.0] On pre-provisioned hosts, the user makes the first pool, with the name `default` (skill `nkp-install`). [pdf p.83-84]
- **Do not edit the default pool or the default L2Advertisement.** That is the pool that NKP or the create made: `metallb` on AHV, `default` on pre-provisioned hosts. The next cluster upgrade stalls and fails. Make a new pool and a new advertisement. [pdf p.672]
- Layer 2 mode: the pool must be in the node primary subnet. No pool may overlap the pod CIDR, the service CIDR, or another pool. [pdf p.672] Keep it outside the DHCP or IPAM pool. [pdf p.721]
- The MetalLB webhook rejects a pool that overlaps another pool. The server dry run shows it. [live 2.19.0]
- The API objects: `IPAddressPool`, `L2Advertisement`, `BGPAdvertisement` are `metallb.io/v1beta1`. `BGPPeer` is `metallb.io/v1beta2` (v1beta1 is deprecated). [live 2.19.0]
- kube-vip owns `CP_VIP`. Never put `CP_VIP` in a MetalLB pool.

UNKNOWN (N-21): whether a second item in `clusterConfig.addons.serviceLoadBalancer.configuration.addressRanges` adds IPs to the default pool. The server dry run accepts it [live 2.19.0]. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspool metallb -o jsonpath='{.spec.addresses}'`. Until then, use a new pool (M2).

## M1. A Service stays `<pending>`

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements,bgpadvertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get events -A --field-selector reason=AllocationFailed
```

| Result | Cause | Fix |
|---|---|---|
| All pool IPs are in use (count the `LoadBalancer` Services) | the pools are full | M2 |
| Event `AllocationFailed` names a pool or an IP | the Service asks for a pool or IP that is not free | change the Service annotation, or M2 |
| A pool has no `L2Advertisement` or `BGPAdvertisement` | the IP is given but not announced | add the advertisement (M2) |
| Speaker pods not `Running` | MetalLB is broken | skill `nkp-troubleshooting` |
| EXTERNAL-IP is set, but clients get no answer | ARP or routing, or Cilium DSR | Check from a host in the same subnet. On AHV, see [cni.md](cni.md), section C4. |

Done when: you know which row applies.

To prove a new cluster end to end (PVC + pod + `LoadBalancer` Service + `curl` from the operator host), use skill `nkp-storage-backup`, `csi.md` C12.

## M2. Add a Layer 2 pool for apps

Ask the user for `APP_LB_RANGE` and a pool name. Append `APP_LB_RANGE` to the cluster env file (rule 4). `autoAssign: false` keeps the pool for Services that ask for it. Set `auto` to `true` to let MetalLB use it for any Service.

Show the plan (the file path `$PWD/<cluster>-metallb-<pool>.yaml`, the pool name, the range, `autoAssign`). Stop for "yes". Then write the file:

```bash
# CHANGES  (writes the pool file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
pool='apps'; auto='false'
: "${APP_LB_RANGE:?}"
printf -- 'apiVersion: metallb.io/v1beta1\nkind: IPAddressPool\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  autoAssign: %s\n  addresses:\n  - %s\n---\napiVersion: metallb.io/v1beta1\nkind: L2Advertisement\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  ipAddressPools:\n  - %s\n' "$pool" "$auto" "$APP_LB_RANGE" "$pool" "$pool" > "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

Preview with a server dry run. All MetalLB webhooks have `sideEffects: None`. [live 2.19.0]

```bash
# READ-ONLY  (server dry run: the API server and the MetalLB webhook check the objects and change nothing)
source ~/nkp-<cluster>.env 2>/dev/null
pool='apps'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

- `created (server dry run)` for both objects: go on.
- `overlaps with already defined CIDR`: the range is in another pool. Ask for a new range.

Show the plan (the cluster, the pool name, the range) and stop for "yes":

```bash
# CHANGES  (creates the MetalLB pool and its L2Advertisement)
source ~/nkp-<cluster>.env 2>/dev/null
pool='apps'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

A Service asks for a pool with the annotation `metallb.io/address-pool: <pool>` (the old name `metallb.universe.tf/address-pool` also works) [field: MetalLB v0.15.3 source], or for one IP with `metallb.io/loadBalancerIPs: <ip>`. [field] When the annotation names a pool that is not the pool of the current IP, MetalLB removes the IP and gives a new IP from the requested pool. Clients of the old IP stop working. [field: MetalLB v0.15.3 source] Add the IPs of a new pool to the no-proxy list when the site has a proxy ([proxy.md](proxy.md), section X2).

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
```

Done when: the first command lists the pool and its advertisement, and a Service that asks for the pool has an EXTERNAL-IP from it.

## M3. BGP mode

BGP is for a site where the pool is not in the node subnet, or where the network team wants routes. MetalLB peers from every speaker node with the router and announces `BGP_PREFIX`. [pdf p.673] The network team configures the router: it must accept a BGP session from each node address with `BGP_MY_ASN`. [pdf p.673, p.783]

**Stop first.** On 2.19.0, the API server rejects every `BGPPeer`, also the guide example: "Maximum boundary value must be of type integer with format int32 in spec.myASN". The pool and the BGPAdvertisement pass. [live 2.19.0]

UNKNOWN (N-20): whether a fix exists for the `BGPPeer` rejection on NKP 2.19. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd bgppeers.metallb.io -o jsonpath='{.spec.versions[?(@.name=="v1beta2")].schema.openAPIV3Schema.properties.spec.properties.myASN}'` (the block in step 1).

1. Run the N-20 check first:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd bgppeers.metallb.io -o jsonpath='{.spec.versions[?(@.name=="v1beta2")].schema.openAPIV3Schema.properties.spec.properties.myASN}{"\n"}'
```

2. If it prints `"format":"int32"` and `"maximum":4294967295`, the rejection is still there. Stop here. Do not ask for the BGP values, and do not write a file. Tell the user that BGP mode is blocked on this version (N-20), and offer a Layer 2 pool (M2). Do not change the MetalLB CRD.
3. Only when the schema is different: ask the user for the four BGP values, and append them to the cluster env file (rule 4). Then show the plan (the file path `$PWD/<cluster>-metallb-bgp.yaml`, the peer, the ASNs, the prefix). Stop for "yes". Then write the file:

```bash
# CHANGES  (writes the BGP file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
pool='bgp'
: "${BGP_PEER_IP:?}" "${BGP_MY_ASN:?}" "${BGP_PEER_ASN:?}" "${BGP_PREFIX:?}"
printf -- 'apiVersion: metallb.io/v1beta2\nkind: BGPPeer\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  myASN: %s\n  peerASN: %s\n  peerAddress: %s\n---\napiVersion: metallb.io/v1beta1\nkind: IPAddressPool\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  addresses:\n  - %s\n---\napiVersion: metallb.io/v1beta1\nkind: BGPAdvertisement\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  ipAddressPools:\n  - %s\n' "$pool" "$BGP_MY_ASN" "$BGP_PEER_ASN" "$BGP_PEER_IP" "$pool" "$BGP_PREFIX" "$pool" "$pool" > "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

4. Preview with a server dry run. If the `BGPPeer` fails with the int32 message, do not apply. Go back to step 2.

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
pool='bgp'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

5. Only when all three objects print `created (server dry run)`: show the plan and stop for "yes". Then apply with the M2 apply block (`pool='bgp'`).

Check the BGP session. Before any `BGPPeer` exists, the output is "% BGP instance not found". [live 2.19.0] With a working peer, the router row shows a prefix count, not `Active` or `Connect`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system exec ds/metallb-speaker -c frr -- vtysh -c "show bgp summary"
```

`ds/metallb-speaker` reads one speaker pod. Each node has its own session.

Done when: each speaker shows an established session, and the router has a route for the Service IP.
