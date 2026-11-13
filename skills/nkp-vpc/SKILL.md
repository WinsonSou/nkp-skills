---
name: nkp-vpc
description: >
  NKP cluster inside a Nutanix Flow VPC: overlay node subnet, floating IPs for the API and UI
  (--control-plane-external-endpoint; --cluster-hostname on a management cluster only), workload cluster in a VPC,
  kube-vip and MetalLB on the overlay, bastion and kind MTU 1442, tenant and transit VPC layouts,
  floating IP, subnet and VPC cleanup after a cluster delete.
metadata:
  nkp_versions: "2.17-2.19"
  last_verified: "2026-11-04"
  sources: "live 2.19.0, pdf 2.19, portal TN-2207 v2.0"
---

# NKP in a Flow VPC

<!-- RULES:BEGIN -->
## Rules for every NKP skill

1. **Marks.** Line 1 of each command block is `# READ-ONLY`, `# CHANGES`, or `# USER-TERMINAL`. CHANGES: it changes a cluster, the infrastructure, a registry, the container engine, or a file on the operator host. USER-TERMINAL: it shows a secret on the screen, or it runs on another host (the text after the mark names the host). Give it to the user to run in their own terminal. Do not run it.
2. **Approval.** Before a CHANGES block, show the command, the target, and the result. Stop. Run it only after the user types "yes" to that plan. "Just run it" is not "yes". If the user answers with another word (for example "proceed" or "ok"), ask them to type "yes".
3. **Env files.** Run blocks with bash. `~/nkp-site.env` holds the site values and the secrets. `~/nkp-<cluster>.env` holds the values of one cluster. Its first line is `source ~/nkp-site.env 2>/dev/null`. Line 2 of a block is `source ~/nkp-<cluster>.env 2>/dev/null` when the block uses a cluster-file variable. Otherwise line 2 is `source ~/nkp-site.env 2>/dev/null`. Before you run a block, replace `<cluster>` in `~/nkp-<cluster>.env` with the cluster name. If the user has not named the cluster, keep `~/nkp-<cluster>.env` in the block and ask for the name. Do not take a name from an example or another conversation. After the cluster env file exists, use its real name (for example `~/nkp-dev-01.env`) in every block that you show. Commands use the variables as `"$VAR"`.
4. **Values.** When you know a value, append one line to its file: `echo "export VAR='value'" >> ~/nkp-site.env` (CHANGES). Write a line only after the user gives or confirms the value. Ask first, and write the line in a later reply, after the answer. If the user has not given the value, do not show the append block. Do not put an example or a guessed value in it. Never write an empty value or a placeholder such as `<ip>`. A shell value inside a block (for example `obj=''`) stays empty, with its `:?` guard, until the user gives it. Never put `<...>` text in it. To change a value, append a new line. The last line wins. Some skill files add a `| File | Site variables |` table with more variables. For a value with no variable in these tables, make an UPPER_SNAKE name and ask the user. If `~/nkp-site.env` does not exist, make it: `touch ~/nkp-site.env && chmod 600 ~/nkp-site.env` (CHANGES).
5. **Secrets.** The user types the secret lines into `~/nkp-site.env` with an editor. Do not repeat or use a secret from the chat, and do not write it into an example line. Tell the user to put it in the file and to change it. Check a secret only with `printenv VAR >/dev/null` or `[ -n "$(printenv VAR)" ]`. Never print an env file, `env`, `set`, a kubeconfig, or Secret data.
6. **Unknowns.** Use only the UNKNOWN lines in the skills: `UNKNOWN (<id>): <what>. Find out with: <command>`. Run the check or ask the user. For a fact that is not in the skills, say "not in the skills" and give a READ-ONLY check. Never make up an ID or a fact.
7. **Offline.** Use only these skills, the bundle, `--help`, and the cluster. Read versions from the cluster or from `nkp version`.
8. **Tags.** `[live 2.19.0]` live cluster · `[pdf p.N]` NKP 2.19 guide · `[portal]` Nutanix portal · `[field]` not confirmed. Trust them in this order.

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `MGMT_KUBECONFIG` `BUNDLE_DIR` `IMAGE_BUNDLES` `REGISTRY_URL` `REGISTRY_CA_FILE` `PC_ENDPOINT` `PC_CA_FILE` `PC_PROJECT` `PE_CLUSTER` `SUBNET` `STORAGE_CONTAINER` `VM_IMAGE` `SSH_PUBKEY_FILE` `NTP_SERVERS` `NKP_HTTP_PROXY` `NKP_HTTPS_PROXY` |
| `~/nkp-site.env` secrets | `NUTANIX_USER` `NUTANIX_PASSWORD` `REGISTRY_MIRROR_USERNAME` `REGISTRY_MIRROR_PASSWORD` `NUTANIX_REGISTRY_USERNAME` `NUTANIX_REGISTRY_TOKEN` |
| `~/nkp-<cluster>.env` | `CLUSTER_NAME` `CP_VIP` `LB_IP_RANGE` `WORKSPACE_NS` `CLUSTER_KUBECONFIG` `NO_PROXY_LIST` |
<!-- RULES:END -->
Use this skill for an NKP cluster whose nodes are on a Nutanix Flow Virtual Networking VPC **overlay** subnet. The CNI stays Cilium. This skill gives only the VPC parts. The create script itself: skill `nkp-install` (its file `nutanix.md`). The cluster delete: skill `nkp-cluster-lifecycle`. Flow CNI (pods in VPCs): skill `nkp-flow-cni`. The Prism Central objects (VPC, subnets, floating IPs): skill `nutanix-networking` (RECIPES.md headings below). If skill `nutanix-networking` is not installed, the user does it in Prism Central.

| File | Site variables |
|---|---|
| `~/nkp-<cluster>.env` | `VPC_NAME` `FIP_API` `FIP_API_ID` `FIP_UI` `FIP_UI_ID` `API_EXTERNAL_ENDPOINT` `UI_HOSTNAME` |

- `VPC_NAME`: the VPC of the cluster nodes. `SUBNET` is the **overlay** subnet in that VPC (which file: step 2). `FIP_API`: the floating IP of the API, from the external subnet of the VPC. `API_EXTERNAL_ENDPOINT`: `FIP_API`, or a DNS name that resolves to `FIP_API`. `FIP_API_ID`, `FIP_UI_ID`: the Prism Central extIds of the floating IPs (the delete in step 7 needs them).
- **Management cluster only**: `FIP_UI` (the floating IP of the UI) and `UI_HOSTNAME` (`FIP_UI`, or a DNS name that resolves to `FIP_UI`). A workload cluster does not use them (Facts).

## Facts

- Versions in TN-2207 (v2.0): AOS and Prism Central 7.5 or later, Network Controller 7.0.0 or later, NKP 2.17 or later. [portal] NKP 2.16 is not in its range.
- A floating IP is a 1:1 NAT from an external-subnet IP to one private IP in the VPC, all ports. Floating IPs belong to one VPC. The floating IP is never `CP_VIP`. It can be the external endpoint of the API (`--control-plane-external-endpoint`). [portal]
- kube-vip (`CP_VIP`) and MetalLB (`LB_IP_RANGE`) use ARP (Layer 2). Both ranges must be in the overlay subnet, outside its IP pool. So they are private: from outside the VPC, users reach them only through a floating IP. [portal][pdf p.720-721]
- With `--control-plane-external-endpoint`, the external endpoint replaces the VIP in the CAPI `Cluster`, in kubeadm `controlPlaneEndpoint`, in `cluster-info`, in the Cilium `KUBERNETES_SERVICE_HOST`, and in the kubeconfig. The nodes reach the API through the floating IP. kube-vip still holds `CP_VIP` in the overlay. [live 2.19.0]
- The API certificate has the external endpoint in its names, without `--extra-sans`. `CP_VIP` is not in the names. [live 2.19.0] To use `https://CP_VIP:6443` with TLS checks inside the VPC, add `CP_VIP` to the API certificate names at create time (skill `nkp-networking`, step 3, row "API server certificate SANs").
- `--cluster-hostname` works on a **management cluster** only: it gives the UI certificate `kommander-traefik-tls` the `UI_HOSTNAME` name. Traefik keeps its IP from `LB_IP_RANGE`. [live 2.19.0] The ingress field: skill `nkp-networking`, `ingress-certs.md` I1.
- A **workload** create accepts `--cluster-hostname` and drops it without an error: no object holds the name, and the workload Traefik certificate has only its LB IP. The Kommander dashboard is on the management cluster: on a workload cluster `/dkp/kommander/dashboard` gives 404. [live 2.19.0]
- Without a UI hostname, Traefik sends `/_oauth_kommander` (the login) to the **private** LB IP with a 307 redirect. A browser outside the VPC cannot follow it. This is why a management cluster with users outside the VPC needs `--cluster-hostname`. [live 2.19.0]
- VPC overlay NICs have MTU 1442. Cilium Geneve makes the pod route MTU 1392. [live 2.19.0][pdf p.711] Docker on the operator host uses 1500 by default. [portal]
- Cilium keeps `bpf-lb-mode: dsr` with `bpf-lb-dsr-dispatch: geneve` in a VPC. On two lab clusters in a VPC (NAT floating IPs), a floating IP to an LB IP answered. [live 2.19.0] Network Controller VLANs and no-NAT: skill `nkp-networking`, `cni.md` C4 (N-01).
- NKP has no object for a VPC, a subnet, or a floating IP. The CAPX objects name only the subnet. [live 2.19.0] Prism Central owns these objects. `nkp delete cluster` does not delete them (step 7).
- Pod and service CIDRs must not overlap any VPC range that the nodes route to. The cluster sends the traffic to the pod or service network, and the packets are lost. [portal]

UNKNOWN (N-02): a management cluster create in a VPC (kind bootstrap on an operator host with MTU 1442) is not tested; an exposed workload create in a VPC is [live 2.19.0]. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{.items[0].status.phase}{"\n"}'` after a management create in a VPC.

## Step 1: Choose the layout

Ask the user:
1. Must users or a management cluster outside the VPC reach the API or the UI? (no = **isolated**, yes = **exposed**)
2. Is the external subnet of the VPC NAT or no-NAT?
3. Is this a management cluster, or a workload cluster for a management cluster outside the VPC?
4. Is the operator host (bastion) a VM in the same VPC?

| Answer | Layout | Floating IPs | Extra create flags |
|---|---|---|---|
| Only VMs in the VPC use the cluster | isolated | 0 | none [portal] |
| Management cluster, users outside the VPC, NAT external subnet | exposed | 2: `FIP_API` → `CP_VIP`, `FIP_UI` → the Traefik IP (first IP of `LB_IP_RANGE`) | `--control-plane-external-endpoint`, `--cluster-hostname` [portal][live 2.19.0] |
| Workload cluster in a VPC, management cluster outside the VPC | exposed | 1: `FIP_API` → `CP_VIP` (the management cluster and the nodes reach the API through it) | `--control-plane-external-endpoint` only. No `--cluster-hostname`. [live 2.19.0] |
| Each more `LoadBalancer` Service that outside users need (also the Traefik of a workload cluster) | — | +1 for each Service | none (step 6) [portal] |

- With a no-NAT external subnet, the VPC can advertise the overlay range. Then outside hosts reach `CP_VIP` and the LB IPs directly and need no floating IP. [portal] Ask the network team if the overlay range is routed.
- The guide asks for 3 floating IPs: bastion, `--extra-sans`, UI. [pdf p.721] These skills use the form of TN-2207: the external endpoint already puts the API floating IP in the certificate [live 2.19.0], so a separate `--extra-sans` floating IP gives nothing. Add a bastion floating IP only when users reach the bastion from outside.
- Tenant VPCs, transit VPC, shared or per-tenant management cluster, registry placement, Flow CNI with a VPC: [references/layouts.md](references/layouts.md).

Done when: you know the layout, the cluster kind, and the number of floating IPs.

## Step 2: Prepare Prism Central

First read what exists (READ-ONLY): skill `nutanix-networking`, RECIPES.md "Subnets", "VPCs", "Floating IPs" (list calls). Then show the missing items as a plan. Each create is a CHANGES step: stop for "yes". If skill `nutanix-networking` is not installed, the user does it in Prism Central (Infrastructure → Network) and confirms each item. [portal][pdf p.709-710]

1. An external subnet: a VLAN subnet with "External Connectivity for VPCs" on, NAT or no-NAT. Its pool must have IPs for all SNAT and all floating IPs. A VPC can have only one NAT external subnet. [portal]
2. A VPC on that external subnet, with a default route (all addresses) to the external subnet, or the routes that the nodes need. A VPC create adds no default route (RECIPES.md "VPCs"). [portal]
3. An overlay subnet in the VPC with IPAM on. It is the node subnet (`SUBNET`). Leave free IPs outside its pool for `CP_VIP` and `LB_IP_RANGE`. [portal][pdf p.720-721] Check them with skill `nutanix-networking`, RECIPES.md "Free IP check for a VIP or an LB range". Its ARP probe proves an overlay IP free only from a host in the VPC. From a host outside the VPC, use only its API sources (pool, reservations, VM NICs).
4. Exposed layout: the floating IPs of step 1.
   - Address: choose it from the external subnet pool. Skip the addresses of other floating IPs and the VPC gateway addresses (`externalIps` of the VPC). A NAT external subnet has no VM NICs, so these two lists are all the addresses to skip. [live 2.19.0]
   - Select floating IPs by address, not by name: bulk floating IPs all have one name.
   - Create each one with its private-IP association in one call: RECIPES.md "Floating IPs" → "Create and associate in one call", the "Virtual IP" association. `FIP_API` → `CP_VIP` [pdf p.720-721]. Management cluster only: `FIP_UI` → the first IP of `LB_IP_RANGE` [portal][live 2.19.0].
   - Do this **before the create**: the nodes join through `FIP_API`. [live 2.19.0]
   - Done when each one has `associationStatus` `ASSOCIATED_TO_PRIVATE_IP` (not `ASSOCIATED_TO_VNIC`).
   - Record its address and its extId (`FIP_API`, `FIP_API_ID`; `FIP_UI`, `FIP_UI_ID`).
5. From the overlay subnet, the nodes reach Prism Central on TCP 9440 and the registry on TCP 443. [portal]

UNKNOWN (N-43): whether a create works when `FIP_API` is associated only after the create. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-public get configmap cluster-info -o jsonpath='{.data.kubeconfig}' | grep server:`.

Ask the user for the values. Append each value only after the user gives or confirms it (rule 4). `VPC_NAME`, `CP_VIP`, `LB_IP_RANGE` and, for the exposed layout, `FIP_API`, `FIP_API_ID`, `API_EXTERNAL_ENDPOINT` go to the cluster env file. Exposed management cluster: also `FIP_UI`, `FIP_UI_ID`, `UI_HOSTNAME`. `SUBNET` (the overlay subnet name):
- Management cluster: append `SUBNET` to `~/nkp-site.env`.
- Workload cluster: append `SUBNET` to its cluster env file, and also `PE_CLUSTER` and `STORAGE_CONTAINER` when they are not the site values. Do not change `~/nkp-site.env`: the management cluster and the other clusters use its values. The cluster env file sources the site file first, so its lines win only for this cluster.

A DNS name needs an A record to its floating IP first. Without DNS, use the floating IP itself as the value. Then check the pod and service CIDRs against all VPC ranges that the nodes route to. Set `vpc_cidrs` to the comma-separated list that the user gives:

```bash
# READ-ONLY  (needs python3)
source ~/nkp-site.env 2>/dev/null
vpc_cidrs=''; pod_cidr='192.168.0.0/16'; svc_cidr='10.96.0.0/12'
: "${vpc_cidrs:?}"
python3 -c 'import ipaddress,sys; k=[ipaddress.ip_network(c) for c in sys.argv[1:3]]; v=[ipaddress.ip_network(c.strip()) for c in sys.argv[3].split(",")]; bad=[(str(a),str(b)) for a in k for b in v if a.overlaps(b)]; print("OVERLAP", bad) if bad else print("no overlap")' "$pod_cidr" "$svc_cidr" "$vpc_cidrs"
```

`pod_cidr` and `svc_cidr` are the NKP defaults. [live 2.19.0] On `OVERLAP`, choose free CIDRs with the user and add the CIDR flags (skill `nkp-install`, `nutanix.md` N7). Set the two values in the block to the new CIDRs and run it again.

Done when: items 1-5 are done or confirmed, the values are in the env files, and the check prints `no overlap`.

## Step 3: Prepare the operator host

Where the operator host can be:
- Isolated layout: a VM **in the same VPC**, because `CP_VIP` is private. [portal]
- Exposed layout: in the VPC, or outside it. From outside, `CP_VIP` answers `000` and `FIP_API` answers; the create and the node joins go through `FIP_API`, when it is associated before the create (step 2 item 4). [live 2.19.0]

The MTU part of this step is for a **management** cluster on an operator host **in the VPC** (NIC MTU 1442). A management create (and its dry run) makes a kind bootstrap cluster on the operator host. With MTU 1500 in Docker and 1442 on the NIC, TLS to Prism Central fails during the bootstrap. [portal] A workload create makes no kind cluster, so the Docker MTU cannot fail it. [live 2.19.0] A host on a VLAN has the same MTU on the NIC and in Docker. Run the block. For a workload cluster, read only the `pc` and `registry` lines.

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

- The NIC, bridge, and kind MTUs are the same (or `no kind network` and the bridge MTU is the NIC MTU): change nothing. The `running:` names do not matter.
- The bridge MTU or the kind MTU is not the NIC MTU: fix Docker with [references/layouts.md](references/layouts.md) L8. That restarts Docker, which stops the `running:` containers (a bootstrap cluster, a registry). Ask the user first.

Done when: the MTUs are the same (management cluster in the VPC), and `pc` and `registry` print a code that is not `000` (`pc 302` is normal).

## Step 4: Create the cluster

Use skill `nkp-install` (its file `nutanix.md`, N4 or N5) for the create script. Isolated layout: no extra lines. Exposed layout: before you write the script, add these lines before `"$@"`. A workload cluster gets only the first line.

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
  --cluster-hostname "$UI_HOSTNAME" \
```

The block that runs the script sources the cluster env file, so the variables come from it. After the dry run (`nutanix.md` N4D), show the user these lines:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^ +host:|^ +address:|^ +hostname:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

A workload dry run has no `kommanderCluster` and no ingress part, so it has no `hostname:` line. [live 2.19.0]

Done when: a `host:` line shows `API_EXTERNAL_ENDPOINT`, an `address:` line shows `CP_VIP`, and the user says "yes" to the create. Then the create runs as in `nutanix.md` N4D.

## Step 5: Verify the VPC parts

`WORKSPACE_NS` is `kommander` for a management cluster and the workspace namespace for a workload cluster. The Traefik Service of a workload cluster is in `WORKSPACE_NS`; a workload cluster has no `kommander` namespace. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}api={.value.nutanix.controlPlaneEndpoint.host} vip={.value.nutanix.controlPlaneEndpoint.virtualIP.configuration.address}{"\n"}{end}ui={.spec.kommanderCluster.spec.ingress.hostname}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get svc kommander-traefik -o jsonpath='traefik={.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" config view --minify -o jsonpath='server={.clusters[0].cluster.server}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
curl -sk -o /dev/null -m 10 -w 'api %{http_code}\n' "https://${API_EXTERNAL_ENDPOINT:-$CP_VIP}:6443/version"
curl -sk -o /dev/null -m 10 -w 'ui %{http_code}\n' "https://${UI_HOSTNAME:-${LB_IP_RANGE%%-*}}/dkp/kommander/dashboard"
```

Done when [live 2.19.0]:
- Exposed: `api=` is `API_EXTERNAL_ENDPOINT`, `vip=` is `CP_VIP`, `server=` uses `API_EXTERNAL_ENDPOINT`. Isolated: `api=` and `vip=` are `CP_VIP`.
- `traefik=` is an IP of `LB_IP_RANGE` (an overlay IP, usually the first). All nodes are `Ready` with overlay IPs (not in order).
- `api 200`. `000` means no answer: see "Common failures".
- Management cluster: `ui=` is `UI_HOSTNAME` (exposed) and `ui 302` (redirect to the login). Then the user runs `nkp get dashboard` (skill `nkp-install`, USER-TERMINAL). The URL uses `UI_HOSTNAME`.
- Workload cluster: `ui=` is empty and `ui` gives 404 or `000`. This is normal: the UI is on the management cluster.

## Step 6: Day-2 changes

**Set the UI hostname later** (management cluster only; the create had no `--cluster-hostname`, or the user adds a DNS name). The KommanderCluster is owned by the NKPCluster, so patch the NKPCluster, not the KommanderCluster. [live 2.19.0] Append `UI_HOSTNAME` first (rule 4), and `INGRESS_HOSTNAME` with the same value. Then use skill `nkp-networking`, `ingress-certs.md` I3, the hostname-only patch (dry run, plan, stop for "yes", apply). Then run step 5. Your own certificate for a DNS name: the same I3 steps 1-4.

**Another `LoadBalancer` Service for outside users** (also the Traefik of a workload cluster). List the Service IPs:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,IP:.status.loadBalancer.ingress[0].ip
```

Make one floating IP for each Service, associated with the Service IP, as in step 2 item 4 (plan, stop for "yes"). [portal] No NKP object does this. Keep a list of these floating IPs (address, extId, Service) for step 7. More LB IPs: skill `nkp-networking`, `metallb.md`.

UNKNOWN (N-50): how to give the Traefik of a workload cluster an outside hostname, so that the `/_oauth_kommander` redirect does not use the private LB IP (`--cluster-hostname` has no effect on a workload cluster). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get ingress -o custom-columns=NAME:.metadata.name,HOSTS:.spec.rules[*].host`.

**Change `FIP_API` or `API_EXTERNAL_ENDPOINT` after the create**: do not. See [references/layouts.md](references/layouts.md), L7 (N-42).

## Step 7: Clean up the VPC after a cluster delete

`nkp delete cluster` deletes the node VMs. The floating IPs, the overlay subnet, and the VPC stay. A volume group stays only for each PVC that the cluster had. [live 2.19.0]

1. **Before the delete**, record what the cluster uses: run the Service list block of step 6 and this block. Keep the output in the run log: the floating IP delete needs the extIds.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
echo "cluster=$CLUSTER_NAME vpc=$VPC_NAME subnet=$SUBNET vip=$CP_VIP lb=$LB_IP_RANGE"
echo "fip_api=$FIP_API id=$FIP_API_ID fip_ui=$FIP_UI id=$FIP_UI_ID"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o name
```

2. Delete the cluster with skill `nkp-cluster-lifecycle` (`delete.md`). Do the list above before its operator-host file cleanup, because that removes the cluster env file. After the delete, the floating IPs stay `ASSOCIATED_TO_PRIVATE_IP` on a private IP that no VM holds, and they answer `000`. This is normal until item 4. [live 2.19.0]
3. **Leftover audit** (READ-ONLY): skill `nutanix-nkp`, RECIPES.md "Leftover audit for a cluster". Expect no VM with the cluster name prefix.
4. **Floating IPs** (CHANGES): `FIP_API`, `FIP_UI`, and each Service floating IP of step 6, unless another cluster uses them. Show the addresses and extIds as the plan; stop for "yes". For each one: read it by extId and check its address, then disassociate it, then delete it: skill `nutanix-networking`, RECIPES.md "Floating IPs" → "Delete a floating IP". Do not delete an associated floating IP directly. Done when a read by extId gives 404. [live 2.19.0]
5. **Volume groups**: only when the cluster had PVCs. Skill `nkp-cluster-lifecycle`, `delete.md` D5 (it points to skill `nutanix-storage`, RECIPES.md "What an NKP cluster leaves behind" + "Delete a volume group").
6. **Overlay subnet, VPC, route table**: these are site objects. The next cluster in this VPC, the bastion, or other clusters can use them. A cluster delete never means a subnet or VPC delete. Ask the user if the site still needs them. Delete only after the user says no: plan, stop for "yes", then RECIPES.md "Subnets" (**Delete**), then "VPCs" (after its subnets; its route table goes with it).
7. External subnet: keep it. Other VPCs use it. `CP_VIP` and `LB_IP_RANGE` are free again in the overlay subnet.

If a companion skill is not installed, the user does items 3-6 in Prism Central and confirms each one.

Done when: the audit shows no VM, each floating IP of the cluster gives 404 (or the user keeps it), and the user chose to keep or delete the subnet and the VPC.

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| Bootstrap: TLS or handshake errors to Prism Central | Docker or kind MTU 1500 on a 1442 NIC. [portal] | Step 3, then `nkp delete bootstrap` (skill `nkp-install`) and create again. |
| Nodes do not join, Cilium cannot reach the API | `FIP_API` is not associated with `CP_VIP`, or the VPC does not route the overlay to its floating IP. [live 2.19.0] | Step 2 item 4. Ask the network team. |
| `api 000` from outside, inside the VPC `CP_VIP` answers | Isolated layout, or no `FIP_API`. | Exposed layout needs the create flag (step 4). |
| `ui 000`, `api 200`, management cluster | `FIP_UI` is not associated with the Traefik IP, or Cilium DSR (N-01). | Check the association. Then skill `nkp-networking`, `cni.md` C4. |
| `namespaces "kommander" not found` on a workload cluster | The workload Traefik is in `WORKSPACE_NS`. [live 2.19.0] | Use `-n "$WORKSPACE_NS"` (step 5). |
| Workload cluster: `ui=` empty, `ui 404` | Normal: no UI on a workload cluster. [live 2.19.0] | None. |
| `nkp get dashboard` shows a private IP | No `--cluster-hostname` on the management cluster. | Step 6, UI hostname. |
| TLS name error on `https://CP_VIP:6443` | `CP_VIP` is not in the API certificate. [live 2.19.0] | Use `API_EXTERNAL_ENDPOINT`. |
| Floating IPs answer `000` after a cluster delete | Normal: they point to a private IP that no VM holds. [live 2.19.0] | Step 7 item 4. |
| Pods cannot reach a host in another VPC | Pod or service CIDR overlaps that VPC range. [portal] | A new cluster with free CIDRs (step 2). |
| `ImagePullBackOff` | No route or rule from the overlay to the registry on 443. [portal] | Step 2 item 5. Registry seeding: skill `nkp-airgap`. |

Other failures: skill `nkp-troubleshooting`.

## Related skills

Create script and IP plan: skill `nkp-install`. Cilium, MTU, MetalLB pools, ingress certificate: skill `nkp-networking`. Cluster delete: skill `nkp-cluster-lifecycle`. Bundle and registry: skill `nkp-airgap`. Flow CNI: skill `nkp-flow-cni`. Prism Central objects: skill `nutanix-networking`, skill `nutanix-nkp`, skill `nutanix-storage`.
