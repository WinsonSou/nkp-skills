# Answers: nkp-vpc batch (B5)

Rules applied in every section: line 1 mark on every block, `source` on line 2, no CHANGES block runs before the user types `yes` to its plan, no value appended before the user gives it, no secret printed, no invented fact (UNKNOWN ids and "not in the skills" are used where the skills do not hold the fact).

---

## nkp-vpc V1

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md`, `skills/nkp-vpc/references/layouts.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`, `skills/nkp-networking/references/cni.md` (MTU, C4), `skills/nkp-networking/references/ingress-certs.md` (I1).

### Questions first

```text
ask_user_question (4 questions):

1. header "Delivery"
   Q: "Is this site connected, or air-gapped? The answer picks the create case (N4A/N4B/N4C) in the script I write."
   options:
   - "Connected, pull from docker.io/nutanix with the Nutanix Docker Hub token (Recommended if the bastion has internet)"
   - "Air-gapped, no site registry (NKP pushes the bundle into a registry inside the new cluster)"
   - "Air-gapped with a seeded site registry mirror (Harbor/Nexus/Artifactory)"

2. header "Names or IPs"
   Q: "For API_EXTERNAL_ENDPOINT and UI_HOSTNAME, do you want DNS names that resolve to the floating IPs, or the floating IPs themselves?"
   options:
   - "DNS names, e.g. nkp-a.corp.example.com (Recommended: the API certificate and the UI certificate are made for a name, and the name survives a floating IP change)"
   - "The floating IPs themselves"

3. header "Corp LAN route"
   Q: "Is the corp LAN routed to the VPC external subnet, so that users can reach the floating IPs? (This is a network-team fact, not an NKP setting.)"
   options:
   - "Yes, routed (Recommended)"
   - "No, not yet - I will ask the network team first"
   - "Not known"

4. header "More LB services"
   Q: "Will users outside the VPC need any LoadBalancer Service other than the NKP UI (for example an app ingress, or NDK)? Each one needs one more floating IP."
   options:
   - "No, only the API and the UI (Recommended for now)"
   - "Yes, one or two more - I will name them"
   - "Not known yet"
```

Values I must still get from you (no append block until you give each one): `SUBNET` (the overlay subnet name `tenant-a-nodes`) and the site values `PC_ENDPOINT`, `PE_CLUSTER`, `STORAGE_CONTAINER`, `VM_IMAGE`, `SSH_PUBKEY_FILE`; the cluster values `CP_VIP`, `LB_IP_RANGE`, `FIP_API`, `FIP_UI`, `API_EXTERNAL_ENDPOINT`, `UI_HOSTNAME`, and the list of VPC CIDRs that the nodes route to.

### Answer: layout and floating IP count

Facts used: `[portal]` = TN-2207 v2.0, `[pdf p.720-721]`, `[live 2.19.0]`.

- Your answers map to one row of the layout table: **exposed**, NAT external subnet, management cluster, bastion inside the VPC. `[portal]`
- **Floating IPs: 2.**
  - `FIP_API` → the private IP `CP_VIP`.
  - `FIP_UI` → the **first** IP of `LB_IP_RANGE` (Traefik takes it).
  - **+1 for each further `LoadBalancer` Service** that corp-LAN users must reach (question 4).
  - **No floating IP for the bastion**: it is in the VPC, so it reaches `CP_VIP` directly and it is the operator host of the create. The guide's 3-floating-IP form (bastion, `--extra-sans`, UI) `[pdf p.721]` does not apply here: the external endpoint already puts `FIP_API` in the API certificate `[live 2.19.0]`, and the bastion needs no outside access.
- A floating IP is a 1:1 NAT from the external-subnet IP to one private IP in the VPC, all ports, and it belongs to one VPC. The floating IP is never `CP_VIP`. `[portal]`
- The external subnet pool must hold every SNAT IP **and** these 2 floating IPs (plus 1 per extra Service). A VPC can have only one NAT external subnet. `[portal]`
- Version gate for this design: AOS and Prism Central **7.5 or later** (your 7.5 is the minimum, so OK), Network Controller **7.0.0 or later**, NKP **2.17 or later**. `[portal]` The skills are verified on 2.19.

### Answer: exactly what you add to the create

Nothing changes in the registry, subnet, image or size flags. Two lines go into the create script, **before** the final `"$@"`, and only in the exposed layout:

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
  --cluster-hostname "$UI_HOSTNAME" \
```

What those two flags do `[live 2.19.0]`:

- `--control-plane-external-endpoint` puts the external endpoint in the CAPI `Cluster`, in kubeadm `controlPlaneEndpoint`, in `cluster-info`, in the Cilium `KUBERNETES_SERVICE_HOST`, in the kubeconfig and in the API certificate names. kube-vip still holds `CP_VIP` in the overlay. The nodes join through `FIP_API`.
- `--cluster-hostname` sets `NKPCluster.spec.kommanderCluster.spec.ingress.hostname`; the UI certificate `kommander-traefik-tls` gets this name.
- `CP_VIP` is **not** in the API certificate names. `https://CP_VIP:6443` with TLS checks fails inside the VPC. Add `--extra-sans "$CP_VIP"` at create time only if you need that.

### Prerequisites in Prism Central (your actions, before the create)

1. External subnet on the AHV VLAN with "External Connectivity for VPCs" on, NAT, pool sized for SNAT + both floating IPs. `[portal]`
2. VPC `tenant-a` on that external subnet, with the default route the nodes need. `[portal]`
3. Overlay subnet `tenant-a-nodes` with IPAM on. Leave `CP_VIP` and `LB_IP_RANGE` **outside** its pool. `[portal][pdf p.720-721]`
4. **Before the create**: associate `FIP_API` with `CP_VIP` and `FIP_UI` with the first IP of `LB_IP_RANGE`. The nodes join through `FIP_API`. `[live 2.19.0]` UNKNOWN (N-43) in the skill is whether an after-create association also works - do it before.
5. From the overlay: TCP 9440 to Prism Central and TCP 443 to the registry. `[portal]`

### Check 1: the bastion MTU (the make-or-break item for a VPC)

VPC overlay NICs have MTU **1442**, Docker defaults to 1500. With 1500 in the kind bootstrap cluster, TLS to Prism Central fails during the bootstrap. `[portal]` V2 in this batch is exactly that failure.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
dev=$(ip route show default | awk '{print $5; exit}'); echo "nic $dev mtu $(cat "/sys/class/net/$dev/mtu")"
docker network inspect bridge --format 'bridge mtu {{index .Options "com.docker.network.driver.mtu"}}'
docker network inspect kind --format 'kind mtu {{index .Options "com.docker.network.driver.mtu"}} containers {{len .Containers}}' 2>/dev/null || echo "no kind network"
cat /etc/docker/daemon.json 2>/dev/null || echo "no daemon.json"
curl -sk -o /dev/null -m 10 -w 'pc %{http_code}\n' "$PC_ENDPOINT"
[ -z "$REGISTRY_URL" ] || curl -sk -o /dev/null -m 10 -w 'registry %{http_code}\n' "$REGISTRY_URL/v2/"
```

Done when: NIC, bridge and kind MTU are all 1442, and `pc` and `registry` print a code that is not `000`.

**Plan (CHANGES) - sets the Docker MTU to the NIC MTU and restarts Docker.** Target: this bastion, `/etc/docker/daemon.json` plus the Docker daemon. Result: the default bridge MTU becomes 1442; **all containers stop**, including any bootstrap cluster. Check `docker ps` first; it needs `sudo` without a password prompt. I stop here for `yes`.

```bash
# CHANGES  (sets the Docker MTU to the NIC MTU in /etc/docker/daemon.json and restarts Docker)
source ~/nkp-site.env 2>/dev/null
dev=$(ip route show default | awk '{print $5; exit}'); mtu=$(cat "/sys/class/net/$dev/mtu"); : "${mtu:?}"
f=/etc/docker/daemon.json; t=$(mktemp)
{ [ -s "$f" ] && cat "$f" || echo '{}'; } | jq --argjson m "$mtu" '.mtu = $m' > "$t" && sudo install -m 644 "$t" "$f" && rm -f "$t" && sudo systemctl restart docker
```

The `mtu` key changes only the default bridge; an existing `kind` network keeps its MTU. `[field]` If the kind network has the wrong MTU and `containers 0`, this second block (CHANGES, after `yes`):

```bash
# CHANGES  (makes the kind network again with the NIC MTU)
source ~/nkp-site.env 2>/dev/null
dev=$(ip route show default | awk '{print $5; exit}'); mtu=$(cat "/sys/class/net/$dev/mtu"); : "${mtu:?}"
[ "$(docker network inspect kind --format '{{len .Containers}}' 2>/dev/null || echo 0)" = 0 ] && { docker network rm kind 2>/dev/null; docker network create -o "com.docker.network.driver.mtu=$mtu" kind; }
```

### Check 2: pod and service CIDRs against the VPC ranges

This is the second classic VPC failure: an overlap loses the packets silently. `[portal]` Set `vpc_cidrs` to the list you give me (comma separated), then:

```bash
# READ-ONLY  (needs python3)
source ~/nkp-nkp-a.env 2>/dev/null
vpc_cidrs=''; pod_cidr='192.168.0.0/16'; svc_cidr='10.96.0.0/12'
: "${vpc_cidrs:?}"
python3 -c 'import ipaddress,sys; k=[ipaddress.ip_network(c) for c in sys.argv[1:3]]; v=[ipaddress.ip_network(c.strip()) for c in sys.argv[3].split(",")]; bad=[(str(a),str(b)) for a in k for b in v if a.overlaps(b)]; print("OVERLAP", bad) if bad else print("no overlap")' "$pod_cidr" "$svc_cidr" "$vpc_cidrs"
```

Done when it prints `no overlap`. On `OVERLAP` we pick free CIDRs together and add `--kubernetes-pod-network-cidr` and `--kubernetes-service-cidr` to the script; the CIDRs cannot be changed after the create. `[pdf p.724]`

### Create script and create

The script write block depends on the answer to question 1 (N4A connected / N4B internal bundle / N4C site mirror), so I do not show it yet. When you answer, I write it from `nutanix.md` with these two lines added before `"$@"`:

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
  --cluster-hostname "$UI_HOSTNAME" \
```

**Plan (CHANGES) - dry run.** Target: this bastion. Result: the create objects are printed to `./nkp-a-dryrun.yaml` (mode 600, it holds Secrets); **no cluster is created**. Stop for `yes`.

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-nkp-a.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Then I show you only these lines (the VPC-critical ones):

```bash
# READ-ONLY
source ~/nkp-nkp-a.env 2>/dev/null
grep -n -E '^ +host:|^ +address:|^ +hostname:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Done when a `host:` line shows your `API_EXTERNAL_ENDPOINT`, an `address:` line shows `CP_VIP`, and a `hostname:` line shows `UI_HOSTNAME`.

**Plan (CHANGES) - the create.** Target: `tenant-a` VPC in Prism Central via `PC_ENDPOINT`. Result: 3 control-plane and 4 worker VMs on the overlay subnet, a kind bootstrap cluster on this bastion, the pivot, Kommander. Stop for `yes`.

```bash
# CHANGES  (creates the cluster: a kind bootstrap cluster and VMs in Prism Central, then the pivot and Kommander)
source ~/nkp-nkp-a.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

### Verify

```bash
# READ-ONLY
source ~/nkp-nkp-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}api={.value.nutanix.controlPlaneEndpoint.host} vip={.value.nutanix.controlPlaneEndpoint.virtualIP.configuration.address}{"\n"}{end}ui={.spec.kommanderCluster.spec.ingress.hostname}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get svc kommander-traefik -o jsonpath='traefik={.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" config view --minify -o jsonpath='server={.clusters[0].cluster.server}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
curl -sk -o /dev/null -m 10 -w 'api %{http_code}\n' "https://${API_EXTERNAL_ENDPOINT:-$CP_VIP}:6443/version"
curl -sk -o /dev/null -m 10 -w 'ui %{http_code}\n' "https://${UI_HOSTNAME:-${LB_IP_RANGE%%-*}}/dkp/kommander/dashboard"
```

Done when: `api=` is `API_EXTERNAL_ENDPOINT`, `vip=` is `CP_VIP`, `ui=` is `UI_HOSTNAME`, `server=` uses `API_EXTERNAL_ENDPOINT`, `traefik=` is the first overlay IP of `LB_IP_RANGE`, all nodes are `Ready` on overlay IPs, `api 200` and `ui 302`. Then the dashboard command goes to you (rule 1):

```bash
# USER-TERMINAL
source ~/nkp-site.env 2>/dev/null
nkp get dashboard --kubeconfig "$MGMT_KUBECONFIG"
```

For corp-LAN users on kubectl: give them a kubeconfig from this cluster; its `server:` is `https://API_EXTERNAL_ENDPOINT:6443`, which they reach through `FIP_API`.

---

## nkp-vpc V2

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md` (N7), `skills/nkp-networking/references/cni.md` (C5, MTU).

### Questions first

```text
ask_user_question (4 questions):

1. header "Cluster name"
   Q: "Which cluster name is the hanging create using? I need it for ~/nkp-<cluster>.env."
   options:
   - "It is nkp-a (Recommended if this is the same cluster as the VPC conversation)"
   - "Another name - I will type it"

2. header "Operator host"
   Q: "Is the host where you run nkp create cluster the VPC VM (in tenant-a) or a host outside the VPC?"
   options:
   - "A VM in the same VPC (Recommended / expected in this layout)"
   - "A host outside the VPC"

3. header "Bootstrap state"
   Q: "Does a kind bootstrap cluster still exist from the failed attempt?"
   options:
   - "Not known - run the read-only check and tell me (Recommended)"
   - "Yes, it is still there"
   - "No, I already deleted it"

4. header "Cache of the exact error"
   Q: "What is the exact CAPX message - 'TLS handshake timeout' or an x509 certificate error? The two have different causes."
   options:
   - "TLS handshake timeout / i/o timeout (Recommended guess: this is the MTU)"
   - "x509: certificate signed by unknown authority / certificate error"
   - "Both appear"
```

### Answer: the cause

**A Docker/kind MTU that is higher than the VPC overlay NIC MTU.** VPC overlay NICs are MTU **1442**; Docker and therefore the kind bootstrap cluster use 1500 by default. `[portal]` The bootstrap cluster runs on the operator host and talks to Prism Central from inside a container: the small packets of `curl` pass, the large TLS flight does not, so CAPX logs `TLS handshake timeout` while `curl` to PC from the bastion "works fine". The skill lists this as the first cause of bootstrap TLS/handshake errors to Prism Central. `[portal]`

Two things that are **not** the cause here, so we do not "fix" them:

- An x509 error would be a certificate problem (self-signed PC → `PC_CA_FILE` / `--additional-trust-bundle`) `[pdf p.719]`, not a handshake timeout.
- A missing route to TCP 9440 from the overlay `[portal]` is excluded, because `curl` from the in-VPC bastion gets an answer. The read-only block proves it with an HTTP code.

### Check (proves it before any change)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
dev=$(ip route show default | awk '{print $5; exit}'); echo "nic $dev mtu $(cat "/sys/class/net/$dev/mtu")"
docker network inspect bridge --format 'bridge mtu {{index .Options "com.docker.network.driver.mtu"}}'
docker network inspect kind --format 'kind mtu {{index .Options "com.docker.network.driver.mtu"}} containers {{len .Containers}}' 2>/dev/null || echo "no kind network"
cat /etc/docker/daemon.json 2>/dev/null || echo "no daemon.json"
curl -sk -o /dev/null -m 10 -w 'pc %{http_code}\n' "$PC_ENDPOINT"
[ -z "$REGISTRY_URL" ] || curl -sk -o /dev/null -m 10 -w 'registry %{http_code}\n' "$REGISTRY_URL/v2/"
```

Expected: `nic ... mtu 1442`, `bridge mtu 1500` (or nothing) and `kind mtu 1500` → that is the bug. `pc 200`-class code confirms that PC is reachable with small packets.

### Fix

**Plan (CHANGES) - Docker MTU.** Target: this bastion, `/etc/docker/daemon.json` plus the daemon. Result: the default bridge MTU becomes the NIC MTU (1442). **All containers stop**, so the failed bootstrap cluster must be gone or will stop. Needs `sudo` without a password prompt; if it prompts, you run the block. I stop for `yes`.

```bash
# CHANGES  (sets the Docker MTU to the NIC MTU in /etc/docker/daemon.json and restarts Docker)
source ~/nkp-site.env 2>/dev/null
dev=$(ip route show default | awk '{print $5; exit}'); mtu=$(cat "/sys/class/net/$dev/mtu"); : "${mtu:?}"
f=/etc/docker/daemon.json; t=$(mktemp)
{ [ -s "$f" ] && cat "$f" || echo '{}'; } | jq --argjson m "$mtu" '.mtu = $m' > "$t" && sudo install -m 644 "$t" "$f" && rm -f "$t" && sudo systemctl restart docker
```

The `mtu` key changes only the default bridge; an old `kind` network keeps its MTU. `[field]` **Plan (CHANGES) - remake the kind network** when it has the wrong MTU and `containers 0` (= no bootstrap cluster inside it). Stop for `yes`.

```bash
# CHANGES  (makes the kind network again with the NIC MTU)
source ~/nkp-site.env 2>/dev/null
dev=$(ip route show default | awk '{print $5; exit}'); mtu=$(cat "/sys/class/net/$dev/mtu"); : "${mtu:?}"
[ "$(docker network inspect kind --format '{{len .Containers}}' 2>/dev/null || echo 0)" = 0 ] && { docker network rm kind 2>/dev/null; docker network create -o "com.docker.network.driver.mtu=$mtu" kind; }
```

**Plan (CHANGES) - remove the failed bootstrap cluster.** Target: this bastion, the kind cluster only. Result: no leftover bootstrap; nothing in Prism Central is touched by this block. Stop for `yes`.

```bash
# CHANGES  (deletes the kind bootstrap cluster on the operator host)
source ~/nkp-site.env 2>/dev/null
nkp delete bootstrap
```

Then run the create again (the same script). Re-check with the read-only block: `nic`, `bridge` and `kind` MTU must all be 1442, and after the create `pc` and `registry` must answer.

UNKNOWN (N-40) in the skill: whether `nkp` makes the kind network with the Docker bridge MTU when no kind network exists. If the second block does not apply, the check after `nkp create bootstrap` answers it.

If the MTU is already 1442 everywhere, the next candidate is outside the VPC skill and the debug ladder takes over (skill `nkp-troubleshooting`, the bootstrap section of `controllers.md`).

---

## nkp-vpc V3

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md`, `skills/nkp-networking/SKILL.md`, `skills/nkp-networking/references/ingress-certs.md` (I1, I2, I4), `skills/nkp-networking/references/cni.md` (C4), `skills/nkp-install/SKILL.md` (dashboard block).

### Answer

"Just run it" is not `yes` (rule 2). Below is the exact command, the target and the result. Say `yes` and I run it.

The cause is known: the cluster was created **without** `--cluster-hostname`, so `spec.kommanderCluster.spec.ingress.hostname` holds the Traefik IP, which is an overlay address (`172.x`). `[live 2.19.0]` The fix is one field on the **NKPCluster** in namespace `kommander` - not on the KommanderCluster, which the NKPCluster owns. `[live 2.19.0]`

### Questions first

```text
ask_user_question (3 questions):

1. header "Hostname form"
   Q: "Is UI_HOSTNAME a DNS name (e.g. nkp-a.corp.example.com) or the floating IP itself?"
   options:
   - "A DNS name whose A record points to FIP_UI (Recommended: the UI certificate is issued for this name)"
   - "The floating IP itself"

2. header "Floating IP association"
   Q: "In Prism Central, is FIP_UI already associated with the FIRST IP of LB_IP_RANGE (the Traefik IP shown by the read-only block)?"
   options:
   - "Yes, associated (Recommended)"
   - "No / not sure - the read-only block tells me the Traefik IP and I will check Prism Central"

3. header "Env file"
   Q: "Do I use ~/nkp-nkp-a.env for this cluster, with WORKSPACE_NS=kommander?"
   options:
   - "Yes (Recommended: it is the management cluster)"
   - "No - another file / another workspace namespace"
```

### Step 1: read the state (READ-ONLY, runs now)

```bash
# READ-ONLY
source ~/nkp-nkp-a.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS MGMT_KUBECONFIG CLUSTER_KUBECONFIG UI_HOSTNAME FIP_UI; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='ingress={.spec.kommanderCluster.spec.ingress}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get svc kommander-traefik -o jsonpath='traefik={.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" config view --minify -o jsonpath='server={.clusters[0].cluster.server}{"\n"}'
```

Done when: six `set:` lines, `ingress={"hostname":"172.x.x.x"}` (the old value), `traefik=` = first IP of `LB_IP_RANGE`, and `server=` = `https://API_EXTERNAL_ENDPOINT:6443`. If `UI_HOSTNAME` or `FIP_UI` prints `MISSING`, the env file needs the line - I add it only after you confirm the value (rule 4).

### Step 2: preview (READ-ONLY, server dry run, changes nothing)

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-nkp-a.env 2>/dev/null
p=$(printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s"}}}}}' "$UI_HOSTNAME")
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type merge -p "$p" --dry-run=server -o jsonpath='{.spec.kommanderCluster.spec.ingress}{"\n"}'
```

Done when the output shows `hostname` = your `UI_HOSTNAME` and the API server accepted the patch.

### Step 3: the plan, then `yes`

- **Command:** the merge patch below.
- **Target:** NKPCluster `nkp-a` in namespace `kommander` on the management cluster (`MGMT_KUBECONFIG`). One field: `spec.kommanderCluster.spec.ingress.hostname`, `172.x` → `UI_HOSTNAME`.
- **Result:** the Kommander ingress is reconciled to the new name; the UI certificate `kommander-traefik-tls` is re-issued for `UI_HOSTNAME`; **the UI URL changes** - old bookmarks to the IP stop being the documented URL; `nkp get dashboard` prints the new URL. Nothing else in the cluster changes, no node restarts.

Stop here. I run it after you type `yes`.

```bash
# CHANGES  (sets the UI hostname of the cluster ingress)
source ~/nkp-nkp-a.env 2>/dev/null
p=$(printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s"}}}}}' "$UI_HOSTNAME")
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type merge -p "$p"
```

### Step 4: verify

```bash
# READ-ONLY
source ~/nkp-nkp-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}api={.value.nutanix.controlPlaneEndpoint.host} vip={.value.nutanix.controlPlaneEndpoint.virtualIP.configuration.address}{"\n"}{end}ui={.spec.kommanderCluster.spec.ingress.hostname}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommandercluster "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[?(@.type=="IngressAddressReady")]}{.type}={.status} {.reason}{"\n"}{end}{range .status.conditions[?(@.type=="IngressCertificateReady")]}{.type}={.status} {.reason}{"\n"}{end}'
curl -sk -o /dev/null -m 10 -w 'ui %{http_code}\n' "https://${UI_HOSTNAME:-${LB_IP_RANGE%%-*}}/dkp/kommander/dashboard"
```

Done when: `ui=` is `UI_HOSTNAME`, `IngressAddressReady=True IngressServiceAddressFound`, `IngressCertificateReady=True Ready`, and `ui 302`.

If `ui 000` while `api 200`: check that `FIP_UI` is associated with the `traefik=` IP in Prism Central, then Cilium DSR (skill `nkp-networking`, `cni.md` C4, open item N-01) - on a VPC overlay subnet a node that does not own the Service IP can send the reply and the network drops it. That fix is a new cluster with `loadBalancer.mode: snat`, not a patch.

Then the dashboard URL, for your own terminal (rule 1 - it shows the admin password):

```bash
# USER-TERMINAL
source ~/nkp-site.env 2>/dev/null
nkp get dashboard --kubeconfig "$MGMT_KUBECONFIG"
```

Note on a DNS `UI_HOSTNAME`: the name needs an A record to `FIP_UI` first (`[pdf p.970]`, skill `nkp-networking`, `ingress-certs.md` I2), otherwise the certificate is right but browsers cannot resolve it.

---

## nkp-vpc V4

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/delete.md` (D1-D5), `skills/nkp-vpc/SKILL.md` (step 7), `skills/nkp-vpc/references/layouts.md`.

### Questions first

```text
ask_user_question (4 questions):

1. header "Workspace namespace"
   Q: "Which workspace namespace holds the NKPCluster of tenant-b-dev? I must pass it; nkp delete cluster defaults to kommander, which would target the wrong cluster."
   options:
   - "kommander-default-workspace (Recommended default for a workload cluster)"
   - "Another workspace namespace - I will type it"

2. header "Data"
   Q: "Do the PVCs of tenant-b-dev hold data that you need? The delete removes the node disks and all cluster data and cannot be undone."
   options:
   - "No data is needed - delete it (Recommended if this is a teardown)"
   - "There is data but it is backed up already (Velero) - delete it"
   - "There is data I still need - stop, take a backup first"

3. header "VPC afterwards"
   Q: "After the cluster is gone, do you also want the tenant VPC deleted in Prism Central?"
   options:
   - "Delete the floating IPs and the overlay subnet, keep the VPC for now (Recommended: safest, easy to reuse)"
   - "Delete everything, including the VPC"
   - "Delete only the floating IPs"

4. header "Operator host files"
   Q: "May I also remove the local files of this cluster (create script, dry-run file with Secrets, kubeconfig, cluster env file)? I show the exact list first."
   options:
   - "Yes, remove them after the cluster is gone (Recommended)"
   - "Keep them for now"
```

Values I need: `WORKSPACE_NS` (question 1). If `~/nkp-tenant-b-dev.env` does not exist, I make it (CHANGES) and append `CLUSTER_NAME='tenant-b-dev'`, `WORKSPACE_NS=...`, and the kubeconfig path - each only after you confirm it.

### Step 1: record what the cluster owns in Prism Central (before anything is deleted)

UNKNOWN (N-05) in the skill: the full list of objects that stay after a delete in a VPC. So we record first.

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
echo "cluster=$CLUSTER_NAME vpc=$VPC_NAME subnet=$SUBNET fip_api=$FIP_API fip_ui=$FIP_UI vip=$CP_VIP lb=$LB_IP_RANGE"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o name
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,IP:.status.loadBalancer.ingress[0].ip
```

UNKNOWN (P-11): whether the delete leaves the Nutanix CSI volume groups. Record them now, and compare in Prism Central after the delete:

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns=NAME:.metadata.name,HANDLE:.spec.csi.volumeHandle
```

Give me these lists and I keep them for step 5.

### Step 2: identify the cluster (D1)

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host,PHASE:.status.phase,CP:.spec.capiCluster.topology.controlPlane.replicas'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
```

Done when: the row shows `tenant-b-dev` with `MGMT` empty/false and a workspace namespace → it is a workload cluster, so D2/D3. If `MGMT` is `true` or the namespace is `kommander`, stop: that would be the management cluster delete (D4), a different plan.

### Step 3: safety gate (D2)

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nkpclusters -A
```

Stop conditions: the last command lists an NKPCluster (this cluster manages others - delete those first `[pdf p.718]`), or a PVC holds data you need, or the name is not exactly `tenant-b-dev`.

### Step 4: the plan, then `yes` **and the name**

- **Command:** `nkp delete cluster` below.
- **Target:** workload cluster `tenant-b-dev` in namespace `$WORKSPACE_NS`, driven from the management cluster (`MGMT_KUBECONFIG`), with `--timeout 30m`.
- **Goes:** all nodes and VMs on the VPC overlay subnet, all pods, all PVC data, every `LoadBalancer` Service of the cluster first (NKP deletes them). `[pdf p.814]` The floating IPs and the overlay subnet in Prism Central are **not** deleted by NKP - step 5.
- **Stays:** the VPC, subnets and floating IPs in Prism Central `[portal/live]`; the Prism Central images; the local files (until question 4); `CP_VIP` and `LB_IP_RANGE` become free.
- **Cannot be undone.**

Approval needs the exact cluster name in the same message: `yes, delete tenant-b-dev`.

```bash
# CHANGES  (deletes the workload cluster: its VMs, nodes, and data; cannot be undone)
source ~/nkp-tenant-b-dev.env 2>/dev/null
nkp delete cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m
```

Expected output: "Deleting Services with type LoadBalancer", "Deleting ClusterResourceSets", "Deleting cluster resources", "Waiting for the cluster to be fully deleted", "Deleted ... cluster". `[pdf p.814]`

### Step 5: prove nothing is left on the NKP side

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters,clusters.cluster.x-k8s.io,machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME"
```

Done when both show "No resources found" / "NotFound". If the NKPCluster stays (the UI would show the cluster in `Error` `[pdf p.496]`), first confirm that no Machine exists, then this cleanup (CHANGES, plan first, `yes` needed):

```bash
# CHANGES  (deletes the NKPCluster object on the management cluster)
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete nkpcluster "$CLUSTER_NAME" --wait=false
```

The finalizers are `capicluster-cleanup` and `kommandercluster-cleanup`. `[live 2.19.0]` Removing a finalizer skips the cleanup and can leave VMs in Prism Central - never do it while machines exist; that case is skill `nkp-troubleshooting`.

### Step 6: Prism Central - your actions, one confirmation each

NKP has no object for a VPC, a subnet, or a floating IP, so `nkp delete cluster` cannot remove them. `[live 2.19.0]`

1. **VMs:** no VM with the `tenant-b-dev` name prefix stays.
2. **Floating IPs:** disassociate and delete `FIP_API`, `FIP_UI`, and each floating IP of a `LoadBalancer` Service from step 1 - unless another cluster uses one.
3. **Volume groups:** look for the volume handles recorded in step 1 (open item P-11).
4. **Overlay subnet:** delete only if no other VM (the bastion, another cluster) uses it.
5. **VPC:** delete only if it has no subnet and no VM left. Your answer to question 3 decides.
6. **External subnet:** keep it - other VPCs use it.
7. `CP_VIP` and `LB_IP_RANGE` are free again in the overlay subnet.

### Step 7: operator host files (only if you answered yes to question 4)

List first. Exact names only - never a `*` after the cluster name (`nkp-dev-*` would also match `dev-01`).

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
for f in "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/nkp-$CLUSTER_NAME-patch.json" "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml" "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-metallb-conf.yaml" "$CLUSTER_KUBECONFIG" "$HOME/nkp-$CLUSTER_NAME.env"; do [ -e "$f" ] && ls -l "$f"; done; true
```

**Plan (CHANGES) - remove exactly those files.** Target: this operator host. Result: the files of `tenant-b-dev` are gone, including the dry-run file that holds Secrets; the cluster env file goes last because the other names come from it. `~/nkp-site.env` is never touched. Stop for `yes`.

```bash
# CHANGES  (deletes the local files of the deleted cluster)
source ~/nkp-tenant-b-dev.env 2>/dev/null
: "${CLUSTER_NAME:?}"
rm -f -- "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/nkp-$CLUSTER_NAME-patch.json" "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml" "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-metallb-conf.yaml" ${CLUSTER_KUBECONFIG:+"$CLUSTER_KUBECONFIG"} && rm -f -- "$HOME/nkp-$CLUSTER_NAME.env"
```

---

## nkp-vpc V5

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md`, `skills/nkp-vpc/references/layouts.md` (L5), `skills/nkp-flow-cni/SKILL.md` (step 1, step 3), `skills/nkp-flow-cni/references/egress-vpc.md` (V1), `skills/nkp-networking/references/cni.md` (C1, C4, C5).

### Questions first

```text
ask_user_question (3 questions):

1. header "Cluster"
   Q: "Is this about a cluster that already exists, or a new one you want to plan?"
   options:
   - "Planning a new cluster for team separation (Recommended)"
   - "A cluster already running in a VPC - I will name it"

2. header "Prism Central / NC version"
   Q: "Flow CNI 1.1.0 needs Prism Central pc.7.6 or later and Network Controller 7.6.0 or later. What does the site run?"
   options:
   - "PC 7.5 / NC 7.0 - we are below the Flow CNI minimum (Recommended guess from V1 in this batch)"
   - "PC 7.6 or later and NC 7.6.0 or later"

3. header "Goal"
   Q: "What must be separated: tenants from each other, or each namespace of one cluster from the others?"
   options:
   - "Tenants must not see each other's networks (Recommended: one VPC and one cluster per tenant)"
   - "Namespaces inside one cluster need their own VPC"
```

### Answer: no, do not combine them

Two different uses of Flow are being mixed:

| | NKP in a Flow VPC (`nkp-vpc`) | Flow CNI (`nkp-flow-cni`) |
|---|---|---|
| Flow gives | the **node** network: VPC, overlay subnet, floating IPs | the **pod** network: namespaces mapped to VPCs |
| CNI | Cilium (default) | Flow CNI replaces Cilium |
| Node subnet | VPC **overlay** subnet | **VLAN Basic** (AHV-managed) subnets, not an overlay subnet |
| LoadBalancer IPs | MetalLB on the overlay + floating IPs for outside | MetalLB only |

- **Open item N-04:** no source says that nodes on a VPC overlay subnet can use Flow CNI. Only Nutanix support can answer it. The skill's instruction is explicit: **do not combine them.** `skills/nkp-vpc/references/layouts.md` L5, `skills/nkp-flow-cni/SKILL.md` step 1.
- The reason is a hard prerequisite: Flow CNI 1.1.0 needs **VLAN Basic (AHV-managed) node subnets**, plus PC **7.6 or later** and Network Controller **7.6.0 or later** in "Integrated with Prism Central" mode, AOS 7.6+/AHV 11.2+, NKP 2.18 or later, and **Rocky Linux** on all nodes. Nodes on a VPC overlay subnet do not meet the VLAN Basic requirement. `[portal]`

### What to do instead

- **Tenant separation (question 3 = tenants):** give each tenant **its own VPC and its own cluster**, CNI stays Cilium. That is the per-tenant NKP row of L1, and the skill's recommendation for tenant separation with Cilium. Tenant overlay ranges may then even overlap, and each tenant gets one bastion with a floating IP. `[portal]`
- **Namespaces inside one cluster:** that is Flow CNI's own job - namespaces mapped to extra VPCs in Prism Central (Shared Services VPC per cluster, one pod CIDR per VPC). It requires the VLAN Basic node subnets above, so it is a **different cluster** from the one on the VPC overlay. Also note: pods that exist before the mapping stay in the Shared Services VPC, so map a namespace before you deploy into it. `[portal]`
- Both are only possible at create time: the CNI provider cannot be changed on a running cluster. `[pdf p.497-498][live 2.19.0]`

### Check (before any plan, takes 1 minute)

The cluster name is not known yet, so the file name stays a placeholder (rule 3). Replace `<cluster>` when you name it.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
echo "VM_IMAGE=$VM_IMAGE"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get clusterclass -o custom-columns='NAME:.metadata.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get --raw "/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy/v2/charts/nutanix-flow-cni/tags/list"; echo
```

Done when: the image name has `rocky`, the workspace namespace has a class `nkp-nutanix-v2.19.0`, and the ConfigMap plus the tag list show the same `nutanix-flow-cni` chart version. Even then, the VLAN Basic node subnet and PC/NC 7.6 items must come from you - and they are exactly what a VPC overlay node subnet breaks.

---

## nkp-vpc V6

**Skill files read:** `skills/nkp/SKILL.md` (license tiers), `skills/_shared/RULES.md` (rule 6), `skills/nkp-vpc/SKILL.md`, `skills/nkp-vpc/references/layouts.md` (L3, L6), `skills/nkp-flow-cni/SKILL.md` (step 1).

### Answer: both facts are **not in the skills**

- **Max floating IPs per VPC in Prism Central 7.5:** not in the skills. TN-2207 v2.0 (the source for the VPC skill) gives no per-VPC floating IP maximum. `skills/nkp-vpc/references/layouts.md` L6 lists the limits it does know (one NAT external subnet per VPC, floating IPs belong to one VPC, two VPCs may map the same private IP), and a maximum per VPC is not one of them. I will not make up a number.
- **NCI license for Flow Virtual Networking:** not in the skills, by design. `layouts.md` L6 says: "Flow Virtual Networking needs a license tier that the site must confirm. TN-2207 gives no tier. [portal] Not in the skills: the exact tier." The NKP license tiers (Starter/Pro/Ultimate) in the router skill are the **NKP** license, a different thing from the NCI/AOS license that enables Flow Virtual Networking.
- Flow CNI's own license tier is UNKNOWN (F-08) in `nkp-flow-cni/SKILL.md`: "the license tier that it needs" is not known; the check given is the NKP license list, then ask Nutanix.

### What the skills do give you (this is the part that sizes your site)

- **One NAT external subnet per VPC.** `[portal]`
- **Size the external subnet pool for all SNAT IPs plus all floating IPs of all VPCs on it:** 2 per exposed cluster, 1 per `LoadBalancer` Service that outside users need, 1 per bastion with outside access. `[portal]` (L3) This is the practical ceiling you must plan against, and it is a pool-size fact, not a per-VPC maximum.
- A floating IP is a 1:1 NAT to one private IP in the VPC, all ports, and it belongs to one VPC. The floating IP is never `CP_VIP`. `[portal]`

### Check it on your side (not from a skill)

These are outside the skills; they are the only honest route to both numbers, and they are READ-ONLY for me:

1. Prism Central → Infrastructure → Network → your external subnet: the free IP count of the pool bounds the **usable** floating IPs today (SNAT shares that pool).
2. Prism Central → Settings → Licensing, or your Nutanix account team: which NCI/AOS edition and license tier enables Flow Virtual Networking on PC 7.5, and its documented per-VPC limits. Nutanix support is the authority for a per-VPC maximum.
3. If the question is really about the NKP side, the tier is visible on the management cluster (cluster name not given yet, so the file name stays a placeholder):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps -o custom-columns='NAME:.metadata.name,TIER:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing'
```

That prints the **NKP** tier (Starter/Pro/Ultimate) `[live 2.19.0]` - it does not answer the NCI question. Also note the Flow CNI version gate: Flow CNI needs PC 7.6+, so on PC 7.5 Flow CNI is not available at all; Flow **VPC/networking** is available from 7.5 (TN-2207 range), which is the part your floating IP question belongs to. `[portal]`

### Questions first

```text
ask_user_question (2 questions):

1. header "Which limit"
   Q: "Do you need the per-VPC floating IP maximum for planning, or the external subnet pool size? They are different numbers."
   options:
   - "External subnet pool size for the whole site (Recommended: this one the skills can size)"
   - "The documented per-VPC maximum from Nutanix (I will ask Nutanix support / the PC admin)"

2. header "License source"
   Q: "Who can confirm the NCI license edition for Flow Virtual Networking?"
   options:
   - "Our Nutanix account team / support case (Recommended)"
   - "The Prism Central admin (Settings > Licensing)"
   - "Not known"
```

---

## nkp-vpc V7

**Skill files read:** `skills/nkp/SKILL.md` (cluster types, license tiers), `skills/_shared/RULES.md`, `skills/nkp-vpc/SKILL.md` (steps 1-5), `skills/nkp-vpc/references/layouts.md` (L1, L3, L4, L5, L6), `skills/nkp-install/SKILL.md` (N5 path), `skills/nkp-install/references/nutanix.md` (N1, N5), `skills/nkp-networking/references/ingress-certs.md` (I1).

### Questions first

```text
ask_user_question (4 questions):

1. header "External subnet"
   Q: "What is the external subnet of team X's VPC - NAT or no-NAT?"
   options:
   - "NAT (Recommended: then outside users and the management cluster reach the cluster through 2 floating IPs)"
   - "No-NAT, and the network team routes the overlay range (then no floating IP is needed)"
   - "Not known - I will ask the network team"

2. header "Who uses team X cluster"
   Q: "Who must reach the API and the UI of team X's cluster?"
   options:
   - "Team X users on the enterprise VLAN / corp LAN (Recommended)"
   - "Only VMs inside team X's VPC"
   - "Team X users, plus other clusters in the same VPC"

3. header "Management cluster path"
   Q: "Can the management cluster's network reach Prism Central on 9440 and the new cluster's floating IP? TN-2207 requires one of the two ('register them by floating IP or FQDN')."
   options:
   - "Yes, both (Recommended)"
   - "Prism Central yes, the tenant VPC only through a transit VPC"
   - "Not known"

4. header "Workspace"
   Q: "Does team X already have a workspace namespace on the management cluster?"
   options:
   - "Yes - I will name it (Recommended)"
   - "No - we need a workspace first (skill nkp-identity-security)"
   - "Put it in kommander-default-workspace for now"
```

Values I need before any create: `VPC_NAME`, `SUBNET` (overlay), `CP_VIP`, `LB_IP_RANGE`, `FIP_API`, `FIP_UI`, `API_EXTERNAL_ENDPOINT`, `UI_HOSTNAME`, `WORKSPACE_NS`, `CLUSTER_NAME`, and the VPC CIDR list. The cluster name is not given, so I keep `~/nkp-<cluster>.env` in the blocks and ask for it (rule 3).

### Answer: the layout is "mixed" (L1)

Management cluster on the enterprise VLAN, workload clusters one VPC per tenant:

| Item | Your case |
|---|---|
| Management cluster | on the enterprise VLAN subnet, self-managed, **needs no floating IP at all** `[portal]` |
| Workload cluster for team X | in team X's own VPC, created **by the management cluster**, in team X's workspace namespace `[portal]` |
| How the management cluster reaches it | `FIP_API` of the team X cluster (exposed layout) - TN-2207: "register them by floating IP or FQDN" `[portal]` |
| Floating IPs | 2 (`FIP_API` → `CP_VIP`, `FIP_UI` → first IP of `LB_IP_RANGE`), +1 per extra outside `LoadBalancer` Service |

### What you need, in order

1. **Prism Central objects for team X** (you, in Prism Central): an external subnet with "External Connectivity for VPCs" (NAT, pool sized for SNAT + 2 floating IPs, or no-NAT with the overlay range routed by the network team); the VPC; an overlay subnet with IPAM on, with `CP_VIP` and `LB_IP_RANGE` reserved outside its pool; both floating IPs associated **before** the create. `[portal][pdf p.720-721]`
2. **Unique ranges.** The team X overlay range and its pod/service CIDRs must not overlap any range the nodes route to - also not the enterprise VLAN, the management cluster CIDRs, or another tenant VPC. Overlap = silent packet loss. `[portal]` The CIDRs cannot be changed after the create. `[pdf p.724]`
3. **Register placement.** The nodes pull from the overlay subnet on 443. Registry places that work: in the same VPC on the overlay; in a shared transit VPC; or on the external VLAN through the external subnet. `[portal]` `NTP_SERVERS` is mandatory on an air-gapped site and must be reachable from the overlay. `[pdf p.724]`
4. **Storage.** The storage container must be in the Prism Element cluster of the nodes; CSI does not use VPC objects. `[pdf p.720]`
5. **Workspace namespace** on the management cluster for team X (`--namespace`). The CLI default `kommander` is for the management cluster only. `[live 2.19.0]`
6. **Create the workload cluster from the management cluster** (N5, no `--self-managed`), with the exposed flags. Add these two lines before `"$@"` in the N5 script block:

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
  --cluster-hostname "$UI_HOSTNAME" \
```

7. **Operator host.** The N5 create still runs on an operator host with a container engine and the kind bootstrap cluster, and it needs the MTU fix of V1/V2 if that host is a VM on a VPC overlay (MTU 1442). Whether a create of an **exposed** cluster works from an operator host **outside** the VPC is open item N-41 in the skill; the safe answer is a bastion VM inside the team X VPC (one floating IP for it if people outside must log in). `[portal]`
8. **Proxy.** If the site has an HTTP proxy, add `CP_VIP`, `API_EXTERNAL_ENDPOINT`, `UI_HOSTNAME` and the first IP of `LB_IP_RANGE` to the no-proxy list (skill `nkp-networking`, `proxy.md` X2). `[portal]`

### Before the create: two read-only checks

Management cluster reachability and the workspace (the cluster name is a placeholder until you name it):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{.items[*].spec.kommanderCluster.spec.ociRegistry.mirrorURL}{"\n"}'
curl -sk -o /dev/null -m 10 -w 'pc %{http_code}\n' "$PC_ENDPOINT"
```

Done when: team X's workspace namespace is listed, and `pc` is not `000`. An empty mirror line means the management cluster has no site registry mirror - that decides the registry flags of the N5 script. (UNKNOWN (A-06) in `nutanix.md` covers the internal-mirror-only case; I ask you then, I do not guess.)

CIDR overlap check against the VPC ranges you give me:

```bash
# READ-ONLY  (needs python3)
source ~/nkp-<cluster>.env 2>/dev/null
vpc_cidrs=''; pod_cidr='192.168.0.0/16'; svc_cidr='10.96.0.0/12'
: "${vpc_cidrs:?}"
python3 -c 'import ipaddress,sys; k=[ipaddress.ip_network(c) for c in sys.argv[1:3]]; v=[ipaddress.ip_network(c.strip()) for c in sys.argv[3].split(",")]; bad=[(str(a),str(b)) for a in k for b in v if a.overlaps(b)]; print("OVERLAP", bad) if bad else print("no overlap")' "$pod_cidr" "$svc_cidr" "$vpc_cidrs"
```

### Open items you must know before you spend a day on this

- **N-44:** whether a management cluster outside the VPC can create a workload cluster in a VPC with only `FIP_API` (no route to the overlay). The skill gives the check to run **after** the create, and TN-2207 only says "register them by floating IP or FQDN". `[portal]`
- **N-41:** whether a create of an exposed cluster works from an operator host outside the VPC.
- **N-45:** which DNS server the overlay subnet gives the nodes, and whether it must resolve `API_EXTERNAL_ENDPOINT` and `UI_HOSTNAME`. Check after the create: `getent hosts "$API_EXTERNAL_ENDPOINT" "$UI_HOSTNAME"` on the bastion in the VPC.
- **L6:** a VM in a VPC cannot also have a plain VLAN NIC `[field]`, so a team X node is in the tenant VPC only and cannot sit on the enterprise VLAN at the same time. Team X's users therefore need floating IPs (or a transit VPC), not "just a VLAN".
- **Do not use Flow CNI here** (V5 answer): Flow CNI needs VLAN Basic node subnets, and nodes on a VPC overlay do not meet that (open item N-04).

Once you answer the four questions and give the values, I write the N5 create script with the two extra lines, then we do the dry run (`N4D`): I show you the plan (dry-run file path, that it holds Secrets, no cluster created), you type `yes`, and only then the create runs.
