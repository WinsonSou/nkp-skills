# t5-wl-02-vpc — workload cluster `skilltest-wl-02` inside the Flow VPC `<vpc>`

Goal: create workload cluster `skilltest-wl-02` on overlay subnet `<vpc>-sn1` (VPC `<vpc>`), managed by
`nkp-mgmt-01` (outside the VPC, VLAN `PRIMARY-IPAM`). Skills followed: `nkp-vpc` (`SKILL.md` + `references/layouts.md`),
`nkp-install` (`references/nutanix.md` N2/N3/N4D/N5/N6 + `SKILL.md` kubeconfig + Verify), and the ntnx-skills
(`nutanix-api`, `nutanix-networking`) for the Prism Central part of `nkp-vpc` step 2.
Operator host `<bastion>`, Prism Central `<pc>`. Standing approval from the brief for every CHANGES block in scope.

**Status: done.** VPC `<vpc>`, overlay subnet `<vpc>-sn1`, CP_VIP `<vpc-net>.21`, LB `.22-.26`,
FIP_API `<net>.135`, FIP_UI `<net>.136`. Create RC=0 in **12 min 53 s**; Verify + N6 pass; cluster left running.
Two skill expectations do not hold for a workload cluster: `ui=` is empty and `ui` is 404 (the UI lives on the
management cluster). N-41 answered yes. Wall clock 05:09 -> 05:56 UTC.

## 0. State read before anything (READ-ONLY, laptop, ntnx.py)

`GET /networking/v4.4/config/{vpcs,subnets,route-tables,routes,floating-ips}`, `GET /vmm/v4.1/ahv/config/vms/{id}`:

```text
VPC <vpc> eddfb515-9a8c-44ec-bbb6-6421a53a057b  external subnet SECONDARY-IPAM-VPC-EXT 7238c8d9-9e9b-4c3e-a21e-db7f3b529028
  externalIps (VPC SNAT, 2 gateway hosts): <net>.183, <net>.184
  route table ae55acb0-315a-4145-af31-bf6d5045a2f4
    0.0.0.0/0 -> EXTERNAL_SUBNET 7238c8d9   (PRESENT, step 2 item "default route" done)
    <vpc-net>.0/24 -> LOCAL_SUBNET 056c6a90
SUBNET PRIMARY-IPAM              26224f58  VLAN <net>.0/25   gw .1   pool .81-.120    dns <dns>
SUBNET SECONDARY-IPAM-VPC-EXT    7238c8d9  VLAN <net>.128/25 nat=True pool .135-.250  dns none
SUBNET <vpc>-sn1            056c6a90  OVERLAY <vpc-net>.0/24 gw .1 pool .50-.249 vpc <vpc> dns <dns>
  ipUsage: numAssignedIPs 4, numFreeIPs 252, pool 200/200 free
FIPs: 48, ALL named fip-dummy-name, ALL NOT_ASSOCIATED  -> 0 FIPs in use
VMs (10): PCVM, <ad-vm>, BASTION, and the 7 `nkp-mgmt-01` nodes; every NIC is on PRIMARY-IPAM.
          No NIC on the overlay subnet and none on the external subnet  ->  <vpc-net>.21-.26 free.
```

- Step 1 of `nkp-vpc` (layout): workload cluster in a VPC + management cluster outside the VPC + NAT external
  subnet + bastion NOT in the VPC -> row "Workload cluster in a VPC, management cluster outside the VPC" ->
  **exposed, 2 floating IPs**, create flags `--control-plane-external-endpoint` and `--cluster-hostname`.
- Step 2 item 1 (default route): already present on the VPC, nothing to add.
- Step 2 item 5 (overlay reaches PC 9440 and registry 443): already proven for this VPC — the previous
  cluster in it ran and joined; re-checked live with curl from a node later (`N-43`/verify section).

## 1. nkp-vpc step 2 — Prism Central objects made (CHANGES, in-scope approval)

The skill lists 5 items as "user actions" in the Prism Central UI. Done with the ntnx-skills (`nutanix-networking`
RECIPES "Floating IPs" + "VPCs"), script `/tmp/t5-wl-02/step2_fips.py`, on the laptop.

| Item | Check / action | Result |
|---|---|---|
| 1 external subnet | `SECONDARY-IPAM-VPC-EXT` VLAN 101, <net>.128/25, NAT, pool .135-.250 | already there |
| 2 VPC + default route | route table `ae55acb0` has `0.0.0.0/0 -> EXTERNAL_SUBNET` | **already there, nothing added** |
| 3 overlay subnet `SUBNET` | `<vpc>-sn1` <vpc-net>.0/24 gw .1 pool .50-.249 dns <dns> | already there; `.21-.26` are outside the pool |
| 4 two floating IPs, associated **before** the create | created below | done |
| 5 overlay reaches PC/registry | proven by the previous cluster in this VPC; re-checked at verify | ok |

FIP address choice (recipe rule: skip addresses of other FIPs and the VPC gateway `externalIps` `.183/.184`;
pool `.135-.250`): 48 FIPs exist, all `fip-dummy-name`, all `NOT_ASSOCIATED`, using
`.138 .145 .148-.155 .160 .162-.164 .166 .169 .176 .192 .194 .195 .197 .200 .202 .203 .209-.212 .214 .216 .223-.225
.228 .230-.236 .239 .241 .243 .245 .247 .249 .250`. `.135` and `.136` are free (`.135`/`.137` held the deleted
`<old-mgmt-cluster>` pair). No VM NIC is on the overlay subnet or on the external subnet, so `<vpc-net>.21-.26` are free.

```text
POST /networking/v4.4/config/floating-ips  (PrivateIpAssociation, vpcReference eddfb515…, external subnet 7238c8d9…)
67b38bb0-d149-4888-8daa-f494de3af8a3  skilltest-wl-02-api  <net>.135 -> <vpc-net>.21  ASSOCIATED_TO_PRIVATE_IP
d9ed43a7-8fc4-4b77-9bbc-317cb738965e  skilltest-wl-02-ui   <net>.136 -> <vpc-net>.22  ASSOCIATED_TO_PRIVATE_IP
fresh list: 50 FIPs total
```

Create + PrivateIpAssociation in one POST worked (the recipe only marks the PUT form verified).

## 2. Cluster env file (CHANGES)

`~/nkp-skilltest-wl-02.env` (600, `bash -n` ok): `CLUSTER_NAME=skilltest-wl-02`, `CP_VIP=<vpc-net>.21`,
`LB_IP_RANGE=<vpc-net>.22-<vpc-net>.26`, `WORKSPACE_NS=kommander-default-workspace`, `SUBNET=<vpc>-sn1`,
`VPC_NAME=<vpc>`, `FIP_API=<net>.135`, `FIP_UI=<net>.136`, `API_EXTERNAL_ENDPOINT=<net>.135`,
`UI_HOSTNAME=<net>.136`. `~/nkp-site.env` not touched.

## 3. nkp-vpc step 3 — MTU read-only check (READ-ONLY)

```text
nic ens3 mtu 1500; bridge mtu 1500; kind mtu 1500 containers 0; no /etc/docker/daemon.json
running: harbor-jobservice nginx harbor-core harbor-portal redis harbor-db registry registryctl harbor-log
pc 302; registry 200
```

All three MTUs equal -> no Docker change, no restart, nothing stops the Harbor registry. The bastion is a
PRIMARY-IPAM VM (MTU 1500), not a VPC VM (1442), so the 1442 premise does not apply here.
The bastion is **not** in the VPC (only reachable case for a workload create anyway) — see N-41 below.

## 4. nkp-vpc step 2 CIDR check (READ-ONLY)

`vpc_cidrs='<vpc-net>.0/24,<net>.128/25'`, pod `192.168.0.0/16`, svc `10.96.0.0/12` -> `no overlap`.

## 5. N2 / N3 / N5 step 1 (READ-ONLY)

```text
N2: set: syntax; all 12 names set; case 5 (MGMT_KUBECONFIG REGISTRY_URL REGISTRY_CA_FILE NTP_SERVERS +
    mirror credentials) all set; VPC_NAME FIP_API FIP_UI API_EXTERNAL_ENDPOINT UI_HOSTNAME all set
N3: nkp v2.19.0; pc 302; ping <vpc-net>.21 -> 100% packet loss (VIP free); ssh key file found
N5 step 1: workspaces default-workspace/kommander-default-workspace, kommander-workspace/kommander (plus
    skilltest-ws, the parallel wl-01 agent's), mgmt mirror https://<registry-host>/nutanix
```

## 6. Create script (CHANGES) — N5 step 3 + nkp-vpc step 4 lines

`~/nkp-skilltest-wl-02-create.sh` (1259 bytes, 700) = the N5 block verbatim plus, before `"$@"`:
`--control-plane-replicas 1` (brief: test-only single CP), then the nkp-vpc step 4 pair
`--control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT"`, `--cluster-hostname "$UI_HOSTNAME"`,
then `--insecure` and `--timeout 60m`.

## 7. N4D dry run (CHANGES; writes `~/skilltest-wl-02-dryrun.yaml`, 11054 bytes)

**RC=0 in under 5 s** (05:12:24 for generate + preflight). Unlike the `--self-managed` management create, a
workload dry run builds **no kind bootstrap cluster** — it only generates objects and runs the preflight checks
against Prism Central. So step 3's kind/Docker-MTU issue cannot bite a workload create. [live 2.19.0]

Objects: 5 Secrets (`-pc-credentials`, `-for-ccm`, `-for-csi`, `-for-konnector-agent`,
`-image-registry-mirror-credentials`) + `NKPCluster kommander-default-workspace/skilltest-wl-02`. **No
`kommanderCluster` and no `ingress` in the file at all** (0 matches) — so the UI hostname is not visible here.

N4D grep + nkp-vpc step 4 grep:

```text
69:kind: NKPCluster   75:  name: skilltest-wl-02    76:  namespace: kommander-default-workspace
140:                addressRanges:  141: - end: <vpc-net>.26   142:  start: <vpc-net>.22
156:                image: (ubuntu-24.04-release-cis-1.36.2)      175: url: https://<registry-host>/nutanix
183:              host: <net>.135               195: url: https://<pc>:9440
187:                  address: <vpc-net>.21
```

Step 4 "Done when" satisfied for API (`host: <net>.135`) and VIP (`address: <vpc-net>.21`). Also seen:
`controlPlane.replicas: 1`, one `md-0` with autoscaler min=max=4, `subnets: [<vpc>-sn1]` for CP and workers,
`storageContainer: SelfServiceContainer`, `kubeProxy.mode: disabled`, CNI Cilium, `insecure: true`, NTP `<ntp>`.

## 8. Env values with no DNS (nkp-vpc "Values")

There is no DNS in this lab. The skill allows a raw IP in both places — `API_EXTERNAL_ENDPOINT`: "`FIP_API`, or a
DNS name that resolves to `FIP_API`"; `UI_HOSTNAME`: "`FIP_UI`, or a DNS name that resolves to `FIP_UI`" — and only
adds "A DNS name needs an A record to its floating IP first." So `API_EXTERNAL_ENDPOINT='<net>.135'` and
`UI_HOSTNAME='<net>.136'` are the skill-sanctioned values. No other caveat for a site without DNS is in the skill.

## 9. Create (CHANGES) — RC=0

tmux `wl02`, log `~/skilltest-wl-02-create.log`. **05:13:21 -> 05:26:14 = 12 min 53 s.**

```text
05:13:22 generate + preflight; 5 Secrets + NKPCluster applied to kommander-default-workspace (2 s)
05:13:24 cluster create done; infrastructure ready 05:14:44; control-plane ready 05:15:44
05:15:44 waiting for machines; RC=0 at 05:26:14
```

No kind bootstrap cluster, no pivot phase (that is `--self-managed` only).

## 10. "Set the kubeconfig variables" (workload) — CHANGES

The workload create writes **no** `~/<cluster>.conf` (unlike the management create). The SKILL.md workload block
(`nkp get kubeconfig --cluster-name … --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"`) ran clean:
`~/skilltest-wl-02.conf` 5595 bytes mode 600, and `export CLUSTER_KUBECONFIG='…'` appended to
`~/nkp-skilltest-wl-02.env` only.

```text
NAME                                     STATUS  ROLES           AGE  VERSION   INTERNAL-IP
skilltest-wl-02-zwc6z-pz28g              Ready   control-plane   34m  v1.36.2   <vpc-net>.60
skilltest-wl-02-md-0-lgf8m-4dlxl-4594p   Ready   <none>          33m  v1.36.2   <vpc-net>.70
skilltest-wl-02-md-0-lgf8m-4dlxl-95rpn   Ready   <none>          34m  v1.36.2   <vpc-net>.160
skilltest-wl-02-md-0-lgf8m-4dlxl-krjm7   Ready   <none>          24m  v1.36.2   <vpc-net>.78
skilltest-wl-02-md-0-lgf8m-4dlxl-wm2mc   Ready   <none>          33m  v1.36.2   <vpc-net>.61
```

## 11. Verify (nkp-install SKILL.md) + N6 (READ-ONLY) — all pass

```text
nkp describe cluster: 1 CP Machine True/Ready, 4 worker Machines True/Ready; Cluster/ and ControlPlane/ rows empty
    (as the skill says); NKPCluster PHASE Reconciled, v2.19.0/v1.36.2
helmrelease wait (mgmt ns kommander, --all): every "condition met" (… traefik, traefik-forward-auth-mgmt, velero)
nodes: 5 Ready; pods --field-selector non-running: "No resources found"; pod wait: all "condition met"
N6: nutanix-volume (default) SC | IPAddressPool metallb ["<vpc-net>.22-<vpc-net>.26"] | ntnx-system 8/8 pods
    Running (nutanix-csi-controller-dw6rn 5 restarts, three csi-node pods 2-4 restarts) | 5 Cilium + 5
    cilium-envoy pods Running | mgmt kommander-traefik EXTERNAL-IP <net>.51 (= first mgmt LB IP)
```

## 12. nkp-vpc step 5 — results (READ-ONLY)

```text
api=<net>.135  vip=<vpc-net>.21        (matches API_EXTERNAL_ENDPOINT / CP_VIP)
ui=                                     EMPTY — .spec.kommanderCluster.spec.ingress does not exist
kubectl -n kommander get svc kommander-traefik   -> Error: namespaces "kommander" not found
kubectl -n kommander-default-workspace get svc kommander-traefik -> EXTERNAL-IP <vpc-net>.22 (= first LB IP)
kubeconfig server = https://<net>.135:6443    (= API_EXTERNAL_ENDPOINT)
cluster-info server = https://<net>.135:6443
api 200 ; ui 404
```

The whole `kommanderCluster` on the live NKPCluster (no `ingress` key at all):

```json
{"spec":{"clusterRef":…,"kubeconfigRef":{"name":"skilltest-wl-02-kubeconfig"},
 "namespaceRef":{"name":"kommander-default-workspace"},
 "ociRegistry":{"mirrorURL":"https://<registry-host>/nutanix",…},
 "platform":{"version":"v2.19.0"}}}
```

**The UI hostname never reached any object.** Grep count for `<net>.136`: mgmt-side `nkpcluster,cluster,
configmap,secret` in `kommander-default-workspace` = **0**; workload-side `configmap -A` = **0**; workload
`ingress -A` = **0**. Workload-cluster ingresses have no host rule (`HOSTS <none>`): `kube-oidc-proxy` (`/dkp/api-server`)
and `traefik-forward-auth` (`/_oauth_kommander`). The workload `kommander-traefik` certificate:

```text
subject=CN = traefik.localhost.localdomain
X509v3 Subject Alternative Name: IP Address:<vpc-net>.22
```

The Kommander dashboard is on the **management** cluster; the workload cluster has no `/dkp/kommander/dashboard`
route (404) and runs a different namespace set (`kommander-default-workspace` + `kommander-flux`, no
`kommander`).

## 13. N-41, N-43, N-01 (READ-ONLY)

**N-41 -> answered: yes.** A full exposed create from an operator host **outside** the VPC works.

```text
from <bastion>: https://<vpc-net>.21:6443/version -> 000   (the private VIP is unreachable outside the VPC)
                https://<net>.135:6443/version -> 200   (the FIP answers)
                https://<net>.136/            -> 404    (NAT path to the overlay LB IP works)
create RC=0, 5 nodes joined through FIP_API, all Machines Ready
API cert SANs: DNS:kubernetes, …, IP 10.96.0.1, IP <vpc-net>.60, IP <net>.135, IP 0.0.0.0, IP 127.0.0.1
               (FIP_API present, CP_VIP <vpc-net>.21 absent — as the skill says)
```

**N-43 -> still open, but the expected line is there.** `cluster-info` and the kubeconfig `server:` show
`https://<net>.135:6443`, i.e. the external endpoint replaced the VIP. `FIP_API` was associated **before** the
create (the skill's required order), so the "associated only after" case stays untested.

**N-01 -> `bpf-lb-mode: dsr`, `bpf-lb-dsr-dispatch: geneve`** (Cilium keeps DSR in the VPC), and the UI FIP reaches
the first LB service through the NAT:

```text
https://<net>.136/                       -> 404 "404 page not found"   (traefik answered)
https://<net>.136/_oauth_kommander       -> 307 Location: https://<vpc-net>.22/_oauth_kommander
https://<net>.136/dkp/api-server         -> 401  (kube-oidc-proxy answered)
https://<net>.136/dkp/kommander/dashboard-> 404  (no such route in a workload cluster)
```

The 307 leaks the **private** LB IP into the redirect, so a browser outside the VPC cannot follow it. That is
exactly the problem `--cluster-hostname` solves — on a management cluster.

## 14. Final PC state (READ-ONLY, laptop client)

```text
VMs on <vpc>-sn1: 5 (skilltest-wl-02-zwc6z-pz28g .60, md-0 …4594p .70, …95rpn .160, …wm2mc .61, …krjm7 .78)
overlay subnet ipUsage: 9 assigned, 195/200 pool free
FIPs: skilltest-wl-02-api <net>.135 ASSOCIATED_TO_PRIVATE_IP <vpc-net>.21
      skilltest-wl-02-ui  <net>.136 ASSOCIATED_TO_PRIVATE_IP <vpc-net>.22
Cluster left running (brief). Nothing of `skilltest-wl-01` or `~/nkp-site.env` touched.

## Learnings

1. **[nkp-skill nkp-vpc/SKILL.md Step 1, layout table, row "Workload cluster in a VPC, management cluster
   outside the VPC"] The row says "exposed | 2 (the management cluster reaches the API through `FIP_API`) | same
   as exposed", i.e. 2 floating IPs and the two exposed create flags. Live, for a *workload* cluster the second
   FIP and `--cluster-hostname` do nothing.** Evidence: the `UI_HOSTNAME` value `<net>.136` appears in **0**
   objects (mgmt-side `nkpcluster`/`cluster`/`configmap`/`secret` in `kommander-default-workspace`, workload-side
   `configmap -A` and `ingress -A`); the live NKPCluster has no `spec.kommanderCluster.spec.ingress` key at all;
   the workload `kommander-traefik` cert is `CN=traefik.localhost.localdomain` + `IP <vpc-net>.22` only;
   `/dkp/kommander/dashboard` through `FIP_UI` is 404 because the Kommander dashboard lives on the management
   cluster. The workload FIP_UI is not useless (it carries `/_oauth_kommander` 307 and `/dkp/api-server` 401 for
   that cluster's traefik/kube-oidc-proxy), but the cluster works and is verified without it.
   **Fix:** replace the row with "Workload cluster in a VPC, management cluster outside the VPC | exposed | **1**
   (`FIP_API` → `CP_VIP`, the management cluster and the nodes reach the API through it) | `--control-plane-external-endpoint`
   only; `--cluster-hostname` has no effect on a workload cluster (verified 2.19.0) — add one FIP + one
   `--control-plane-external-endpoint` per extra Service instead (step 6)". And in the flag list at the top:
   `FIP_UI` / `UI_HOSTNAME` "management cluster only".

2. **[nkp-skill nkp-vpc/SKILL.md Facts, `--cluster-hostname` bullet] "`--cluster-hostname` gives the UI
   certificate `kommander-traefik-tls` the `UI_HOSTNAME` name. Traefik keeps the first IP of `LB_IP_RANGE`."** This
   holds only for a self-managed (management) cluster. On a workload create the CLI **accepts the flag and silently
   drops it** (create RC=0, nothing in the objects). **Fix:** add "management cluster (`--self-managed`) only; a
   workload cluster ignores it silently — check with `kubectl -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o
   jsonpath='{.spec.kommanderCluster.spec.ingress.hostname}'`, which prints empty."

3. **[nkp-skill nkp-vpc/SKILL.md Step 5, `traefik=` line] `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander
   get svc kommander-traefik` → `Error from server (NotFound): namespaces "kommander" not found` on a workload
   cluster.** The service is in the workspace namespace: `-n "$WORKSPACE_NS"` gives
   `EXTERNAL-IP <vpc-net>.22`. **Fix:** use `-n "$WORKSPACE_NS"` and add "(a management cluster uses `kommander`, a
   workload cluster uses its workspace namespace)".

4. **[nkp-skill nkp-vpc/SKILL.md Step 5, "Done when"] The exposed Done-when asks for `ui=` = `UI_HOSTNAME` and
   `ui 302`. Neither holds for a workload cluster (`ui=` empty, `ui 404`), and nothing in the skill warns of
   that.** **Fix:** split the Done-when per cluster kind — workload: `api=API_EXTERNAL_ENDPOINT`, `vip=CP_VIP`,
   `server=` uses the FIP, `traefik=` = first LB IP in `$WORKSPACE_NS`, all nodes Ready with overlay IPs,
   `api 200` (no `ui` line); management cluster: the current list, including `ui=` and `ui 302`.

5. **[nkp-skill nkp-vpc/SKILL.md Step 4, "Done when"] It checks only `host:` (API) and `address:` (VIP) in the dry
   run, and for a workload cluster the dry-run YAML has no `kommanderCluster` and no `ingress` (0 matches), so
   there is nothing to check for the UI hostname and a wrong `--cluster-hostname` cannot be caught before the
   create.** **Fix:** say so in step 4, and point at learning 1: on a workload cluster, drop the flag.

6. **[nkp-skill nkp-vpc/SKILL.md Step 3, the stop rule] "If `running:` shows a name (a bootstrap cluster, a
   registry), stop and ask the user."** Read literally this block always stops on this site, because the Harbor
   registry runs in Docker on the bastion (8 containers). The stop only matters when a Docker restart is needed.
   **Fix:** "If the three MTUs differ **and** `running:` shows a name, stop and ask the user; if they match, nothing
   changes and no container stops."
   Same step, the 1442 premise: the bastion is a `PRIMARY-IPAM` VLAN VM, `nic ens3 mtu 1500`, so
   `bridge 1500 = kind 1500 = NIC 1500` already. **Fix:** one line "this applies only when the operator host is a
   VM inside the VPC (1442); an outside host needs no change" — and note it is compatible with N-41 (an outside
   host is the working case).

7. **[nkp-skill nkp-vpc/SKILL.md Step 3 + nkp-install/references/nutanix.md N4D] N4D says the dry run "creates a
   kind bootstrap cluster, installs CAPI, runs the preflight checks, prints the objects, and deletes the bootstrap
   cluster", and my Step-3 narrative copies the MTU/kind worry. For a workload cluster there is no kind cluster at
   all: the dry run returned RC=0 in under 5 s and the create itself has no bootstrap/pivot phase.** [live 2.19.0]
   **Fix:** in N4D and in nkp-vpc step 3, add "(a workload create, `--self-managed=false`, makes no kind bootstrap
   cluster: the dry run takes seconds and the Docker/kind MTU cannot fail it)".

8. **[nkp-skill nkp-install/references/nutanix.md N5] A workload create writes no kubeconfig file.** After RC=0
   there was no `~/skilltest-wl-02.conf`, so the management-cluster form `ls -l "./$CLUSTER_NAME.conf"` (A-05,
   SKILL.md) has no workload equivalent, and N5 only says "go to the SKILL.md step". **Fix:** one line in N5 step 4
   Done-when: "the workload create writes **no** kubeconfig; run the workload block of SKILL.md 'Set the kubeconfig
   variables' (`nkp get kubeconfig --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"`)."

9. **[nkp-skill nkp-vpc/SKILL.md Step 2] The five items are written as Prism Central **UI** actions ("The user does
   these steps in Prism Central (Infrastructure → Network)")**, while the same repo ships `ntnx-skills` that do all
   of them over the v4 API. An agent had to improvise the mapping. **Fix:** at the top of step 2, add "Agent path
   (API): `nutanix-networking` recipes — `GET /networking/v4.4/config/{vpcs,subnets,route-tables,floating-ips}` for
   items 1-4, `POST …/vpcs` + `POST …/route-tables/{id}/routes` (nexthop `EXTERNAL_SUBNET`) if the route is missing,
   `POST …/floating-ips` with a `PrivateIpAssociation` for item 4." Also add the completion check that the items
   need: `associationStatus == ASSOCIATED_TO_PRIVATE_IP` for both FIPs (the recipe's VmNic form says
   `ASSOCIATED_TO_VNIC`).

10. **[nkp-skill nkp-vpc/SKILL.md Step 2 item 4] It does not say where the FIP addresses come from when the site
    has no IPAM for floating IPs, or that the VPC gateway `externalIps` must be skipped.** This lab has 48
    `fip-dummy-name` FIPs (all `NOT_ASSOCIATED`) spread over the pool, so address choice needed a full list plus a
    set difference against gateway `.183/.184`; `.135`/`.136` were picked and recorded. **Fix:** add "choose an
    address from the external-subnet pool that is not in the FIP list, not a VPC `externalIps` gateway address, and
    not a VM address (a NAT external subnet has no VM NICs, so the FIP list and the gateways are the whole
    exclusion set) — record the address and the extId in the run log." Plus: "create + `PrivateIpAssociation` in
    one `POST` works [live ganges-7.6.0.10, 2026-11-04]; the ntnx recipe only marks the PUT form verified".

11. **[fact] N-41 answered: yes.** A complete exposed create of a workload cluster works from an operator host
    **outside** the VPC: create RC=0 in 12 min 53 s, all 4 workers + 1 CP joined, and from the bastion
    `https://<vpc-net>.21:6443/version` = `000` (private VIP unreachable) while `https://<net>.135:6443/version` =
    `200`. The API cert carries `IP <net>.135` (the FIP) and **not** `<vpc-net>.21`. **Fix:** close N-41 in
    nkp-vpc and in `research/OPEN-ITEMS.md`.

12. **[fact] N-43 stays open, expected line confirmed.** `cluster-info` and the kubeconfig `server:` =
    `https://<net>.135:6443` with `FIP_API` associated **before** the create, i.e. the external endpoint replaced
    the VIP everywhere (CAPI `Cluster`, `cluster-info`, kubeconfig). The "associated only after the create" case was
    not run (it costs a second cluster).

13. **[fact] N-01 confirmed: `bpf-lb-mode: dsr`, `bpf-lb-dsr-dispatch: geneve`, and a NAT floating IP reaches the
    first LB service.** `https://<net>.136/` → `404 404 page not found` (traefik), `/_oauth_kommander` → `307`
    with `Location: https://<vpc-net>.22/_oauth_kommander`, `/dkp/api-server` → `401`. **The redirect carries the
    private LB IP**, so an outside browser cannot follow it — that is the concrete reason to set the UI hostname on
    a cluster whose UI users are outside the VPC.

14. **[fact] One FIP + `--cluster-hostname` are what the mgmt cluster needs; the workload needs one FIP.** Also
    noted for ran-away costs: `--control-plane-replicas 1` gave a 5-node cluster whose VMs took overlay IPs from the
    IPAM pool `.60 .61 .70 .78 .160` (not in ascending order), so an IP plan must not assume sequential
    allocation.

15. **[process] A `sleep 300 && ssh …` call hung for 30 minutes and the parent had to stop me.** The `sleep` and the
    SSH were in one command, with no `ServerAliveInterval`. **Fix for the operator procedure:** keep each local
    `sleep` ≤ 120 s in its own call, wrap every remote command in `timeout`, and use `ssh -o
    ServerAliveInterval=15 -o ServerAliveCountMax=4`; check a long create with `tmux ls` + `tail` instead of one
    long call.
