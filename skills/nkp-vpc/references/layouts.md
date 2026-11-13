# VPC layouts: tenants, transit VPC, registry, Flow CNI

Use this file from skill `nkp-vpc`, step 1, when the site has more than one VPC, a transit VPC, a management cluster outside the VPC, or asks about Flow CNI with a VPC. Use L8 from step 3 to fix the Docker MTU. All facts are from TN-2207 v2.0 [portal] unless a tag says other.

## L1. Management cluster and workload clusters

| Layout | Management cluster | Workload clusters | How the management cluster reaches a workload API |
|---|---|---|---|
| All in one VPC | in the VPC (self-managed) | same VPC | `CP_VIP` directly (same overlay) |
| Mixed | on an enterprise VLAN subnet | one VPC per tenant | `FIP_API` of each workload cluster (exposed layout, 1 floating IP), or routes through a transit VPC |
| Shared control plane | in the transit VPC | in tenant VPCs | routed through the transit VPC; tenant overlay ranges must be unique |
| Per-tenant NKP | one per tenant, in the tenant VPC (self-managed) | same tenant VPC | `CP_VIP` directly; tenant overlay ranges can overlap; one bastion with a floating IP per tenant |

- Mixed layout: the VLAN management cluster needs no floating IPs for itself. Create each workload cluster from the management cluster, in its workspace namespace (skill `nkp-install`, `nutanix.md` N5), with only `--control-plane-external-endpoint` (skill `nkp-vpc`, step 4). `--cluster-hostname` has no effect on a workload cluster. [portal][live 2.19.0]
- In every layout with more than one subnet (mixed, shared control plane, a second tenant), the `SUBNET` of a workload cluster goes in its cluster env file, not in `~/nkp-site.env` (skill `nkp-vpc`, step 2).
- When the management cluster creates a workload cluster in a VPC, the CAPI controllers on the management cluster must reach Prism Central, and `FIP_API` of the new cluster. TN-2207 says "register them by floating IP or FQDN". [portal]
- A VLAN management cluster with no route to the overlay (a NAT external subnet) created a workload cluster in a VPC through `FIP_API` only: create RC=0 in 13 min, all Machines Ready, NKPCluster `Reconciled`. From the operator host on the same VLAN, `CP_VIP` answered `000` and `FIP_API` answered `200`. [live 2.19.0]

Done when: the user chose one row.

## L2. Transit VPC

- A transit VPC is a hub. Tenant VPCs connect to it through **overlay external subnets**. Only a transit VPC can have an overlay external subnet. [portal]
- The uplink of a transit VPC is a VLAN external subnet. A transit VPC cannot connect to another transit VPC. [portal]
- Shared services for all tenants go in the transit VPC: registry, DNS, identity provider, monitoring. [portal]
- No-NAT path: each VPC on the path must set its externally routable prefixes (ERPs). Without them, the transit VPC does not advertise the tenant ranges. [portal]

When do two tenant VPCs need a floating IP to talk to each other? [portal]

| Case | Floating IP needed |
|---|---|
| Tenant ranges overlap | yes |
| Tenants must not see each other's IPs | yes |
| The only path is a NAT overlay external subnet | yes |
| Unique ranges, no-NAT overlay external subnet, correct ERPs | no, routed |

## L3. NAT limits

- A VPC can have only **one NAT external subnet**. If a cluster must reach two networks that both need NAT, use NAT for one and no-NAT for the other, or a firewall in a transit VPC, or two clusters. [portal]
- Size the external subnet pool for all SNAT IPs and all floating IPs of all VPCs on it: 2 per exposed management cluster, 1 per exposed workload cluster, 1 per outside `LoadBalancer` Service, 1 per bastion with outside access. Each VPC gateway also holds pool addresses (`externalIps`). [portal][live 2.19.0]
- TN-2207 tested only inbound control for VPC overlays. Outbound rules (security policies) are the site's job. [portal]

## L4. Registry and air-gapped sites

The nodes pull from the overlay subnet on TCP 443. [portal] Registry places that work [portal]:
1. In the same VPC, on the overlay. No floating IP, no NAT.
2. In the transit VPC, shared by all tenant VPCs.
3. On the external VLAN, reached through the NAT or no-NAT external subnet.

- The create flags for the registry and the bundle do not change in a VPC: skill `nkp-install` (`nutanix.md` N4B or N4C). Seeding: skill `nkp-airgap`.
- `NTP_SERVERS` is mandatory on an air-gapped site. [pdf p.724] The NTP servers must be reachable from the overlay.
- The image build (`nkp create image nutanix`) on the bastion also needs the subnet and the Docker MTU fix (skill `nkp-vpc`, step 3). [pdf p.712][portal]
- With a proxy: add `CP_VIP`, `API_EXTERNAL_ENDPOINT`, the first IP of `LB_IP_RANGE`, and (management cluster) `UI_HOSTNAME` to the no-proxy list. The list itself: skill `nkp-networking`, `proxy.md` X2.

UNKNOWN (N-45): the DNS server that the overlay subnet gives to the nodes, and whether it must resolve the DNS names of `API_EXTERNAL_ENDPOINT` and `UI_HOSTNAME`. TN-2207 does not say. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && getent hosts "$API_EXTERNAL_ENDPOINT" "$UI_HOSTNAME"` on the bastion in the VPC.

## L5. Flow CNI and a VPC

These are two different uses of Flow:

| | NKP in a Flow VPC (skill `nkp-vpc`) | Flow CNI (skill `nkp-flow-cni`) |
|---|---|---|
| Flow gives | the node network: VPC, overlay subnet, floating IPs | the pod network: namespaces in VPCs |
| CNI | Cilium (default) | Flow CNI |
| Node subnet | VPC overlay subnet | not an overlay subnet (skill `nkp-flow-cni`) |
| LoadBalancer IPs | MetalLB in the overlay, floating IPs for outside | MetalLB |

Open item N-04: no source says that nodes on a VPC overlay subnet can use Flow CNI. Only Nutanix support can answer. Do not combine them. For tenant separation with Cilium, give each tenant its own VPC and cluster (per-tenant NKP, L1). [portal]

## L6. Other limits

- A VM in a VPC cannot also have a plain VLAN NIC, so a node cannot be in the VPC and on the enterprise VLAN at the same time. Use a transit VPC. [field]
- Floating IPs belong to one VPC. Two VPCs can map their floating IPs to the same private IP. Do not use a private IP as a name across VPCs. [portal]
- Prism Central must be reachable from every overlay on TCP 9440 (CAPX, CSI, the Prism Central onboarding). [portal] Onboarding works with nodes on an overlay subnet: the `konnector-agent` pod runs. [live 2.19.0]
- The storage container must be in the Prism Element cluster of the nodes. [pdf p.720] CSI does not use VPC objects.
- Licensing: Flow Virtual Networking needs a license tier that the site must confirm. TN-2207 gives no tier. [portal] Not in the skills: the exact tier.
- Prism Central size for VPCs: the Flow CNI guide asks for an XL Prism Central. TN-2207 does not say this for plain VPCs. [portal] Ask the Prism Central admin.

## L7. Change the external API endpoint

Use this from skill `nkp-vpc`, step 6, when the user wants a new `FIP_API` or `API_EXTERNAL_ENDPOINT` on a running cluster. The API accepts the field change [live 2.19.0], but the effect on certificates, kubeconfigs, and nodes is not known. Stop. Do not patch the field.

UNKNOWN (N-42): a supported way to change the external API endpoint of a running cluster. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.nutanix.controlPlaneEndpoint}{"\n"}'`.

## L8. Fix the Docker MTU on the operator host

Use this from skill `nkp-vpc`, step 3, only when the bridge MTU or the kind MTU is not the NIC MTU. When they are the same, change nothing.

The restart stops all containers. If the step 3 `running:` line shows a name (a bootstrap cluster, a registry), stop and ask the user. The block needs `jq` and `sudo` without a password prompt; if not, give it to the user. It reads the file with `sudo`, keeps all other keys, the owner, and the mode, and saves a copy as `daemon.json.bak`. Show the plan and stop for "yes".

```bash
# CHANGES  (sets the Docker MTU to the NIC MTU in /etc/docker/daemon.json, keeps a .bak copy, restarts Docker)
dev=$(ip route show default | awk '{print $5; exit}'); mtu=$(cat "/sys/class/net/$dev/mtu"); : "${mtu:?}"
sudo -n true || { echo "needs sudo without a password"; exit 1; }
f=/etc/docker/daemon.json; t=$(mktemp); trap 'rm -f "$t"' EXIT
if sudo test -s "$f"; then sudo cp -p "$f" "$f.bak" && sudo cat "$f" | jq --argjson m "$mtu" '.mtu = $m' > "$t"; else echo '{}' | jq --argjson m "$mtu" '.mtu = $m' > "$t"; fi && [ -s "$t" ] && sudo tee "$f" < "$t" > /dev/null && sudo systemctl restart docker
```

If `jq` fails (the file is not valid JSON), the block changes nothing. Show the error to the user.

The `mtu` key changes only the default bridge. An old `kind` network keeps its MTU. [field] When the kind network has the wrong MTU and `containers 0`, make it again (CHANGES, after "yes"):

```bash
# CHANGES  (makes the kind network again with the NIC MTU)
dev=$(ip route show default | awk '{print $5; exit}'); mtu=$(cat "/sys/class/net/$dev/mtu"); : "${mtu:?}"
[ "$(docker network inspect kind --format '{{len .Containers}}' 2>/dev/null || echo 0)" = 0 ] && { docker network rm kind 2>/dev/null; docker network create -o "com.docker.network.driver.mtu=$mtu" kind; }
```

UNKNOWN (N-40): whether `nkp` makes the kind network with the Docker bridge MTU when no kind network exists. Find out with: `docker network inspect kind --format '{{index .Options "com.docker.network.driver.mtu"}}'` after `nkp create bootstrap`. Upstream kind makes a new `kind` network with the MTU of the default bridge. [field: kind source] Podman MTU: not in the skills.

Done when: the step 3 READ-ONLY block shows the same MTU for the NIC, the bridge, and the kind network.
