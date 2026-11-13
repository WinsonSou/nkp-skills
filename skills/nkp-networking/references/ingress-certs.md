# Ingress, custom domain, and certificates

Use this file from skill `nkp-networking` for Traefik, the NKP UI domain, the ingress certificate, and an Ingress for an app.

| File | Site variables |
|---|---|
| `~/nkp-<cluster>.env` | `INGRESS_HOSTNAME` `INGRESS_CERT_FILE` `INGRESS_KEY_FILE` `INGRESS_CA_FILE` |

- `INGRESS_HOSTNAME`: the DNS name of the cluster UI and ingress, for example `nkp.example.com`.
- `INGRESS_CERT_FILE`: PEM file with the full chain: server certificate, intermediates, and root. [pdf p.493] `INGRESS_KEY_FILE`: its private key (PEM). `INGRESS_CA_FILE`: the CA bundle (root and intermediates). The private key file is a secret: keep it mode 600 and never print it.

## I1. Facts

- Traefik is a platform app on every cluster. Service `kommander-traefik` in `WORKSPACE_NS` (`kommander` on the management cluster; a workload cluster has no `kommander` namespace) [live 2.19.0], type `LoadBalancer`, `externalTrafficPolicy: Cluster`, ports `web` 80, `websecure` 443, `registry` 5000, `external-ceph` 8085. [live 2.19.0]
- IngressClass `kommander-traefik` is the default IngressClass. GatewayClass `traefik` exists (only the Gateway API CRDs are installed). [live 2.19.0]
- The UI certificate: Certificate `kommander-traefik-tls` from the ClusterIssuer `kommander-ca` (a self-signed CA made by NKP). The Traefik default TLSStore uses it. [live 2.19.0] Browsers show a warning until you set your own certificate.
- The CA Certificate `cert-manager/kommander-ca` has `duration: 87600h` (10 years). The UI Certificate `kommander/kommander-traefik-tls` has `duration: 2160h` (90 days), and cert-manager renews it. [live 2.19.0]
- cert-manager 1.20.3 runs on every cluster. [live 2.19.0]
- The KommanderCluster (management cluster, workspace namespace) holds the ingress state. Its NKPCluster field is `spec.kommanderCluster.spec.ingress` with `hostname`, `certificateSecretRef`, `issuerRef`. [live 2.19.0] Without a domain, `hostname` is the Traefik IP. [live 2.19.0]
- The Issuer, ClusterIssuer, or certificate Secret is on the target cluster (the workload cluster for a workload cluster). The NKPCluster is on the management cluster. [pdf p.492, p.494]
- ACME (Let's Encrypt and other public CAs) does not work air-gapped, and does not work with an IP as hostname. [pdf p.491, p.978] Air-gapped: keep the default certificate or use your own certificate (I3).
- At create time on Nutanix, the flags `--cluster-hostname`, `--ingress-certificate`, `--ingress-private-key`, `--ingress-ca` set the same values. [live 2.19.0] The create script: skill `nkp-install`.

Read the state:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.kommanderCluster.spec.ingress}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommandercluster "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[?(@.type=="IngressAddressReady")]}{.type}={.status} {.reason}{"\n"}{end}{range .status.conditions[?(@.type=="IngressCertificateReady")]}{.type}={.status} {.reason}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get svc kommander-traefik -o go-template='{{with index .status.loadBalancer.ingress 0}}{{or .hostname .ip}}{{end}}{{"\n"}}'
```

The KommanderCluster has the same name as the NKPCluster, in the same namespace, on the management cluster and for a workload cluster. [live 2.19.0]

## I2. DNS first

The hostname must resolve from the browsers and from the cluster. Make an A record to the Traefik IP (or a CNAME when the third command in I1 prints a name). [pdf p.970] The platform app `external-dns` can make the record (skill `nkp-platform-apps-gitops`). [pdf p.971]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
getent hosts "$INGRESS_HOSTNAME"
```

Done when: the name resolves to the Traefik IP.

## I3. Your own certificate (also air-gapped)

The certificate must be for `INGRESS_HOSTNAME`. cert-manager does not renew it. The user replaces it before it expires. [pdf p.968]

1. Check the files. The output shows the subject, the names, and the end date. It does not show the key.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
openssl x509 -in "$INGRESS_CERT_FILE" -noout -subject -enddate -ext subjectAltName
grep -c 'BEGIN CERTIFICATE' "$INGRESS_CERT_FILE"
[ "$(openssl x509 -in "$INGRESS_CERT_FILE" -noout -pubkey | sha256sum)" = "$(openssl pkey -in "$INGRESS_KEY_FILE" -pubout | sha256sum)" ] && echo "key matches" || echo "KEY DOES NOT MATCH"
```

- The names must include `INGRESS_HOSTNAME`. The count must be 2 or more (full chain). [pdf p.493] The last line must be `key matches`.

2. Create the Secret on the target cluster, in the workspace namespace. [pdf p.493-494]

```bash
# CHANGES  (creates the TLS Secret of the cluster ingress on the target cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" create secret generic "$CLUSTER_NAME-ingress-tls" --type=kubernetes.io/tls --from-file=ca.crt="$INGRESS_CA_FILE" --from-file=tls.crt="$INGRESS_CERT_FILE" --from-file=tls.key="$INGRESS_KEY_FILE"
```

3. Preview the NKPCluster patch with a server dry run. The NKP webhooks have `sideEffects: None`. [live 2.19.0]

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
p=$(printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s","certificateSecretRef":{"name":"%s-ingress-tls"}}}}}}' "$INGRESS_HOSTNAME" "$CLUSTER_NAME")
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type merge -p "$p" --dry-run=server -o jsonpath='{.spec.kommanderCluster.spec.ingress}{"\n"}'
```

4. Show the plan (cluster, hostname, Secret name; the UI moves to the new name). Stop for "yes". Then apply:

```bash
# CHANGES  (sets the custom domain and certificate of the cluster ingress)
source ~/nkp-<cluster>.env 2>/dev/null
p=$(printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s","certificateSecretRef":{"name":"%s-ingress-tls"}}}}}}' "$INGRESS_HOSTNAME" "$CLUSTER_NAME")
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type merge -p "$p"
```

**Hostname only** (no own certificate; the UI keeps the `kommander-ca` certificate with the new name). Skip steps 1-2. In the steps 3-4 blocks, use this patch body in `p`:

```bash
# READ-ONLY  (prints the hostname-only patch body for I3 steps 3-4)
source ~/nkp-<cluster>.env 2>/dev/null
printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s"}}}}}\n' "$INGRESS_HOSTNAME"
```

The server dry run accepts this patch. [live 2.19.0] In the step 4 plan, give the old and the new hostname (the UI URL changes).

To renew: replace the Secret with the new files. The `certificateSecretRef` stays the same. Show the plan (cluster, Secret name, the new files). Stop for "yes". Then run:

```bash
# CHANGES  (replaces the TLS Secret of the cluster ingress on the target cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" create secret generic "$CLUSTER_NAME-ingress-tls" --type=kubernetes.io/tls --from-file=ca.crt="$INGRESS_CA_FILE" --from-file=tls.crt="$INGRESS_CERT_FILE" --from-file=tls.key="$INGRESS_KEY_FILE" --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - >/dev/null && echo replaced
```

Done when: I4 passes.

## I4. Verify

Run the second command of I1. Then:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
echo | openssl s_client -connect "$INGRESS_HOSTNAME:443" -servername "$INGRESS_HOSTNAME" 2>/dev/null | openssl x509 -noout -subject -issuer -enddate
```

- `IngressAddressReady=True IngressServiceAddressFound` and `IngressCertificateReady=True Ready`. [pdf p.971][live 2.19.0]
- The `openssl` issuer is your CA, not `kommander-ca`.
- `IngressCertificateReady=False`: the Secret is missing on the target cluster, is in the wrong namespace, or has no full chain. `IngressServiceNotFound`: Traefik has no IP (see [metallb.md](metallb.md), section M1). [pdf p.495]

## I5. ACME (connected sites only)

The ClusterIssuer on the target cluster must have the name `kommander-acme-issuer`, and its account Secret the name `kommander-acme-issuer-account`. [pdf p.493, p.966-967]

- HTTP01: the cluster must be reachable from the ACME server. The solver Ingress needs the annotations `kubernetes.io/ingress.class: kommander-traefik` and `traefik.ingress.kubernetes.io/router.priority: "2147483647"`. On-premises, the guide uses `traefik.ingress.kubernetes.io/router.tls: "true"` in place of the priority annotation. [pdf p.966-967]
- DNS01: required for a cluster behind a proxy or with no inbound access. [pdf p.492, p.964] The DNS provider settings come from the user's DNS team.
- Other ACME servers: set `spec.acme.server` (ZeroSSL, another public ACME CA, or an internal ACME server). [pdf p.965]

Example ClusterIssuer (HTTP01, on-premises). Ask the user for the e-mail and the server URL:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: kommander-acme-issuer
spec:
  acme:
    email: ops@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: kommander-acme-issuer-account
    solvers:
    - http01:
        ingress:
          ingressTemplate:
            metadata:
              annotations:
                kubernetes.io/ingress.class: kommander-traefik
                traefik.ingress.kubernetes.io/router.tls: "true"
```

Write it to `$PWD/<cluster>-acme-issuer.yaml` with the user's values (CHANGES: show the file, stop for "yes"). Then preview it:

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-acme-issuer.yaml"
```

Show the plan (the cluster, the issuer). Stop for "yes". Then apply:

```bash
# CHANGES  (creates the ClusterIssuer kommander-acme-issuer on the target cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-acme-issuer.yaml"
```

Then use the I3 steps 3-4 blocks with this patch body in `p`:

```bash
# READ-ONLY  (prints the patch body for I3 steps 3-4)
source ~/nkp-<cluster>.env 2>/dev/null
printf '{"spec":{"kommanderCluster":{"spec":{"ingress":{"hostname":"%s","issuerRef":{"name":"kommander-acme-issuer","kind":"ClusterIssuer"}}}}}}\n' "$INGRESS_HOSTNAME"
```

The server dry run accepts this patch. [live 2.19.0] Check the order:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get certificates,orders,challenges -A
```

Done when: I4 passes.

## I6. An Ingress for an app

Traefik serves every Ingress of class `kommander-traefik` on the Traefik IP. [pdf p.596] Example (the app owner applies it in the app namespace):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: kommander-traefik
  rules:
  - http:
      paths:
      - path: /echo1
        pathType: Prefix
        backend:
          service:
            name: http-echo-1
            port:
              number: 80
```

- Without a `host`, the rule takes the path on every name. Add `host:` for name-based routing.
- Without a `tls` section, Traefik uses its default certificate (the UI certificate).
- A plain TCP or UDP service: use a `LoadBalancer` Service with MetalLB ([metallb.md](metallb.md)), or an extra Traefik entry point through the Traefik app overrides (skill `nkp-platform-apps-gitops`).

## I7. External load balancer in front of Traefik

- The external load balancer must not end TLS. [pdf p.594, p.977]
- The guide sets Traefik to `service.type: NodePort` with fixed node ports (30000-32768) in the Traefik values, and points the load balancer at every worker on those ports. [pdf p.978-979] The Traefik values change: skill `nkp-platform-apps-gitops`.
- Set `clusterHostname` (I3, or `kommander.yaml`) to the load balancer name. [pdf p.978]
- Source IP of clients: Traefik uses `externalTrafficPolicy: Cluster` [live 2.19.0], so the pods see a node IP. `Local` keeps the client IP. [field]
