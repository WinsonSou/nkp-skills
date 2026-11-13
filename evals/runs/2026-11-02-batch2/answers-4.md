# Answers, batch 2 final (prompts-4.md)

All blocks run with bash. The login shell of the operator host is zsh, so start each block with `bash` (for example `bash -c '...'`) or run it with `bash`.

---

## nkp-troubleshooting T1

Skill files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-troubleshooting/references/flux.md`, `skills/nkp-troubleshooting/references/diagnose.md`, `skills/nkp-cluster-lifecycle/SKILL.md` (step 1), `skills/nkp-install/SKILL.md` (Prepare the env files).

### Questions that I would ask first

1. What changed last on `dev-01` (a create, an upgrade, a scale, an app change, an infrastructure change), and when did the apps tab turn red?
2. Does only the apps tab show an error, or does the cluster also show not-ready in the UI? Is a second cluster in the default workspace also affected?
3. Is the management cluster healthy now (`kubectl` answers)?
4. Is the site air-gapped with a registry mirror? (An app that cannot pull from the registry shows the same symptom. The owner skill of the pull failure is `nkp-airgap`.)

Facts that I state: the cluster name is `dev-01`, so the cluster env file is `~/nkp-dev-01.env`. The default workspace namespace is `kommander-default-workspace` [pdf p.489]. I confirm the namespace from the listing below before I write it into the file.

"Apps tab red" is not in the skills. The nearest object in the skills is the platform-app layer (rung 4: the `KommanderCluster` conditions, `HelmRelease`, `Kustomization`). I start there, but I do the upper rungs first. Rungs 1 to 3 come before rung 4, also when the symptom points to rung 4.

### Step 1: Select the cluster (start here)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,PLATFORM:.status.platformVersion'
```

- `get nodes` does not answer: the management API is down. Use `nkp-troubleshooting` `references/diagnose.md`, section "API server down".
- A healthy NKPCluster has PHASE `Reconciled`. `Reconciling Platform Applications` and `Reconciling Kubernetes and Cluster Infrastructure` are the other phases [live 2.19.0].
- The NAMESPACE of `dev-01` gives `WORKSPACE_NS`. For the default workspace I expect `kommander-default-workspace`; I use the value from this output.

Then check the cluster env file:

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

If the file does not exist, this is the plan (skill `nkp-install`, item 2 of "Prepare the env files"):

- Command: the block below.
- Target: a new file `~/nkp-dev-01.env` on the operator host, mode 600, one `source` line. It changes no cluster.
- Result: the file exists. Then I append `CLUSTER_NAME` and `WORKSPACE_NS` (rule 4) after you confirm the namespace from the listing, and you set `CLUSTER_KUBECONFIG` with skill `nkp-install`, step "Set the kubeconfig variables".

```bash
# CHANGES  (makes the cluster env file with mode 600 if it does not exist)
test -e ~/nkp-dev-01.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-dev-01.env); }
```

I stop here for your "yes" before I run it.

### Step 2: The debug ladder

**Rung 1. NKPCluster.**

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='phase={.status.phase}{"\n"}{range .status.conditions[*]}NKP {.type}={.status} {.reason}: {.message}{"\n"}{end}{range .status.capiCluster.conditions[*]}CAPI {.type}={.status} {.reason}: {.message}{"\n"}{end}' \
  | awk -F'[= ]' 'NR==1 || (($2 ~ /^(RollingOut|ScalingUp|ScalingDown|Remediating|Paused|Deleting)$/) ? $3!="False" : $3!="True")'
```

Healthy: only the `phase=Reconciled` line. Every other line is a problem [live 2.19.0].

**Rung 2. CAPI objects.**

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplanes,machinedeployments,machines,machinehealthchecks -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
```

Healthy: every `Machine/` row has READY `True`; all machines are `Running`, READY `True`, UP-TO-DATE `True`.

**Rung 3. Cluster addons (CAREN through CAAPH).**

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmreleaseproxies -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
```

Healthy: READY `True`, STATUS `deployed`.

**Rung 4. Platform apps (Kommander and Flux). This rung matches the apps tab.**

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.kommanderCluster.conditions[?(@.status!="True")]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -v -w True
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get kustomizations -A | grep -v -w True
```

Healthy: the first command prints nothing; the other two print only the header line [live 2.19.0]. The HelmReleases of a cluster are on that cluster, not on the management cluster [pdf p.1047].

### Step 3: Find the failing link and its message

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REASON:.status.conditions[?(@.type=="Ready")].reason,SUSPEND:.spec.suspend' | grep -v -w True
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get kustomizations -A | grep -v -w True
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ocirepositories,gitrepositories,helmcharts -A | grep -v -w True
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments
```

Start with the lowest failing link: source (`OCIRepository` or `GitRepository`) → HelmChart → HelmRelease → Kustomization. A failed source makes every link above it fail. If an AppDeployment is fine but no HelmRelease exists on the cluster, the workspace or the attach is the problem:

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommanderclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.kommanderCluster.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

The KommanderCluster PHASE must be `Joined` [live 2.19.0].

Read the message of the lowest failing object. Set `kind`, `name`, `ns` from the listing; keep `where='cluster'` for Flux kinds (set `where='mgmt'` only for an AppDeployment):

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kind=''; name=''; ns=''; where='cluster'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get "$kind" "$name" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}{.status.history[0].status}{"\n"}'
kubectl --kubeconfig "$kc" -n "$ns" get events --field-selector "involvedObject.name=$name" --sort-by=.lastTimestamp | tail -10
```

### Step 4: Where the message sends you

| Message text | Owner of the fix |
|---|---|
| `exhausted`, `another rollback/release in progress` | skill `nkp-platform-apps-gitops` |
| `dependency ... is not ready` | do step 3 on the dependency |
| `failed to pull`, `unauthorized`, `x509`, `not found` on an OCI source | skill `nkp-airgap` |
| `admission webhook "validation.gatekeeper.sh" denied` | skill `nkp-identity-security` |
| `values` or schema error | skill `nkp-platform-apps-gitops` |
| Helm `context deadline exceeded`, pods not Ready | rung 5 (pod `describe` and `logs --previous`) |
| AppDeployment ok, no HelmRelease on the cluster | skill `nkp-platform-apps-gitops` (workspace or attach) |

Fact that I state now, because it limits what I can do in this session:

- Skill `nkp-platform-apps-gitops` is not installed here. Skill `nkp-airgap` and skill `nkp-identity-security` are also not installed.
- For those rows I give you the failing object and its message, and I give no change command. A HelmRelease reset (`spec.suspend` true, then false) is a CHANGES command in `nkp-platform-apps-gitops`; I do not show it.
- If the cause is still not known after rung 5, the next step is a support bundle with `nkp diagnose` (skill `nkp-troubleshooting`, `references/diagnose.md`). That is a CHANGES command, and I show it with its plan when you ask for it.

Done when I can name the failing object, its cluster, its namespace, and its message; then you load `nkp-platform-apps-gitops` (or `nkp-airgap`) for the fix.

---

## nkp-networking W1

Skill files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-networking/SKILL.md`, `skills/nkp-networking/references/proxy.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`.

### The short answer

On Nutanix AHV, one proxy set covers all nodes and the CAPI controllers. Add three lines to the create script, before `"$@"` [live 2.19.0]:

```text
  --http-proxy "$NKP_HTTP_PROXY" \
  --https-proxy "$NKP_HTTPS_PROXY" \
  --no-proxy "$NO_PROXY_LIST" \
```

Then, after the create, do one more part for the platform-app pods (Gatekeeper pod mutation, section X4). The three flags do not cover those pods [pdf p.980-983].

The cluster name is `nkp-mgmt`, so the cluster env file is `~/nkp-nkp-mgmt.env` and `WORKSPACE_NS='kommander'` (management cluster) [live 2.19.0].

### Questions that I would ask before I write any value

1. Does the proxy address have the form `http://proxy.corp.example.com:3128`? The same URL for HTTP and HTTPS, or two URLs?
2. Does the proxy need a user and a password? If yes, the two env lines are a secret; you write them, I do not.
3. What are the host names of `PC_ENDPOINT` and `REGISTRY_URL`? They are internal, so they must be in the no-proxy list. Also: the node subnet CIDR, other internal hosts or domains, and the identity provider host.
4. Which install case is this: 4A connected, 4B air-gapped with the internal mirror, 4C site registry mirror? This sets the rest of the create script (skill `nkp-install`).

I do not write `NKP_HTTP_PROXY` or `NKP_HTTPS_PROXY` yet. The scheme and the credentials are not confirmed, and a guessed URL in the env file is worse than none (rule 4). I append them in the reply after your answer.

### Step 1: X0 credentials check (run now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
case "$NKP_HTTP_PROXY $NKP_HTTPS_PROXY" in *@*) echo "proxy URL has a user or password";; *) echo "no credentials in the proxy URL";; esac
```

If it prints `has a user or password`, three blocks become USER-TERMINAL (operator host) and I give them to you: X4 step 1, the N-23 check, and the dry run of skill `nkp-cluster-lifecycle` step 3b. Fact: NKP keeps the proxy URL as plain text in the NKPCluster and in the ConfigMap `gatekeeper-overrides`.

### Step 2: Build the no-proxy list (section X2)

After your answer, I set `extra` to the comma-separated entries (PC host, registry host, internal domains with a leading dot, other internal hosts) and run the preview. It prints the list and changes nothing.

```bash
# READ-ONLY  (prints the list; changes nothing)
source ~/nkp-nkp-mgmt.env 2>/dev/null
extra=''; aws=''; pods='192.168.0.0/16'; svcs='10.96.0.0/12'
: "${CP_VIP:?}" "${LB_IP_RANGE:?}"
base='localhost,127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,.svc,.svc.cluster,.svc.cluster.local,svc.,.svc.cluster.,.svc.cluster.local.,169.254.169.254,169.254.0.0/24'
echo "$base${aws:+,10.0.0.0/16,.elb.amazonaws.com},$pods,$svcs,$CP_VIP,${LB_IP_RANGE%%-*}${extra:+,$extra}"
```

What the list already holds from the env file, and why:

- `CP_VIP`: the API server [pdf p.979].
- The first IP of `LB_IP_RANGE`: the `kommander-traefik` address, which carries the NKP UI [pdf p.980].
- The pod CIDR and the service CIDR: the defaults; I change `pods` and `svcs` if the create changes them.
- `aws` stays empty: this site is not AWS.

Rules for the entries: comma and no space; a domain suffix entry also needs a trailing dot (`.corp.example.com.`) [pdf p.667, p.980]. The list takes 128 items or fewer [live 2.19.0].

I show you the printed list. I stop there. After you agree to the list, this is the plan for the next block:

- Command: the block below.
- Target: `~/nkp-nkp-mgmt.env`, one appended line `NO_PROXY_LIST`.
- Result: `NO_PROXY_LIST` is in the cluster env file; no cluster changes.

```bash
# CHANGES  (appends NO_PROXY_LIST to the cluster env file)
source ~/nkp-nkp-mgmt.env 2>/dev/null
extra=''; aws=''; pods='192.168.0.0/16'; svcs='10.96.0.0/12'
: "${CP_VIP:?}" "${LB_IP_RANGE:?}" "${CLUSTER_NAME:?}"
base='localhost,127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,.svc,.svc.cluster,.svc.cluster.local,svc.,.svc.cluster.,.svc.cluster.local.,169.254.169.254,169.254.0.0/24'
echo "export NO_PROXY_LIST='$base${aws:+,10.0.0.0/16,.elb.amazonaws.com},$pods,$svcs,$CP_VIP,${LB_IP_RANGE%%-*}${extra:+,$extra}'" >> "$HOME/nkp-$CLUSTER_NAME.env"
```

`extra` gets the same text as in the preview run. I do not type the proxy URL into this block.

### Step 3: Check the list and the proxy

```bash
# READ-ONLY
source ~/nkp-nkp-mgmt.env 2>/dev/null
tr ',' '\n' <<< "$NO_PROXY_LIST" | wc -l
```

The count must be 128 or less.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
curl -sS -o /dev/null -w '%{http_code}\n' --proxy "$NKP_HTTPS_PROXY" https://registry.k8s.io/v2/
```

A code that is not `000` means the operator host reaches the proxy. `000` means no connection: the operator host must be in the same proxy domain as the new cluster [pdf p.666].

### Step 4: Put the three flags in the create script (skill `nkp-install`)

The create script is `~/nkp-nkp-mgmt-create.sh` (mode 700). Skill `nkp-install` writes it (case 4A, 4B, or 4C in `references/nutanix.md`). The three proxy lines go before `"$@"`:

```text
  --http-proxy "$NKP_HTTP_PROXY" \
  --https-proxy "$NKP_HTTPS_PROXY" \
  --no-proxy "$NO_PROXY_LIST" \
```

Then the dry run and the real create:

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-nkp-mgmt.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

- Plan: the file path, and the fact that the file holds Secrets. I stop for your "yes" before I run it. Never apply that file with `kubectl` [pdf p.729].
- Done when the dry run ends without an error and you agree with the shown lines.

UNKNOWN (N-23): on Nutanix, whether `--http-proxy` on `nkp create cluster nutanix` sets both `clusterConfig.proxy` and the CAPI controllers. This check answers only the node part; it reads the file with anchored patterns that end in `:`:

```bash
# READ-ONLY
source ~/nkp-nkp-mgmt.env 2>/dev/null
grep -n -E '^kind:|^ +(http|https|additionalNo):' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

The controller part needs a real create, then: `kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}'`. I give that check after the create.

### Step 5: After the create, the platform-app pods (section X4)

Gatekeeper is off by default (`mutations.enablePodProxy: false`) [live 2.19.0]. Without X4, Flux, Kommander, Helm, OCI, and Git pulls from the pods do not use the proxy [pdf p.980-983]. Check the current state first:

```bash
# READ-ONLY
source ~/nkp-nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep gatekeeper
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get configmap gatekeeper-overrides -o jsonpath='{.data.values\.yaml}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns -l gatekeeper.d2iq.com/mutate=pod-proxy
```

If X0 found credentials, this block is USER-TERMINAL (it prints the URL). Then X4 does four steps: write the values file, merge old values, server dry run, apply; then label the namespaces `kommander` and `kommander-flux`. Those are three CHANGES blocks in `references/proxy.md`, X4 steps 2a, 2d, and 3. I show each one with its plan and stop for your "yes" before each. I do not show them in this reply, because the create does not exist yet.

### Step 6: Verify (section X6)

```bash
# READ-ONLY
source ~/nkp-nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o json | jq -c '.spec.capiCluster.topology.variables[] | select(.name=="clusterConfig") | .value.proxy // {} | {http: ((.http // "") | length), https: ((.https // "") | length), additionalNo}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander run proxy-check --image=busybox --restart=Never --dry-run=server -o json | jq -c '[.spec.containers[0].env[]?.name]'
```

Done when line 1 shows lengths above 0, line 2 lists `HTTP_PROXY HTTPS_PROXY NO_PROXY`, and line 3 prints `["HTTP_PROXY","HTTPS_PROXY","NO_PROXY"]`.

### Facts and warnings for this site

- Do not use the Flux pod env as proof of the proxy. The Flux chart always sets these variables, also with no proxy [live 2.19.0].
- A later change of the proxy replaces all nodes [pdf p.672]. The later change is X5: CAPI controllers, then X4, then `clusterConfig.proxy`.
- This is a management cluster, so the no-proxy list must name the API VIP of each workload cluster, each as a single IP. The NKP UI does not read a CIDR in no-proxy [pdf p.979]. Each new workload cluster therefore needs a new list, and a new list replaces all nodes of the management cluster [pdf p.672].
- `PC_ENDPOINT` and `REGISTRY_URL` are internal: their hosts must be in `extra`, or the nodes send Prism Central and registry traffic to the proxy.

---

## nkp-networking W7

Skill files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-networking/SKILL.md`, `skills/nkp-networking/references/cni.md` (C4), `skills/nkp-networking/references/metallb.md` (M1 check), `skills/nkp-troubleshooting/references/diagnose.md` (D1).

### The likely cause

The UI is not on the API VIP. Traefik serves it, and the Service `kommander/kommander-traefik` takes the first IP of the MetalLB range [live 2.19.0][pdf p.721]. The API VIP is a kube-vip static pod that moves between control-plane nodes; it does not give Service IPs [live 2.19.0]. So two different mechanisms carry the two addresses. `kubectl` to the VIP works and the UI IP does not: the fault is on the Service/LoadBalancer path, not on the control plane.

The Cilium default datapath on AHV uses `bpf-lb-mode: dsr` with DSR dispatch `geneve` [live 2.19.0]. On subnets that the Network Controller manages, and on VPC overlay subnets, a node that does not own the Service IP can send the reply, and the network drops it. Symptom: the UI and the LoadBalancer IPs do not answer and the API VIP answers [field].

That is UNKNOWN (N-01): whether the default DSR mode breaks LoadBalancer replies on Network Controller VLANs and VPC subnets, and whether SNAT is the fix. The skills do not confirm it. The checks below tell us whether your case matches.

It is not the self-signed certificate: a certificate problem gives a browser warning, not no answer.

### Questions that I would ask

1. What is the cluster name? Your prompt does not name it, so I keep `~/nkp-<cluster>.env` in the blocks. The UI IP belongs to the management cluster, so I expect `WORKSPACE_NS='kommander'`; confirm it.
2. Does the UI IP answer from a host inside the node subnet, and only fail from outside? That one answer separates N-01 (outside only) from a MetalLB address or advertisement problem (both) and from a routing or firewall problem (only some sources).
3. What changed just before it stopped: an NKP or Kubernetes upgrade, an addon change, a network or subnet change, a firewall change? An address that answered before and does not answer now is not a plain "wrong configuration from day one".
4. Is the UI address the first IP of `LB_IP_RANGE`? Take it from the Service, not from memory.

### Step 1: Read the network state (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.clusterNetwork}{"\n"}{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}cni={.value.addons.cni}{"\n"}lb={.value.addons.serviceLoadBalancer}{"\n"}kubeProxy={.value.kubeProxy}{"\n"}proxyNo={.value.proxy.additionalNo}{"\n"}sans={.value.extraAPIServerCertSANs}{"\n"}{end}ingress={.spec.kommanderCluster.spec.ingress}{"\n"}'
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ds -A | grep -E 'cilium|calico|kube-proxy|speaker'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements,bgpadvertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ingressclass
```

What I look for on a default AHV cluster [live 2.19.0]: DaemonSets `cilium`, `cilium-envoy`, `metallb-speaker` and no `kube-proxy`; one IPAddressPool `metallb` and one L2Advertisement `metallb`; `kommander/kommander-traefik` as a `LoadBalancer` Service with an EXTERNAL-IP (the UI address); `ingress` showing `hostname` when nobody set a domain.

- Service EXTERNAL-IP empty `<pending>`: that is a different fault (`references/metallb.md`, section M1), not this one.
- Service has the IP but nothing answers from outside: continue.
- The table in `references/metallb.md`, section M1 has this row: "EXTERNAL-IP is set, but clients get no answer" gives two candidates, ARP or routing, and Cilium DSR, and says to check from a host in the same subnet, then go to `references/cni.md` C4 [live 2.19.0]. Your inside/outside answer selects the row.

### Step 2: The N-01 check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get configmap cilium-config -o jsonpath='{.data.bpf-lb-mode}{"\n"}'
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status --brief
```

- `dsr` plus "answers inside the node subnet, not outside" matches N-01. `snat` does not match N-01.
- A `cilium-dbg status --brief` that is not `OK` is a CNI problem first: use `nkp-troubleshooting`, rung 5.
- Then do the test from a client outside the node subnet (not from the operator host if the operator host is inside the subnet). Ask the user or a network colleague for that test; I cannot run it.

### Step 3: What the skills offer as a fix

- The field fix is `loadBalancer.mode: snat`, set through the Cilium values ConfigMap at create time (`references/cni.md`, section C3) [field][pdf p.728].
- A running cluster ignores new Cilium values: an edit of the cluster spec or of the `cilium-config` ConfigMap does not reach the installed Cilium [pdf p.727]. So on this cluster that fix is not available. Do not patch `cilium-config` and expect a change.
- This is a management cluster. For a management cluster the fix is not in the skills (`references/cni.md`, C4). I do not show a NodePort plus external load balancer workaround: it is not a known fix for N-01.

So what I would tell you:

1. This matches a known, unconfirmed field pattern (N-01) on Network Controller VLANs. The skills do not have a supported fix for a running management cluster.
2. Collect the evidence and open a case with Nutanix support. The support bundle is `nkp diagnose` (skill `nkp-troubleshooting`, `references/diagnose.md`, D1). On an air-gapped site the node collector image is not in the 2.19.0 bundle: do `prestage.md` item P5 first (skill `nkp-airgap`, also not installed here). `nkp diagnose` starts privileged pods on every node and writes a file, so it is a CHANGES command and I show it with its plan before I run it.
3. Give support these facts: the failing address is the `kommander-traefik` MetalLB IP, `bpf-lb-mode: dsr`, the nodes are on a Network Controller VLAN, the API VIP answers, and the exact inside/outside test results.

If the same symptom later appears on a new workload cluster that you have not created yet, the documented path is a new cluster with `loadBalancer.mode: snat` in the Cilium values ConfigMap before the create (C3). Tell me before that create, and I plan it.
