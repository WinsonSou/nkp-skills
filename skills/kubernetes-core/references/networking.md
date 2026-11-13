# Services, DNS, NetworkPolicy, Ingress (plain Kubernetes)

Use this file from skill `kubernetes-core`. It covers the plain Kubernetes objects. The CNI (Cilium, Hubble), MetalLB, Traefik, certificates, and the proxy belong to skill `nkp-networking`.

## N1. A Service does not answer

Go from the Service to the pods. Stop at the first step that is wrong.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; svc=''
: "${ns:?}" "${svc:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get svc "$svc" -o jsonpath='type={.spec.type} clusterIP={.spec.clusterIP} selector={.spec.selector} ports={.spec.ports}{"\n"}lb={.status.loadBalancer.ingress}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get endpointslices -l "kubernetes.io/service-name=$svc" -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pods -o wide --show-labels
```

| What you see | Cause | Fix |
|---|---|---|
| EndpointSlice ENDPOINTS `<unset>` or empty | No ready pod matches the `selector`. | Compare the selector with the pod labels (`--show-labels`). Pods not ready: file [pods.md](pods.md), P3. |
| Endpoints exist, the port is wrong | `targetPort` is not the port where the container listens. | `targetPort` must be the container port (a number, or the name of a container port). |
| `selector` empty | A Service without a selector. Someone must manage the EndpointSlices. | Usually a mistake. Add the selector. |
| type `LoadBalancer`, `lb` empty (`<pending>`) | No IP from the load balancer. | skill `nkp-networking` (MetalLB). |
| Works from the pod, not from another namespace | A NetworkPolicy. | N3. |
| Works by IP, not by name | DNS. | N2. |

- Service types [live 2.19.0]: `ClusterIP` (inside the cluster), `NodePort` (a port on every node, default range 30000-32767), `LoadBalancer` (an external IP), `ExternalName` (a DNS CNAME, no proxy).
- `externalIPs` is rejected: use a `LoadBalancer` Service. The API server admission plugins: skill `nkp-identity-security` (`cluster-security.md` C5).
- `externalTrafficPolicy: Local` keeps the client IP, but only nodes with a ready pod answer.
- A headless Service (`clusterIP: None`) has no virtual IP. DNS gives the pod IPs. A StatefulSet needs one (file [workloads.md](workloads.md), W5).

Test from inside the cluster with a pod in the same namespace (`kubectl debug`, file [pods.md](pods.md), P7) or with a test pod (N2).

## N2. DNS

Facts [live 2.19.0]: CoreDNS v1.14.2, Deployment `coredns` (2 replicas) in `kube-system`, Service `kube-dns` (ports 53 UDP and TCP, 9153 metrics), cluster domain `cluster.local`. The Corefile forwards other names to the node `/etc/resolv.conf`.

Names:
- Service: `<svc>.<ns>.svc.cluster.local`. In the same namespace, `<svc>` is enough.
- StatefulSet pod through its headless Service: `<pod>.<svc>.<ns>.svc.cluster.local`.
- `ndots:5` in the pod `/etc/resolv.conf`: a name with fewer than 5 dots goes first through the search list. An external name with a trailing dot (`example.com.`) skips it.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get deploy coredns
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get endpointslices -l kubernetes.io/service-name=kube-dns
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system logs deploy/coredns --tail=50
```

Healthy: `coredns` READY `2/2`, the EndpointSlice has 2 endpoints, the log has no `[ERROR]` lines. [live 2.19.0] `[ERROR] plugin/errors: ... i/o timeout` for external names: the upstream DNS server of the nodes does not answer (site DNS, or a proxy-only site). A name that resolves inside the cluster but not outside is normal in an air gap.

Test pod (it runs once and is deleted). Pod Security `restricted` accepts it:

```bash
# CHANGES  (runs one short test pod in the namespace, then deletes it)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; name=''
: "${ns:?}" "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" run "dnscheck-$(date +%s)" --image=busybox:1 --restart=Never --rm --attach --quiet --overrides='{"apiVersion":"v1","spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":65534,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"c","image":"busybox:1","args":["nslookup","'"$name"'"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}' --pod-running-timeout=2m
```

- `name` is the name to test, for example `kubernetes.default.svc.cluster.local` or a Service name.
- `busybox:1` is in the 2.19.0 bundles. [live 2.19.0] `ErrImagePull`: skill `nkp-airgap`.
- `NXDOMAIN` for a Service: wrong name or namespace. A timeout: CoreDNS is down, or a NetworkPolicy blocks UDP and TCP port 53 to `kube-system` (N3).
- For the pod network path (drops, policy verdicts), use Hubble: skill `nkp-networking`, step 2.

## N3. NetworkPolicy

- With no NetworkPolicy that selects a pod, all traffic to and from the pod is allowed.
- When one policy selects a pod for `Ingress`, only the traffic that some policy allows comes in. The same for `Egress`. Policies add up (a union). There is no "deny" rule in a NetworkPolicy.
- `policyTypes`: `["Ingress"]`, `["Egress"]`, or both. An egress-only policy or a deny-all-egress policy must list `Egress`. [live 2.19.0]
- Peers: `podSelector` (same namespace), `namespaceSelector`, both in one item (AND: pods with that label in those namespaces), or `ipBlock` (`cidr`, `except`). Ports: `port`, `endPort`, `protocol` (`TCP`, `UDP`, `SCTP`). [live 2.19.0]
- Two list items (`- podSelector` and `- namespaceSelector`) are an OR. One item with both keys is an AND. This is the most common mistake.
- Every namespace has the label `kubernetes.io/metadata.name: <ns>`. [live 2.19.0] Use it in `namespaceSelector`.
- A deny-all-egress policy also blocks DNS. Allow UDP and TCP 53 to `kube-system` pods with `k8s-app: kube-dns`. [live 2.19.0]
- Cilium enforces NetworkPolicy (`enable-k8s-networkpolicy=true`) and also has its own `CiliumNetworkPolicy` and `CiliumClusterwideNetworkPolicy`. [live 2.19.0] For Cilium policies, Hubble, and dropped flows, use skill `nkp-networking`.
- NKP has its own NetworkPolicies in `kommander-flux`. [live 2.19.0] Do not change them.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get networkpolicies
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe networkpolicies
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ciliumnetworkpolicies -A
```

Example: deny all ingress in a namespace, then allow port 8080 from pods with `app: frontend` in the same namespace, and allow DNS egress. The API server accepts the first policy in a server dry run. [live 2.19.0]

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 8080
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
```

The third policy makes the namespace egress-only-DNS. Add more egress rules for the app before you apply it. Write the file and apply it with the `SKILL.md` step 4 flow (server dry run, plan, "yes").

## N4. Ingress

- An Ingress needs an IngressClass. On NKP, the class is `kommander-traefik` (the default). [live 2.19.0] The Traefik setup, TLS, and an Ingress example are in skill `nkp-networking`, file `ingress-certs.md` I6.
- `pathType` is required: `Prefix`, `Exact`, or `ImplementationSpecific`. The backend Service and port must exist in the same namespace as the Ingress.
- Field help: `kubectl explain ingress.spec --recursive`.
- Gateway API objects (`gateways`, `httproutes`) exist on 2.19.0 (from Traefik). [live 2.19.0] Their use is not in the skills.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ingressclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get ingress
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe ingress
```

`describe ingress` shows each rule and its backend endpoints. `<error: services "x" not found>` names a missing Service.
