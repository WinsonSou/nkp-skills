# Batch 2 eval — answers (part 2)

All blocks are bash. The operator host login shell is zsh, so start a bash shell first (`bash`) or write each block to a file and run `bash <file>`. Line 1 of every block is the mark. Line 2 sources the env file that the block uses.

No block below was run: there is no live cluster and no shell access to the operator host in this session. Every command is given to you to run or approve.

---

## nkp-networking W1

Skill files read: `skills/nkp/SKILL.md`, `skills/nkp-networking/SKILL.md`, `skills/nkp-networking/references/proxy.md`, `skills/nkp-networking/assets/no-proxy-base.txt`, `skills/nkp-networking/references/cni.md` (C2, for the CIDR entries), `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md` (N1, N2, N4C, N4D), `skills/_shared/RULES.md`.

**Answer: four things — two env values, one built no-proxy list, and one 3-line addition to your create script.** The LB range and the VIP are already in the file, so nothing is missing there.

### Facts

- A proxy site needs the proxy in **three** places: the operator host/bootstrap cluster, the CAPI controllers, the nodes — and then the platform-app pods after the create. [pdf p.666, p.980]
- On Nutanix AHV, `nkp create cluster nutanix` makes the bootstrap cluster and the capi-components itself, so **one** set of flags covers them. [pdf p.666]
- `--registry-url` / `--registry-cacert` are **not** a mirror. Your internal mirror needs `--registry-mirror-url` + `--registry-mirror-cacert` (case N4C). [pdf p.723]
- Internal hosts (Prism Central, the registry mirror, your internal domain) must be in the no-proxy list, or their traffic goes to the squid. [pdf p.669]
- UNKNOWN (N-23): whether `--http-proxy` on Nutanix sets **both** `clusterConfig.proxy` and the CAPI controllers. We check that on the dry run below.

### Questions before I write any value

1. Is the proxy reached as `http://proxy.corp.example.com:3128`? I use that form below; confirm the scheme.
2. Does the squid need a user and password? If yes, it is a secret: you type those lines with an editor, I do not see them and do not write them (rule 5).
3. Is this site air-gapped with your seeded registry mirror (case N4C), so the script also needs `--airgapped`, `--bootstrap-cluster-image`, `--registry-mirror-*` and `--ntp-servers`? Or is it connected?
4. Give me these, for the no-proxy list: the Prism Central host, the registry mirror host, your internal DNS domain(s), the node subnet CIDR, and — if this management cluster will host workload clusters — each workload-cluster API VIP later.
5. Are the pod and service CIDRs the defaults (`192.168.0.0/16`, `10.96.0.0/12`)?

### Step 1: read the current state (nothing changes)

```bash
# READ-ONLY
source ~/nkp-nkp-mgmt.env 2>/dev/null
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NKP_HTTP_PROXY NKP_HTTPS_PROXY NO_PROXY_LIST; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in NUTANIX_USER NUTANIX_PASSWORD REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
```

This prints names only, never values.

### Step 2: write the two proxy values (needs your "yes")

**Command:** append two lines to `~/nkp-site.env`. **Target:** the operator host file only. **Result:** `NKP_HTTP_PROXY` and `NKP_HTTPS_PROXY` exist for every later block. Nothing on a cluster changes.

```bash
# CHANGES  (appends the proxy URLs to the site env file)
source ~/nkp-site.env 2>/dev/null
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
echo "export NKP_HTTP_PROXY='http://proxy.corp.example.com:3128'" >> ~/nkp-site.env
echo "export NKP_HTTPS_PROXY='http://proxy.corp.example.com:3128'" >> ~/nkp-site.env
```

Stop here. Type **yes** (and confirm the scheme from question 1) and I run it.

If the squid needs credentials: do **not** put them in the line above. You add the credential form of both lines in your own terminal:

```bash
# USER-TERMINAL  (you edit the site env file; the proxy password is a secret)
vi ~/nkp-site.env
```

### Step 3: build the no-proxy list (read-only preview)

Set `dir` to the skill folder, and put your confirmed internal entries in `extra` (comma, no space). The two CIDR values are the ones you confirm in question 5.

```bash
# READ-ONLY  (prints the list; changes nothing)
source ~/nkp-nkp-mgmt.env 2>/dev/null
dir='/tmp/nkp-eval-b2n/skills/nkp-networking'; extra=''; aws='no'; pods='192.168.0.0/16'; svcs='10.96.0.0/12'
: "${dir:?}" "${CP_VIP:?}" "${LB_IP_RANGE:?}"
base=$(awk -v a="$aws" '$1=="all" || ($1=="aws" && a=="yes") {print $2}' "$dir/assets/no-proxy-base.txt" | paste -sd, -)
echo "$base,$pods,$svcs,$CP_VIP,${LB_IP_RANGE%%-*}${extra:+,$extra}"
```

`extra` must contain at least the Prism Central host, the registry mirror host, and your internal domain with a leading dot (for example `.corp.example.com`). A domain suffix goes in twice in the base list with a trailing dot, and your domain entries need the same care: without the trailing-dot form some clients add the search domain and send cluster traffic to the proxy. [pdf p.980]

### Step 4: save the list (needs your "yes")

**Command:** append `NO_PROXY_LIST` to `~/nkp-nkp-mgmt.env`. **Target:** the operator host file. **Result:** the create script can use it. No cluster change.

```bash
# CHANGES  (appends NO_PROXY_LIST to the cluster env file)
source ~/nkp-nkp-mgmt.env 2>/dev/null
dir='/tmp/nkp-eval-b2n/skills/nkp-networking'; extra=''; aws='no'; pods='192.168.0.0/16'; svcs='10.96.0.0/12'
: "${dir:?}" "${CP_VIP:?}" "${LB_IP_RANGE:?}"
base=$(awk -v a="$aws" '$1=="all" || ($1=="aws" && a=="yes") {print $2}' "$dir/assets/no-proxy-base.txt" | paste -sd, -)
echo "export NO_PROXY_LIST='$base,$pods,$svcs,$CP_VIP,${LB_IP_RANGE%%-*}${extra:+,$extra}'" >> ~/nkp-nkp-mgmt.env
```

Run it with the `extra` string that you confirm. Stop; type **yes**.

### Step 5: add the flags to the create script

Add these lines to `~/nkp-nkp-mgmt-create.sh`, immediately before the final `"$@"`:

```text
  --http-proxy "$NKP_HTTP_PROXY" \
  --https-proxy "$NKP_HTTPS_PROXY" \
  --no-proxy "$NO_PROXY_LIST" \
```

- Nutanix AHV and NKP Metal take this one set for all nodes. [live 2.19.0]
- Do not add the `--control-plane-*` / `--worker-*` variants on AHV; they are for pre-provisioned, vSphere, AWS, Azure and GCP. [pdf p.668-669]
- The create script is `# CHANGES` when we rewrite it; the create itself is the CHANGES command that needs your "yes".

Then dry run, and check N-23 on the result (this file holds Secrets — the grep is anchored and prints no Secret value):

```bash
# CHANGES  (writes the dry-run objects to a local mode-600 file; creates no cluster)
source ~/nkp-nkp-mgmt.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-nkp-mgmt.env 2>/dev/null
grep -n -E '^kind:|^ +(http|https|additionalNo):' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

If `http`, `https` and `additionalNo` appear under `clusterConfig.proxy`, the nodes get the proxy. If they do not, tell me: then the proxy reaches only the CAPI controllers and we must add the node part yourself (skill `nkp-networking`, section X5 C) — that is exactly what N-23 is about.

### Step 6: after the create — platform apps

The pods of the platform apps (Flux, Kommander apps) do not read the node proxy. Gatekeeper must add it: section X4 of `references/proxy.md`. On Starter you also patch the FederatedNamespace template. Tell me when the create ends and I will do X4 with you (it is three CHANGES blocks: a ConfigMap, namespace labels, and possibly the `fns` patch).

### Done when

`NO_PROXY_LIST` and both proxy URLs are in the env files, the dry run shows the three values, and after the create the Flux pods show a proxy variable length greater than 0 (X6).

---

## nkp-networking W2

Skill files read: `skills/nkp/SKILL.md`, `skills/nkp-networking/SKILL.md` (step 1, step 3), `skills/nkp-networking/references/proxy.md` (X2, X4, X5, X6), `skills/nkp-networking/assets/no-proxy-base.txt`, `skills/nkp-cluster-lifecycle/SKILL.md` (step 2, step 3), `skills/nkp-cluster-lifecycle/references/variables.md` (V2, V5), `skills/_shared/RULES.md`.

**Answer: the proxy lives in three places, so a new address is three changes, in this order: (A) CAPI controllers, (B) platform-app pods, (C) the nodes. Part C replaces every node of `dev-mgmt`, one at a time.**

### Facts

- Three places: the CAPI controllers, the platform-app pods, and the nodes (`clusterConfig.proxy`). [pdf p.666-671]
- Part C changes a machine spec. CAPI machines are immutable, so **all nodes are replaced**; the pool rolls one new node in, then drains one old node (`maxSurge: 1`, `maxUnavailable: 0`). [pdf p.672, p.992]
- `clusterConfig.proxy.additionalNo` has a maximum of 128 items. [live 2.19.0]
- `nkp upgrade capi-components` also has the proxy flags but is deprecated (`nkp upgrade kommander` runs it now). Do not use it for this. [live 2.19.0]
- UNKNOWN (N-22): whether the CAPI operator reverts the `kubectl set env` of part A. We check it a few minutes after the change.
- Removing a proxy entirely is not in the skills.

### Questions

1. What is the new proxy URL (scheme, host, port)? Same port or a new one?
2. Does the new proxy need new credentials? If yes, that is a secret — you edit `~/nkp-site.env` yourself.
3. Do the internal hosts in the no-proxy list change (new proxy host name in an exclusion, a new internal domain)? If not, `NO_PROXY_LIST` stays as it is.
4. Is the old proxy kept alive until the rollout of part C finishes? I recommend yes: the nodes need one or the other during the roll.
5. `dev-mgmt` is the management cluster (`WORKSPACE_NS=kommander`)? That matters for part A and for the Gatekeeper ConfigMap namespace.
6. During part C, workloads with one replica stop for a short time, and each pool needs room for one more VM (vCPU, memory, one IP in the subnet pool). Is there room, and is a PodDisruptionBudget going to block a drain?

### Step 1: read the state

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.proxy}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}{"\n"}'
```

### Step 2 (do this first, once): the new value in the env files

**Command:** append the new `NKP_HTTP_PROXY` / `NKP_HTTPS_PROXY` lines. **Target:** `~/nkp-site.env`. **Result:** every later block uses the new address; the last line wins (rule 4).

```bash
# CHANGES  (appends the new proxy URLs to the site env file)
source ~/nkp-site.env 2>/dev/null
echo "export NKP_HTTP_PROXY='http://proxy-new.corp.example.com:3128'" >> ~/nkp-site.env
echo "export NKP_HTTPS_PROXY='http://proxy-new.corp.example.com:3128'" >> ~/nkp-site.env
```

Stop; type **yes** with the confirmed URL. (The values in the block are the ones I need from question 1.)

If `NKP_HTTP_PROXY`/`NKP_HTTPS_PROXY` are not in the file yet because the cluster was created by hand, say so and we append them first.

### Step 3: part A — CAPI controllers (needs your "yes")

**Command:** `kubectl set env` on the CAPI controllers and on the git-operator StatefulSet. **Target:** `dev-mgmt`, namespaces of the CAPI providers; the pods restart. **Result:** CAPX, CAREN, CAAPH, CAPI and git-operator use the new proxy. The block skips a controller that the cluster does not have.

```bash
# CHANGES  (sets the proxy variables on the CAPI controllers and git-operator; the pods restart)
source ~/nkp-dev-mgmt.env 2>/dev/null
for d in caaph-system/caaph-controller-manager capa-system/capa-controller-manager capg-system/capg-controller-manager capi-kubeadm-bootstrap-system/capi-kubeadm-bootstrap-controller-manager capi-kubeadm-control-plane-system/capi-kubeadm-control-plane-controller-manager capi-system/capi-controller-manager cappp-system/cappp-controller-manager capv-system/capv-controller-manager capx-system/capx-controller-manager capz-system/capz-controller-manager caren-system/cluster-api-runtime-extensions-nutanix; do kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "${d%/*}" get deploy "${d#*/}" >/dev/null 2>&1 && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "${d%/*}" set env "deployment/${d#*/}" HTTP_PROXY="$NKP_HTTP_PROXY" HTTPS_PROXY="$NKP_HTTPS_PROXY" NO_PROXY="$NO_PROXY_LIST"; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n git-operator-system set env statefulset/git-operator-git HTTP_PROXY="$NKP_HTTP_PROXY" HTTPS_PROXY="$NKP_HTTPS_PROXY" NO_PROXY="$NO_PROXY_LIST"
```

Stop; type **yes**. Then wait about five minutes and check N-22:

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}{"\n"}'
```

The names must still be there. If they are gone, the CAPI operator reverted them: tell me and we stop — then the proxy for the controllers needs a different route (not in the skills).

### Step 4: part B — platform-app pods (needs your "yes")

Gatekeeper writes the proxy into new pods of labeled namespaces. Check first, then replace the ConfigMap. The full block is X4 of `references/proxy.md`; the check is:

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmreleases -A | grep gatekeeper
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get configmap gatekeeper-overrides -o jsonpath='{.data.values\.yaml}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get ns -l gatekeeper.d2iq.com/mutate=pod-proxy
```

If `gatekeeper-overrides` exists, show me its values and I keep your other values in the rewrite. Then the CHANGES block (values file + `create configmap ... | apply`) uses `"$NKP_HTTP_PROXY"`, `"$NKP_HTTPS_PROXY"` and `"$NO_PROXY_LIST"`, so it picks up the new address. Pods that already run keep the **old** address; restart the core services that must use the proxy, after the change. [pdf p.980-981]

### Step 5: part C — the nodes (needs your "yes", replaces all nodes)

Print the new node proxy value:

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
jq -nc --arg h "$NKP_HTTP_PROXY" --arg s "$NKP_HTTPS_PROXY" --arg n "$NO_PROXY_LIST" '{http:$h,https:$s,additionalNo:($n|split(","))}'
```

Then, with skill `nkp-cluster-lifecycle` step 3: read the topology to get the index `v` of `clusterConfig`, write the patch with `field='proxy'` and the printed JSON as `value`, preview with `--dry-run=server`, show you the diff, stop for **yes**, apply, and watch.

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o go-template='{{range $i, $v := .spec.capiCluster.topology.variables}}variable {{$i}}: {{$v.name}}{{"\n"}}{{end}}'
```

**Plan for part C:** target `dev-mgmt` NKPCluster, field `clusterConfig.proxy`; result: every node is replaced one by one; the API stays up (3 control planes); single-replica workloads stop briefly. The server dry run accepts this change [live 2.19.0]. A dry run that passes is not proof of safety, so I show you the diff and wait.

### Step 6: verify

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.proxy}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander-flux get pods -o json | jq -r '.items[] | .metadata.name + ": " + ([.spec.containers[0].env[]? | select(.name|test("PROXY")) | .name + "=" + ((.value // "") | length | tostring) + " chars"] | join(" "))'
```

Line 1 shows `http`, `https`, `additionalNo` with the new address. Line 2 lists the three names. Line 3 shows the Flux pods with a non-zero length. Also check the proxy itself from the operator host (X2):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
curl -sS -o /dev/null -w '%{http_code}\n' --proxy "$NKP_HTTPS_PROXY" https://registry.k8s.io/v2/
```

An HTTP code that is not `000` means the new proxy answers. Keep the old proxy reachable until the part C rollout ends.

### Done when

`additionalNo` + the new `http`/`https` are in the NKPCluster, the controller env names are still present, the Flux pods show a non-zero proxy length, and all nodes are `Ready` after the roll.

---

## nkp-networking W3

Skill files read: `skills/nkp/SKILL.md`, `skills/nkp-networking/SKILL.md` (step 1, step 3), `skills/nkp-networking/references/metallb.md` (facts, M2, M3), `skills/nkp-cluster-lifecycle/SKILL.md` (step 1), `skills/_shared/RULES.md`.

**Read this first: BGP mode is blocked on NKP 2.19.0 by a known API-server defect.** [live 2.19.0] UNKNOWN (N-20): the API server rejects **every** `BGPPeer`, also the guide example, with `Maximum boundary value must be of type integer with format int32 in spec.myASN`. The `IPAddressPool` and the `BGPAdvertisement` pass. So we do this in the safe order: write the file, run the server dry run, and only apply when all three objects are accepted.

### Facts

- MetalLB 0.15.3 in `metallb-system`; the speaker uses FRR 9.1.3 for BGP (`METALLB_BGP_TYPE=frr`). [live 2.19.0]
- MetalLB peers from **every** speaker node (every node) with your router and announces the prefix. The network team must configure the router to accept a BGP session from each node address with AS 64500. [pdf p.673, p.783]
- Do not edit the default pool `metallb` or the L2Advertisement `metallb`; the next upgrade stalls. A new pool + a new advertisement is the correct shape. [pdf p.672]
- BGP is the right mode here: `203.0.113.0/27` is not the node subnet, so a Layer 2 pool would be invalid (a Layer 2 pool must be in the node primary subnet). [pdf p.672]
- The pool must not overlap the pod CIDR, the service CIDR, or another pool.
- One question on your values, before I write them: `203.0.113.0/27` is the TEST-NET-3 range that documentation uses. Confirm that it is really the prefix the network team routes to us, and that `198.51.100.1` / AS 64501 are the real values.

### Step 1: read the state of dev-01

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.clusterNetwork}{"\n"}{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}lb={.value.addons.serviceLoadBalancer}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements,bgpadvertisements,bgppeers
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ds -n metallb-system
```

I need this output before the plan: the existing pools tell us that `203.0.113.0/27` is free.

### Step 2: save the four BGP values (needs your "yes")

**Command:** append four lines to `~/nkp-dev-01.env`. **Target:** the operator host file. **Result:** the BGP blocks have their values. No cluster change.

```bash
# CHANGES  (appends the BGP values to the cluster env file)
source ~/nkp-dev-01.env 2>/dev/null
echo "export BGP_PEER_IP='198.51.100.1'" >> ~/nkp-dev-01.env
echo "export BGP_MY_ASN='64500'" >> ~/nkp-dev-01.env
echo "export BGP_PEER_ASN='64501'" >> ~/nkp-dev-01.env
echo "export BGP_PREFIX='203.0.113.0/27'" >> ~/nkp-dev-01.env
```

Stop; type **yes** after you confirm the values (and the TEST-NET-3 question).

### Step 3: write the manifest (no cluster change)

```bash
# CHANGES  (writes the BGP file on the operator host; changes no cluster)
source ~/nkp-dev-01.env 2>/dev/null
pool='bgp'
: "${BGP_PEER_IP:?}" "${BGP_MY_ASN:?}" "${BGP_PEER_ASN:?}" "${BGP_PREFIX:?}"
printf -- 'apiVersion: metallb.io/v1beta2\nkind: BGPPeer\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  myASN: %s\n  peerASN: %s\n  peerAddress: %s\n---\napiVersion: metallb.io/v1beta1\nkind: IPAddressPool\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  addresses:\n  - %s\n---\napiVersion: metallb.io/v1beta1\nkind: BGPAdvertisement\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  ipAddressPools:\n  - %s\n' "$pool" "$BGP_MY_ASN" "$BGP_PEER_ASN" "$BGP_PEER_IP" "$pool" "$BGP_PREFIX" "$pool" "$pool" > "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

This writes `dev-01-metallb-bgp.yaml` with `BGPPeer` (v1beta2 — v1beta1 is deprecated), `IPAddressPool bgp` = `203.0.113.0/27`, and `BGPAdvertisement bgp`. Stop for **yes** (it writes a file on your host only).

### Step 4: server dry run — the decision point

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-dev-01.env 2>/dev/null
pool='bgp'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

- All three objects `created (server dry run)`: go to step 5.
- `BGPPeer` fails with `Maximum boundary value must be of type integer with format int32 in spec.myASN`: **BGP mode is blocked on this version (N-20). I stop.** I do not change the MetalLB CRD, and I do not weaken the schema. The options then are: keep Layer 2 with a pool in the worker subnet (M2), or use an external load balancer in front of Traefik (I7). Both are in the skills; BGP is not available.
- `overlaps with already defined CIDR`: tell me the free prefix and we do step 2 and 3 again.

If you want the N-20 evidence for a support case:

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd bgppeers.metallb.io -o jsonpath='{.spec.versions[?(@.name=="v1beta2")].schema.openAPIV3Schema.properties.spec.properties.myASN}{"\n"}'
```

### Step 5: apply (only if step 4 is clean; needs your "yes")

**Command:** `kubectl apply` of the three objects. **Target:** cluster `dev-01`, namespace `metallb-system`. **Result:** MetalLB peers with 198.51.100.1 and announces `203.0.113.0/27`; the speakers start a session from each node.

```bash
# CHANGES  (creates the BGP peer, the pool and the advertisement)
source ~/nkp-dev-01.env 2>/dev/null
pool='bgp'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

Stop; type **yes**.

### Step 6: verify the session

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system exec ds/metallb-speaker -c frr -- vtysh -c "show bgp summary"
```

Before any `BGPPeer` exists the output is `% BGP instance not found`. With a working peer the router row shows a prefix count, not `Active` or `Connect`. `ds/metallb-speaker` reads one speaker pod; each node has its own session. Then ask the network team for the route to the Service IP.

### Done when

Every speaker shows an established session, the router has a route for the announced prefix, and a test Service with `metallb.io/address-pool: bgp` gets an EXTERNAL-IP. If step 4 fails: we have the N-20 message and a Layer 2 or external-LB plan instead.

---

## nkp-networking W4

Skill files read: `skills/nkp/SKILL.md`, `skills/nkp-networking/SKILL.md` (step 3), `skills/nkp-networking/references/cni.md` (C1, C2), `skills/nkp-networking/references/proxy.md` (X2), `skills/nkp-cluster-lifecycle/references/variables.md` (V7), `skills/nkp-install/SKILL.md` (create step), `skills/nkp-install/references/nutanix.md` (N1 IP plan, N5), `skills/_shared/RULES.md`.

**Answer: no. The pod CIDR cannot change on a running cluster.** The dry run saying OK is the trap: the API server accepts the patch and the cluster breaks.

### Facts

- Pod CIDR and service CIDR cannot change after the create. [pdf p.497-498, p.724]
- "The API dry run accepts the change" — recorded on the live 2.19.0 cluster. [live 2.19.0] That is exactly what you saw.
- The network breaks, and **a revert does not fix it**. [pdf p.498]
- Same rule for the Cilium IPAM mode, `kubeProxy.mode` (the API rejects that one outright), and the CNI provider. [live 2.19.0]
- The CIDR rule exists because Cilium IPAM takes a pod CIDR per node from Kubernetes at create time. [cni.md C4]

So there are two real options. Only the first one is in the skills.

**Option 1 (in the skills): a new cluster with `--kubernetes-pod-network-cidr 172.20.0.0/16`, then move the workloads.** Make the new cluster in a new workspace namespace with a new `CP_VIP` and a new `LB_IP_RANGE`, then move the apps and delete `dev-01` (skill `nkp-cluster-lifecycle`, references/delete.md). This is planned downtime for the workloads, and it needs new IPs from the subnet pool for 7+ nodes. [pdf p.693]

**Option 2 (not in the skills): keep `192.168.0.0/16` and change the VPN routing instead** — for example, do not send `192.168.0.0/16` over the office VPN, or use a more specific route on the office side. That is a network-team decision. The skills have no step for it, so I will not give you commands for it.

### Questions before I write a create script for the replacement cluster

1. Which do you want: the new cluster (option 1), or do you take option 2 to the network team first?
2. Is `172.20.0.0/16` free? It must not overlap the node subnet, `CP_VIP`, the `LB_IP_RANGE`, the service CIDR `10.96.0.0/12`, or another cluster's pod CIDR that routes into your network. Overlapping pod CIDRs on two clusters that talk to each other is the same problem again.
3. Does the service CIDR stay at `10.96.0.0/12`?
4. Is `dev-01` allowed to have a new `CP_VIP` and a new `LB_IP_RANGE`? Both must be outside the DHCP/IPAM pool. [pdf p.693-694]
5. Do you keep the cluster name `dev-01`? I recommend a new name (`dev-02`) and cut over, so the old cluster stays as a fallback until the apps move.
6. Does the site use an HTTP proxy? Then the new cluster's no-proxy list needs the **new** pod CIDR in place of `192.168.0.0/16`. [pdf p.670]

### Step 1: confirm the current state (read-only)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.clusterNetwork}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | wc -l
```

This gives me the real CIDRs, the node subnet, and an idea of the workload count to move.

### Step 2: the change I will **not** run

For the record, this is the patch you would be tempted to make, and the reason I refuse it:

```text
[{"op":"replace","path":"/spec/capiCluster/clusterNetwork/pods/cidrBlocks/0","value":"172.20.0.0/16"}]
```

The server dry run passes. NKP then hands new pod CIDRs to nodes that still hold addresses from the old range; existing pods lose connectivity, new pods get addresses from a range that the CNI is not programmed for, and the revert does not repair the existing pod IPs. [pdf p.498][live 2.19.0]

### Step 3: option 1 plan (needs your "yes" at each CHANGES block)

The create script for the replacement cluster is section N5 of `references/nutanix.md`, plus one new flag before `"$@"`:

```text
  --kubernetes-pod-network-cidr 172.20.0.0/16 \
```

- The create flags exist on Nutanix and Metal; on other providers you edit `spec.clusterNetwork` in the dry-run YAML. [live 2.19.0][pdf p.678-679]
- The change is at create time only. That is the whole point.
- With Calico (not the AHV default) you must also set `spec.calicoNetwork.ipPools[].cidr`. [pdf p.679]
- Preflight stops on a CIDR overlap and names the `Flag:` line. [pdf p.726]

Then: move the workloads, verify, delete `dev-01` with `references/delete.md`. Workload moves are an app-owner job, not an NKP change; tell me which app teams are involved and I list the order.

### Done when

You have chosen option 1 or option 2. For option 1: the new cluster is `Reconciled`, its pods get addresses from `172.20.0.0/16`, and `dev-01` is deleted after the move.

---

## nkp-networking W5

Skill files read: `skills/nkp/SKILL.md`, `skills/nkp-networking/SKILL.md` (step 1, step 3), `skills/nkp-networking/references/metallb.md` (facts, M1, M2), `skills/nkp-networking/references/proxy.md` (X2, last item of M2), `skills/_shared/RULES.md`.

**I have not run it, and I will not run it on "I trust you".** Rule 2: "just run it" is not "yes". I show you the command, the target and the result; you type **yes**. Below is also one fact that can make this range wrong, so the approval matters.

### Facts

- **Do not edit the default pool `metallb` or the L2Advertisement `metallb`.** The next cluster upgrade stalls and fails. A new pool plus a new advertisement is the correct shape. [pdf p.672]
- A **Layer 2** pool must be in the node primary subnet, outside the DHCP/IPAM pool, and it must not overlap the pod CIDR, the service CIDR, or another pool. [pdf p.672, p.721]
- `192.0.2.50-192.0.2.59` is the TEST-NET-1 documentation range. If the `dev-01` worker subnet is not `192.0.2.0/24`, a Layer 2 pool with these addresses is invalid and the speakers will announce addresses the network cannot reach. **Check the worker subnet first (step 1).** If these addresses are not in the worker subnet, BGP is the correct mode — and BGP is blocked on 2.19.0 (N-20, see W3).
- 10 addresses is inside the range shape `<first-ip>-<last-ip>`; `APP_LB_RANGE` takes that form. [metallb.md]
- `autoAssign: false` keeps the pool for Services that ask for it with the annotation `metallb.io/address-pool: apps`. If you want any new Service to get one of these IPs without an annotation, that is `autoAssign: true` — tell me which.

### Questions

1. Confirm the worker/node subnet of `dev-01`. Are `192.0.2.50` to `192.0.2.59` inside it, and outside the DHCP/IPAM pool? If not, this range cannot be announced in Layer 2 mode.
2. `autoAssign` false (only Services with the pool annotation) or true (any Service)? Default in my plan: false.
3. Does the site use an HTTP proxy? Then these 10 IPs go into the no-proxy list too, after they are in use. [pdf p.980]
4. Pool name: `apps` in my plan. Another name?

### Step 1: read the state (this decides whether the range is valid)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.clusterNetwork}{"\n"}{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}lb={.value.addons.serviceLoadBalancer}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements,bgpadvertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
```

The last line gives the node addresses, so we see the worker subnet directly. Send me this output before you approve step 3.

### Step 2: save the range (needs your "yes")

**Command:** append `APP_LB_RANGE` to `~/nkp-dev-01.env`. **Target:** the operator host file. **Result:** the pool file block has its value. No cluster change.

```bash
# CHANGES  (appends the app pool range to the cluster env file)
source ~/nkp-dev-01.env 2>/dev/null
echo "export APP_LB_RANGE='192.0.2.50-192.0.2.59'" >> ~/nkp-dev-01.env
```

Stop; type **yes** (only after step 1 shows the range is in the worker subnet).

### Step 3: write the pool file (no cluster change)

```bash
# CHANGES  (writes the pool file on the operator host; changes no cluster)
source ~/nkp-dev-01.env 2>/dev/null
pool='apps'; auto='false'
: "${APP_LB_RANGE:?}"
printf -- 'apiVersion: metallb.io/v1beta1\nkind: IPAddressPool\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  autoAssign: %s\n  addresses:\n  - %s\n---\napiVersion: metallb.io/v1beta1\nkind: L2Advertisement\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  ipAddressPools:\n  - %s\n' "$pool" "$auto" "$APP_LB_RANGE" "$pool" "$pool" > "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

### Step 4: server dry run

```bash
# READ-ONLY  (server dry run: the API server and the MetalLB webhook check the objects and change nothing)
source ~/nkp-dev-01.env 2>/dev/null
pool='apps'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

`created (server dry run)` for both objects: go on. `overlaps with already defined CIDR`: the range is in another pool; give me a free range.

### Step 5: the plan I stop at

**Command:** `kubectl apply` of two objects. **Target:** cluster `dev-01`, namespace `metallb-system`. **Result:** a new IPAddressPool `apps` with `192.0.2.50-192.0.2.59` (`autoAssign: false`) and a new L2Advertisement `apps`. The default pool and advertisement are not touched, so the next upgrade is safe.

```bash
# CHANGES  (creates the MetalLB pool and its L2Advertisement)
source ~/nkp-dev-01.env 2>/dev/null
pool='apps'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

Type **yes** to this plan and only this plan.

### Step 6: verify

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
```

Done when `apps` is listed and a Service with the annotation `metallb.io/address-pool: apps` gets one of the 10 IPs. Then tell me the app namespaces and I add the 10 IPs to the no-proxy list if the site has a proxy.

---

## nkp-networking W6

Skill files read: `skills/nkp/SKILL.md`, `skills/nkp-networking/SKILL.md` (facts, common failures), `skills/nkp-networking/references/ingress-certs.md` (I1-I4), `skills/nkp-networking/references/metallb.md` (M1, for the Traefik IP), `skills/_shared/RULES.md`.

**Answer: yes, that works air-gapped. Own certificate (I3): create a TLS Secret on the cluster, then point the NKPCluster ingress at it. ACME is not an option on a dark site.** [pdf p.491, p.978]

### Facts

- Today the UI certificate `kommander-traefik-tls` comes from the ClusterIssuer `kommander-ca`, a self-signed CA that NKP makes. That CA is why the browser warns. [live 2.19.0]
- The ingress state lives in the KommanderCluster: `spec.kommanderCluster.spec.ingress` with `hostname`, `certificateSecretRef`, `issuerRef`. [live 2.19.0]
- The Secret and any issuer are on the **target** cluster; the NKPCluster is on the **management** cluster. [pdf p.492, p.494] For the management cluster the target cluster and the management cluster are the same, and `WORKSPACE_NS` is `kommander`.
- The certificate must be for the hostname. cert-manager does **not** renew a certificate you bring. You replace it before it expires. [pdf p.968]
- The chain file must hold **2 or more** `BEGIN CERTIFICATE` blocks (server certificate, intermediates, root). [pdf p.493]
- The cluster hostname must resolve to the Traefik IP from the browsers **and** from the cluster. [pdf p.970]

### Questions

1. Confirm the paths: `~/certs/cert.pem`, `~/certs/key.pem`, `~/certs/ca.pem`? I use the absolute paths in the env file, not relative ones.
2. Is `nkp.example.com` already an A record (or CNAME) to the Traefik IP of the management cluster? If the record does not exist, the UI moves to a name that does not answer, and we must make the record first.
3. Does the browser that complains trust your internal CA? If it does not, the warning stays even with a good chain. That is a client-side trust-store job, not an NKP one.
4. `ca.pem`: is it the root only, or root plus intermediates? It goes into the Secret as `ca.crt`.
5. Is the current `hostname` in the NKPCluster an IP (the default) or already a name? If it is an IP, this change also moves the UI URL.

### Step 1: read the current ingress state

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.kommanderCluster.spec.ingress}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommandercluster "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[?(@.type=="IngressAddressReady")]}{.type}={.status} {.reason}{"\n"}{end}{range .status.conditions[?(@.type=="IngressCertificateReady")]}{.type}={.status} {.reason}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterissuers,certificates -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get svc kommander-traefik -o go-template='{{with index .status.loadBalancer.ingress 0}}{{or .hostname .ip}}{{end}}{{"\n"}}'
```

### Step 2: save the four values (needs your "yes")

**Command:** append four lines to `~/nkp-dev-mgmt.env`. **Target:** operator host file. **Result:** the later blocks have the paths and the hostname. No cluster change. The key file is a secret: it stays mode 600 and I never print it.

```bash
# CHANGES  (appends the ingress values and tightens the key file mode)
source ~/nkp-dev-mgmt.env 2>/dev/null
echo "export INGRESS_HOSTNAME='nkp.example.com'" >> ~/nkp-dev-mgmt.env
echo "export INGRESS_CERT_FILE='$HOME/certs/cert.pem'" >> ~/nkp-dev-mgmt.env
echo "export INGRESS_KEY_FILE='$HOME/certs/key.pem'" >> ~/nkp-dev-mgmt.env
echo "export INGRESS_CA_FILE='$HOME/certs/ca.pem'" >> ~/nkp-dev-mgmt.env
chmod 600 "$HOME/certs/key.pem"
```

Stop; type **yes** with the confirmed paths.

### Step 3: check the files (read-only, prints no key)

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
openssl x509 -in "$INGRESS_CERT_FILE" -noout -subject -enddate -ext subjectAltName
grep -c 'BEGIN CERTIFICATE' "$INGRESS_CERT_FILE"
[ "$(openssl x509 -in "$INGRESS_CERT_FILE" -noout -pubkey | sha256sum)" = "$(openssl pkey -in "$INGRESS_KEY_FILE" -pubout | sha256sum)" ] && echo "key matches" || echo "KEY DOES NOT MATCH"
getent hosts "$INGRESS_HOSTNAME"
```

- The SAN list must contain `nkp.example.com`.
- The count must be 2 or more.
- The last lines must be `key matches` and the name must resolve to the Traefik IP.

Stop here if any of the three fails, and tell me which.

### Step 4: create the TLS Secret (needs your "yes")

**Command:** create Secret `dev-mgmt-ingress-tls` of type `kubernetes.io/tls`. **Target:** cluster `dev-mgmt`, namespace `kommander` (the workspace namespace — on the management cluster the Secret goes on the management cluster itself). **Result:** the full chain and the key are in the cluster; Traefik picks the certificate up when step 6 points at it.

```bash
# CHANGES  (creates the TLS Secret of the cluster ingress on the target cluster)
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" create secret generic "$CLUSTER_NAME-ingress-tls" --type=kubernetes.io/tls --from-file=ca.crt="$INGRESS_CA_FILE" --from-file=tls.crt="$INGRESS_CERT_FILE" --from-file=tls.key="$INGRESS_KEY_FILE"
```

Stop; type **yes**. (Do not run `kubectl get secret -o yaml` on it; that prints the key.)

### Step 5: preview the NKPCluster patch

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-dev-mgmt.env 2>/dev/null
p=$(printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s","certificateSecretRef":{"name":"%s-ingress-tls"}}}}}}' "$INGRESS_HOSTNAME" "$CLUSTER_NAME")
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type merge -p "$p" --dry-run=server -o jsonpath='{.spec.kommanderCluster.spec.ingress}{"\n"}'
```

The output must show the new hostname and `certificateSecretRef`. An error means stop.

### Step 6: the plan I stop at

**Command:** merge patch of the NKPCluster ingress with `hostname` and `certificateSecretRef` (no `issuerRef`: your CA is not a cert-manager issuer). **Target:** management cluster `dev-mgmt`, namespace `kommander`. **Result:** the UI serves the new certificate at `https://nkp.example.com`. If the UI was on the IP before, **the URL changes to the name** — tell your users before you approve.

```bash
# CHANGES  (sets the custom domain and certificate of the cluster ingress)
source ~/nkp-dev-mgmt.env 2>/dev/null
p=$(printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s","certificateSecretRef":{"name":"%s-ingress-tls"}}}}}}' "$INGRESS_HOSTNAME" "$CLUSTER_NAME")
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type merge -p "$p"
```

Stop; type **yes**.

### Step 7: verify

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommandercluster "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[?(@.type=="IngressAddressReady")]}{.type}={.status} {.reason}{"\n"}{end}{range .status.conditions[?(@.type=="IngressCertificateReady")]}{.type}={.status} {.reason}{"\n"}{end}'
echo | openssl s_client -connect "$INGRESS_HOSTNAME:443" -servername "$INGRESS_HOSTNAME" 2>/dev/null | openssl x509 -noout -subject -issuer -enddate
```

- `IngressAddressReady=True IngressServiceAddressFound` and `IngressCertificateReady=True Ready`. [pdf p.971][live 2.19.0]
- The `openssl` issuer is your internal CA, not `kommander-ca`.
- `IngressCertificateReady=False`: the Secret is in the wrong namespace, missing on the target cluster, or has no full chain. [pdf p.495]

### Renewal

cert-manager does not renew this one. Note the `enddate` from step 7 in your calendar, and repeat steps 4 and 7 with the new files (delete and create the Secret again; the `certificateSecretRef` name stays the same).

---

## nkp-networking W7

Skill files read: `skills/nkp/SKILL.md`, `skills/nkp-networking/SKILL.md` (step 1, common failures), `skills/nkp-networking/references/cni.md` (C3, C4), `skills/nkp-networking/references/metallb.md` (M1), `skills/nkp-networking/references/ingress-certs.md` (I1, I7), `skills/nkp-troubleshooting/SKILL.md` (step 2, step 3), `skills/_shared/RULES.md`.

**Probable cause: Cilium DSR on a Network Controller–managed VLAN (N-01). The UI IP and the API VIP fail in different ways because they are different mechanisms: kube-vip holds the API VIP, and MetalLB plus Cilium DSR hold the LoadBalancer IP of Traefik.** But it is `[field]` — not confirmed — so the checks below come first.

### Facts

- On AHV with the default datapath, Cilium uses `bpf-lb-mode: dsr` with DSR dispatch `geneve`. [live 2.19.0]
- Symptom: the UI and the LoadBalancer IPs do not answer while the API VIP answers. On AHV subnets that the Network Controller manages — and on VPC overlay subnets — replies whose source is the Service IP, sent from a node that does not own that IP, can be dropped by the network. [cni.md C4]
- kube-vip holds the control-plane VIP only. It does not give Service IPs, and it does not load balance. [live 2.19.0][pdf p.786] That is why kubectl to the VIP still works: different VIP, different path.
- The field fix is `loadBalancer.mode: snat`, through the Cilium values ConfigMap. [field]
- **But**: a running cluster ignores new Cilium values. The values reach Cilium only when the cluster uses them from the create. An edit of the cluster spec or of `cilium-config` later does not reach the installed Cilium. [pdf p.727] UNKNOWN (N-01) confirms exactly this: "a fix needs a new cluster with SNAT".
- The values ConfigMap path is documented for a **workload cluster**. For a management cluster, C3 step 4 says: not in the skills.
- UNKNOWN (N-01): whether DSR really is the cause here, and whether SNAT is the fix.

Two other causes from the skills are less likely but cheap to exclude: ARP/routing for a Layer 2 pool ("EXTERNAL-IP is set but clients get no answer" — check from a host in the same subnet), and a Traefik/pool problem (M1).

### Questions

1. From a host **inside** the node subnet, does the UI IP answer on 443? (Your sentence says outside fails; I need the inside result.)
2. Is the UI reached by IP or by a DNS name? If a name, does it resolve to the Traefik LB IP?
3. Did anything change when it stopped — an AHV subnet change, a move to a Network Controller VLAN, an NKP patch, a MTU change? You say the nodes are on a Network Controller VLAN: was the cluster built on that VLAN, or did it move?
4. Is the management cluster the one affected, or a workload cluster? This decides the fix path (see below).
5. Where is the operator host: inside or outside the node subnet?

### Step 1: read the network state

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.clusterNetwork}{"\n"}{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}lb={.value.addons.serviceLoadBalancer}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get configmap cilium-config -o jsonpath='{.data.bpf-lb-mode}{" "}{.data.bpf-lb-dsr-dispatch}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get pods -l k8s-app=cilium -o wide
```

`dsr geneve` on line 2 is the DSR signature. Line 4 shows the Traefik EXTERNAL-IP; compare it with your `LB_IP_RANGE` and with the node addresses.

### Step 2: confirm the datapath and look for dropped replies

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep -E 'Routing|KubeProxyReplacement|Masquerading'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- hubble observe --last 50 --verdict DROPPED
```

`hubble observe` reads the flows of the node where that agent pod runs; run it in the agent pod of the node behind the Traefik IP. Find the node with `kubectl get pod -o wide`, then the agent pod with `-l k8s-app=cilium --field-selector spec.nodeName=<node>`, then `exec <agent-pod>` in place of `exec ds/cilium`.

Also exclude the cheap causes (M1, last row): a client **in the same subnet** must get an answer. If it does not, the problem is in the pool/advertisement, not in the routing.

```bash
# READ-ONLY  (run on the operator host; only meaningful when the operator host is in the node subnet)
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -n kommander kommander-traefik -o jsonpath='{.status.loadBalancer.ingress[0]}{"\n"}'
```

### Step 3: what the skills say about the fix

If the checks show `dsr` and drops from a node that does not own the IP, this is N-01 and the skills have **no in-place fix**:

| Cluster | Skills answer |
|---|---|
| Workload cluster | Build the replacement with the Cilium values ConfigMap at create time with `loadBalancer: {mode: snat}` (C3), then move the apps. A running cluster ignores the value. |
| Management cluster | **Not in the skills.** C3 step 4 covers a workload cluster only. I do not have a supported in-place path for the UI of the management cluster. |

If it is the management cluster, the one workaround that **is** in the skills is I7: put an external load balancer in front of Traefik. Set Traefik to `service.type: NodePort` with fixed ports (30000-32768) in the Traefik values, point the external LB at every worker on those ports, and make the LB **not** end TLS. [pdf p.978-979] Then the client talks to node ports, not to the Service IP, so the DSR reply path is no longer used. That changes the Traefik values, which is a platform-app change (skill `nkp-platform-apps-gitops`) — I would plan it separately, with a rollback plan.

For a support case, the evidence is: `bpf-lb-mode=dsr`, the drop records from step 2, the Network Controller VLAN on the node subnet, and the fact that the API VIP (kube-vip) is fine.

### Step 4: what I will not do

- I will not patch `cilium-config` or add a Cilium value to the running cluster. It has no effect on the installed Cilium, and it makes the next upgrade diff meaningless. [pdf p.727]
- I will not change the MTU or the subnet on the AHV side without a fault that shows MTU.

### Done when

We know one of three things: the inside-subnet test also fails (pool/advertisement fault, M1 fix), or the checks show DSR/N-01 (then you choose I7 or a new cluster), or the drop records name a different cause and we go to skill `nkp-troubleshooting`.

---

## nkp-networking W8

Skill files read: `skills/nkp/SKILL.md`, `skills/nkp-networking/SKILL.md` (the CNI row), `skills/nkp-networking/references/cni.md` (C1, N-03), `skills/_shared/RULES.md`.

**Answer: not in the skills. I cannot confirm support, and I cannot give you the apiserver port.**

### Facts

- The NKP 2.19 guide has **no word about Cilium ClusterMesh**. [N-03]
- UNKNOWN (N-03): whether NKP supports Cilium ClusterMesh. A missing `clustermesh-apiserver` Deployment means ClusterMesh is not on. A ClusterMesh setup is not in the skills.
- What the skills do say: NKP 2.19 on AHV runs **Cilium 1.19.4** as the default CNI, replaced kube-proxy (`kubeProxy.mode: disabled`), tunnel routing with geneve, `bpf-lb-mode: dsr`, and Hubble on with a relay in `kube-system`. [live 2.19.0] The port of a ClusterMesh apiserver is not among the facts in these skills.
- A configuration that joins two clusters' pod networks also touches the pod CIDR (`192.168.0.0/16` on both by default) — two clusters with the same pod CIDR cannot mesh as they are. That CIDR cannot be changed after a create. [pdf p.497-498] This is a real constraint for any ClusterMesh plan, whatever the support answer is.

### What I can check (read-only, on your clusters)

These tell us whether the capability is even present in the installed Cilium:

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get deploy clustermesh-apiserver
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get svc | grep -i clustermesh
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get configmap cilium-config -o jsonpath='{.data.cluster-name}{" "}{.data.cluster-id}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg version
```

Run the same block with the env file of the second cluster.

- No `clustermesh-apiserver` Deployment: ClusterMesh is not installed. That is the normal state of an NKP cluster; the addon surface in `clusterConfig.addons.cni` has no ClusterMesh setting. [live 2.19.0]
- If a Deployment **does** exist, read its Service ports — that is the only trustworthy source for the port on your cluster:

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get svc clustermesh-apiserver -o jsonpath='{range .spec.ports[*]}{.name}={.port}/{.targetPort} {.protocol}{"\n"}{end}'
```

I will not quote a port number from memory: rule 6. The command above prints the real port of your installation.

### What to do with the answer

1. Run the checks above on both clusters and send me the output.
2. If ClusterMesh is present, the support statement still matters — ask Nutanix support whether NKP 2.19 supports it, because the guide does not cover it and the skills have no setup steps.
3. If it is absent: **not in the skills** for support, and no setup path. For cross-cluster service connectivity the supported pattern in these skills is a Service of type `LoadBalancer` per cluster (MetalLB) plus DNS, or NDK for data services — tell me the actual use case (service discovery, failover, shared services) and I name the skill that covers it.

### Done when

We have the check output, and you have either the port from your own cluster or a "not in the skills" answer with an escalation path.
