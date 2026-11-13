---
name: nkp-networking
description: >
  NKP cluster networking: Cilium or Calico CNI, Hubble flows, pod and service CIDR, MTU, LoadBalancer IPs
  (MetalLB Layer 2 and BGP pools, kube-vip API VIP, Nutanix CCM), Traefik ingress, custom domain and
  ingress certificate (cert-manager, ACME), HTTP proxy and the no-proxy list.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-02"
  sources: "live 2.19.0, pdf 2.19"
---

# NKP networking

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

## The network parts

| Part | What does it | Facts |
|---|---|---|
| CNI | Cilium 1.19.4 on AHV (default) [live 2.19.0] and EKS [pdf p.20] (P-05). Calico on the other providers. | Choose at create time only. [references/cni.md](references/cni.md) |
| kube-proxy | Cilium replaces it: no `kube-proxy` DaemonSet, `clusterConfig.kubeProxy.mode: disabled`. [live 2.19.0] Calico clusters keep kube-proxy. [pdf p.593] | `kubeProxy.mode` cannot change after the create. [live 2.19.0] |
| Service `LoadBalancer` IPs | MetalLB 0.15.3 (Layer 2 by default, FRR 9.1.3 for BGP). On AHV, CAREN fills the default pool `metallb` from `--kubernetes-service-load-balancer-ip-range`. [live 2.19.0] Cloud providers use the cloud load balancer. [pdf p.594] | [references/metallb.md](references/metallb.md) |
| Control-plane VIP | kube-vip 1.1.1, a static pod `kube-vip-<node>` in `kube-system`. It moves the API VIP between control-plane nodes. It does not do load balancing and it does not give Service IPs. [live 2.19.0][pdf p.786] | Set at create time (`CP_VIP`, skill `nkp-install`). |
| Nutanix CCM | Node metadata only. It gives no Service IPs. [live 2.19.0] | |
| Ingress | Traefik (chart 39.0.7, image v3.6.12). IngressClass `kommander-traefik` is the default. Service `kommander/kommander-traefik` gets the first IP of the MetalLB range. [live 2.19.0][pdf p.721] | [references/ingress-certs.md](references/ingress-certs.md) |
| Certificates | cert-manager 1.20.3. The UI certificate `kommander-traefik-tls` comes from the ClusterIssuer `kommander-ca` (self-signed CA). [live 2.19.0] | [references/ingress-certs.md](references/ingress-certs.md) |
| HTTP proxy | Three places: the nodes, the CAPI controllers, the platform-app pods (Gatekeeper). [pdf p.666, p.980] | [references/proxy.md](references/proxy.md) |

Not in this skill: Flow CNI (skill `nkp-flow-cni`), a cluster inside a Flow VPC (skill `nkp-vpc`), plain Kubernetes NetworkPolicy and Service basics (skill `kubernetes-core`).

## Job → section

| Job | Where |
|---|---|
| Read the network state of a cluster | step 1 |
| Choose the CNI, CIDRs, custom Cilium values (WireGuard, SNAT), Calico tuning, MTU | [references/cni.md](references/cni.md) |
| See pod traffic (Hubble) | step 2 |
| More LoadBalancer IPs, a separate pool, BGP mode, a Service stays `<pending>` | [references/metallb.md](references/metallb.md) |
| Custom domain, own certificate, ACME, an Ingress for an app, an external load balancer | [references/ingress-certs.md](references/ingress-certs.md) |
| Proxy flags at create time, the no-proxy list, change the proxy after the create, pods without proxy settings | [references/proxy.md](references/proxy.md) |
| Create flags of a new cluster | skill `nkp-install` |
| Apply a change to the NKPCluster (JSON patch, rollout watch) | skill `nkp-cluster-lifecycle`, step 3 |

## Step 1: Read the network state

Use this before every change. The first block reads the NKPCluster on the management cluster. The second block reads the cluster itself.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.clusterNetwork}{"\n"}{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}cni={.value.addons.cni}{"\n"}lb={.value.addons.serviceLoadBalancer}{"\n"}kubeProxy={.value.kubeProxy}{"\n"}proxyNo={.value.proxy.additionalNo}{"\n"}sans={.value.extraAPIServerCertSANs}{"\n"}{end}ingress={.spec.kommanderCluster.spec.ingress}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o json | jq -c '.spec.capiCluster.topology.variables[] | select(.name=="clusterConfig") | .value.proxy // {} | {http: ((.http // "") | length), https: ((.https // "") | length)}'
```

The block does not print the proxy URLs, because a URL can hold a password. It prints only their length.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ds -A | grep -E 'cilium|calico|kube-proxy|speaker'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements,bgpadvertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ingressclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterissuers,certificates -A
```

What you see on a default AHV cluster [live 2.19.0]:
- `clusterNetwork`: pods `192.168.0.0/16`, services `10.96.0.0/12` (the defaults). `cni` provider `Cilium`, strategy `HelmAddon`. `lb` provider `MetalLB` with one `addressRanges` item. `kubeProxy` `{"mode":"disabled"}`. `proxyNo` empty and the lengths `0` when the site has no proxy.
- DaemonSets `cilium`, `cilium-envoy`, `metallb-speaker`. No `kube-proxy`.
- One IPAddressPool `metallb` and one L2Advertisement `metallb`. No BGP objects.
- One `LoadBalancer` Service: `kommander/kommander-traefik` (management cluster).
- `ingress` shows `hostname` (the first LB IP when nobody set a domain).

Done when: you know the CNI, the CIDRs, the LB mode, and the proxy state of the cluster.

## Step 2: Hubble (Cilium only)

Hubble is on. Hubble Relay runs in `kube-system` (Service `hubble-relay`, port 443, mTLS). There is no Hubble UI. [live 2.19.0] The `hubble` CLI is in the `cilium-agent` container. It sees the flows of the node where that agent pod runs. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status --brief
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- hubble observe --last 20
```

- `cilium-dbg status --brief` prints `OK` on a healthy agent. [live 2.19.0]
- For one pod, run `hubble observe` in the agent pod on the node of that pod. Set `ns` and `pod`. For dropped packets, add `--verdict DROPPED` to the last line.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''
: "${ns:?}" "${pod:?}"
node=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='{.spec.nodeName}')
agent=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get pods -l k8s-app=cilium --field-selector spec.nodeName="$node" -o name)
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec "$agent" -c cilium-agent -- hubble observe --pod "$ns/$pod" --last 50
```

- The platform app `cilium-hubble-relay-traefik` exposes the relay through Traefik with TLS passthrough. [pdf p.309]

Done when: `hubble observe` prints flows.

## Step 3: Plan a change

Most network settings are fixed at create time. Before a change, find the row:

| Change | Possible on a running cluster? |
|---|---|
| Pod CIDR, service CIDR, Cilium IPAM mode | No. Make a new cluster and move the workloads. [pdf p.497-498] The API accepts the change. [live 2.19.0] The network breaks. A revert does not fix it. [pdf p.498] |
| CNI provider | No. The API accepts the change [live 2.19.0], but a CNI switch is not in the skills. Stop. |
| `kubeProxy.mode` | No. The API rejects it: "Value cannot be changed after cluster creation". [live 2.19.0] |
| Cilium Helm values | Only from a values ConfigMap that the cluster had at create time. [pdf p.727] A later edit of `cilium-config` or of the cluster spec does not reach Cilium. See [references/cni.md](references/cni.md). |
| More LoadBalancer IPs, BGP | Yes: a new MetalLB pool. Do not edit the default pool `metallb` or the L2Advertisement `metallb`: the next cluster upgrade stalls. [pdf p.672] |
| Custom domain, ingress certificate | Yes: an NKPCluster merge patch. [pdf p.493-494] |
| HTTP proxy | Yes, in three places. The node part replaces all nodes. [pdf p.670-672] |
| API server certificate SANs | At create time: `--extra-sans`. [live 2.19.0] Later: not in the skills. A Flow VPC external endpoint (`--control-plane-external-endpoint`): skill `nkp-vpc`. |

Done when: you showed the user the row, and the user agrees with the plan.

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| A `LoadBalancer` Service stays `<pending>` | The pools have no free IP, or no advertisement selects the pool. | [references/metallb.md](references/metallb.md), section M1. |
| A Service with `externalIPs` is rejected | NKP API servers deny `externalIPs` (skill `nkp-identity-security`, `cluster-security.md` C5). | Use a `LoadBalancer` Service (MetalLB): [references/metallb.md](references/metallb.md). |
| The UI IP does not answer, the API VIP answers | Cilium DSR on a Network Controller VLAN or a VPC subnet (N-01). | [references/cni.md](references/cni.md), section C4. |
| Large packets hang (TLS, image pulls), small packets pass | MTU. | [references/cni.md](references/cni.md), section C5. |
| Pods cannot reach a service in the cluster, the proxy logs show cluster addresses | The no-proxy list is incomplete. | [references/proxy.md](references/proxy.md), section X2. |
| Browser shows a certificate warning | The default self-signed `kommander-ca` certificate. | [references/ingress-certs.md](references/ingress-certs.md). |
| `IngressCertificateReady` is `False` | The certificate Secret or the issuer is wrong or missing. | [references/ingress-certs.md](references/ingress-certs.md), section I4. |

For other failures, use skill `nkp-troubleshooting`.

## Related skills

Create flags and IP plan of a new cluster: skill `nkp-install`. Node pools and the NKPCluster patch method: skill `nkp-cluster-lifecycle`. App overrides (Traefik values, external-dns): skill `nkp-platform-apps-gitops`. Gatekeeper policy: skill `nkp-identity-security`. Flow CNI: skill `nkp-flow-cni`. Flow VPC: skill `nkp-vpc`.
