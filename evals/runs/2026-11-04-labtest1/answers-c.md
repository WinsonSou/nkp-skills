# Answers, group c

## nkp-vpc V1

Skill files read:
- `nkp-skills/nkp/SKILL.md` (router)
- `nkp-skills/_shared/RULES.md`
- `nkp-skills/nkp-vpc/SKILL.md`
- `nkp-skills/nkp-vpc/references/layouts.md`
- `nkp-skills/nkp-install/SKILL.md`, `nkp-skills/nkp-install/references/nutanix.md`
- `ntnx-skills/nutanix-api/SKILL.md`, `ntnx-skills/nutanix-api/REFERENCE.md`
- `ntnx-skills/nutanix-networking/SKILL.md`, `ntnx-skills/nutanix-networking/RECIPES.md`

**2 floating IPs**, and you add **2 lines** to the create script.

Your answers fill the table of step 1 in `nkp-vpc` completely: the row "Management cluster, users outside the VPC, NAT external subnet" → layout **exposed**, and the operator host (bastion) is a VM in the same VPC, which sets the MTU work in step E.

| Floating IP | Address from | Points at |
|---|---|---|
| `FIP_API` | external subnet pool | `CP_VIP` (private-IP association) |
| `FIP_UI` | external subnet pool | the **first** IP of `LB_IP_RANGE` (Traefik keeps its IP from that range) |

Why not 3: the guide asks for a third, `--extra-sans` floating IP, but with `--control-plane-external-endpoint` the API certificate already holds the external endpoint's names [live 2.19.0], so a separate one gives nothing. A bastion floating IP only if people must reach the bastion itself from the corp LAN — you did not ask for that.

Why the UI IP must go through `FIP_UI`: `LB_IP_RANGE` is an overlay range, private to the VPC. Without `--cluster-hostname`, Traefik sends `/_oauth_kommander` with a 307 to the private LB IP and a corp-LAN browser cannot follow it [live 2.19.0].

**What you add to the create** (management cluster, script of `nutanix.md` N4A/N4B/N4C, before `"$@"`):

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
  --cluster-hostname "$UI_HOSTNAME" \
```

That is all. `--control-plane-external-endpoint` replaces the VIP in the CAPI `Cluster`, in kubeadm `controlPlaneEndpoint`, in `cluster-info`, in the Cilium `KUBERNETES_SERVICE_HOST` and in the kubeconfig, so the nodes and the corp LAN reach the API through `FIP_API`. kube-vip still holds `CP_VIP` in the overlay.

### What I need from you before any of this runs

Values I do not have (I write each line into the env file only after you confirm the value):

- cluster name for the env file: you said `nkp-a`, so `~/nkp-a.env`
- `CP_VIP`, `LB_IP_RANGE` (both in `tenant-a-nodes`, outside its IPAM pool)
- `FIP_API`, `FIP_UI` (addresses from the external subnet pool)
- `API_EXTERNAL_ENDPOINT` — `FIP_API` itself, or a DNS name with an A record to it
- `UI_HOSTNAME` — `FIP_UI` itself, or a DNS name with an A record to it
- the CIDR of `tenant-a` (and of every VPC the nodes route to) for the overlap check
- connected site or air-gapped with a mirror (selects N4A / N4B / N4C)

Not in the skills, so you ask the Prism Central admin: the Network Controller version. TN-2207 v2.0 needs Network Controller 7.0.0 or later and AOS/PC 7.5 or later [portal]; PC 7.5 is what you have.

### Step A — read what Prism Central already has

I run:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import sys
sys.path.insert(0, 'scripts')          # run from the nutanix-api skill folder
from ntnx import *
N = '/networking/v4.4/config'
print([(s['name'], s['subnetType'], s.get('isExternal'), s.get('isNatEnabled'))
       for s in list_all(f'{N}/subnets')])
for v in list_all(f'{N}/vpcs'):
    rt = next(r for r in list_all(f'{N}/route-tables') if r.get('vpcReference') == v['extId'])
    print(v['name'], v['extId'], v.get('externalSubnets'),
          [(r['destination']['ipv4']['ip']['value'] + '/' + str(r['destination']['ipv4']['prefixLength']),
            r['nexthop']['nexthopType']) for r in list_all(f"{N}/route-tables/{rt['extId']}/routes")])
print([(f['floatingIp']['ipv4']['value'], f.get('associationStatus'), f['extId'])
       for f in list_all(f'{N}/floating-ips')])
PY
```

What I expect, and what I do with it: `tenant-a` exists with one NAT external subnet, `tenant-a-nodes` is an `OVERLAY` subnet with IPAM on, and the VPC route table shows `0.0.0.0/0 EXTERNAL_SUBNET`. A VPC create adds **no** default route, so if that route is missing I add it as its own CHANGES step and stop for "yes". The floating IP list tells me which addresses are taken; the VPC `externalIps` (gateway addresses) are also taken.

### Step B — free-IP check for `CP_VIP` and `LB_IP_RANGE`

I run it **on the bastion** (it is in the VPC, so the ARP probe is valid on the overlay; from a corp-LAN host every address would look free):

I use the recipe "Free IP check for a VIP or an LB range" from `nutanix-networking/RECIPES.md` with `tenant-a-nodes` as the subnet and the addresses as the candidates:
`CP_VIP` plus every address of `LB_IP_RANGE`, from the first to the last.

```bash
# READ-ONLY
source ~/nkp-a.env 2>/dev/null
python3 - <<'PY'
import sys
sys.path.insert(0, 'scripts')          # run from the nutanix-api skill folder
from ntnx import *
# the helper block of that recipe, pasted above this call
for row in free_ip_check('tenant-a-nodes', [CP_VIP] + range_list(LB_IP_RANGE)):
    print(row)
PY
```

I need `holder` empty for each address and `arp FAILED`. `inPool: true` means IPAM can hand the address to a node, so reserve it first (recipe "Subnet IP reservations"). A named `holder` means take the next address.

### Step C — the two floating IPs (CHANGES, two separate plans)

Each one is one POST with `PrivateIpAssociation` (one call, result `ASSOCIATED_TO_PRIVATE_IP` [live 2.19.0]):

```python
post(f'{N}/floating-ips', {"$objectType": "networking.v4.config.FloatingIp", "name": "nkp-a-api",
  "floatingIp": {"$objectType": "networking.v4.config.FloatingIPAddress",
                 "ipv4": {"$objectType": "networking.v4.config.FloatingIPv4Address", "value": FIP_API}},
  "externalSubnetReference": ext_subnet_id,
  "association": {"$objectType": "networking.v4.config.PrivateIpAssociation", "vpcReference": vpc_id,
    "privateIp": {"$objectType": "common.v1.config.IPAddress",
      "ipv4": {"$objectType": "common.v1.config.IPv4Address", "value": CP_VIP, "prefixLength": 32}}}})
```

and the same with `FIP_UI` → first address of `LB_IP_RANGE`. Plan I show you: the address, the private IP it maps to, the VPC, and "this is a change in Prism Central, no cluster exists yet". I stop for "yes" before each. They must exist **before** the create: the nodes join through `FIP_API`.

### Step D — CIDR overlap check

```bash
# READ-ONLY  (needs python3)
source ~/nkp-site.env 2>/dev/null
vpc_cidrs=''; pod_cidr='192.168.0.0/16'; svc_cidr='10.96.0.0/12'
: "${vpc_cidrs:?}"
python3 -c 'import ipaddress,sys; k=[ipaddress.ip_network(c) for c in sys.argv[1:3]]; v=[ipaddress.ip_network(c.strip()) for c in sys.argv[3].split(",")]; bad=[(str(a),str(b)) for a in k for b in v if a.overlaps(b)]; print("OVERLAP", bad) if bad else print("no overlap")' "$pod_cidr" "$svc_cidr" "$vpc_cidrs"
```

I put your `tenant-a` CIDR into `vpc_cidrs`. On `OVERLAP` we pick free CIDRs together and add `--kubernetes-pod-network-cidr` / `--kubernetes-service-cidr`. Both are fixed at create time.

### Step E — operator host MTU (this one matters here)

A management create makes a **kind bootstrap cluster on the bastion**, and the bastion NIC in the VPC is MTU 1442. Docker at 1500 makes TLS to Prism Central fail during the bootstrap [portal]. I run:

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

I expect `nic <dev> mtu 1442`, and a bridge and kind MTU that are either 1442 or absent. If Docker says 1500, the fix is `layouts.md` L8: it edits `/etc/docker/daemon.json`, keeps a `.bak`, and **restarts Docker** (it stops the containers named in `running:`), so I show the plan and stop for "yes". `pc` must not print `000` (`302` is normal).

### Step F — the create, then the check

I write `~/nkp-a-create.sh` (case N4A / N4B / N4C as you answer), with the two VPC lines added, then the dry run, then the create after your "yes" (management: `--timeout 60m`, 22–24 min). The dry-run check I show you:

```bash
# READ-ONLY
source ~/nkp-a.env 2>/dev/null
grep -n -E '^ +host:|^ +address:|^ +hostname:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

`host:` must show `API_EXTERNAL_ENDPOINT`, `address:` must show `CP_VIP`, and (management cluster) a `hostname:` line must show `UI_HOSTNAME`.

Then the VPC part of step 5:

```bash
# READ-ONLY
source ~/nkp-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}api={.value.nutanix.controlPlaneEndpoint.host} vip={.value.nutanix.controlPlaneEndpoint.virtualIP.configuration.address}{"\n"}{end}ui={.spec.kommanderCluster.spec.ingress.hostname}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get svc kommander-traefik -o jsonpath='traefik={.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" config view --minify -o jsonpath='server={.clusters[0].cluster.server}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
curl -sk -o /dev/null -m 10 -w 'api %{http_code}\n' "https://${API_EXTERNAL_ENDPOINT:-$CP_VIP}:6443/version"
curl -sk -o /dev/null -m 10 -w 'ui %{http_code}\n' "https://${UI_HOSTNAME:-${LB_IP_RANGE%%-*}}/dkp/kommander/dashboard"
```

Done when: `api=` is `API_EXTERNAL_ENDPOINT`, `vip=` is `CP_VIP`, `server=` uses `API_EXTERNAL_ENDPOINT`, `traefik=` is an IP of `LB_IP_RANGE`, every node is `Ready` on an overlay IP, `api 200`, `ui=` is `UI_HOSTNAME` and `ui 302`.

One warning: **UNKNOWN (N-02)** — a management create in a VPC (kind bootstrap on a host with MTU 1442) is not tested; the exposed *workload* create is [live 2.19.0]. If the bootstrap fails on TLS to Prism Central, that is the reason to check step E first, then `nkp delete bootstrap` and create again.

I stop here: after step A/B/D/E output, after the plan for each floating IP (need "yes"), and after the dry-run lines (need "yes" for the create).

---

## nkp-vpc V4

Skill files read:
- `nkp-skills/nkp/SKILL.md`
- `nkp-skills/nkp-vpc/SKILL.md`, `nkp-skills/nkp-vpc/references/layouts.md`
- `nkp-skills/nkp-cluster-lifecycle/SKILL.md`, `nkp-skills/nkp-cluster-lifecycle/references/delete.md`
- `nkp-skills/nkp-storage-backup/SKILL.md`, `nkp-skills/nkp-storage-backup/references/csi.md`
- `ntnx-skills/nutanix-api/SKILL.md`, `ntnx-skills/nutanix-api/REFERENCE.md`
- `ntnx-skills/nutanix-nkp/SKILL.md`, `ntnx-skills/nutanix-nkp/RECIPES.md`
- `ntnx-skills/nutanix-storage/SKILL.md`, `ntnx-skills/nutanix-storage/RECIPES.md`
- `ntnx-skills/nutanix-networking/SKILL.md`, `ntnx-skills/nutanix-networking/RECIPES.md`

Two different things stay in Prism Central: the **volume groups** (they always stay) and the **VPC objects** (floating IPs, overlay subnet, VPC — NKP deletes none of them). "Nothing left" therefore has two lists, and they need two approvals.

I use `~/nkp-tenant-b-dev.env`. If that file does not exist, tell me where `CLUSTER_NAME`, `WORKSPACE_NS`, `CLUSTER_KUBECONFIG`, `MGMT_KUBECONFIG`, `VPC_NAME`, `SUBNET`, `CP_VIP`, `LB_IP_RANGE`, `FIP_API`, `FIP_API_ID` are recorded — without them the delete and the floating-IP delete cannot run.

### 1. Identify the cluster (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host,PHASE:.status.phase,CP:.spec.capiCluster.topology.controlPlane.replicas'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
```

I expect one row for `tenant-b-dev` in a workspace namespace (not `kommander`) with no `MGMT true`. A row with namespace `kommander` or `MGMT true` means this is a management cluster: then I stop and we talk again, because the file for that is D4.

### 2. Safety gate (READ-ONLY)

Run from the folder of the create.

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,SIZE:.spec.capacity.storage,HANDLE:.spec.csi.volumeHandle'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nkpclusters -A
```

The PV list is the input of step 5: each `HANDLE` is `NutanixVolumes-<uuid>` and that `<uuid>` **is** the Prism Central volume-group `extId` [live 2.19.0]. The LB list is the input of step 4. The last command must give `the server doesn't have a resource type "nkpclusters"` or `No resources found`; a list of NKPClusters means this cluster manages other clusters and we delete those first.

### 3. Record the VPC objects before the delete (READ-ONLY)

This must run **before** the delete and before the local file cleanup, because the cleanup deletes the env file that holds the extIds.

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
echo "cluster=$CLUSTER_NAME vpc=$VPC_NAME subnet=$SUBNET vip=$CP_VIP lb=$LB_IP_RANGE"
echo "fip_api=$FIP_API id=$FIP_API_ID fip_ui=$FIP_UI id=$FIP_UI_ID"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o name
```

Workload cluster, so `FIP_UI`/`FIP_UI_ID` are empty by design. Keep this output in the run log.

### 4. The delete plan, then the delete

Plan I show you:
1. `nkp delete cluster --cluster-name tenant-b-dev --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m` on the management cluster.
2. What goes: all nodes and VMs, all pods, every `LoadBalancer` Service from step 2, the NKPCluster, and **all data in the PVCs of the cluster** [pdf p.814][live 2.19.0].
3. What stays: one volume group per PV (with its data) until step 5, the mirror Secrets `tenant-b-dev-oci-cert` and `tenant-b-dev-oci-creds`, the VPC objects, and the local files.
4. Approval: you type **`yes` and the exact cluster name** `tenant-b-dev` in one message. A bare "yes" is not enough for a delete.

```bash
# CHANGES  (deletes the workload cluster tenant-b-dev: its VMs, nodes, and data; cannot be undone)
source ~/nkp-tenant-b-dev.env 2>/dev/null
nkp delete cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m
```

Expected: three steps, `INF Deleted <namespace>/tenant-b-dev cluster`, RC 0, under a minute or two. If a PVC holds data you still need, say so now: backup is skill `nkp-storage-backup`, `velero.md` B3.

### 5. Check the delete, then the Prism Central audit (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters,clusters.cluster.x-k8s.io,machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME"
```

Done when both show no object. From the VLAN bastion you cannot reach `CP_VIP` (VPC private), so the `ping`/`curl` check of D3 proves nothing here; the floating IPs are the proof, and they will answer `000` until step 6 — that is normal, not a fault [live 2.19.0].

Then the full leftover audit:

I run `audit('tenant-b-dev')` — the recipe "Leftover audit for a cluster" of `nutanix-nkp/RECIPES.md`, pasted into a python block above this call — and print it as JSON:

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
python3 - <<'PY'
import sys, json
sys.path.insert(0, 'scripts')          # run from the nutanix-api skill folder
from ntnx import *
# audit() from the recipe, pasted above this call
print(json.dumps(audit('tenant-b-dev'), indent=1, default=str))
PY
```

I read the result like this: `VMs` must be 0 (a row means the delete failed, or another cluster owns that name prefix — the prefix also matches `tenant-b-dev-2`); `volume_groups` is **expected** non-zero; `floating_ips` and `ip_reservations` and `categories` are the rows we handle below; `floating_ips_unnamed` holds bulk-created FIPs named `fip-dummy-name`, which cannot be attributed — I only show them as candidates when they hold a private IP, and you confirm.

### 6. Floating IPs (CHANGES)

Plan: the addresses and extIds of `FIP_API` (and `FIP_UI` if the file has one), plus one floating IP for each `LoadBalancer` Service that outside users needed (for a workload cluster the Traefik IP, if you gave it one). For each: read it by extId and check its address, `PUT` it without `association` (`ASSOCIATED_TO_PRIVATE_IP` → `NOT_ASSOCIATED`), then `DELETE` with the fresh ETag. A direct delete of an associated FIP is not the operation. ~6 s each.

```python
F = f'{N}/floating-ips/{fip_id}'
o, etag = get(F); assert o['floatingIp']['ipv4']['value'] == expected_address
o.pop('association', None); put(F, o, etag)
delete(F, get(F)[1]); get(F)          # expect 404
```

I stop for "yes" on the exact list before the first call. Done when a read by extId gives 404. Do not delete a floating IP that another cluster in that VPC uses.

### 7. Volume groups (CHANGES, only when the step 2 PV list was not empty)

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
python3 - <<'PY'
import sys
sys.path.insert(0, 'scripts')          # run from the nutanix-api skill folder
from ntnx import *
G = '/volumes/v4.3/config/volume-groups'

def entries(g):
    d = g.get('description') or ''
    if 'K8sClusterID' not in d or ' for ' not in d:
        return None
    field = lambda k: next((p.split(':', 1)[1] for p in d.split(', ') if p.startswith(k + ':')), None)
    return d.split(' for ', 1)[1].split(',', 1)[0], field('PVC'), field('NS')

for g in list_all(G):
    if g.get('isHidden') or g.get('usageType') == 'INTERNAL':
        continue
    e = entries(g)
    if not e or e[0] != 'tenant-b-dev':
        continue
    att = req(f"{G}/{g['extId']}/vm-attachments")[2].get('data') or []
    print(g['name'], g['extId'], e[1], e[2], g.get('sizeInBytes'), [a.get('extId') for a in att])
PY
```

The rule: keep a group only when the description has `K8sClusterID` **and** `for tenant-b-dev,` (with the comma, so `tenant-b-dev-2` never matches) and `GET /volume-groups/{extId}/vm-attachments` is empty. Never a group with `isHidden: true` or `usageType: INTERNAL` — those 11 on a lab PC belong to Prism Central itself.

Measurement to set your expectation: a workload cluster with PVCs leaves **4** groups, without PVCs **0** [live 2.19.0].

Plan I show you: the count, and for each group the name, extId, PVC and namespace, plus "the delete destroys that PVC data". I stop for "yes". Then per group the delete recipe (`$actions/detach-vm` for anything still attached, assert `vm-attachments` empty, `delete` with the fresh ETag). Done when `nkp_leftovers` returns nothing and each extId gives 404. Also check the recovery points (the `nutanix-snapshot-class` has `deletionPolicy: Retain`, so snapshots stay).

### 8. Overlay subnet, VPC, route table — your decision, not the delete's

These are site objects: the bastion, another tenant, or the next cluster in that VPC can use them. A cluster delete never means a subnet or VPC delete. So I ask: does the site still need `tenant-b-dev`'s VPC and its overlay subnet?

- yes (recommended when the VPC is reusable): keep both. `CP_VIP` and `LB_IP_RANGE` are free again in the overlay subnet.
- no: plan, stop for "yes", delete the **overlay subnet first**, then the VPC (its route table goes with it). The external subnet is never deleted: other VPCs use it.

### 9. Operator host files last (CHANGES)

After step 6 and 7, because they read names from the env file. First the exact-name list (READ-ONLY, no `*`), then the delete of those files plus `~/nkp-tenant-b-dev.env`, and the two mirror Secrets `tenant-b-dev-oci-cert` / `-oci-creds` in the workspace namespace (they are not in the VPC, they are on the management cluster, and they stay after a delete).

Ordering summary: record → delete cluster → check → audit → floating IPs → volume groups → VPC objects (your call) → local files.

I stop at: the step 2 facts (if a PVC matters, or the cluster manages others), the step 4 plan, the step 6 plan, the step 7 plan, and the step 8 question.

---

## nkp-vpc V7

Skill files read:
- `nkp-skills/nkp/SKILL.md`
- `nkp-skills/nkp-vpc/SKILL.md`, `nkp-skills/nkp-vpc/references/layouts.md`
- `nkp-skills/nkp-install/SKILL.md`, `nkp-skills/nkp-install/references/nutanix.md`
- `nkp-skills/nkp-identity-security/references/rbac.md` (workspaces, R5)
- `ntnx-skills/nutanix-api/SKILL.md`, `ntnx-skills/nutanix-api/REFERENCE.md`
- `ntnx-skills/nutanix-networking/SKILL.md`, `ntnx-skills/nutanix-networking/RECIPES.md`

This is the **mixed** layout: management cluster on the enterprise VLAN, one VPC per tenant, workload cluster created from the management cluster in its workspace namespace. You need **1 floating IP** (`FIP_API` → `CP_VIP`) and **no** `--cluster-hostname` (it has no effect on a workload cluster). The management cluster needs nothing new for itself.

Here is the list, in the order the work goes.

### A. In Prism Central (that tenant's VPC)

1. An external subnet with "External Connectivity for VPCs", NAT or no-NAT. Ask the network team which; it changes only whether outside hosts need floating IPs.
2. A VPC for team X on that external subnet. **A VPC create adds no default route** — add `0.0.0.0/0` → `EXTERNAL_SUBNET` in its route table, or the nodes have no outside path.
3. An overlay subnet in the VPC with IPAM on. That is this cluster's `SUBNET`. Leave free addresses outside its pool for `CP_VIP` and `LB_IP_RANGE`.
4. One floating IP from the external subnet pool, associated in the same call to `CP_VIP` as a **private-IP** association (kube-vip owns that address; no NIC does). **Before** the create: the nodes and the management cluster join through it.
5. Free-IP proof for `CP_VIP` and each `LB_IP_RANGE` address. Run the ARP probe **on a host inside that VPC** (an existing VM there) — from the VLAN bastion every address looks free.
6. Reachability from the overlay: Prism Central on TCP 9440, the registry on TCP 443.

### B. On the management cluster

7. A workspace for team X. Workspace management needs **Ultimate** [pdf p.27] — check the tier (`kubectl -n kommander get licenses... status.dkpLevel`). `WORKSPACE_NS` is the **WORKSPACE NAMESPACE** column (`nkp create workspace team-x` makes `<ws>-<5 random chars>`), never `team-x`.
8. The management cluster's CAPI controllers must reach Prism Central **and** the new cluster's `FIP_API`. TN-2207 says "register them by floating IP or FQDN" [portal]. On a live lab, a VLAN management cluster with no route to the overlay created a VPC workload cluster through `FIP_API` alone, RC 0 in 13 min [live 2.19.0]; from the VLAN bastion `CP_VIP` answered `000` and `FIP_API` answered `200`.

### C. The env file `~/nkp-team-x.env`

Its own `CP_VIP` and `LB_IP_RANGE` (each cluster needs its own, both in the overlay subnet, outside its pool), `WORKSPACE_NS`, and — because this subnet is not the site subnet — `SUBNET` here, **not** in `~/nkp-site.env`. `PE_CLUSTER` and `STORAGE_CONTAINER` stay the site values (you said same PE cluster), so you do not repeat them. Also `VPC_NAME`, `FIP_API`, `FIP_API_ID`, `API_EXTERNAL_ENDPOINT`. The file's first line is `source ~/nkp-site.env 2>/dev/null`.

I write those lines only after you confirm each value; I need: the cluster name (must be `a-z 0-9 . -`), `CP_VIP`, `LB_IP_RANGE`, `FIP_API` + its extId, `API_EXTERNAL_ENDPOINT` (the FIP, or a DNS name with an A record), the overlay subnet name, the VPC name, and the workspace namespace.

### D. The create (workload cluster, `nutanix.md` N5)

One extra line in the N5 script and nothing else:

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
```

No `--self-managed` (the management cluster creates it), no `--cluster-hostname`, no MTU work on the Docker side (a workload create makes no kind cluster — run only the `pc` and `registry` curl lines of step 3).

Then the usual: N2 env check → write script (CHANGES, files only) → dry run (CHANGES, writes `~/…-dryrun.yaml`, holds 5 Secrets, never printed) → your "yes" → create in tmux (`3–13 min`) → `nkp get kubeconfig` for the mandatory workload kubeconfig → verify.

### E. Things that will surprise the team

- No UI: on a workload cluster `/dkp/kommander/dashboard` is 404, and `--cluster-hostname` is silently dropped [live 2.19.0]. Team X uses kubectl against `API_EXTERNAL_ENDPOINT`, and the NKP UI is at the management cluster.
- Overlay NIC MTU 1442, pod route MTU 1392 [live 2.19.0][pdf p.711]. Anything the team runs that assumes 1500 bytes needs its own check.
- Pod CIDR `192.168.0.0/16` and service CIDR `10.96.0.0/12` must not overlap any VPC range the nodes route to. I run the overlap check with that VPC's CIDR before the create.
- A VM in a VPC cannot also hold a plain VLAN NIC [field]. If team X needs the enterprise VLAN too, that is a transit VPC design (`layouts.md` L2), not this cluster.
- `CP_VIP` is not in the API certificate names; use `API_EXTERNAL_ENDPOINT` for TLS.
- Another outside `LoadBalancer` Service of that cluster needs one more floating IP (step 6 of `nkp-vpc`).

I stop here: I need the values in section C, the workspace namespace, and the Ultimate-tier answer before I write anything.

---

## nkp-vpc V8

Skill files read:
- `nkp-skills/nkp/SKILL.md`
- `nkp-skills/nkp-vpc/SKILL.md`, `nkp-skills/nkp-vpc/references/layouts.md`
- `nkp-skills/nkp-install/SKILL.md`, `nkp-skills/nkp-install/references/nutanix.md`
- `ntnx-skills/nutanix-api/SKILL.md`, `ntnx-skills/nutanix-api/REFERENCE.md`
- `ntnx-skills/nutanix-networking/SKILL.md`, `ntnx-skills/nutanix-networking/RECIPES.md`

Rule of the env files: **one file per cluster**, each holding that cluster's own values, and the overlay `SUBNET` goes in the **cluster** file, never in `~/nkp-site.env` — the management cluster and team-x use the site file, and changing it would break them. The cluster file sources the site file first, so its lines win for that cluster only.

### What stays as it is

`~/nkp-site.env` — no change. It keeps `MGMT_KUBECONFIG`, `PC_ENDPOINT`, `PE_CLUSTER`, `STORAGE_CONTAINER`, `VM_IMAGE`, `SSH_PUBKEY_FILE`, `NTP_SERVERS`, the registry values, `SUBNET` (the **VLAN** subnet of `nkp-mgmt`), and the secrets.

`~/nkp-team-x.env` — already correct for `vpc-x`; nothing to do. The keys it holds, and the only ones that are per-cluster:

`CLUSTER_NAME`, `WORKSPACE_NS`, `SUBNET` (the overlay subnet in `vpc-x`, **not** the VLAN one), `VPC_NAME`, `CP_VIP`, `LB_IP_RANGE`, `FIP_API`, `FIP_API_ID`, `API_EXTERNAL_ENDPOINT`, `CLUSTER_KUBECONFIG`.

You did not give team-x's own numbers in this turn, so I do not rewrite that file. The check that it is right, without printing any value:

```bash
# READ-ONLY
source ~/nkp-team-x.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS SUBNET VPC_NAME CP_VIP LB_IP_RANGE FIP_API FIP_API_ID API_EXTERNAL_ENDPOINT CLUSTER_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
echo "subnet is the overlay: $( [ "$SUBNET" = "$(source ~/nkp-site.env 2>/dev/null; echo "$SUBNET")" ] && echo NO || echo yes )"
```

If that last line prints `NO`, team-x is still on the VLAN subnet and I show the append for it.

### The new file for team-y

1. Make it (CHANGES, writes one file with mode 600):

```bash
# CHANGES  (makes the cluster env file ~/nkp-team-y.env with mode 600 if it does not exist)
test -e ~/nkp-team-y.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-team-y.env); }
```

2. The lines that belong in `~/nkp-team-y.env`, from the values you gave me and the ones I still need. Plan only — I append each line in a later reply, after you confirm the value (rule 4):

| Variable | Value | Status |
|---|---|---|
| `CLUSTER_NAME` | `team-y` (your name for the cluster? confirm the exact name) | confirm |
| `VPC_NAME` | `vpc-y` | given |
| `SUBNET` | `vpc-y-nodes` (the overlay subnet) | given |
| `WORKSPACE_NS` | the **WORKSPACE NAMESPACE** column for team-y's workspace | needed |
| `CP_VIP` | a free address in `vpc-y-nodes`, outside its IPAM pool | needed |
| `LB_IP_RANGE` | a free range in `vpc-y-nodes`, outside its IPAM pool | needed |
| `FIP_API` | one address from the `vpc-y` external subnet pool | needed |
| `FIP_API_ID` | its extId (the delete in `nkp-vpc` step 7 needs it) | needed |
| `API_EXTERNAL_ENDPOINT` | `FIP_API`, or a DNS name with an A record to it | needed |

`PE_CLUSTER` and `STORAGE_CONTAINER` you do **not** put in the file: same PE cluster, so the site values are correct [rule of step 2]. `MGMT_KUBECONFIG` also comes from the site file.

The append form, once you confirm (CHANGES, one line per value, last line wins):

```bash
# CHANGES  (appends values to ~/nkp-team-y.env)
echo "export VPC_NAME='vpc-y'" >> ~/nkp-team-y.env
echo "export SUBNET='vpc-y-nodes'" >> ~/nkp-team-y.env
```

### Why the two files must differ in these four keys

`CP_VIP`, `LB_IP_RANGE`, `SUBNET` and `WORKSPACE_NS` are per-cluster. Everything else is site-wide. `VPC_NAME`, `FIP_API`, `FIP_API_ID`, `API_EXTERNAL_ENDPOINT` differ too, because each VPC has its own floating IP: a floating IP belongs to exactly one VPC [portal].

Overlay CIDRs **may** overlap between `vpc-x` and `vpc-y` — the VPCs are separate. What must **not** overlap is the pod CIDR (`192.168.0.0/16`) and service CIDR (`10.96.0.0/12`) of each cluster against every VPC range that cluster's nodes route to. I run the overlap check with `vpc-y`'s CIDR before the create.

### Order for team-y

1. Check the file: N2 block for case "5 mirror" (prints `set:`/`MISSING:` per name, never a value).
2. Prism Central: the `vpc-y` default route `0.0.0.0/0` → its external subnet (a VPC create adds none), and 1 floating IP `FIP_API` → `CP_VIP` as a private-IP association, **before** the create.
3. Free-IP proof for `CP_VIP` and `LB_IP_RANGE` from a host inside `vpc-y` (not the VLAN bastion).
4. Write `~/nkp-team-y-create.sh` from `nutanix.md` N5 plus the one line `--control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT"`, no `--cluster-hostname`.
5. Dry run, show the `host:` / `address:` lines, then create after "yes", then `nkp get kubeconfig`.

I stop here: I need `CP_VIP`, `LB_IP_RANGE`, `FIP_API`, `FIP_API_ID`, `API_EXTERNAL_ENDPOINT`, the workspace namespace, and confirmation of the exact cluster name.

---

## nkp-vpc V9

Skill files read:
- `nkp-skills/nkp/SKILL.md`
- `nkp-skills/nkp-vpc/SKILL.md`, `nkp-skills/nkp-vpc/references/layouts.md`
- `nkp-skills/nkp-install/SKILL.md`, `nkp-skills/nkp-install/references/nutanix.md`
- `nkp-skills/nkp-identity-security/references/rbac.md` (R5 workspaces)
- `ntnx-skills/nutanix-api/SKILL.md`, `ntnx-skills/nutanix-api/REFERENCE.md`
- `ntnx-skills/nutanix-networking/SKILL.md`, `ntnx-skills/nutanix-networking/RECIPES.md`

### How many floating IPs

**1: `FIP_API` → `CP_VIP`.** Workload cluster in a VPC, management cluster outside it, exposed layout, NAT external subnet.

- kubectl needs the API only, so no second floating IP.
- No `FIP_UI`: a workload cluster has no NKP UI (`/dkp/kommander/dashboard` is 404).
- Add one more floating IP for each `LoadBalancer` Service that outside users need (for example if you later want the workload Traefik reachable). kubectl alone does not need one.

It must exist **and** be associated before the create: the nodes and the management cluster join through it.

### Which create flags

Base: the N5 workload script of `nutanix.md`. Added:

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
```

and nothing else from the VPC skill:

- **not** `--cluster-hostname` — a workload create accepts it and drops it; no object holds the name [live 2.19.0].
- **not** `--self-managed`.
- `--namespace "$WORKSPACE_NS"` — which is the **WORKSPACE NAMESPACE** column for workspace `team-z-ws` (`nkp create workspace team-z-ws` makes something like `team-z-ws-7kr7h`), **not** the workspace name. Never put `team-z-ws` in `WORKSPACE_NS`.
- The registry mirror flags come from the site file as usual; MTU lines are not needed (no kind bootstrap for a workload create).

Before the create: the workspace must exist (workspace management needs Ultimate), `vpc-z` must have the default route `0.0.0.0/0` → its external subnet (a VPC create adds none), `CP_VIP` and `LB_IP_RANGE` must be free addresses in the overlay outside its IPAM pool (ARP probe from a host inside `vpc-z` — from your VLAN bastion every address looks free), and your pod/service CIDRs must not overlap `vpc-z`.

### How to check it after the create

```bash
# READ-ONLY
source ~/nkp-team-z.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}api={.value.nutanix.controlPlaneEndpoint.host} vip={.value.nutanix.controlPlaneEndpoint.virtualIP.configuration.address}{"\n"}{end}ui={.spec.kommanderCluster.spec.ingress.hostname}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get svc kommander-traefik -o jsonpath='traefik={.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" config view --minify -o jsonpath='server={.clusters[0].cluster.server}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
curl -sk -o /dev/null -m 10 -w 'api %{http_code}\n' "https://${API_EXTERNAL_ENDPOINT:-$CP_VIP}:6443/version"
curl -sk -o /dev/null -m 10 -w 'ui %{http_code}\n' "https://${UI_HOSTNAME:-${LB_IP_RANGE%%-*}}/dkp/kommander/dashboard"
```

What proves it, and what is normal [live 2.19.0]:

| Line | Expected | If not |
|---|---|---|
| `api=` | `API_EXTERNAL_ENDPOINT` (not `CP_VIP`) | the create flag is missing |
| `vip=` | `CP_VIP` | wrong env value |
| `server=` | uses `API_EXTERNAL_ENDPOINT` | kubeconfig is the old one, rerun `nkp get kubeconfig` |
| `traefik=` | an IP of `LB_IP_RANGE`, usually the first | MetalLB pool or advertisement: `nkp-networking`, `metallb.md` M1 |
| nodes | all `Ready`, overlay IPs, not in sequence | CNI/join: the FIP association, or `nkp-troubleshooting` |
| `api 200` | yes | `000` = no answer: `FIP_API` not associated to `CP_VIP`, or no route |
| `ui=` and `ui` | `ui=` empty and `ui` 404 or `000` | **this is normal for a workload cluster** |

`UI_HOSTNAME` and `FIP_UI` are not values of a workload cluster, so the `ui` line falls back to the first IP of `LB_IP_RANGE` — that is the Service IP, not a hostname.

From your VLAN bastion, `CP_VIP` answers `000` and `FIP_API` answers `200` — the private overlay is not routable from the VLAN. That is the expected asymmetry, not a fault.

Also confirm: `nkp describe cluster` shows `Machine/` rows `READY True`, the NKPCluster PHASE is `Reconciled` (30–40 min after the create is normal), and the workspace namespace of `team-z-ws` is where all of this lives.

I stop here: I need `CP_VIP`, `LB_IP_RANGE`, `FIP_API` + extId, `API_EXTERNAL_ENDPOINT`, the workspace namespace for `team-z-ws`, the cluster name for the env file, and the `vpc-z` CIDR for the overlap check.

---

## nkp-storage-backup S5

Skill files read:
- `nkp-skills/nkp/SKILL.md`
- `nkp-skills/nkp-storage-backup/SKILL.md`, `nkp-skills/nkp-storage-backup/references/csi.md` (C10)
- `nkp-skills/nkp-cluster-lifecycle/references/delete.md` (D5.2)
- `ntnx-skills/nutanix-api/SKILL.md`, `ntnx-skills/nutanix-api/REFERENCE.md`
- `ntnx-skills/nutanix-storage/SKILL.md`, `ntnx-skills/nutanix-storage/RECIPES.md`
- `ntnx-skills/nutanix-nkp/RECIPES.md` ("Leftover audit for a cluster")

Yes — they are almost certainly still there. `nkp delete cluster` deletes the node VMs and their disks, removes the volume groups' VM attachments, and **keeps every Nutanix CSI volume group** of a PVC, user and platform. Measured: 4 groups after a workload cluster that had PVCs, 0 after one that had none [live 2.19.0]. So: `test-07` had PVCs → expect about 4 groups; no PVCs → expect none and this stays empty.

Find them with the leftover recipe (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import sys
sys.path.insert(0, 'scripts')          # run from the nutanix-api skill folder
from ntnx import *
G = '/volumes/v4.3/config/volume-groups'

def entries(g):
    """(cluster, pvc, ns) from a CSI volume-group description, or None."""
    d = g.get('description') or ''
    if 'K8sClusterID' not in d or ' for ' not in d:
        return None
    cluster = d.split(' for ', 1)[1].split(',', 1)[0]
    field = lambda k: next((p.split(':', 1)[1] for p in d.split(', ') if p.startswith(k + ':')), None)
    return cluster, field('PVC'), field('NS')

rows = []
for g in list_all(G):
    if g.get('isHidden') or g.get('usageType') == 'INTERNAL':
        continue                                   # the Prism Central groups
    e = entries(g)
    if not e or e[0] != 'test-07':
        continue
    att = req(f"{G}/{g['extId']}/vm-attachments")[2].get('data') or []
    rows.append({'name': g['name'], 'extId': g['extId'], 'pvc': e[1], 'ns': e[2],
                 'size': g.get('sizeInBytes'), 'attached': [a.get('extId') for a in att]})
for r in rows:
    print(r)
print('count', len(rows))
PY
```

How to read it:

- One row per volume group; `extId` is the group id, and it is also the `<uuid>` in the PV handle `NutanixVolumes-<uuid>`. `pvc` and `ns` come from the CSI description (`… CSI StorageClass nutanix-volume for test-07, PVC:<pvc>, NS:<ns> …`).
- `attached` empty = nobody holds it, which is the normal state after a delete. A non-empty `attached` means the VMs still exist: the delete failed, so this is not a leftover and we look at the VMs first (`nutanix-nkp` "Leftover audit", `VMs` row).
- Groups with `isHidden: true` or `usageType: INTERNAL` are skipped on purpose: those are Prism Central's own (11 on a lab PC). Never delete them.
- The match is on `for test-07,` **with the comma**, so a group of `test-07-old` or `test-07b` never shows up. If a row looks like it belongs to another cluster, say so before we touch it.

For the whole picture of that cluster (VMs, floating IPs, IP reservations, categories — not only the volumes), run `nutanix-nkp` RECIPES.md "Leftover audit for a cluster" with `audit('test-07')`; it prints a count per kind and the rows.

Two things before any delete:

1. **The data in those groups is the PVC data, and a delete destroys it.** Tell me if any of it matters; a Velero restore or a copy is a separate job (`nkp-storage-backup`, `velero.md`).
2. The **recovery points** are separate objects. `nutanix-snapshot-class` has `deletionPolicy: Retain`, so snapshots survive a `VolumeSnapshot` delete and they do not disappear when we delete the groups.

When you say "yes" to the exact list (name, extId, PVC, ns, size), the delete is the `nutanix-storage` recipe "Delete a volume group": detach any VM (`$actions/detach-vm`), assert `vm-attachments` is empty, `delete` with the fresh ETag (`:NA==`-style ETags are valid), then `get` must give 404. Done when the list above prints `count 0`.

I stop here: I need your "yes" on the list that the block prints. It is a delete; it cannot be undone.

---

## nkp-storage-backup S10

Skill files read:
- `nkp-skills/nkp/SKILL.md`
- `nkp-skills/nkp-storage-backup/SKILL.md`, `nkp-skills/nkp-storage-backup/references/csi.md` (C12)
- `nkp-skills/nkp-networking/references/metallb.md` (M1)
- `nkp-skills/nkp-airgap/SKILL.md`, `nkp-skills/nkp-airgap/references/nodes.md` ("Check that the site mirror has an image")
- `ntnx-skills/nutanix-api/SKILL.md` (for the volume-group follow-up)

One correction first, because it decides whether this works at all: **on an air-gapped site there is no "normal nginx image".** On the 2.19.0 lab mirror `docker.io/library/nginx` gives **404**; the bundle has `docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine`, which runs as non-root on port **8080** [live 2.19.0]. So the test uses that image plus a busybox init container (`docker.io/library/busybox:1`). We prove both exist in your mirror before the manifest is written; I never guess an image path and never pull from the internet.

Cluster `wl-05` → `~/nkp-wl-05.env`.

### Step 1 — read the state (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-wl-05.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u | grep -E 'nginx|busybox'
```

I expect exactly one `(default)` StorageClass `nutanix-volume` on AHV, one IPAddressPool with a free IP, and `kommander-traefik` holding the first IP. The last line is only a cross-check of names already on the cluster.

### Step 2 — prove the mirror has the two images (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
repo=''; : "${repo:?set repo, for example library/busybox}"
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"; p="${h#"$host"}"; p="${p#/}"; p="${p:+$p/}"
url="https://$host/v2/$p$repo/tags/list"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file /dev/stdin -w '\nhttp=%{http_code}\n' "$url" <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD"
```

I run it three times: `repo='library/nginx'` (I expect `http=404` — that is why we do not use it), `repo='nginxinc/nginx-unprivileged'` (expect `200`, tag `1.29.5-alpine`), `repo='library/busybox'` (expect `200`, tag `1`). `401` is a wrong pull account, `x509` a wrong `REGISTRY_CA_FILE`. If a name is not there, the fix is another image from a pushed bundle or `nkp create bundle` — not a network pull.

### Step 3 — the namespace and the manifest (CHANGES, one plan)

I need a new namespace name from you (`ns`). Plan I show you: cluster `wl-05`, namespace `<ns>`, file `$PWD/wl-05-smoke.yaml`, a 1 GiB PVC on the default class, one pod, one `LoadBalancer` Service (80 → 8080), one pool IP, expected results of step 4, and the removal in step 5. After your "yes":

```bash
# CHANGES  (writes the smoke test file on the operator host; changes no cluster)
source ~/nkp-wl-05.env 2>/dev/null
web_img=''; web_tag=''; init_img=''; init_tag=''
: "${web_img:?}" "${web_tag:?}" "${init_img:?}" "${init_tag:?}"
cat > "$PWD/$CLUSTER_NAME-smoke.yaml" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: smoke-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: smoke
  labels:
    app: smoke
spec:
  initContainers:
  - name: seed
    image: docker.io/$init_img:$init_tag
    command: ["sh", "-c", "echo smoke test $CLUSTER_NAME > /data/index.html"]
    volumeMounts:
    - name: data
      mountPath: /data
  containers:
  - name: web
    image: docker.io/$web_img:$web_tag
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: smoke-data
---
apiVersion: v1
kind: Service
metadata:
  name: smoke-lb
spec:
  type: LoadBalancer
  selector:
    app: smoke
  ports:
  - port: 80
    targetPort: 8080
EOF
```

The file deliberately holds no `Namespace` object — with one in it the dry run fails on the later objects (`namespaces "…" not found`) [live 2.19.0]. Next block makes the namespace first. Its "yes" is the one from this plan:

```bash
# CHANGES  (creates the namespace, the PVC, the pod, and the LoadBalancer Service)
source ~/nkp-wl-05.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" create namespace "$ns"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-smoke.yaml" && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" apply -f "$PWD/$CLUSTER_NAME-smoke.yaml"
```

`web_img` / `web_tag` / `init_img` / `init_tag` stay empty with their `:?` guards until step 2 prints the paths and tags that your mirror actually has, and you confirm them. On the 2.19.0 bundle they are `nginxinc/nginx-unprivileged` `1.29.5-alpine` and `library/busybox` `1`; if step 2 shows another tag, the tag changes, not the path.

### Step 4 — the proof (READ-ONLY)

The operator host must be on the Layer 2 subnet of the nodes, or have a route to the pool.

```bash
# READ-ONLY
source ~/nkp-wl-05.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" wait --for=condition=Ready pod/smoke --timeout=5m
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pvc smoke-data
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,HANDLE:.spec.csi.volumeHandle' | grep -E "^NAME|$ns"
ip=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get svc smoke-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "ip=$ip"
curl -s --noproxy '*' --max-time 10 -o /dev/null -w 'http=%{http_code}\n' "http://$ip/"
curl -s --noproxy '*' --max-time 10 "http://$ip/"
```

Done when: the PVC is `Bound`, its PV handle is `NutanixVolumes-<uuid>` (that uuid is the Prism Central volume group), `ip=` is an IP of the pool, the first curl prints `http=200`, and the second prints `smoke test wl-05`. That one result proves the CSI, MetalLB and Cilium together. PVC `Bound` and pod `Running` took about 70 s on a live 2.19.0 workload cluster.

| What you see | Cause | Next |
|---|---|---|
| `wait` times out, PVC `Pending` | CSI or StorageClass | `SKILL.md` step 2 (`describe pvc`, CSI logs); `waiting for first consumer` alone is normal |
| `ErrImagePull` / `ImagePullBackOff` | the mirror lacks that image | step 2 again, or `nkp-airgap` |
| `ip=` empty | no free pool IP, or no advertisement | `metallb.md` M1 |
| `http=000` | no route from the operator host, ARP, or Cilium DSR | `metallb.md` M1 last row, `cni.md` C4 |
| `http=403` / `404` | nginx cannot read the file | `kubectl logs pod/smoke -c web` and `-c seed` |

### Step 5 — remove the test (CHANGES, separate plan)

Do it now, not before a future cluster delete: a delete keeps one volume group per PVC, so this leaves a group behind if you forget. Plan: it deletes the namespace with the PVC, the pod and the Service and frees the LB IP. After "yes":

```bash
# CHANGES  (deletes the namespace with the PVC, the pod, and the Service; frees the LB IP)
source ~/nkp-wl-05.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" delete namespace "$ns" --timeout=5m
```

`nutanix-volume` has `reclaimPolicy: Delete`, so the CSI deletes the PV. **UNKNOWN (D-60)**: whether the CSI also deletes the volume group in Prism Central when that PVC goes. The check after the delete: `kubectl get pv` shows no handle for it, and in Prism Central look for the handle uuid (`nutanix-storage` recipe "List and find volume groups"). If the group is still there, it is a 1 GiB leftover like any other.

I stop at: the namespace name, the two image names from step 2, and the plan of step 3.

---

## nkp-storage-backup S11

Skill files read:
- `nkp-skills/nkp/SKILL.md`
- `nkp-skills/nkp-storage-backup/SKILL.md` (step 1), `nkp-skills/nkp-storage-backup/references/csi.md` (C10)
- `nkp-skills/nkp-cluster-lifecycle/references/delete.md` (D2, same rule)
- `ntnx-skills/nutanix-storage/SKILL.md`, `ntnx-skills/nutanix-storage/RECIPES.md`
- `ntnx-skills/nutanix-api/SKILL.md`

Your `<none>` comes from the column itself, not from the cluster. `custom-columns` needs one column for each path: a joined path such as `.spec.claimRef.namespace/.spec.claimRef.name` prints `<none>` on **every** row [live 2.19.0]. The data is there; the projection is wrong.

Corrected command (READ-ONLY), cluster `app-01` → `~/nkp-app-01.env`:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,SIZE:.spec.capacity.storage,SC:.spec.storageClassName,RECLAIM:.spec.persistentVolumeReclaimPolicy,VG:.spec.csi.volumeHandle'
```

- `NS` and `PVC` are now two columns and fill in.
- `VG` is the volume group: the handle is `NutanixVolumes-<uuid>`, and that `<uuid>` **is** the `extId` of the volume group in Prism Central [live 2.19.0]. That is the id you asked for.

If you want the bare uuid without the `NutanixVolumes-` prefix, say so and I show the shell `cut`. The other source is Prism Central itself: the description of each group names the cluster, the PVC and the namespace:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
python3 - <<'PY'
import sys
sys.path.insert(0, 'scripts')          # run from the nutanix-api skill folder
from ntnx import *
G = '/volumes/v4.3/config/volume-groups'
for g in list_all(G):
    if g.get('isHidden') or g.get('usageType') == 'INTERNAL':
        continue
    d = g.get('description') or ''
    if 'K8sClusterID' in d and ' for ' in d and d.split(' for ', 1)[1].split(',', 1)[0] == 'app-01':
        print(g['extId'], g['name'], d)
PY
```

Two edge cases for your list:

- A PV with an empty `claimRef` (`Released` or `Available`) legitimately prints `<none>` in `NS` and `PVC`. That is not a projection fault: nobody claims it any more, and the volume group may still exist in Prism Central. Tell me if you find rows like that; they are cleanup candidates (`nutanix-storage` "What an NKP cluster leaves behind").
- The other direction: a PVC whose PV is gone is a different question. `get pvc -A` and the PV list side by side answer both.

Not in the skills: any join between PVs and volume groups in one API call. The handle uuid is the join key.

I stop here: nothing in this answer changes anything. If you want the Prism Central side (descriptions, sizes, attachments) or the cleanup of unclaimed groups, say so and I show the plan first.
