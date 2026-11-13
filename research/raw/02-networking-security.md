# NKP 2.19 — Networking, Ingress, Security and Identity (research)

Scope: CNI, load balancing, ingress, certificates, DNS, identity/SSO, policy engines, service mesh,
FIPS/CIS, secrets, dashboards. Version reference: NKP **2.19** (Kubernetes 1.36.2).

Source tags: `[pdf p.N]` = `research/raw/pdf/2.19/`, `[web: url]`, `[field: <note>]`.
Public PDF > web > field notes. Facts I could not confirm are marked `UNKNOWN`.

---

## Components

### Cilium (default CNI)
- **What**: eBPF CNI: pod networking, NetworkPolicy/CiliumNetworkPolicy, kube-proxy replacement, service LB, Hubble observability.
- **Upstream**: https://github.com/cilium/cilium (`cilium` Helm chart)
- **NKP role / name**: CAREN cluster-class addon `addons.cni.provider: Cilium` (`strategy: HelmAddon` or `ClusterResourceSet`); also referenced as platform app `cilium-hubble-relay-traefik`. "NKP now supports Cilium as the default CNI. Cilium replaces kube-proxy and handles Kubernetes Service load balancing." `[pdf p.593]` Cilium is used by the **Nutanix provider and Amazon EKS provider**; "All other providers use Calico CNI." `[pdf p.20]`
- **Runs on**: workload + management clusters (all node OS).
- **Deployed by**: CAPI/CAREN addon hook at `AfterControlPlaneInitialized` via HelmAddon (or ClusterResourceSet) `[web: nutanix-cloud-native.github.io/cluster-api-runtime-extensions-nutanix/addons/cni/]`
- **Default**: **enabled (default CNI on AHV/EKS)**. Never ask for it — a standard `nkp create cluster` installs Cilium. `[pdf p.593]` `[field/web: jlnhnng.github.io/nkp-field-docs/architecture/networking/]`
- **Version in 2.19**: **Cilium 1.19.4** (chart 1.19.4) `[web: stg-live.itcs.lu/blog/nkp-219-released-verified]` `[web: .../nkp-219-upgrade-workload-clusters]`. (2.17 docs: 1.18.2, 2.18 notes: 1.19.2 but cluster ran 1.19.4.)
- **Default Helm values NKP ships** (from the "custom Cilium" walkthrough — this *is* the default render) `[pdf p.727-728]`:
  `cni.exclusive: false`, `cni.chainingMode: portmap`, `hubble.enabled: true` + `hubble.relay.enabled: true` with `tls.server.mtls: true` and `tls.auto` cronJob cert rotation (certValidityDuration 60d, 1st of month), `ipam.mode: kubernetes`, `kubeProxyReplacement: true`, `tunnelProtocol: geneve`, `socketLB.hostNamespaceOnly: true`, `loadBalancer.mode: dsr` with `dsrDispatch: geneve`, `k8sServiceHost/k8sServicePort` from `ControlPlaneEndpoint`, `image.useDigest: false` (digest off so mirrors work).
- **Depends on / talks to**: kube-apiserver (KPR needs k8sServiceHost/Port), Traefik (Hubble relay exposure), MetalLB or CCM for LB IPs.
- **Air-gap notes**: air-gapped supported. Cilium images ship in the air-gapped bundle; `useDigest: false` in every sub-image is required when using a registry mirror (digests break mirror rewriting). Custom values must be supplied **at create time** through a ConfigMap referenced by `values.sourceRef` — editing the cluster spec or the `cilium-config` ConfigMap afterwards **does not** reach an installed addon `[pdf p.727]`. Referencing a ConfigMap from the NKPCluster `addons.cni.values.sourceRef` *does* get re-rendered on cluster upgrade `[web: itcs 2.19 part 5]`.
- **Key CRDs / namespaces / commands**: `CiliumNetworkPolicy`, `CiliumClusterwideNetworkPolicy`, `CiliumNodeConfig` (v2); namespace `kube-system`; `cilium` DaemonSet/Deployment, `cilium-config` ConfigMap; `kubectl -n kube-system get ds cilium`; `cilium status`, `hubble observe`.
- **Gotchas**: (a) DSR is the NKP default and **fails on AHV Network-Controller-managed VLANs** — replies leave with the service IP as source from a NIC that does not own it and get dropped; symptom = LB address dead while API VIP is fine; fix = `loadBalancer.mode: snat` via ConfigMap+sourceRef so it survives upgrades `[web: itcs 2.19 part 4 series summary]`. (b) IPAM mode / Pod CIDR / Service CIDR are immutable on a running cluster `[pdf p.497-498]`. (c) With VXLAN tunneling DSR is rejected by Cilium — NKP uses Geneve for that reason.
- **Not shipped / not documented by NKP**: ClusterMesh, Cilium LB IPAM, L2 announcer (see below).

### Cilium Hubble (relay + exposure)
- **What**: flow observability for Cilium (relay gRPC service, UI).
- **NKP role**: core Cilium values (relay on, mTLS) + platform app **`cilium-hubble-relay-traefik`** ("Exposes the Cilium Hubble Relay gRPC service through Traefik with TLS passthrough enabled, since Hubble Relay handles mTLS termination") `[pdf p.309]`. Internal **required** app, depends on `traefik` `[pdf p.310]`.
- **Default**: relay enabled; Hubble **UI** not part of NKP (field values add `hubble.ui.enabled: true` manually) `[field: everything-nkp/cilium/nkp-cilium-wireguard.yaml]`.
- **Version 2.19**: app `cilium-hubble-relay-traefik` (relay-traefik 0.0.5 / chart 0.0.3 in 2.17 notes) `[web: scribd 2.17 release notes]`.
- **Commands**: `kubectl -n kube-system get svc hubble-relay`; `hubble observe --pod <ns>/<pod>`.

### Cilium ClusterMesh
- **Status in NKP 2.19**: **not an NKP feature** — zero hits in the 2.19 PDF; no platform app, no CLI flag. `UNKNOWN` as a supported configuration.
- **Field technique** `[field: everything-nkp/cilium/nkp-cilium-wireguard.yaml]`: put ClusterMesh into the Cilium values ConfigMap: `cluster.id`, `cluster.name`, `clustermesh.useAPIServer: true`, `clustermesh.apiserver.service.type: LoadBalancer` + `loadBalancerIP`, `clustermesh.apiserver.tls.auto.enabled`, and `clustermesh.config.clusters[]` with each remote cluster's LB IP + port 2379. `clustermesh-apiserver` lands in `kube-system`.
- **Known bug** `[field: everything-nkp/cilium-clustermesh-certificate-fix.md]`: Cilium 1.17.4 `cilium-certgen` wrote `keyEncipherment` into **ECDSA** clustermesh etcd certs → etcd logs `x509: certificate specifies an incompatible key usage`. Fix path: edit `clustermesh-apiserver-generate-certs` CronJob usage list, delete/recreate the clustermesh secrets, restart pods.
- **Air-gap**: needs `clustermesh.apiserver.image.repository` pointed at the mirror and `useDigest: false`.

### Calico (alternative CNI)
- **What**: CNI + network policy; Tigera operator based.
- **Upstream**: https://github.com/projectcalico/calico (Tigera operator)
- **NKP role**: `addons.cni.provider: Calico` `[web: CAREN addons/cni]`. Used by all providers except Nutanix AHV and (per concepts page) EKS. **kube-proxy is retained and fully supported with Calico** `[pdf p.593]`.
- **Runs on**: workload + management clusters.
- **Deployed by**: CAREN addon. With `strategy: ClusterResourceSet` the hook creates **two** ClusterResourceSets: a shared Tigera-operator CRS and a per-cluster Calico `Installation` CRS (defaults come from ConfigMaps copied from the hook pod namespace) `[web: CAREN addons/cni]`.
- **Default**: **optional / non-default** on AHV. Still fully supported in 2.19 (docs, upgrade path, encapsulation tuning) `[pdf p.783-784]` `[pdf p.1026-1027]`.
- **Version in 2.19**: 2.17 notes 3.30.4 `[web: scribd 2.17 release notes]`; 2.19 value `UNKNOWN` (not in the PDF).
- **Tuning**: interface autodetection (`IP_AUTODETECTION_METHOD`/interface name), encapsulation IP-in-IP (RFC 2003) or VXLAN (RFC 7348); change encapsulation **after** creation but before production `[pdf p.783-784, p.786]`.
- **Air-gap**: images in bundle; `calico-cni-installation-<cluster>` + `tigera-operator-<cluster>` ClusterResourceSets are per-cluster since 2.x `[pdf p.1026-1027]`.
- **Commands**: `kubectl -n calico-system get pods`; `nkp upgrade addons <provider> --cluster-name=<name>` upgrades the CRS pair.
- **Conflict to verify at runtime**: PDF p.20 says the **EKS** provider uses Cilium, but the EKS walkthrough output shows `calico-system` DaemonSets `[pdf p.860-861]`. Check with `kubectl -n kube-system get ds cilium` vs `kubectl -n calico-system get ds calico-node`.

### Nutanix Flow CNI (OVN-Kubernetes)
- **What**: Nutanix's CNI, built on **OVN-Kubernetes**, where pods join the Nutanix **VPC** routing domain so pod↔VM and pod↔pod traffic is routed and policy-enforced at the AHV layer (Flow Network Security), not only in the guest kernel.
- **Upstream / vendor**: Nutanix (NCI 7.5+); Helm chart **`nutanix-flow-cni`** from `https://nutanix.github.io/helm-releases/` (`nutanix/flow-ovn-kubernetes` image); chart 1.1.0 on Artifact Hub, 1.3.0 used in 2.18 field work.
- **NKP role / name**: CAREN CNI provider **`Flow`** (Nutanix only, `HelmAddon` only — ClusterResourceSet unsupported) `[web: CAREN addons/cni]`. Not mentioned anywhere in the NKP 2.19 PDF (zero hits) — the PDF documents Flow only as *Flow Virtual Networking subnets / floating IPs* for Prism Central.
- **Runs on**: workload + management clusters on **AHV only**.
- **Deployed by**: CAREN addon; older/field route = delete `addons.cni` from the generated Cluster and append a `HelmChartProxy` named `flow-cni-<cluster-uuid>` into namespace `flow-cni-system` `[web: jlnhnng.github.io/nkp-field-docs/install/v2.18/flow-cni/management-cluster/]`.
- **Default**: **optional, non-default**, off.
- **Prerequisites** (vendor doc) `[web: nai.howntnx.win/2.7.0/nkp_flow_cni/nkp_flow_cni/]`: NKP ≥2.17, **Rocky Linux nodes only** (no Ubuntu support yet), AOS ≥7.6, AHV ≥11.2, Prism Central ≥**pc.7.6**, Network Controller ≥7.6.0; Flow must run in **Integrated with Prism Central (Network Controller)** mode — standalone Flow Controller is not supported; underlay on an AHV-managed VLAN-basic subnet; Helm + an access token from the Flow downloads page.
  Note: NKP 2.19 supports pc.7.5 *and* pc.7.6 `[web: next.nutanix.com NKP 2.19]` → Flow CNI effectively forces pc.7.6.
- **Air-gap notes**: images live in the **private** `docker.io/nutanix` registry, not the public bundle. Either mirror them into the local registry and use `imageRegistries`, or create a `kubernetes.io/dockerconfigjson` secret and reference it as `addons.cni.imagePullCredentials.secretRef` — the hook copies the secret into `flow-cni-system`, `flow-cns-system` and `ovn-kubernetes` on the workload cluster `[web: CAREN addons/cni]`. Field form: base64 `svcpubflowcni:<token>` into `global.dockerConfigSecret.auth` + `imagePullSecretName` `[web: jlnhnng flow-cni]`.
- **Cost**: OVN-K + Flow needs **more CPU/memory than Cilium or Calico** (vendor quick-start uses 4 vCPU / 8 Gi nodes) `[web: CAREN addons/cni]`.
- **Key CRDs / namespaces**: namespaces `flow-cni-system`, `flow-cns-system`, `ovn-kubernetes`; `networking.nutanix.com/v1alpha1` (VPC-scoped pod network: `podNetwork.cidr`, `hostSlice`) `[web: nutanix.com/tech-center/blog/advanced-multi-tenant-kubernetes-with-flow-cni-...]`.
- **Rule**: CNI is choose-before-create. Retrofitting is disruptive; requires a rebuild.
- **License**: Flow CNI appears on the Nutanix software-options matrix under NKP; tier mapping `UNKNOWN` (matrix marks not readable) `[web: nutanix.com/products/cloud-platform/software-options]`.

### kube-proxy
- **Status**: **not used with Cilium** — replaced by eBPF (`kubeProxyReplacement: true`) `[pdf p.593, p.728]`. Fully supported and available **only** in Calico environments `[pdf p.593]`.
- **Air-gap**: no action. **Verify**: `kubectl -n kube-system get ds kube-proxy` → absent on Cilium clusters `[web: itcs 2.18]`.

### CoreDNS / NodeLocal DNS
- **CoreDNS**: shipped by kubeadm as the cluster DNS; listed as a core NKP networking component `[pdf p.12]` (with Cilium, Calico, TFA). No NKP platform app, no NKP tunables. Version = upstream k8s release.
- **NodeLocal DNS / node-local-dns cache**: **not shipped, not documented** in NKP 2.19 (zero hits). Cilium's per-node DNS proxy is not enabled by default either. `UNKNOWN` whether supported if added manually.
- **DNS defaults**: pod DNS `pod-ip.namespace.pod.cluster-domain`, `svc.namespace.svc.cluster-domain` `[pdf p.591]`.
- **DNS for air-gap**: required external domains listed at `[pdf p.53-54]` (docker.io, gcr.io, registry.k8s.io, quay.io, nvcr.io, charts.jetstack.io, helm.traefik.io, kiali.io, jaegertracing.github.io, open-policy-agent.github.io, raw.githubusercontent.com, insights.nutanix.com, …). "In an air-gapped installation, the required domains need not be accessible."

### MetalLB
- **What**: bare-metal `type: LoadBalancer` implementation (L2/ARP and BGP).
- **Upstream**: https://github.com/metallb/metallb
- **NKP role**: the external LB for **pre-provisioned infrastructure and vSphere** `[pdf p.593-594]`. Cloud providers use their native LB (ELB etc.). Nutanix AHV uses the Nutanix CCM, not MetalLB.
- **Runs on**: those clusters only (pre-provisioned, vSphere).
- **Deployed by**: CAREN cluster addon (HelmReleaseProxy `metallb-<cluster>`); configuration is **manual** CRs after creation.
- **Default**: enabled on pre-provisioned/vSphere; must be configured (pool) or the LB stays `<pending>`.
- **Version 2.19**: notes say 0.15.2, cluster runs **v0.15.3** `[web: itcs 2.19 overview]`.
- **Config snippets** `[pdf p.781-783]`:
  - L2: `IPAddressPool{spec.addresses:[<range>]}` + `L2Advertisement{ipAddressPools:[default]}` in `metallb-system`.
  - BGP: `BGPPeer{myASN, peerASN, peerAddress}` + `IPAddressPool` + `BGPAdvertisement`.
  - `kubectl apply -f metallb-conf.yaml`
- **Constraints**: pool CIDRs must sit inside the node's primary subnet, must not overlap pod/service CIDRs, and must not overlap the service-LB range used by the Nutanix CCM `[pdf p.782]`.
- **Air-gap**: images in bundle. The **first IP of the MetalLB range is the `kommander-traefik` LB address** and must be in `noProxy` `[pdf p.979-980]`.
- **Gotcha**: with Cilium DSR on a Network-Controller VLAN, the announced LB IP can stop answering (see Cilium gotcha).

### kube-vip
- **What**: virtual IP for the **control-plane endpoint** when no external LB exists.
- **Upstream**: https://kube-vip.io/
- **NKP role**: "The built-in virtual IP uses the kube-vip project"; it is a failover VIP, **not** a load balancer — it does not spread API load `[pdf p.786-787]`.
- **Runs on**: pre-provisioned clusters (also AWS/other providers for the CP VIP; Flatcar needs `--virtual-ip-interface ens192` or the VIP never configures) `[pdf p.682-683]`.
- **Deployed by**: CAPI create flow.
- **Default**: off unless requested. Flags: `--control-plane-endpoint-host <VIP>` + `--virtual-ip-interface <nic>` (the NIC must exist on all control-plane machines) `[pdf p.786-787]`.
- **Version 2.19**: **kube-vip 1.1.1** (in the 2.19 component table) `[web: itcs 2.19 overview]`.
- **Air-gap**: image in bundle. **`noProxy`** must list every managed cluster's API VIP as an explicit IP, not CIDR `[pdf p.979]`.

### Nutanix CCM (`nkp-cloud-provider-nutanix`) + AHV Service LB
- **What**: Nutanix Cloud Controller Manager — node metadata, and **`type: LoadBalancer` services on AHV** allocated from a pre-defined IP range.
- **Upstream**: https://github.com/nutanix-cloud-native/cloud-provider-nutanix
- **NKP role**: chart `nkp-cloud-provider-nutanix` deployed as `HelmChartProxy nkp-cloud-provider-nutanix-<cluster>`; credentials in Secret `nutanix-ccm-credentials` (`kube-system`) `[pdf p.2661-2719]`.
- **Default**: enabled on every Nutanix cluster.
- **Version 2.19**: **0.8.12** (2.18: 0.7.4) `[web: itcs 2.19 part 5]`; not in the release-notes component table `[web: itcs 2.19 overview]`.
- **Key flag**: `--kubernetes-service-load-balancer-ip-range=<first>-<last>` on `nkp create cluster nutanix` `[pdf p.724-725]`. The NKP UI takes the **first IP of that range** `[pdf p.720-721]`.
- **Constraints**: range routable from CP/worker subnets, static, outside DHCP/IPAM pools, unused otherwise `[pdf p.721]`.
- **Air-gap**: nothing special. Rotating the PC endpoint requires updating both CCM and CSI secrets `[pdf p.1326-1327]`.

### Cilium LB IPAM / L2 announcer
- **Status**: **not used by NKP** and not documented (zero hits in the 2.19 PDF). NKP delegates LB IPs to MetalLB (pre-provisioned/vSphere) or the Nutanix CCM (AHV) or the cloud provider.
- **Field**: `l2announcements`/`k8sClientRateLimit` appear only as commented-out lines in a hand-written values file `[field: everything-nkp/cilium/nkp-cilium-wireguard.yaml]`.

### Gateway API (CRDs only)
- **What**: `gateway-api` CRDs (GatewayClass/Gateway/HTTPRoute/GRPCRoute…).
- **NKP role**: platform app **`gateway-api-crds`** — internal **required** app, both management and workload clusters `[pdf p.309-310]`. Only the **CRDs** ship; NKP does not document a Gateway implementation, but the partner-catalog docs state "Traefik remains the in-box GatewayClass" `[web: nutanix-cloud-native.github.io/nkp-partner-catalog/offline/nkp-catalog-docs.html]`.
- **Default**: enabled (required internal app), all license tiers `[pdf p.295-297]`.
- **Air-gap**: CRD-only, no images.

### Traefik (default ingress controller)
- **What**: HTTP reverse proxy / ingress controller; also the front door of the NKP UI.
- **Upstream**: https://github.com/traefik/traefik (chart `traefik`)
- **NKP role**: platform app **`traefik`**, one of the three **foundational** apps (with Flux and Reloader) `[pdf p.299]`. "Kommander currently installs Traefik by default on every cluster" `[pdf p.594]`. Ingress class **`kommander-traefik`** `[pdf p.596]`.
- **Default**: enabled on management + workload clusters, all license tiers `[pdf p.297, p.960]`.
- **Version 2.19**: **Traefik chart 39.0.7** (2.18 ran chart/v3.6.12) `[web: itcs 2.19 overview]`
- **Service shape**: `kommander-traefik` in ns `kommander`, `type: LoadBalancer` (MetalLB/CCM/ELB decides the IP) `[pdf p.596]`. Traefik v3 entry points include `web`(80), `websecure`(443), `registry`, `external-ceph` `[pdf p.977]`.
- **Customisation** (`kommander.yaml` `apps.traefik.values` or AppDeployment `configOverrides` — Flux reverts kubectl edits `[pdf p.603-604]`):
  - extra TCP/UDP entry points (e.g. a log shipper or an external service port) `[field: everything-nkp/traefik/traefik-custom-entrypoints/gui-settings.yaml]`
  - session affinity `service.spec.sessionAffinity: ClientIP` + `timeoutSeconds` `[field: everything-nkp/traefik/kommander-traefik-sessionAffinity/gui-settings.yaml]`
  - source-IP preservation `service.spec.externalTrafficPolicy: Local` `[field: <vault>/Traefik Customizations from NKP GUI.md]`, `[field: everything-nkp/external-traffic-policy-local-test.yaml]`
  - AWS internal ELB: `service.annotations."service.beta.kubernetes.io/aws-load-balancer-internal": "true"` `[pdf p.943-944]`
  - external (non-NKP) LB: `service.type: NodePort` + fixed `ports.*.nodePort` (30000-32768) then point the LB at every worker `nodePort` `[pdf p.978-979]`
- **Constraint**: "the external load balancer must be configured **without TLS termination**" `[pdf p.594, p.994]`.
- **Air-gap**: image in bundle; ACME/Let's Encrypt not usable `[pdf p.964, p.369]`; was hit by a 2.19 fix "ACME certificate issuance failures involving the Traefik ingress class" `[web: next.nutanix.com NKP 2.19]`.
- **Key objects/commands**: `Ingress` with `kubernetes.io/ingress.class: kommander-traefik`; `kubectl -n kommander get svc kommander-traefik`.

### Traefik Forward Auth (TFA)
- **What**: forward-auth middleware that authenticates every HTTP request to the NKP UI / platform dashboards against Dex and carries RBAC identity in an encrypted cookie.
- **Upstream**: Nutanix fork of `mesosphere/traefik-forward-auth` — https://github.com/mesosphere/traefik-forward-auth
- **NKP role**: two apps — **`traefik-forward-auth`** (attached/managed clusters) and **`traefik-forward-auth-mgmt`** (management cluster). "deployed by a controller on all attached, managed, and management clusters" `[pdf p.583]`. Internal **required** apps; both depend on `traefik` (+ `dex`, `kommander` for the mgmt variant) `[pdf p.304-305]`.
- **Default**: enabled.
- **Behaviour**: user metadata lives in an encrypted browser cookie (RBAC username + group list). Cookie limit 4 KB → too many groups returns **HTTP 500**; workaround `clusterStorage.enabled: true` (`namespace: kommander`) stores claims in a Secret (GC after 12 h, slower per-request) `[pdf p.584-585]`.
- **Whitelist**: users must be added to `traefikForwardAuth.whitelist` in `apps.traefik-forward-auth-mgmt.values` *and* get RBAC `[pdf p.580]`.
- **Air-gap**: no special step; the Dex issuer is the local cluster host.

### Kommander ingress / NKP UI routing
- UI path: `https://<clusterHostname>/nkp/kommander/dashboard` `[pdf p.580]`; login/`/token` endpoint for CLI `[pdf p.1167]`.
- `clusterHostname` + `ingressCertificate` + `acme` are Kommander installer parameters `[pdf p.960-961]`; changing them post-install: "Custom Domains and Certificates Configuration for All Cluster Types" `[pdf p.490]`.

### cert-manager
- **What**: X.509 certificate issuance/renewal; backs the NKP UI TLS cert and internal PKI.
- **Upstream**: https://github.com/cert-manager/cert-manager (chart from `charts.jetstack.io`)
- **NKP role**: platform app **`cert-manager`** (security category), plus a Konvoy core component `[pdf p.20, p.303-304]`. Optional dependency of `traefik`, `kube-oidc-proxy` `[pdf p.299, p.304]`.
- **Default**: enabled, all tiers; both management and workload clusters.
- **Version 2.19**: **cert-manager 1.20.3** `[web: itcs 2.19 overview]` (2.17 notes: 1.18.2).
- **Patterns**:
  - ACME (Let's Encrypt default; ZeroSSL/SSL.com via `acme.server`) with HTTP01 solver; the ClusterIssuer **must be named `kommander-acme-issuer`** and private key secret `<name>-account`; HTTP01 ingress needs `kubernetes.io/ingress.class: kommander-traefik` + `traefik.ingress.kubernetes.io/router.priority: "2147483647"` (on-prem: `traefik.ingress.kubernetes.io/router.tls: "true"`) `[pdf p.966-967]`
  - DNS01 solver (Route53 example); **required** if the cluster is proxied/network-restricted `[pdf p.964, p.967]`
  - manual CA: `Secret` (type tls) + `ClusterIssuer{spec.ca.secretName}` + `Certificate` `[field: <vault>/Cert Manager Self Signed Cert Issuer.md]`
  - per-cluster issuer lives **on the target cluster**; `KommanderCluster` (on management) references it `[pdf p.964]`
  - ACME does **not** work with an IP `clusterHostname`, nor in air-gap `[pdf p.964, p.1009]`
- **Root CA**: Kommander root CA `kommander-ca` lifetime was raised to **10 years (87600h)** at 2.18 `[web: itcs 2.18]`.
- **Air-gap**: self-signed/cluster-issued certs are the default; use manual CA or internal ACME. Custom trust bundle technique: base64 (`base64 -w 0`) of the PEM CA chain into `--additional-trust-bundle`, and after install into `NutanixCluster.spec.prismCentral.additionalTrustBundle`, the `nutanix-ccm` and `konnector-agent` HelmChartProxy `valuesTemplate`, and the infrastructure-provider Secret key `additionalTrustBundle` `[pdf p.740-741]` `[field: <vault>/NKP additional-trust-bundle.md]`.
- **Commands**: `kubectl get clusterissuer,certificate,order,challenge -A`; `kubectl describe certificate <name> -n <ns>`.

### external-dns
- **What**: syncs Service/Ingress hostnames into a DNS provider.
- **Upstream**: https://github.com/kubernetes-sigs/external-dns
- **NKP role**: platform app **`external-dns`**, category *Tools*, optional, both cluster types, no dependencies `[pdf p.309]`.
- **Default**: optional/off. Recommended companion: "Create a DNS record by setting up the external-dns service" so the record follows the ingress automatically `[pdf p.967, p.971]`.
- **Air-gap**: needs an **internal** DNS provider (RFC2136/BIND, Infoblox, etc.); public providers unreachable. Provider list `UNKNOWN` in NKP docs.

### Dex (identity broker)
- **What**: OIDC identity service that federates to external IdPs; issues the ID token every other component trusts.
- **Upstream**: https://github.com/dexidp/dex
- **NKP role**: platform app **`dex`** (SSO category), internal **required**, management cluster only `[pdf p.304]`. Pre-configured in the NKP UI stack `[pdf p.575]`.
- **Default**: enabled (`apps.dex.enabled: true`) `[pdf p.960]`.
- **Version**: PDF states "Dex 2.22.0, the version used by NKP" `[pdf p.576]` — **stale**. 2.17 notes list 2.14.4 chart, 2.18/2.19 notes list **2.37.0**, clusters actually run **v2.42.0** `[web: scribd 2.17]`, `[web: itcs 2.19 overview]`.
- **Connectors**: LDAP, SAML 2.0, OIDC (incl. Azure/Salesforce), GitHub, GitLab, Google, Microsoft, LinkedIn, Bitbucket Cloud, OpenShift, AuthProxy — with a support matrix for refresh tokens / groups claim / `preferred_username` `[pdf p.576]`.
- **Config surface**: `Installation` CR `apps.dex.values` at install; afterwards ConfigMap **`dex-overrides`** in ns `kommander` + `spec.configOverrides.name` on the `dex` AppDeployment `[pdf p.577, p.586-588]`. Note the AppDeployment pattern also uses `clusterConfigOverrides` with `configMapName` for cluster-targeted overrides `[pdf p.588]`.
- **Token lifetime**: `config.expiry.idTokens` (default 24h) `[pdf p.577]`.
- **Local users**: `config.staticPasswords[]` with bcrypt hash (`htpasswd -bnBC 10 "" <pw> | tr -d ':\n'`); quote the hash — `$` in an unquoted heredoc corrupts it and the dex pod crashloops `[pdf p.586-587]`.
- **SAML**: issuer `https://<cluster-host>/dex`, ACS `https://<cluster-host>/dex/callback`, metadata XML provided `[pdf p.579-580]`.
- **Air-gap**: the IdP must be internal (LDAP/AD/SAML on-prem, or an internal OIDC provider). TLS to the IdP may need an extra CA: mount a CA Secret + `SSL_CERT_FILE` via `extraVolumes`/`extraVolumeMounts`/`env` in `dex-overrides` `[field: everything-nkp/dex-overrides.yaml]`.
- **Logins**: `kubectl` via kube-oidc-proxy, UI via TFA.

### dex-k8s-authenticator
- **What**: web helper that generates kubeconfig snippets after a Dex login.
- **Upstream**: https://github.com/mintel/dex-k8s-authenticator
- **NKP role**: platform app **`dex-k8s-authenticator`**, internal required, **management cluster only**; depends on `dex`, `kommander`, `traefik` `[pdf p.304]`. Integrated into newly attached clusters together with kube-oidc-proxy and TFA `[pdf p.575]`.
- **Default**: enabled (`apps.dex-k8s-authenticator.enabled: true`).
- **Air-gap**: image in bundle; exposed through Traefik.

### kube-oidc-proxy
- **What**: reverse proxy in front of the kube-apiserver that turns an OIDC ID token into Kubernetes user identity (so `kubectl` works with Dex).
- **Upstream**: https://github.com/jetstack/kube-oidc-proxy
- **NKP role**: platform app **`kube-oidc-proxy`**, internal required, **all** cluster types, all tiers; optional deps `cert-manager`, `traefik` `[pdf p.295-296, p.304]`.
- **Default**: enabled on management + attached clusters.
- **Gotcha**: with `insecureSkipEmailVerified: true` in a Dex connector the Go API-server client still requires `email_verified: true` in the token `[pdf p.575]`.

### RBAC model (Kommander roles / workspace / project, federation)
- **Model** `[pdf p.228-232]`: two resource families — **Kommander Roles** (management-cluster resources) and **Cluster Roles** (target clusters) — applied at three scopes: **Global / Workspace / Project**. Namespaced Roles are created on the management cluster in the workspace (or project) namespace and federated to the target clusters.
- **Workspace roles**: `KommanderWorkspaceRole` objects — `kommander-workspace-admin`, `-edit`, `-view` (display names "Kommander Workspace Admin/Edit/View Role") `[pdf p.230-231]`. Propagation to projects is controlled by annotation `workspace.kommander.mesosphere.io/sync-to-project: "true|false"`; by default Admin/Edit/View **are** propagated, other workspace roles are **not** `[pdf p.214-217, p.231]`.
- **Project roles**: `<kommander-project-admin|edit|view>-<suffix>` Roles in the project namespace; bind with `RoleBinding` `[pdf p.231]`.
- **Bindings**: UI (Groups tab → Add Roles) or CRs; `VirtualGroup` (kind `kommander.mesosphere.io/v1beta1`) and `VirtualGroupProjectRoleBinding` `[pdf p.397, p.588]`.
- **Subject naming** (critical): global IdP → group `oidc:<idp-group>` or user `<email>`; per-workspace IdP → `oidc:<workspace_ID>:<idp-group>` or `<workspace_ID>:<email>` `[pdf p.365, p.229]`.
- **Built-in ClusterRoles seen in docs**: `dkp-kommander-admin`, `dkp-admin` (must be bound alongside a Kommander role to actually get into the UI) `[pdf p.229]`. `kommander-federated-edit` still exists but is deprecated (2.18) — audit with `kubectl get clusterrolebindings -o wide | grep kommander-federated-edit` `[web: itcs 2.18]`.
- **Federation**: KubeFed underneath (label `kubefed.io/managed: "true"` on federated Roles) `[pdf p.401]`. KubeFed is **deprecated as of 2.18** but still installed and still federating at 2.18/2.19 `[web: itcs 2.18]`.
- **Multi-tenancy**: workspace == tenant; optional per-workspace IdP + dedicated login URL; project-level narrowing inside a tenant `[pdf p.365-368]`.
- **License**: "NKP RBAC" is Ultimate-only; "RBAC - Admin role only" and "RBAC - Kubernetes" are all tiers `[pdf p.28]`.

### Gatekeeper (OPA) — the shipped policy engine
- **What**: Kubernetes admission policy using the OPA Constraint Framework (ConstraintTemplate + Constraint).
- **Upstream**: https://github.com/open-policy-agent/gatekeeper , library https://github.com/open-policy-agent/gatekeeper-library
- **NKP role**: platform app **`gatekeeper`**, category *Security*, optional-but-default, both cluster types, all tiers `[pdf p.303-304]`, `apps.gatekeeper.enabled: true` `[pdf p.960]`.
- **Default**: **enabled**. Warning: it ships **pre-configured constraint templates that enforce multi-tenancy in projects** — do not disable it casually `[pdf p.581]`.
- **Version 2.19**: **Gatekeeper 3.23.0** `[web: itcs 2.19 overview]`
- **Usage**: PSP replacements — `k8spspprivilegedcontainer`, `k8spsphostfilesystem` (`allowedHostPaths`), mutation CRDs (`Assign` with `pathTests`) `[pdf p.581-583]` `[field: everything-nkp/opa-gatekeeper/sidecar-mutate.yaml]`.
- **Air-gap**: images in bundle; the gatekeeper-library YAMLs are **not** bundled — copy them into the environment (the PDF's `kubectl apply -f https://raw.githubusercontent.com/...` examples do not work air-gapped).
- **License**: "Policy control using Gatekeeper" is **Pro + Ultimate only** `[pdf p.28]`.

### Kyverno
- **Status**: **not an NKP platform app** — zero hits in the 2.19 PDF, absent from the supported-applications table. NKP ships **Gatekeeper** for policy.
- Field observation: a "Kyverno reports controller" (128Mi limit, 3 restarts) exists in a real 2.19 fleet `[web: itcs 2.19 part 5]` — origin `UNKNOWN` (possibly NAI). Treat Kyverno as **not shipped by NKP**.

### NKP Istio — `istio-helm`
- **What**: Istio service mesh, Helm-based install.
- **Upstream**: https://github.com/istio/istio (chart via NKP ClusterApp)
- **NKP role**: platform app **`istio-helm`**, category *Service Mesh*, optional, both cluster types, Pro/Ultimate `[pdf p.295-296, p.306]`. Namespaces: control plane **`istio-helm-system`**, gateway **`istio-helm-gateway-ns`**.
- **Deploy**: `nkp create appdeployment istio-helm --app <APPID-version> --workspace ${WORKSPACE_NAME}` (+ install its dependencies first) `[pdf p.597-598]`. Supported version: see NKP release notes "Supported Applications"; PDF examples show chart **1.23.6** `[pdf p.600, p.603]`.
- **Modes**: **sidecar by default**; **ambient** by overriding with
  `ztunnel{enabled:true,profile:ambient}`, `cni.profile: ambient`, `istiod{profile: ambient, env.CA_TRUSTED_NODE_ACCOUNTS: "istio-helm-gateway-ns/ztunnel,istio-helm-system/ztunnel"}`, then label namespaces `istio.io/dataplane-mode=ambient`. Enabling ambient on an existing install auto-migrates sidecars via job `istio-helm-ztunnel-ambient-migration` `[pdf p.598-599]`.
- **Istio Operator**: **deprecated from NKP 2.17**; migration path to istio-helm documented (extract `IstioOperator` → `istio-helm-<ver>-config-defaults` ConfigMap → `istio-helm-config-overrides` → set `spec.configOverrides.name`; relabel namespaces `istio.io/rev=istio-helm --overwrite`; re-point Gateway/VirtualService labels from `istio: ingressgateway` to `istio: istio-helm-ingressgateway`) `[pdf p.597, p.599-606]`.
- **Dependent apps needing overrides**: **Knative** (`knativeIngressGateway.spec.selector.istio: istio-helm-ingressgateway`, `serving.manifest.spec...`) and **Kiali** (`cr.spec.istio_namespace: istio-helm-system`, component status labels) `[pdf p.605-606]`.
- **Air-gap**: `istioctl` download in the PDF is internet-only — for air-gap use the images/charts in the bundle + `kubectl` instead. Customization always via ConfigMap `configOverrides` (Flux reverts kubectl edits) `[pdf p.603-604]`.
- **Multi-cluster Istio** is not documented by NKP; field repo shows remote-secret based multi-primary across providers `[field: everything-nkp/nkp-istio-multicloud/]`.

### Kiali
- **What**: Istio management console.
- **Upstream**: https://github.com/kiali/kiali (chart `kiali.io`)
- **NKP role**: platform app **`kiali`**, Service Mesh category, optional; depends on `istio` (+ optional `jaeger`) `[pdf p.306]`.
- **Default**: optional/off. Needs the `istio-helm` override above.
- **Version 2.19**: `UNKNOWN` (see release notes "Supported Applications").
- **Air-gap**: chart from `kiali.io` (in the required-domains list) → images in bundle, no internet.

### Jaeger
- **What**: distributed tracing backend.
- **NKP role**: platform app **`jaeger`**, depends on `istio` `[pdf p.306]`; optional; `jaegertracing.github.io` is a required chart domain `[pdf p.53]`.
- **Version 2.19**: `UNKNOWN`.

### Knative
- Optional catalog/platform app that needs Istio + the istio-helm gateway override `[pdf p.305-306, p.605]`.

### Linkerd
- **Status**: **not shipped, not documented** in NKP 2.19 (zero hits). `UNKNOWN` whether supported if installed manually.

### NetworkPolicy
- **What**: L3/L4 pod traffic control, enforced by the CNI.
- **NKP role**: plain Kubernetes `NetworkPolicy` (no NKP CRD). UI/CLI management at **Project** level: Project → Network Policies (policy type Default/Ingress/Egress, pod selectors by label or expression, ipBlock/namespaceSelector/podSelector) `[pdf p.403-404]`.
- **Default**: allow-all until a policy selects a pod; policies are additive `[pdf p.403]`.
- **Enforcement**: Cilium or Calico (both documented as enforcing) `[pdf p.403]`.
- **Air-gap**: nothing.

### Kubetunnel
- **What**: reverse tunnel so a network-restricted cluster can be attached without exposing its API server.
- **Upstream**: D2iQ/Nutanix (app `kubetunnel`)
- **NKP role**: internal **required** networking platform app on both cluster types `[pdf p.309-310]`; the attached cluster dials out to the management cluster, then bilateral traffic is allowed `[pdf p.445-447]`.
- **Default**: enabled; only *used* when you pick "networking restrictions" during attach.
- **Commands**: `kubectl get appdeployments.apps.kommander.d2iq.io -n kommander kubetunnel`.
- **Related**: proxied access to network-restricted clusters restricts certificate solving to **DNS01** `[pdf p.462, p.964]`.

### Multus
- **Status**: **not in the 2.19 PDF** (zero hits) but **installed on every node** by the 2.18+ node roll as a privileged DaemonSet `multus` in `kube-system` (image `multus-cni:v4.2.4-thick`), idle, no NetworkAttachmentDefinition `[web: itcs 2.18]`, still present on 2.19 `[web: itcs 2.19 overview]`. Groundwork for multi-network/AHV. Nothing to configure.

### FIPS 140-3
- **What**: FIPS-validated crypto mode for the control plane.
- **NKP role**: `+fips.0` image tags from `docker.io/mesosphere` for kube-apiserver/controller-manager/scheduler/etcd; `nib` `fips.yaml` override file builds FIPS node images `[pdf p.987-989]`.
- **Default**: **off**, opt-in at create time; cannot be enabled or removed later. Pro/Ultimate only `[pdf p.28]`.
- **OS**: RHEL and CentOS only (the pre-built Rocky/Ubuntu images are CIS, **not** FIPS — "FIPS Compliance: Not supported" for pre-built, "Supported" for custom images) `[pdf p.55-56, p.988]`.
- **Flags**: `--kubernetes-version=v<ver>+fips.0`, `--etcd-version=etcd-<ver>+fips.0`, `--kubernetes-image-repository=docker.io/mesosphere`, `--etcd-image-repository=docker.io/mesosphere`, `--ami <fips AMI>` (AWS) `[pdf p.988]`; pre-provisioned: Secret `$CLUSTER_NAME-fips-overrides` labelled `clusterctl.cluster.x-k8s.io/move=` `[pdf p.989]`.
- **Verify**: **`nkp check cluster fips`** (reads signature files embedded in the `nkp` binary) `[pdf p.989]`.
- **Air-gap**: mirror `docker.io/mesosphere` FIPS images into the local registry; `fips.yaml` ships with the image bundles `[pdf p.989]`.

### CIS hardening
- **NKP role**: pre-built images are hardened — **OS layer CIS Level 1**, **NKP/Kubernetes components follow CIS Level 2** guidance `[pdf p.55]`. Pre-built variants: Rocky Linux 9.8, Ubuntu 24.04 LTS (2.19) `[pdf p.55]`.
- **Field** `[field: <vault>/NKP CAPX L2 Hardening.md]`: CIS L2 gaps closed by patching the **`KubeadmControlPlaneTemplate`** of the ClusterClass and re-pointing `ClusterClass.spec.controlPlane.ref.name` at a `-hardened` template:
  - `apiServer.extraArgs`: `profiling: "false"`, `service-account-lookup: "true"`, `enable-admission-plugins: AlwaysPullImages,DenyServiceExternalIPs,EventRateLimit`, `admission-control-config-file: /etc/kubernetes/admission/admissionConfiguration.yaml` (+ the two `files` entries for AdmissionConfiguration and the eventratelimit Configuration)
  - `controllerManager.extraArgs`: `terminated-pod-gc-threshold`, `profiling: "false"`; `scheduler.extraArgs.profiling: "false"`
  - `anonymous-auth: "false"` **breaks** control-plane join/probes — needs `tcpSocket: 6443` probes first; still WIP
  - `postKubeadmCommands` for kubelet service-file permissions (4.1.1)
  - worker: `--read-only-port=0`, streaming timeout, TLS ciphers, pod PID limit
  - `serverTLSBootstrap: true` in `/var/lib/kubelet/config.yaml` when etcd/kubelet show `tls: bad certificate` `[field: everything-nkp/hardened-clusters/notes.md]`
- **2.18+ product-side hardening** (not in the docs): kube-apiserver pins six explicit ECDHE cipher suites, kube-scheduler/-controller-manager set `--tls-min-version=VersionTLS12`; kubelet `podPidsLimit: 4096` `[web: itcs 2.18]`.
- **Air-gap**: hardened images come from the bundle; no internet needed.

### External Secrets Operator (ESO)
- **What**: syncs secrets from external stores (AWS Secrets Manager, Vault, Azure Key Vault…).
- **Upstream**: https://github.com/external-secrets/external-secrets
- **NKP role**: platform app **`external-secrets`**, Security category `[pdf p.304]`. **Pre-installed on the management cluster by default since NKP 2.17**, and NKP itself uses it for platform secrets (OCI registry credentials, certificates) pushed to workload clusters. Cannot be disabled there (`createPushSecrets`/`processPushSecrets` must stay `true`) `[pdf p.311]`.
- **Default**: management = always on; workload = optional, enabled per cluster from the UI, namespace `external-secrets` `[pdf p.311-312]`.
- **Migration**: brownfield helm-installed ESO must be migrated (backup `externalsecrets`/`pushsecrets`, then re-create as the platform app) or you get CRD/lifecycle conflicts `[pdf p.312]`.
- **Air-gap**: the *backend* must be reachable from inside the air gap (Vault/K8s/`kubernetes-backend` `ClusterSecretStore` works well); cloud vaults are not.
- **Commands**: `kubectl get externalsecrets,clustersecretstores -A`; status `SecretSynced`.

### Sealed Secrets
- **Status**: **not shipped** as a platform app. Only a **tutorial** in the Project GitOps chapter: install `kubeseal` CLI, apply `controller.yaml` (v0.18.1 in the doc), `kubeseal --fetch-cert > mycert.pem`, commit the cert, then commit `SealedSecret` objects `[pdf p.389-390]`.
- **Air-gap**: works well — copy the release manifests + image in, no phone-home.

### Reloader
- **What**: restarts workloads when their ConfigMap/Secret changes.
- **Upstream**: https://github.com/stakater/Reloader
- **NKP role**: platform app **`reloader`** — one of the **three foundational apps** (Flux, Reloader, Traefik) `[pdf p.299]`; `apps.reloader.enabled: true` `[pdf p.960]`.
- **Default**: enabled, all tiers, both cluster types.

### Headlamp (new default dashboard) / Kubernetes Dashboard
- **Headlamp**: https://github.com/kubernetes-sigs/headlamp — platform app **`headlamp`**.
  **New in 2.19**: "From NKP 2.19, Headlamp replaces Kubernetes Dashboard for new deployments as the upstream Kubernetes Dashboard project is deprecated." Deployed independently on each cluster, accessed through NKP SSO, permissions = the user's Kubernetes RBAC. **Enabled by default on management *and* workload clusters for a fresh 2.19 install; NOT enabled by default on upgraded clusters** (must be enabled per workspace). Pro/Ultimate. Helm support, plugin management and plugin catalog are disabled and cannot be configured `[pdf p.313-314]`.
  Verify: `kubectl get appdeployments -A | grep headlamp`, `kubectl get pods -A -l app.kubernetes.io/name=headlamp`.
  Service-account-token login: create `headlamp-viewer` SA + token (`kubectl create token headlamp-viewer -n headlamp-viewer`), `kubectl port-forward svc/<headlamp> 4466`, sign in; do not use a cluster-admin token `[pdf p.313-314]`.
- **Kubernetes Dashboard**: still a platform app in the 2.19 list (`kubernetes-dashboard`) and still installed/upgraded on brownfield clusters (`7.14.1` at 2.18); deprecated, "existing Dashboard instances remain running after upgrade, but Nutanix recommends migrating to Headlamp" `[pdf p.296]` `[web: next.nutanix.com NKP 2.19]` `[web: itcs 2.18]`.

### Nutanix Flow Virtual Networking / Network Controller touchpoints
NKP 2.19 uses Flow VN only at the infrastructure layer — there is **no Flow CNI requirement** for it:
- subnet sizing/updates are done in Prism Central ("Updating a Subnet in the Flow Virtual Networking Guide") `[pdf p.709]`
- VPC subnets / Network-Controller VLANs: migrate VLAN basic → NC-based VLAN subnets; NC VLANs with Cilium **DSR** break LoadBalancer replies (see Cilium gotcha) `[pdf p.709-710]` `[web: itcs 2.19 part 4]`
- **Floating IPs** are the external endpoint mechanism for clusters inside a VPC (1 bastion, 1 for `--extra-sans`, 1 for the UI) `[pdf p.720-721]`
- Flow CNI is the one place where Flow is inside the data path (see Flow CNI).

---

## Relationships

- Cilium -> kube-apiserver: `kubeProxyReplacement: true` needs `k8sServiceHost/k8sServicePort` = the control-plane endpoint/VIP.
- Cilium -> MetalLB / Nutanix CCM / cloud LB: Cilium does the Service LB math, something else must own the external IP.
- Traefik -> MetalLB (pre-provisioned/vSphere) | Nutanix CCM (AHV) | cloud LB: `kommander-traefik` is `type: LoadBalancer`; it is the single ingress entry point for the UI.
- Traefik -> cert-manager: ACME HTTP01 solver creates Ingress objects with `ingress.class: kommander-traefik`; the ClusterIssuer must be `kommander-acme-issuer`.
- Traefik -> TFA -> Dex: every NKP UI HTTP request is authenticated by forward-auth against the Dex issuer; TFA whitelist gates entry, Kubernetes RBAC gates actions.
- Dex -> external IdP (LDAP/AD/SAML/OIDC): Dex is the only trust anchor; attached clusters accept the management cluster's Dex tokens.
- kube-oidc-proxy -> Dex: `kubectl` presents the ID token; kube-oidc-proxy validates it against the apiserver.
- dex-k8s-authenticator -> Dex + Traefik: login UI that emits kubeconfigs.
- TFA -> cookie/cluster Storage: identity+groups must fit in 4 KB or be relocated into a Secret.
- Kommander roles -> ClusterRoles -> KubeFed: Roles are created on the management cluster and federated (label `kubefed.io/managed`) to workspace/project target clusters.
- VirtualGroup -> VirtualGroupProjectRoleBinding: the only way to bind non-Kubernetes groups (IdP users/groups) to project roles.
- Gatekeeper -> Project multi-tenancy: ships constraint templates that enforce project isolation; disabling it weakens tenancy.
- cert-manager -> Kommander root CA: internal PKI for platform endpoints; the CA lifetime changed to 10y at 2.18.
- ESO -> OCI registry credentials + certificates: NKP's own secret distribution from management to workload clusters.
- Headlamp -> Dex/TFA (SSO) + Kubernetes RBAC: no separate user database.
- Hubble Relay -> Traefik: platform app `cilium-hubble-relay-traefik` with TLS passthrough (relay terminates mTLS).
- Istio-Helm -> kube-prometheus-stack: hard dependency; Kiali/Jaeger/Knative depend on Istio.
- Knative/Kiali -> istio-helm gateway rename: need ConfigMap overrides or they keep pointing at the old `istio: ingressgateway` label.
- Kubetunnel -> KommanderCluster attach: required only for the "networking restrictions" attach flow.
- kube-vip -> control-plane endpoint: alternative to an external LB; must be paired with `noProxy` entries on the management cluster.
- MetalLB pool -> Nutanix CCM service range: the two ranges must not overlap, and neither may overlap pod/service CIDRs.
- Flow CNI -> AHV Network Controller (integrated mode) + VPC: CNI is a cluster-lifecycle decision, and needs pc.7.6+.
- ESO/Sealed Secrets -> GitOps: ESO for live external stores, Sealed Secrets for committed manifests; NKP ships the former, documents the latter.

---

## Version deltas (2.16 → 2.19)

| Item | 2.16 | 2.17 | 2.18 | 2.19 |
|---|---|---|---|---|
| Cilium | ~1.17 | 1.18.2 | 1.19.2 documented / 1.19.4 running | **1.19.4** |
| Calico | 3.29/3.30 | 3.30.4 | ? | `UNKNOWN` (still supported) |
| MetalLB | 0.14.x | 0.15.2 | 0.15.2 doc / 0.15.3 running | 0.15.2 doc / **0.15.3** |
| kube-vip | ? | ? | ? | **1.1.1** |
| Traefik | v3 introduced at 2.14 | 3.x | 3.6.12 | **chart 39.0.7** |
| cert-manager | 1.16/1.17 | 1.18.2 | 1.18.2 | **1.20.3** |
| Dex | ? | 2.14.4 chart | 2.37.0 doc / 2.42.0 running | 2.37.0 doc / **2.42.0** |
| Gatekeeper | ? | ? | ? | **3.23.0** |
| Istio | **istio-operator** | operator deprecated → istio-helm default | istio-helm | istio-helm (+ ambient mode support) |
| Dashboard | Kubernetes Dashboard | Kubernetes Dashboard | Dashboard deprecated (still installed) | **Headlamp default on new installs; Dashboard deprecated** |
| ESO | not pre-installed | **pre-installed on management** | same | same |
| KubeFed | active | active | **deprecated** (still runs) | deprecated (still runs) |
| FIPS | ? | ? | FIPS 140-3 clusters + Ubuntu CIS/STIG image | same |
| Multus | – | – | **installed on every node by the node roll** (undocumented) | still installed |
| Node OS images | Rocky 9.5/9.6 | Rocky 9.7 | Rocky 9.7 / Ubuntu 24.04 | **Rocky 9.8 / Ubuntu 24.04 / RHEL 9.8 (build your own)** |
| Kubernetes | 1.33 | 1.34 | 1.35.2 | **1.36.2** |
| Flow CNI | – | first supported (≥2.17) | chart 1.3.0 field-tested | CAREN `provider: Flow`; needs pc.7.6 |
| ACME/Traefik ingress | – | – | – | **2.19 fixes ACME issuance failures with the Traefik ingress class** |

Other deltas relevant here:
- 2.18: control-plane TLS hardening (explicit ECDHE suites, TLS1.2 min for scheduler/CM), Kommander root CA → 10 years, `kommander-federated-edit` deprecated, CAPI Cluster objects become read-only (webhook) → use `NKPCluster` `[web: itcs 2.18]`.
- 2.19: `nkp upgrade workspace` deprecated, `--kommander-applications-repository` removed, GitRepository catalogs removed (OCI only), Prism Central Projects 2.0 (one project per cluster), Nutanix registry on Docker Hub with a portal token (air-gapped keeps its mirror) `[web: next.nutanix.com NKP 2.19]` `[web: itcs 2.19 overview]`.
- 2.19 air-gapped bundle shape changed: **no applications tarball**, 6 image tars + a Release metadata artifact `[web: itcs 2.19 overview]`.

---

## Gaps / open questions

1. **Flow CNI in 2.19 has no PDF documentation at all.** Everything above about Flow CNI is vendor web docs + CAREN docs + field docs (2.18-tested). Confirm for 2.19: supported chart version (2.18 field used 1.3.0), the exact `nkp` CLI surface, whether `provider: Flow` alone is enough, and whether it is licensed in Starter.
2. **Flow CNI forces pc.7.6** while NKP 2.19 also supports pc.7.5 — untested combination, ask Nutanix.
3. **Kyverno**: an unexplained "Kyverno reports controller" runs in a real 2.19 fleet. Not documented anywhere. Find out which app owns it (NAI? Insights?) before telling anyone Kyverno is or is not shipped.
4. **Calico 2.19 version** and whether Calico remains a supported CNI choice on AHV (docs say "optional, still supported"; the licensing/marketing matrix only lists Cilium/Calico generically).
5. **EKS CNI conflict**: PDF p.20 says Cilium, EKS walkthrough shows `calico-system` pods. Verify on a live EKS cluster.
6. **Traefik 2.19 exact version** — only the chart (39.0.7) is known.
7. **Istio-Helm / Kiali / Jaeger / Knative versions in 2.19** — the release-notes "Supported Applications" table was not retrievable; PDF examples show istio-helm 1.23.6 (and an `istioctl` client 1.28.1 in the sample output, which is confusing).
8. **Dex version**: PDF text ("2.22.0") is years stale; release notes say 2.37.0; clusters run 2.42.0. Do not trust the PDF here.
9. **NodeLocal DNS**: not shipped, not documented. If an offline cluster needs it, it is a hand-rolled DaemonSet — decide whether the skills should teach it at all.
10. **Cilium ClusterMesh** is field-only (repo values + a 1.17.4 cert bug). No NKP support statement. If multi-cluster pod networking is a requirement, the supported answer is Istio multi-primary, not ClusterMesh.
11. **DSR default + AHV Network Controller VLAN** is a real 2.19 production incident `[web: itcs 2.19 part 4]`. The skills must teach the SNAT override *before* the first install on an NC-managed VLAN — and that the fix must go through the NKPCluster/Cilium-values ConfigMap, never a live edit.
12. **`nkp check cluster fips`** output format/exit codes not documented — verify in the lab.
13. **Air-gapped gatekeeper-library and sealed-secrets manifests are not bundled** — the skills need a "copy these in" list, else the documented commands silently fail.
14. **Session-affinity / source-IP** Traefik values are field-only; no NKP doc. Confirm they survive Flux reconciliation via `configOverrides` (they should — `apps.traefik.values`).
15. **Identity provider per workspace + Headlamp SSO**: Headlamp on a workspace with its own IdP is untested in these notes.
16. **Trust-bundle injection into Dex/ESO**: the `SSL_CERT_FILE` mount trick is field-only; check whether 2.19 core adds a CA injection path.
