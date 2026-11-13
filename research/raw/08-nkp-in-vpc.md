# NKP clusters inside a Nutanix Flow VPC (Flow Virtual Networking)

Scope: NKP node VMs (control plane + workers) sit on **VPC overlay subnets**, not on a plain VLAN.
The CNI is still Cilium. This file is about the *infrastructure* network, not Flow CNI
(for Flow CNI see `06-flow-cni.md`).

Primary source: Nutanix Tech Note **TN-2207 "Nutanix Kubernetes Platform with Flow Virtual Networking"**,
doc version **2.0, last updated 2026-05-12** (v1.0 January 2025 added mixed deployment + transit VPC in 2.0)
`[portal: TN-2207 Executive Summary]`. Every section of the tech note was read as a guest.

## Documented software versions

| Component | Minimum (TN-2207) | Note |
|---|---|---|
| AOS | **7.5 or later** | `[portal: TN-2207 Executive Summary]` |
| Prism Central | **7.5 or later** | `[portal: TN-2207 Executive Summary]` |
| NKP | **2.17 or later** | `[portal: TN-2207 Executive Summary]` |
| Network Controller | **7.0.0 or later** | `[portal: TN-2207 Executive Summary]` |
| NKP CLI on the bastion | 2.12 or later "depending on the deployed version" | `[portal: TN-2207 Bastion Host]` |
| kubectl on the bastion | 1.28.x or later | `[portal: TN-2207 Bastion Host]` |

NF: the tech note's version floor (NKP 2.17) is older than the 2.19 reference for this repo. The
floating-IP flags this note uses are present in the 2.19 CLI `[live: nkp-help-cluster.txt]`.

## Components

### Flow Virtual Networking (VPC, external subnet, overlay subnet)
- **What**: Software-defined networking in Prism Central. A VPC is a logically isolated network
  domain; networks inside it are overlay networks built with **Geneve** encapsulation.
  `[portal: TN-2207 Flow Virtual Networking Overview]`
- **Upstream**: Nutanix proprietary (Prism Central + Network Controller). Guide: Flow Virtual Networking Guide.
- **NKP role / name**: infrastructure only. The objects NKP names on the CLI side are **subnet names**
  (`--control-plane-subnets`, `--worker-subnets`) and must be the **overlay** subnets `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]`.
- **Runs on**: Prism Central / AHV (Network Controller).
- **Deployed by**: manual, in Prism Central (UI or API). Never by NKP, never by a Kubernetes CR.
- **Default**: n/a (opt-in infrastructure choice).
- **Depends on / talks to**: an **external network** = a **VLAN** subnet with "External Connectivity
  for VPCs" enabled; NAT or no-NAT (routed) mode `[portal: TN-2207 Flow Virtual Networking Overview]`.
- **Air-gap notes**: no images; needed so the overlay has a routable exit toward Prism Central and a registry.
- **Key commands**: Prism Central → Infrastructure → Subnet / VPC / Floating IP. `nkp` only sees subnet **names**.
- **Sources**: `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]`.

### Floating IP (FIP)
- **What**: a 1:1 **static DNAT** mapping from an external-network IP to one private IP inside the VPC.
  "All ports are mapped between the internal IP address and the external floating IP address."
  `[portal: TN-2207 Flow Virtual Networking Overview]`
- **NKP role**: the only way the API endpoint and the NKP UI become reachable from outside the VPC
  `[portal: TN-2207 Nutanix Kubernetes Platform Virtual IP Addresses]`.
- **Important**: FIPs are **VPC aware** — two FIPs in different VPCs may point to the same private IP
  `[portal: TN-2207 Flow Virtual Networking Overview]`.
- **Allocation**: Prism Central, before or during cluster build; associate FIP → private IP (VIP).
- **Sources**: `[portal: TN-2207 Configuring Floating IP Addresses]`.

### Transit VPC
- **What**: hub-and-spoke VPC that routes between tenant VPCs and the physical network, holds shared
  services, BGP sessions and site-to-site VPNs `[portal: TN-2207 Transit VPC-Based Deployments]`.
- **Rules**: user VPCs attach to it through **overlay external subnets**; only a transit VPC may use an
  overlay external network (Flow VN rule, see raw `06`) `[portal: TN-2207 Flow Virtual Networking Overview]`.
- **Sources**: `[portal: TN-2207 Transit VPC-Based Deployments]`.

### Bastion VM (+ kind bootstrap cluster)
- **What**: jump host inside the same VPC; runs the NKP CLI, Docker/Podman, and the temporary
  Kubernetes-in-Docker (kind) bootstrap cluster. "run all the commands on the bastion host"
  `[portal: TN-2207 Bastion Host]`.
- **Hard requirement**: the build host **must be in the same VPC as the target cluster**, because the
  floating IP is not the control-plane VIP `[portal: TN-2207 NKP with Flow Virtual Networking Known Behaviors]`.
- **Sources**: `[portal: TN-2207 Bastion Host]`.

### kube-vip (control-plane VIP)
- **What**: ARP/L2 VIP for the API server, from `--control-plane-endpoint-ip`.
- **In a VPC**: "KubeVIP and MetalLB use the Address Resolution Protocol (ARP) (Layer 2) to broadcast
  the IP address in the same overlay subnet as the VMs. The VIP address must belong to the same subnet
  as the hosts" → the VIP is **private** and not reachable outside the VPC
  `[portal: TN-2207 Nutanix Kubernetes Platform Virtual IP Addresses]`.

### MetalLB (service LoadBalancer range)
- **What**: implementation of the services-of-type-LoadBalancer VIP on Nutanix infrastructure.
- **In a VPC**: L2/ARP announcement inside the overlay subnet; the range given to
  `--kubernetes-service-load-balancer-ip-range` is a **private overlay range**
  `[portal: TN-2207 Nutanix Kubernetes Platform Virtual IP Addresses]`.
- **First IP of the range** is the `kommander-traefik` ingress address and the address the UI is served on
  `[portal: TN-2207 Nutanix Kubernetes Platform Virtual IP Addresses]`, `[pdf p.721]`, `[live: networking.txt]`.

### Cilium (CNI, unchanged by the VPC)
- **What**: default AHV CNI; replaces kube-proxy; Geneve tunnel; `bpf-lb-mode: dsr` by default.
- **In a VPC**: pods are inside the cluster; the VPC sees node IPs only. Pod CIDR must not overlap any
  VPC overlay CIDR `[portal: TN-2207 NKP with Flow Virtual Networking Known Behaviors]`.
- **Sources**: `[live: networking.txt]`, `[pdf p.593]`, `[pdf p.727-728]`.

### Traefik (`kommander-traefik`)
- **What**: the single ingress entry point for the NKP UI and tenant ingresses; `type: LoadBalancer`.
- **In a VPC**: takes the first MetalLB IP; outside access goes through a FIP attached to that private IP
  `[portal: TN-2207 Configuring Floating IP Addresses]`.

## Architecture

Two documented topologies, plus two multitenancy patterns. All node IPs, the control-plane VIP and the
MetalLB pool are **private overlay** addresses; only FIPs live on the external VLAN.

```
                 physical fabric / enterprise VLAN  (external network, NAT or no-NAT)
                 subnet <ext-vlan-subnet> — routable, holds all SNAT + floating IPs
                          |                                ^
              SNAT egress |                                | FIP -> private IP (DNAT, all ports)
                          v                                |
 +------------------------------- VPC  <vpc-name>  overlay CIDR <vpc-cidr> -------------------------------+
 |                                                                                                        |
 |  <bastion-vm>  (same VPC, runs nkp CLI + kind bootstrap, MTU 1442)                                      |
 |      |                                                                                                 |
 |      | CAPI creates VMs                                                                                |
 |      v                                                                                                 |
 |  [CP node] [CP node] [CP node]        CP VIP <cp-overlay-ip>   (kube-vip, ARP/L2)  --FIP--> <fip-cp>    |
 |  [worker node] [worker node] ...                                                                        |
 |      |  Cilium geneve  pods <pod-cidr>  services <svc-cidr>                                             |
 |  [MetalLB pool <metallb-first>-<metallb-last>]  L2/ARP in the same overlay                             |
 |      |                                                                                                  |
 |  kommander-traefik (first MetalLB IP)  -------------------------------FIP--> <fip-ingress>               |
 +--------------------------------------------------------------------------------------------------------+
                          |
                          |  Prism Central <pc-ip>:9440 (nodes only)  ·  registry <registry-ip>:443
```

- **Bastion**: inside the VPC. Builds the cluster; also the only interactive entry point on the same VPC.
- **Management cluster**: can sit in the VPC (self-managed) or on the VLAN (mixed model).
- **Workload clusters**: in their own VPC, or VLAN.
- **Prism Central**: outside the VPC on a VLAN/managed subnet. Nodes need 9440 outbound; no inbound.
- **Registry**: private registry recommended; in the same VPC, or in the transit VPC, or reachable over the
  external network (`[portal: TN-2207 Configuring Flow Virtual Networking VPCs]`, `[portal: TN-2207 Prerequisites...]`).
- **Users**: outside the VPC → FIP; inside the VPC → private IP.

### Topology A — isolated NKP (private API + private UI)
Simplest; **no extra NKP CLI flags**: "everything uses a private IP address". Only users on the same VPC
reach the API and the NKP UI `[portal: TN-2207 VPC Deployment with Isolated Nutanix Kubernetes Platform]`.

### Topology B — exposed NKP (API + UI through floating IPs)
API and ingress are exposed with FIPs; needs a **minimum of two FIPs** per self-managed cluster
(control plane + UI/ingress) `[portal: TN-2207 VPC Deployment with Exposed Nutanix Kubernetes Platform]`.
Any additional `LoadBalancer` service needs its own extra FIP `[portal: TN-2207 VPC Deployment with Exposed...]`.

### Topology C — VLAN management + VPC workloads (mixed)
Management cluster stays on the enterprise VLAN (avoids extra FIPs, routes and firewall exceptions);
each tenant gets a VPC with its own overlay CIDR (may overlap across tenants). The management cluster
must still reach every workload API, by one of: (1) build workload clusters with the exposed flags and
register them by FIP/FQDN, or (2) route through a transit VPC
`[portal: TN-2207 VLAN and VPC Mixed Deployment]`.

### Topology D — transit VPC hub
All tenant VPCs attach to one transit VPC over overlay external subnets; the transit VPC is the single
exit and the single BGP peer with the physical network. Pod/node → outside path:
tenant VPC logical router → overlay external subnet → transit VPC logical router → shared service, or
NAT/no-NAT external subnet → physical network `[portal: TN-2207 Transit VPC-Based Deployments]`.

| Scenario | FIP needed between two tenant VPCs? |
|---|---|
| Overlapping tenant IP ranges | Yes |
| Tenants hidden from each other at IP level | Yes |
| Only path is a **NAT** overlay external network | Yes |
| Unique IPs, **no-NAT** OEN + correct externally routable prefixes (ERPs) | No, routed directly |

`[portal: TN-2207 Transit VPC-Based Deployments]` — in the no-NAT case every VPC on the path must
advertise the correct ERPs (else the transit BGP gateway will not advertise them; alert 802007 — raw `06`).

| Pattern | Management cluster | Registry / DNS / monitoring | Tenant isolation | Cluster life cycle owner |
|---|---|---|---|---|
| Shared NKP control plane | one, in the transit VPC | transit VPC (shared) | network-reachable; tenants must use **unique** overlay CIDRs | platform team |
| Per-tenant NKP | one per tenant, in the tenant VPC (usually self-managed) | transit VPC (provider-operated) | full; **overlapping CIDRs allowed**; per-tenant bastion with FIP | tenant |

`[portal: TN-2207 Shared NKP Control Plane]`, `[portal: TN-2207 Per-Tenant NKP]`

## Requirements

| Item | Requirement | Source |
|---|---|---|
| AOS | 7.5+ | `[portal: TN-2207 Executive Summary]` |
| Prism Central | 7.5+; scale-out (3-node) recommended for production Flow VN | `[portal: TN-2207 Executive Summary]`, `[web: nutanix.dev/enabling-nutanix-flow-virtual-networking-on-ahv]` |
| NKP | 2.17+ | `[portal: TN-2207 Executive Summary]` |
| Network Controller | 7.0.0+, integrated mode (Flow VN) | `[portal: TN-2207 Executive Summary]` |
| Licensing | Flow Virtual Networking is a licensed feature (NCI Pro/Ultimate tier; Flow CNI reported as NCI Ultimate/Pro too). The note only says "meet the minimum licensing requirements" and links Nutanix Cloud Platform Software Options | `[portal: TN-2207 Prerequisites...]`, `[web: next.nutanix.com/t5/ahv-virtualization/connectivity-issues-overlay-subnet]` — **confirm per site** |
| Prism Central account | admin-level permissions; with custom RBAC roles the role must have administrator-level rights | `[portal: TN-2207 Prerequisites...]` |
| External subnet | VLAN subnet with **External Connectivity for VPCs** on; routable; **enough IPs for all SNAT + all floating IPs** | `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]` |
| External subnet mode | NAT **or** no-NAT (routed). **Only one NAT external network per VPC** (hard limit) | `[portal: TN-2207 Known Behaviors]` |
| Overlay subnet | private IP range, associated to the VPC; this is the **node subnet** for `--control-plane-subnets` / `--worker-subnets` | `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]` |
| Node subnet overlap | must not overlap the pod CIDR, service CIDR, or the control-plane VIP | `[portal: TN-2207 Known Behaviors]`, `[pdf p.709]` |
| Pod CIDR | default `192.168.0.0/16`, change with `--kubernetes-pod-network-cidr`; must not collide with any VPC (overlay) range | `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]`, `[pdf p.723-724]` |
| Service CIDR | default `10.96.0.0/12`, change with `--kubernetes-service-cidr`; cluster-wide, immutable after create | `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]`, `[pdf p.723-724]` |
| Control-plane VIP | static IPv4 **in the overlay subnet L2**, not in the DHCP/IPAM pool, unused; supply with `--control-plane-endpoint-ip` | `[pdf p.720]`, `[live: nkp-help-cluster.txt]` |
| Service LB range | static range **inside the overlay subnet**, not in the IPAM pool; supply with `--kubernetes-service-load-balancer-ip-range`; first IP = Traefik/UI | `[pdf p.721]`, `[portal: TN-2207 Configuring Floating IP Addresses]` |
| Floating IPs | 2 for an exposed self-managed cluster (CP + ingress); +1 if the UI is reached through the bastion; PDF lists **3** for the UI-from-outside case: bastion, `--extra-sans`, UI | `[portal: TN-2207 VPC Deployment with Exposed...]`, `[pdf p.721]` |
| MTU (VPC VM) | **1442** (DHCP Option 26 from AHV auto-IPAM); MTU must be set explicitly on VPC subnets if you change it | `[portal: TN-2207 Bastion Host]`, `[pdf p.711]` |
| MTU (Cilium overlay) | infrastructure MTU − 50 (1442 → 1392 encapsulated) | `[pdf p.711]` |
| MTU (Docker/kind on bastion) | must be forced to 1442; Docker default 1500 breaks Prism Central TLS during bootstrap | `[portal: TN-2207 Bastion Host]` |
| DNS | not specified in the note. FQDN form of the FIP (`--cluster-hostname`, `--control-plane-external-endpoint`) requires an A record → FIP → private IP, created manually | `[portal: TN-2207 Configuring Floating IP Addresses]` (DNS server requirement itself: **UNKNOWN**) |
| NTP | mandatory in air-gap; `--ntp-servers` on create | `[pdf p.724]` |
| Ports (infra) | TCP **9440** node network → Prism Central; TCP **443** node network → image registry | `[portal: TN-2207 Prerequisites for Deploying Clusters on Overlay Networks]` |
| Ports (NKP) | full list = the NKP "Ports and Protocols" page; the note defers to it | `[portal: TN-2207 Prerequisites...]` |
| Egress from the VPC | `0.0.0.0/0` route or specific prefixes; security groups / ACLs also gate outbound | `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]` |
| Prism Central size for creating VPCs | Flow-CNI guide states VPC creation needs PC **XL**; not repeated in TN-2207 → **UNKNOWN for plain Flow VN**, verify in PC | `[portal: Flow CNI guide]` via raw `06` |

## Deployment procedure

Prism Central preparation (steps 1–6 in the PDF are Prism Central work, `[pdf p.708-710]`,
`[portal: TN-2207 Configuring Flow Virtual Networking VPCs]`):

1. Prism Central → Infrastructure → **create a VLAN subnet** and enable **External Connectivity for VPCs**.
   Make it routable and size the pool for all SNAT plus all floating IPs.
2. **Create a VPC** and associate it with that external subnet (choose NAT or no-NAT).
3. **Create an overlay subnet** (private range = your node subnet) and associate it with the VPC. Optional:
   create more VPCs/subnets for more tenants.
4. (Exposed topology only) **Request two floating IPs** on the external subnet. Keep them unassociated
   for now. Map the first to the future control-plane VIP and the second to the first MetalLB IP later
   `[portal: TN-2207 Configuring Floating IP Addresses]`.
5. Create the storage container on the Prism Element cluster; verify the subnet and container are on the
   **same Prism Element cluster** `[pdf p.720]`.
6. Have the OS image in Prism Central (`nkp create image nutanix`) — image build also needs a subnet and
   the PC endpoint `[pdf p.712]`.

Bastion preparation:

7. Put the bastion VM **in the same VPC**, on the overlay subnet. Install Docker/Podman, kubectl ≥1.28,
   the NKP CLI ≥2.12 `[portal: TN-2207 Bastion Host]`.
8. **Fix the MTU before the bootstrap cluster exists** — this is the #1 failure:
   ```
   sudo tee /etc/docker/daemon.json <<'EOF'
   { "mtu": 1442 }
   EOF
   sudo systemctl daemon-reload && sudo systemctl restart docker
   ```
   (or, per network only: `docker network create -o "com.docker.network.driver.mtu=1442" kind`)
   VPC VMs are MTU 1442, Docker is 1500 → Prism Central TLS handshakes fail without this
   `[portal: TN-2207 Bastion Host]`.
9. Verify PC reachability from the bastion: `curl -k https://<pc-ip>:9440` and the registry on 443
   `[portal: TN-2207 Prerequisites...]`.

Build (single self-managed management cluster; the flags are the 2.19 CLI flags `[live: nkp-help-cluster.txt]`):

10. Export the values (all placeholders):
    ```
    export NUTANIX_ENDPOINT=<pc-fqdn-or-ip>:9440
    export NUTANIX_USER=<user> NUTANIX_PASSWORD=<password>
    export NUTANIX_CLUSTER=<prism-element-cluster>
    export STORAGE_CONTAINER_NAME=<container>
    export SUBNET=<overlay-subnet-name>              # the VPC overlay subnet
    export VM_IMAGE=<nkp-os-image>
    export CONTROLPLANE_IP=<cp-overlay-ip>           # static, in SUBNET, outside IPAM pool
    export SERVICE_LB_IP_RANGE=<metallb-first>-<metallb-last>   # inside SUBNET
    export KUBERNETES_PODS_NETWORK=<pod-cidr>        # default 192.168.0.0/16, must not match any VPC CIDR
    export KUBERNETES_SERVICES_NETWORK=<svc-cidr>    # default 10.96.0.0/12
    ```
11. Isolated topology: create with the default flags only
    `[portal: TN-2207 VPC Deployment with Isolated Nutanix Kubernetes Platform]`:
    ```
    nkp create cluster nutanix --self-managed \
      --cluster-name=<name> \
      --endpoint=${NUTANIX_ENDPOINT} \
      --control-plane-endpoint-ip=${CONTROLPLANE_IP} \
      --csi-storage-container=${STORAGE_CONTAINER_NAME} \
      --kubernetes-pod-network-cidr=${KUBERNETES_PODS_NETWORK} \
      --kubernetes-service-cidr=${KUBERNETES_SERVICES_NETWORK} \
      --kubernetes-service-load-balancer-ip-range=${SERVICE_LB_IP_RANGE} \
      --control-plane-prism-element-cluster=${NUTANIX_CLUSTER} \
      --control-plane-subnets=${SUBNET} --control-plane-vm-image=${VM_IMAGE} \
      --worker-prism-element-cluster=${NUTANIX_CLUSTER} \
      --worker-subnets=${SUBNET} --worker-vm-image=${VM_IMAGE} \
      --ntp-servers=<ntp1>,<ntp2>
    ```
12. Exposed topology: add **three** flags `[portal: TN-2207 Configuring Floating IP Addresses]`:
    ```
      --control-plane-external-endpoint=<fip-cp-or-fqdn> \
      --cluster-hostname=<fip-ingress-or-fqdn> \
      --extra-sans=<fip-cp-or-fqdn>
    ```
    - `--control-plane-external-endpoint` sets both the externally advertised API address **and the API
      server certificate SAN** `[portal: TN-2207 Configuring Floating IP Addresses]`.
    - `--cluster-hostname` sets the hostname used for the NKP dashboard (`nkp get dashboard` /
      `nkp open dashboard`) `[portal: TN-2207 Configuring Floating IP Addresses]`, `[live: nkp-help-cluster.txt]`.
    - `--extra-sans` is the PDF's alternative for "one IP for passing the `--extra-sans` flag during
      cluster creation" `[pdf p.721]`; it only adds API cert SANs `[live: nkp-help-cluster.txt]`.
      Do not rely on `--extra-sans` for ingress — it does nothing for the UI hostname.
13. In Prism Central, **associate the floating IPs**: FIP-1 → `CONTROLPLANE_IP`, FIP-2 → the first IP of
    `SERVICE_LB_IP_RANGE` `[portal: TN-2207 Configuring Floating IP Addresses]`.
14. If you forgot `--cluster-hostname`, patch it afterwards (this is also the way to add an FQDN):
    ```
    export FLOATING_IP_INGRESS=<fip-ingress>
    kubectl patch kommandercluster -n kommander <cluster> --type=merge --patch-file=/dev/stdin <<EOF
    spec:
      ingress:
        hostname: $FLOATING_IP_INGRESS
    EOF
    ```
    `[portal: TN-2207 Configuring Floating IP Addresses]` (the note's example uses `host-cluster`).
15. Re-fetch the kubeconfig so it points at the FIP: "Access the cluster in the VPC from outside using
    updated kubeconfig after creating the cluster" `[pdf p.721]`.
16. Managed/workload clusters in a tenant VPC: build them from the management cluster (which is on the
    VLAN or in the transit VPC) with the same exposed flags, then register them in NKP by **FIP or FQDN**
    `[portal: TN-2207 VLAN and VPC Mixed Deployment]`. If the management cluster cannot route to the tenant
    VPC, add a transit VPC instead of per-VPC VLAN attachments.
17. Verify: `kubectl get nodes -o wide` (all node IPs are overlay IPs), `kubectl -n kommander get svc kommander-traefik`
    (EXTERNAL-IP = first MetalLB IP), `nkp get dashboard` (prints the FIP hostname).

## Load balancing and ingress in a VPC

- **Two VIPs by default**: kube-vip for the control plane, MetalLB for `LoadBalancer` services. Both are
  **ARP/L2** and must be in the same overlay subnet as the VMs; therefore both are private and unusable
  from outside without a floating IP `[portal: TN-2207 NKP Virtual IP Addresses]`.
- **The control-plane VIP is never the floating IP.** "The floating IP address can be the external endpoint
  (through `--control-plane-external-endpoint`), but it is not the virtual IP address itself"
  `[portal: TN-2207 Known Behaviors]`.
- **Ingress path**: user → FIP → private MetalLB IP (first of the range) → `kommander-traefik` →
  route to the service. One FIP per extra `LoadBalancer` service
  `[portal: TN-2207 VPC Deployment with Exposed...]`.
- **MetalLB config in a VPC**: unchanged from a VLAN — one `IPAddressPool` (`metallb`) with
  `autoAssign: true` and one `L2Advertisement` `[live: networking.txt]`. Do **not** switch it to BGP: the
  overlay subnet is L2 inside the VPC and the VPC's own external network does the routing.
- **UI/FQDN**: `--cluster-hostname` on create, or the `KommanderCluster spec.ingress.hostname` patch;
  the FQDN must resolve to the FIP, which DNATs to the private MetalLB IP
  `[portal: TN-2207 Configuring Floating IP Addresses]`.
- **Cilium DSR vs SNAT** — the trap:
  - NKP ships `loadBalancer.mode: dsr` + `dsrDispatch: geneve`; the live cluster shows `bpf-lb-mode = dsr`
    `[pdf p.727-728]`, `[live: networking.txt]`.
  - On **Network-Controller-managed VLAN subnets** DSR replies leave with the service IP as source from a
    NIC that does not own it and get dropped → the LB address is dead while the API VIP is fine. Fix =
    `loadBalancer.mode: snat` through Cilium values at create time (ConfigMap + `values.sourceRef`), never a
    live `cilium-config` edit `[raw 02: Cilium gotcha]`, `[web: itcs 2.19 part 4]`.
  - TN-2207 does **not** mention DSR at all, and this repo has no lab evidence for DSR on a **VPC overlay**
    subnet → behaviour on an overlay is **UNKNOWN**. VPC subnets are also Network-Controller-managed, so
    treat DSR as suspect there too; if the MetalLB VIP answers inside the VPC but no reply comes back
    through the FIP, test `loadBalancer.mode: snat` first.
  - Do not "fix" it by editing the live `cilium-config` ConfigMap: an installed addon is not re-rendered
    from the cluster spec `[pdf p.727]`.
- **NodePort** works inside the VPC only (node IPs are private). Use `LoadBalancer` + FIP for outside access.

## Air-gap in a VPC

- Recommended: a **private registry** — "crucial for Kubernetes cluster deployments… enhances security,
  enables network isolation, and provides full control over container images". Registry deployment itself
  is out of scope of the note `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]`.
- Reachability: nodes need TCP **443** to the registry from the overlay subnet
  `[portal: TN-2207 Prerequisites...]`. Three placements work:
  1. registry in the **same VPC** on the overlay (simplest; no FIP, no NAT),
  2. registry in the **transit VPC** (shared by all tenant VPCs, routed over overlay external subnets —
     this is exactly what the shared-services role of a transit VPC is for)
     `[portal: TN-2207 Transit VPC-Based Deployments]`,
  3. registry on the **external VLAN**, reached over the NAT/no-NAT external subnet.
- NKP side, in the same `nkp create cluster nutanix` call `[pdf p.722-724]`:
  - bundled in-cluster registry: `--bundle <konvoy-image-bundle>.tar,<kommander-image-bundle>.tar,...`
    (add `nutanix-product-catalog-<ver>-airgapped.tar` **only if you deploy NDK**), plus `--airgapped=true`;
  - or external mirror: `--registry-mirror-url`, `--registry-mirror-username`, `--registry-mirror-password`,
    `--registry-mirror-cacert`;
  - never both `--bundle` and `--registry-mirror-*` `[pdf p.725]`;
  - add the registry (and pod/service CIDRs, `.svc`, the control-plane VIP, the MetalLB/Traefik IP) to
    `--no-proxy` if a proxy is in use `[pdf p.725]`, `[component map]`.
- `--ntp-servers` is **mandatory** in air-gap (no public NTP reachable from the overlay) `[pdf p.724]`.
- The image builder (`nkp create image nutanix`, `nkp create image-bundle`) also runs on the bastion; its
  containers inherit the Docker MTU — the global `"mtu": 1442` fix covers them too
  `[portal: TN-2207 Bastion Host]`.
- Docker Hub rate limits / the Nutanix org images need a PAT:
  `--nutanix-registry-username`, `--nutanix-registry-password` `[live: nkp-help-cluster.txt]`, `[pdf p.709]`.
- Scrub note for the skills: bundle paths in the PDF are `nkp-<version>/container-images/*.tar`.

## Limitations and gotchas

1. **Floating IP cannot be the control-plane VIP.** The VIP must be private, so the build host must be in
   the target VPC — a bastion outside the VPC cannot build the cluster
   `[portal: TN-2207 Known Behaviors]`.
2. **One NAT external network per VPC** (hard limit). Two networks that both need NAT into one cluster
   cannot both be attached → workaround: NAT for one side + no-NAT for the other, or a firewall in a
   transit VPC, or split into two clusters `[portal: TN-2207 Known Behaviors]`.
3. **MTU 1442 vs Docker 1500** → Prism Central SSL failures during bootstrap. Fix kind *and* Docker
   before `nkp create bootstrap` `[portal: TN-2207 Bastion Host]`.
4. **Pod/service CIDRs must not overlap any VPC range.** In-cluster routing prefers the local Kubernetes
   network over the VPC route, so an overlap silently black-holes traffic
   `[portal: TN-2207 Known Behaviors]`, `[pdf p.709]`.
5. **Only two flags are optional-looking but are the whole point**: `--control-plane-external-endpoint`
   (API + cert SAN) and `--cluster-hostname` (UI). Forgetting the second one leaves `nkp open dashboard`
   pointing at a private IP `[portal: TN-2207 Configuring Floating IP Addresses]`.
6. **Every extra `LoadBalancer` service needs its own FIP.** Plan FIP budget per VPC, not per cluster
   `[portal: TN-2207 VPC Deployment with Exposed...]`.
7. **One FIP per private IP**, and FIPs are VPC-scoped: two VPCs can map their own FIPs to the **same**
   private IP — do not use the private IP as a cross-VPC identifier
   `[portal: TN-2207 Flow Virtual Networking Overview]`.
8. **A VPC VM cannot also get a plain VLAN interface** (per community reports) → a node cannot be dual-homed
   onto the enterprise VLAN; plan the transit VPC instead `[web: next.nutanix.com — Connect a VM to both a Flow VPC and L2 VLAN]`
   — *field claim, verify*.
9. **Total FIP count is bounded by the external subnet pool.** Size the external subnet for peak
   (every tenant VPC × 2 FIPs + bastions + SNAT) `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]`.
10. **Prism Central must be reachable from every overlay** (9440) — PC on a management VLAN with no route
    into the VPC means no CAPX, no CSI, no Konnector `[portal: TN-2207 Prerequisites...]`.
11. **Transit VPC uplink must be a VLAN external network**; a transit VPC cannot attach to another transit
    VPC; only transit VPCs may use overlay external networks; ERPs must be set per guest VPC or BGP will not
    advertise them (alert 802007) `[portal: TN-2207 Transit...]`, `[portal: Flow VN Transit VPCs]` via raw `06`.
12. **Cross-VPC pod-to-pod is north-south**: it leaves through an external gateway, so it inherits the
    FIP/NAT path (Flow CNI behaviour, applies when Flow CNI is in use) `[raw 06]`.
13. **Testing scope**: "We tested these topologies to control **inbound** access to VPC overlay networks
    only" `[portal: TN-2207 Configuring Flow Virtual Networking VPCs]`. Outbound control is on you.
14. **CSI**: the storage container must be on the Prism Element cluster you name, and PC must reach PE
    `[pdf p.720]`. NDK/CSI VIPs are separate PE-side objects, not VPC objects.
15. **Cilium DSR on an overlay subnet: UNKNOWN** (no statement in TN-2207, no lab data). See the
    load-balancing section for the SNAT fallback.
16. `nkp delete cluster` does **not** delete the VPC, external subnet, overlay subnet or FIPs — those are
    Prism Central objects with no Kubernetes lifecycle (VPC lifecycle via K8s CRs is explicitly unsupported
    for Flow CNI; same object model here) `[raw 06: Container-only and Hybrid VPC Limitations]` — *inferred,
    not stated in TN-2207.*
17. **`--extra-sans` alone does not expose anything**; it only adds names to the API certificate. The PDF's
    "3 floating IPs for the UI" is bastion + `--extra-sans` + UI, which is a *different* recipe from
    TN-2207's 2-FIP recipe — pick one and be consistent `[pdf p.721]`, `[portal: TN-2207 Configuring Floating IP Addresses]`.

## Relation to Flow CNI

These are two independent uses of Flow, and they are usually **not** combined:

| | NKP in a Flow VPC (this file) | Flow CNI (`06-flow-cni.md`) |
|---|---|---|
| What Flow provides | the **node** network: overlay subnets, VPC, external subnet, FIPs, NAT | the **pod** network: OVN-Kubernetes replaces Cilium, namespaces map to VPCs |
| CNI | Cilium (default) or Calico | Flow CNI (OVN-Kubernetes) only |
| NKP floor | 2.17+ | 2.18+ (Flow CNI) — or 2.15+ per the Flow-CNI guide |
| Node subnet type | VPC **overlay** subnet | VLAN **Basic (AHV-managed)** — Flow CNI requires VLAN Basic node subnets |
| LB IPs | MetalLB + kube-vip, private in the overlay, exposed by FIPs | Flow CNI allocates **no** LB IPs; MetalLB still owns them |
| Prism Central objects | VPC, external subnet (NAT/no-NAT), overlay subnet, floating IPs | plus per-VPC pod CIDRs, namespace scope, egress IPs |
| MTU | 1442 VPC VM / 1392 Cilium-encapsulated | 1442 VPC / 1392 with subnet extension, 1356 with VPN, 1306 with VTEP+VPN |

`[portal: TN-2207 ...]`, `[raw 06: VPC model, requirements tables]`, `[pdf p.711]`

**When to combine them**: essentially never as documented. Flow CNI's prerequisites demand **VLAN Basic**
node subnets, so putting the nodes on a VPC overlay subnet contradicts Flow CNI's own requirements
`[raw 06: requirements tables]` — combined = **UNSUPPORTED / UNKNOWN**.
Choose one:
- Need tenant network isolation *around* the cluster, node IPs from a non-overlapping private range,
  flexible IP space, no OVN: **NKP in a Flow VPC** with Cilium (this file).
- Need namespace→VPC isolation *inside* the cluster, per-namespace egress IPs, VM/pod federation: **Flow CNI**
  on VLAN Basic node subnets (`06-flow-cni.md`).
- Need both styles: put the *cluster* in a VPC with Cilium, and give each tenant its own VPC + cluster
  (per-tenant pattern) instead of namespace-level VPCs `[portal: TN-2207 Per-Tenant NKP]`.

## Relationships

- Prism Central → VPC → external subnet (VLAN, NAT/no-NAT) → physical fabric: the only path in and out.
- VPC → overlay subnet → NKP node VMs: node IPs are private, L2 inside the VPC.
- `--control-plane-endpoint-ip` → kube-vip → ARP in the overlay → floating IP (DNAT) → external users.
- `--kubernetes-service-load-balancer-ip-range` → MetalLB `ipaddresspool`/`l2advertisement` → first IP →
  `kommander-traefik` → floating IP → NKP UI.
- `--cluster-hostname` → `KommanderCluster.spec.ingress.hostname` → `nkp open dashboard`.
- `--control-plane-external-endpoint` → API server cert SAN + advertised endpoint.
- bastion (same VPC) → kind bootstrap (MTU 1442) → CAPI/CAPX → node VMs in the overlay subnet.
- management cluster (VLAN or transit VPC) → workload API **FIP/FQDN** → workload cluster in tenant VPC.
- transit VPC → shared registry / DNS / IdP / observability for all tenant VPCs.
- Pod CIDR/service CIDR ↮ VPC overlay CIDR: must not overlap, in either direction.
- Flow VN (infra) ⟂ Flow CNI (pod network): different layers, opposite node-subnet requirements.

## Version deltas

| Version | Delta |
|---|---|
| TN-2207 **1.0** (January 2025) | Original publication. NKP 2.17-era; AOS/PC 7.5+, NC 7.0.0+. Two topologies (isolated/exposed). `[portal: TN-2207 Executive Summary]` |
| TN-2207 **2.0** (May 2026) | Adds **VLAN and VPC mixed deployment** and **transit VPC deployments** (shared control plane, per-tenant), plus the known-behaviours list. `[portal: TN-2207 Executive Summary]` |
| NKP 2.17 | First version in the tech note's supported range `[portal: TN-2207 Executive Summary]` |
| NKP 2.18 | Flow CNI 1.1.0 arrives (VLAN Basic nodes) — makes the VPC-vs-Flow-CNI distinction real `[raw 06]` |
| NKP 2.19 | Floating-IP flags confirmed in the shipped CLI: `--control-plane-external-endpoint`, `--cluster-hostname`, `--extra-sans` `[live: nkp-help-cluster.txt]`; PDF documents the 3-FIP UI recipe `[pdf p.721]`; MTU guidance for VPC subnets `[pdf p.711]` |

## Gaps / open questions

1. **Cilium DSR on a VPC overlay subnet** — no statement in TN-2207; test in the lab with a MetalLB VIP +
   FIP. Does `loadBalancer.mode: snat` change anything under NAT DNAT? `[N-02]`
2. **Flow VN licensing tier** for NKP in a VPC — the note defers to "software options". Confirm NCI Pro vs
   Ultimate and whether VPC creation needs PC size XL (Flow-CNI guide says XL).
3. **DNS requirement** — the note never states a resolver/DNS server requirement for the overlay. Does the
   overlay inherit the VPC's DHCP DNS, and must that resolve `<fip>` names or `<pc-fqdn>`?
4. **`--extra-sans` vs `--control-plane-external-endpoint`** — 2.19 accepts both; does the PDF's 3-FIP
   recipe still work as written, or is `--control-plane-external-endpoint` now the mandated path? Test the
   resulting API cert SANs.
5. **Object cleanup on `nkp delete cluster`** — do VPC/overlay subnet/FIPs survive? (assumed yes, unverified).
6. **Konnector/onboarding through a floating IP** — is `--onboard-to-prism-central=true` usable when PC is
   only reachable outbound over NAT? Assumed yes (outbound 9440), unverified.
7. **Node subnet as an overlay subnet + `--onboard-to-prism-central`**: does PC show the VM's overlay IP or
   nothing (PC sees the VNIC via Network Controller)? Unverified.
8. **NHIs / Network Controller VLAN subnets vs VPC overlay subnets for nodes** — NKP PDF only documents
   VLAN Basic → NC-VLAN migration `[pdf p.709-710]`; the PDF never says "use a VPC overlay subnet as the node
   subnet". Only TN-2207 does. Which one does Nutanix support officially for a *managed* cluster? `[N-02]`
9. **LoadBalancer + FIP automation** — every extra service needs a manual FIP. No CLI/annotation does this
   automatically. Consider documenting a runbook (`kubectl get svc -w` → create FIP → associate).
