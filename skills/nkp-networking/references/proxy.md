# HTTP proxy

Use this file from skill `nkp-networking` for a site where the nodes reach the internet only through an HTTP or HTTPS proxy. An air-gapped site with no proxy does not need it.

`NKP_HTTP_PROXY` and `NKP_HTTPS_PROXY` (site env file) hold the proxy URLs, for example `http://proxy.example.com:3128`. The names start with `NKP_` on purpose: a plain `HTTP_PROXY` in the env file would also change `kubectl` and `curl` on the operator host. If the proxy URL holds a user and a password, it is a secret: the user writes the two lines with an editor (rule 5).

## X0. Credentials in the proxy URL

Run this check before X2:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
case "$NKP_HTTP_PROXY $NKP_HTTPS_PROXY" in *@*) echo "proxy URL has a user or password";; *) echo "no credentials in the proxy URL";; esac
```

If it prints `has a user or password`:
- These blocks print the URL. Change line 1 to `# USER-TERMINAL  (operator host)` and give them to the user: X4 step 1, the N-23 check, and the skill `nkp-cluster-lifecycle` step 3b dry run (its diff shows `proxy.http`).
- Tell the user that NKP keeps the URL as plain text in the NKPCluster and in the ConfigMap `gatekeeper-overrides`.

The other blocks in this file do not print the URL.

## X1. Where NKP needs the proxy

| Place | What uses it | How to set it |
|---|---|---|
| Bootstrap cluster (kind on the operator host) | the create | the create flags (X3). Operator host prerequisites: skill `nkp-install`. |
| CAPI controllers (management cluster) | CAPX, CAREN, CAAPH, and the other providers: calls to Prism Central, cloud APIs, chart pulls | the create flags at create time. After: X5. [pdf p.666-671] |
| Nodes (kubelet, containerd) | image pulls | the create flags. After: `clusterConfig.proxy` (X5). [pdf p.668, p.671] |
| Platform-app pods (Flux, Kommander apps) | Helm, OCI, and Git pulls from the pods | Gatekeeper pod mutation (X4). [pdf p.980-983] |

On a ClusterClass cluster, the node proxy is `clusterConfig.proxy` with `http`, `https`, and `additionalNo` (max 128 items). NKP adds these no-proxy entries itself: `localhost`, the loopback address, the pod CIDR, the service CIDR, `kubernetes`, `kubernetes.default`, `.svc`, and `.svc.<service domain>`. [live 2.19.0]

## X2. Build the no-proxy list

The fixed entries are the `base` text in the blocks below: loopback, the Kubernetes API names, the service DNS suffixes with and without the trailing dot, and the link-local metadata addresses. `aws` adds two AWS entries. [pdf p.669, p.979-980] Add the site entries:

| Entry | Why |
|---|---|
| Pod CIDR and service CIDR (defaults `192.168.0.0/16`, `10.96.0.0/12`) | in-cluster traffic. Use the real CIDRs when the create changes them. [pdf p.670, p.979] |
| `CP_VIP` and the control-plane node addresses (the node subnet CIDR is OK) | the API server. [pdf p.979] |
| The first IP of `LB_IP_RANGE` | the `kommander-traefik` address (Nutanix, pre-provisioned, vSphere). [pdf p.980] |
| Management cluster only: the API VIP of each workload cluster, each as a single IP, not a CIDR | The Kommander UI does not read a CIDR in no-proxy. [pdf p.979] |
| Internal hosts: the host of `PC_ENDPOINT`, the host of `REGISTRY_URL`, the identity provider, internal domains (with a leading dot) | They are not on the internet. [pdf p.669] |
| AWS only: the VPC CIDR and `.elb.amazonaws.com` | [pdf p.669-670, p.980] |

Rules:
- Separate the entries with a comma and no space. [pdf p.667]
- A domain suffix entry gets a trailing dot too (for example `.svc.cluster.local.`). Without it, some proxy clients add the search domain and send cluster traffic to the proxy. [pdf p.980]

Do these steps:
1. Ask the user for the extra entries: the host names of `PC_ENDPOINT` and `REGISTRY_URL` (if they are set), other internal hosts and domains, the node subnet, and the VIPs of other clusters.
2. Put the extra entries in `extra` as one comma-separated text.
3. Set `aws` to `yes` (any text) only for AWS or EKS.
4. Set `pods` and `svcs` to the real CIDRs if the create changes them.
5. Run the preview block.

On a management cluster, the list must name the API VIP of each workload cluster. So each new workload cluster needs a new list, and a new list on the nodes replaces all nodes of the management cluster (X5 C). Tell the user this. [pdf p.979, p.672]

```bash
# READ-ONLY  (prints the list; changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
extra=''; aws=''; pods='192.168.0.0/16'; svcs='10.96.0.0/12'
: "${CP_VIP:?}" "${LB_IP_RANGE:?}"
base='localhost,127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,.svc,.svc.cluster,.svc.cluster.local,svc.,.svc.cluster.,.svc.cluster.local.,169.254.169.254,169.254.0.0/24'
echo "$base${aws:+,10.0.0.0/16,.elb.amazonaws.com},$pods,$svcs,$CP_VIP,${LB_IP_RANGE%%-*}${extra:+,$extra}"
```

Show the list to the user. Stop. Do not show the next block in the reply that asks for `extra`, `pods`, or `svcs`. After the user agrees to the list, run the same block with the last line changed to append the value (rule 4):

```bash
# CHANGES  (appends NO_PROXY_LIST to the cluster env file)
source ~/nkp-<cluster>.env 2>/dev/null
extra=''; aws=''; pods='192.168.0.0/16'; svcs='10.96.0.0/12'
: "${CP_VIP:?}" "${LB_IP_RANGE:?}" "${CLUSTER_NAME:?}"
base='localhost,127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,.svc,.svc.cluster,.svc.cluster.local,svc.,.svc.cluster.,.svc.cluster.local.,169.254.169.254,169.254.0.0/24'
echo "export NO_PROXY_LIST='$base${aws:+,10.0.0.0/16,.elb.amazonaws.com},$pods,$svcs,$CP_VIP,${LB_IP_RANGE%%-*}${extra:+,$extra}'" >> "$HOME/nkp-$CLUSTER_NAME.env"
```

Check the proxy from the operator host. A connected proxy answers with an HTTP code (for example `200`). `000` means no connection.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
curl -sS -o /dev/null -w '%{http_code}\n' --proxy "$NKP_HTTPS_PROXY" https://registry.k8s.io/v2/
```

Count the items. `clusterConfig.proxy.additionalNo` takes 128 items or fewer. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
tr ',' '\n' <<< "$NO_PROXY_LIST" | wc -l
```

Done when: `NO_PROXY_LIST` is in the cluster env file, the count is 128 or less, and the proxy check prints an HTTP code that is not `000`.

## X3. Proxy flags at create time

Skill `nkp-install` writes the create script. Add these lines before `"$@"` in the script. Every flag is in the `--help` of the provider. [live 2.19.0]

Nutanix AHV and NKP Metal (one set for all nodes):

```text
  --http-proxy "$NKP_HTTP_PROXY" \
  --https-proxy "$NKP_HTTPS_PROXY" \
  --no-proxy "$NO_PROXY_LIST" \
```

Pre-provisioned, vSphere, AWS, Azure, GCP: the `--control-plane-*` and `--worker-*` flags set the nodes. `--http-proxy`, `--https-proxy`, and `--no-proxy` set the CAPI controllers. The three flags alone give nodes with no proxy. [live 2.19.0][pdf p.668-669] Use all nine:

```text
  --control-plane-http-proxy "$NKP_HTTP_PROXY" \
  --control-plane-https-proxy "$NKP_HTTPS_PROXY" \
  --control-plane-no-proxy "$NO_PROXY_LIST" \
  --worker-http-proxy "$NKP_HTTP_PROXY" \
  --worker-https-proxy "$NKP_HTTPS_PROXY" \
  --worker-no-proxy "$NO_PROXY_LIST" \
  --http-proxy "$NKP_HTTP_PROXY" \
  --https-proxy "$NKP_HTTPS_PROXY" \
  --no-proxy "$NO_PROXY_LIST" \
```

AKS: use only the three `--worker-*` lines. `nkp create cluster aks` has no other proxy flag. [live 2.19.0]

EKS: `nkp create cluster eks` has no proxy flag. [live 2.19.0] Do not use the AWS lines on EKS. A proxy on EKS is not in the skills.

- On pre-provisioned hosts, the guide also uses an override file, and says that the proxy flags fill the override Secret themselves. [pdf p.787] The override file format: not in the skills.
- A custom node image built with NIB uses the proxy only during the build. The image does not keep it. [pdf p.670]
- The `nkp create bootstrap` and `nkp create capi-components` commands also have `--http-proxy`, `--https-proxy`, `--no-proxy`. [live 2.19.0] `nkp create cluster` makes both itself with the create flags. [pdf p.666]
- UNKNOWN (N-23): on Nutanix and Metal, whether `--http-proxy` on `nkp create cluster nutanix|metal` sets both `clusterConfig.proxy` and the CAPI controllers. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && grep -n -E '^kind:|^ +(http|https|additionalNo):' "$PWD/$CLUSTER_NAME-dryrun.yaml"` after the dry run of skill `nkp-install`. This check answers only the node part. The controller part needs `kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}'` after a real create.
- After the create, do X4 for the platform apps.

## X4. Proxy for platform-app pods (Gatekeeper mutation)

Gatekeeper adds `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` to new pods in namespaces with the label `gatekeeper.d2iq.com/mutate=pod-proxy`. [pdf p.981-983] It is off by default: `mutations.enablePodProxy: false`. [live 2.19.0] The Gatekeeper HelmRelease reads the ConfigMap `gatekeeper-overrides` (key `values.yaml`) in its own namespace. [live 2.19.0]

- Only pods made after the change get the variables. Core services can start before Gatekeeper. To give a core service the proxy, restart it after the change. [pdf p.980-981]
- A Kommander install with its own `kommander.yaml` (not AHV `--self-managed`): put the same values under `apps.gatekeeper.values` in `kommander.yaml`, and make and label the namespaces `kommander` and `kommander-flux` before the install. [pdf p.981-982]

1. Check for an old ConfigMap and the labels:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep gatekeeper
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get configmap gatekeeper-overrides -o jsonpath='{.data.values\.yaml}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns -l gatekeeper.d2iq.com/mutate=pod-proxy
```

If X0 found credentials, step 1 is USER-TERMINAL. If step 1 prints old values, the user must keep them in step 2b.

UNKNOWN (N-24): for a workload cluster, whether the `gatekeeper-overrides` ConfigMap goes on the workload cluster or in the workspace namespace on the management cluster. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name | grep gatekeeper`.

2. Make the ConfigMap in the HelmRelease namespace from step 1 (`kommander` on the management cluster). Set `ns` to that namespace in 2c and 2d. Do four steps: 2a write, 2b merge, 2c dry run, 2d apply.

2a. Show the plan (the file path, and that it holds the proxy values). Stop for "yes". Then write the file (mode 600):

```bash
# CHANGES  (writes the values file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
: "${CLUSTER_NAME:?}" "${NO_PROXY_LIST:?}" "${NKP_HTTP_PROXY:?}" "${NKP_HTTPS_PROXY:?}"
f="$PWD/$CLUSTER_NAME-gatekeeper-proxy.yaml"
(umask 077 && printf 'disableMutation: false\nmutations:\n  enablePodProxy: true\n  podProxySettings:\n    noProxy: "%s"\n    httpProxy: "%s"\n    httpsProxy: "%s"\n  excludeNamespacesFromProxy: []\n  namespaceSelectorForProxy:\n    "gatekeeper.d2iq.com/mutate": "pod-proxy"\n' "$NO_PROXY_LIST" "$NKP_HTTP_PROXY" "$NKP_HTTPS_PROXY" > "$f")
```

2b. If step 1 printed old values, merge them into the file. Show the merged file to the user, and get a "yes" before 2c. The step 2d apply replaces all of the old ConfigMap. If X0 found credentials, the user does this step in an editor, because the file holds the URL.

2c. Preview with a server dry run. The webhooks that match ConfigMaps have `sideEffects: None` or `NoneOnDryRun`. [live 2.19.0]

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create configmap gatekeeper-overrides --from-file=values.yaml="$PWD/$CLUSTER_NAME-gatekeeper-proxy.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f -
```

The output is `configmap/gatekeeper-overrides created (server dry run)` or `configured (server dry run)`. [live 2.19.0]

2d. Show the plan (the cluster, the namespace, the ConfigMap replaces any old one). Stop for "yes". Then apply:

```bash
# CHANGES  (creates or replaces ConfigMap gatekeeper-overrides)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create configmap gatekeeper-overrides --from-file=values.yaml="$PWD/$CLUSTER_NAME-gatekeeper-proxy.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f -
```

3. Label each namespace whose pods need the proxy. Ask the user for the list. Always include `kommander` and `kommander-flux` on the management cluster. [pdf p.982]

```bash
# CHANGES  (labels namespaces so that Gatekeeper adds the proxy variables to their new pods)
source ~/nkp-<cluster>.env 2>/dev/null
for ns in kommander kommander-flux; do kubectl --kubeconfig "$CLUSTER_KUBECONFIG" label namespace "$ns" gatekeeper.d2iq.com/mutate=pod-proxy --overwrite; done
```

On Starter, the UI cannot set the workspace label. The guide changes the FederatedNamespace template so that the label stays on `kommander`. [pdf p.983] The guide uses a JSON patch; this merge patch adds the same label:

```bash
# CHANGES  (adds the pod-proxy label to the template of FederatedNamespace kommander)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" patch fns -n kommander kommander --type merge -p '{"spec":{"template":{"metadata":{"labels":{"gatekeeper.d2iq.com/mutate":"pod-proxy"}}}}}'
```

An attached cluster: make and label the workspace namespace on that cluster before you attach it. [pdf p.983]

Done when: the X6 pod check prints `["HTTP_PROXY","HTTPS_PROXY","NO_PROXY"]`.

## X5. Change the proxy after the create

The guide does three parts. [pdf p.670-672] Do them in this order. Show the user the full plan first: part C replaces all nodes.

**A. CAPI controllers (management cluster only).** The guide sets the variables on each controller with `kubectl set env`. [pdf p.671] The block skips a controller that the cluster does not have.

In part A, `<cluster>` is the management cluster.

UNKNOWN (N-22): whether the CAPI operator reverts `kubectl set env` on its controllers. The controllers belong to `InfrastructureProvider` objects, and the `CAPIStack` `capi-stack` has a `spec.proxy` field (`http`, `https`, `no`) [live 2.19.0]. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}'` some minutes after the change.

```bash
# CHANGES  (sets the proxy variables on the CAPI controllers and git-operator; the pods restart)
source ~/nkp-<cluster>.env 2>/dev/null
for d in caaph-system/caaph-controller-manager capa-system/capa-controller-manager capg-system/capg-controller-manager capi-kubeadm-bootstrap-system/capi-kubeadm-bootstrap-controller-manager capi-kubeadm-control-plane-system/capi-kubeadm-control-plane-controller-manager capi-system/capi-controller-manager cappp-system/cappp-controller-manager capv-system/capv-controller-manager capx-system/capx-controller-manager capz-system/capz-controller-manager caren-system/cluster-api-runtime-extensions-nutanix; do kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "${d%/*}" get deploy "${d#*/}" >/dev/null 2>&1 && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "${d%/*}" set env "deployment/${d#*/}" HTTP_PROXY="$NKP_HTTP_PROXY" HTTPS_PROXY="$NKP_HTTPS_PROXY" NO_PROXY="$NO_PROXY_LIST"; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n git-operator-system set env statefulset/git-operator-git HTTP_PROXY="$NKP_HTTP_PROXY" HTTPS_PROXY="$NKP_HTTPS_PROXY" NO_PROXY="$NO_PROXY_LIST"
```

The guide list does not have `cluster-api-provider-host-agent-system/capi-host-agent-controller-manager` (Metal and pre-provisioned hosts) [live 2.19.0]. Whether it needs the proxy: not in the skills (N-22).

`nkp upgrade capi-components` also has the proxy flags, but it is deprecated: `nkp upgrade kommander` runs it now. [live 2.19.0] For upgrades, use skill `nkp-upgrade`.

**B. Platform apps.** Do X4. The step 2d apply replaces the old ConfigMap. [pdf p.671]

**C. Nodes.** Change `clusterConfig.proxy` in the NKPCluster. CAPI replaces all nodes. [pdf p.672]

Use skill `nkp-cluster-lifecycle`, step 3, block "Cluster field", with `field='proxy'` and this exact `value` line. Do not print the value, and do not type the URL into the block. The shell makes the value from the env files:

```text
value="$(jq -nc --arg h "$NKP_HTTP_PROXY" --arg s "$NKP_HTTPS_PROXY" --arg n "$NO_PROXY_LIST" '{http:$h,https:$s,additionalNo:($n|split(","))}')"
```

If X0 found credentials, the step 3b dry run is USER-TERMINAL. The server dry run accepts this change. [live 2.19.0] The `additionalNo` list has a maximum of 128 items. [live 2.19.0] The step 3 watch covers the rollout. To remove the proxy: not in the skills.

Done when: X6 passes.

## X6. Verify

```bash
# READ-ONLY  (line 3 is a server dry run: it creates no pod)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o json | jq -c '.spec.capiCluster.topology.variables[] | select(.name=="clusterConfig") | .value.proxy // {} | {http: ((.http // "") | length), https: ((.https // "") | length), additionalNo}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" run proxy-check --image=busybox --restart=Never --dry-run=server -o json | jq -c '[.spec.containers[0].env[]?.name]'
```

- Line 1 shows the length of `http` and `https` (more than 0) and the `additionalNo` list. It does not print the URLs.
- Line 2 lists `HTTP_PROXY HTTPS_PROXY NO_PROXY` (management cluster with part A).
- Line 3 asks the API server to make a new pod in the labeled namespace `WORKSPACE_NS` (`kommander` on the management cluster; on a workload cluster the platform apps are in the workspace namespace [live 2.19.0]), and Gatekeeper mutates it. It prints `["HTTP_PROXY","HTTPS_PROXY","NO_PROXY"]` when X4 works. It prints `[]` when the mutation is off. [live 2.19.0] The Gatekeeper webhook has `sideEffects: None`. [live 2.19.0] For another namespace, change `-n "$WORKSPACE_NS"` to a namespace with the X4 label.
- Do not use the env of the Flux pods as proof. The Flux chart always sets `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` (empty, or unexpanded `${…}` text in `flux-oci-mirror`), also with no proxy. [live 2.19.0] Pods older than the change keep the old values: restart them after X4.
- In-cluster calls that time out and proxy logs that show cluster addresses mean a missing no-proxy entry. Do X2 again.
