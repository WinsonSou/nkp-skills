# Nutanix Flow CNI on NKP — research note

Scope: Nutanix **Flow Container Network Interface (Flow CNI)** on Nutanix Kubernetes Platform (NKP).
Primary source: *Flow Virtual Networking Guide 7.6* on portal.nutanix.com (document metadata:
Product Release Date 2026-07-27, Last Updated 2026-10-27) [portal: Flow Container Network Interface On NKP Clusters].
Live facts: one read-only NKP **2.19.0** management cluster (AHV, Starter, k8s v1.36.2) [live].
Upstream facts: `cluster-api-runtime-extensions-nutanix` (CAREN) docs [web: https://nutanix-cloud-native.github.io/cluster-api-runtime-extensions-nutanix/addons/cni/].

The conflict this note resolves: the guide says "Flow CNI supports only the Kubernetes clusters that
NKP creates and manages" [portal: Flow Container Network Interface On NKP Clusters], and the component
map §6 recorded "Flow CNI is not in 2.19.0 — the ClusterClass enum allows only Calico and Cilium" [live, map].
**The map entry is wrong.** The live 2.19.0 AHV ClusterClass enum is `["Calico","Cilium","Flow"]`
(see *Verdict for NKP 2.19*). The guide still does not use that field: it deletes the whole `cni`
addon and appends a `HelmChartProxy`.

---

## Components

### Flow CNI (Nutanix Flow Container Network Interface)
- **What**: Kubernetes CNI for NKP workload clusters, built on OVN-Kubernetes (OVN + OVS). Pod overlay
  over Geneve, extended into Nutanix VPCs so that pods and VMs share one overlay domain and pod namespaces
  map to VPCs. [portal: Flow Container Network Interface On NKP Clusters]
- **Upstream**: OVN-Kubernetes (ovn-org/ovn-kubernetes) with Nutanix patches; shipped as the Helm chart
  `nutanix-flow-cni` [portal: Preparing Kubernetes Clusters with Flow Container Network Interface].
- **NKP role / name**: a **CNI choice for AHV workload clusters only**. Chart `nutanix-flow-cni`; chart repo
  `https://nutanix.github.io/helm-releases/`; releases into namespaces `flow-cni-system`,
  `flow-cns-system`, `ovn-kubernetes` [web: CAREN CNI docs]; CAREN handler package `pkg/handlers/lifecycle/cni/nutanixflow`.
  ClusterClass field `addons.cni.provider: Flow` (`NutanixCNI`, "additionally support Flow") [live].
- **Runs on**: workload cluster; needs the Prism Central Network Controller / Flow Controller in the data path.
  Not on the management cluster by default (a management cluster can itself be created with Flow) [live].
- **Deployed by**: two documented mechanics.
  1. **Guide method (all versions ≥ 2.15)**: append `HelmChartProxy` (`addons.cluster.x-k8s.io/v1alpha1`) to the
     `nkp create cluster ... --dry-run --output=yaml` manifest, after deleting `addons.cni` [portal: Preparing Kubernetes Clusters with Flow Container Network Interface].
  2. **CAREN method**: `addons.cni.provider: Flow`, `strategy: HelmAddon` **only** (ClusterResourceSet unsupported)
     [web: CAREN CNI docs]; accepted by the enum but **not documented in the NKP 2.19 PDF** [pdf 2.19, no Flow CNI hit].
- **Default**: **disabled**. A default NKP 2.19 AHV install runs Cilium 1.19.4; the live `kommander`
  namespace holds 10 `HelmChartProxy` objects and none is `flow-cni` [live].
- **Version in 2.19**: chart version not pinned in the cluster; the guide says "version must be the version of
  Flow CNI compatible with the deployed NKP version" [portal: Preparing Kubernetes Clusters with Flow Container Network Interface].
  Documented Flow CNI releases: **1.0.0** (VM extension only) and **1.1.0** (container-only, hybrid, multiple VPC)
  [portal: Flow Container Network Interface Prerequisites]. The public repo index `https://nutanix.github.io/helm-releases/index.yaml`
  lists `nutanix-flow-cni` **1.0.0, 1.0.1, 1.1.0** only (checked 2026-11-01) [web]. Field value used on 2.18 was chart **1.3.0** [field] —
  that version is **not** in the public index; treat it as unverified.
  The Flow VN 7.6 release notes are **login-gated** → exact 2.19 pairing **UNKNOWN**.
- **Depends on / talks to**: Prism Central 7.6+ Network Controller (or Flow Controller 7.6+) with Flow in
  **Integrated with Prism Central** mode; AHV **VLAN Basic** subnets; Konnector (cluster must be onboarded to PC);
  MetalLB for egress services; pod/service CIDRs that do not overlap any VPC CIDR
  [portal: Flow Container Network Interface Prerequisites].
- **Air-gap notes**: the Flow CNI chart and images are **not** in the NKP bundle — you download a separate
  `flow-cni-1.1.0` dark-site bundle from the portal and push it with `nkp push bundle` into Harbor on the
  management cluster [portal: Deploying Flow CNI in a Dark Site]. Images live on the private
  `docker.io/nutanix` repository, so an image pull secret / token is mandatory [web: CAREN CNI docs].
- **Key CRDs / namespaces / CLI commands**:
  - `HelmChartProxy addons.cluster.x-k8s.io/v1alpha1` (install), `Cluster` topology variable `clusterConfig`.
  - `EgressIP` and `EgressService` (`k8s.ovn.org/v1`), MetalLB `IPAddressPool` / `L2Advertisement` (`metallb.io/v1beta1`).
  - Namespaces `flow-cni-system`, `flow-cns-system`, `ovn-kubernetes`; secret `flow-cni-secret`.
  - Commands: `nkp create cluster nutanix ... --dry-run --output=yaml`, `yq eval '... del(...addons.cni)'`,
    `kubectl apply -f cluster-<name>-install.yaml --server-side=true`, `nkp push bundle`.
  - **No `nkp` CLI flag exists for CNI** — flags grep for `cni|flow` in `nkp create cluster nutanix --help` returns 0 [live].
- **Sources**: portal pages listed above; [live]; [web: CAREN CNI docs]; [pdf 2.19 — absent].

### Prism Central Network Controller (Flow, integrated mode)
- **What**: The Prism Central component that owns VPCs, overlay/VLAN subnets, NAT/no-NAT gateways and the
  BGP gateway. Flow CNI registers the workload cluster with it.
- **Upstream**: Nutanix-only (formerly "Atlas networking"; bundles still use the `atlas-controller` name) [portal: Deploying the Network Controller at a Dark Site].
- **NKP role / name**: outside NKP. Prerequisite, not an NKP component.
- **Runs on**: Prism Central VM(s). **Deployed by**: Prism Central enablement (`Settings > Flow Management`), LCM
  (connected) or LCM dark-site web server (air-gap).
- **Default**: off. Deploying an XL PC at pc.7.5+ auto-deploys it in Integrated mode; on S/L PC you enable it
  manually and it needs extra CPU/memory [portal: Infrastructure Requirements for Network Controller].
- **Version in 2.19**: Network Controller **7.6.0+** / Flow Controller **7.6.0+** for Flow CNI 1.1.0+
  [portal: Flow Container Network Interface Prerequisites].
- **Air-gap notes**: separate **Network Controller LCM bundle** + Nutanix compatibility bundle served from the
  LCM dark-site web server; `mspctl controller airgap enable --url=http://<lcm-web-server>/release`,
  then `configure_lcm --print` must show `is_darksite: True` [portal: Deploying the Network Controller at a Dark Site].
- **Key commands**: `mspctl controller airgap enable|get`, `configure_lcm --print`,
  `kubectl get secrets -n ncr-system harbor-admin-password` (Harbor, for the CNI bundle push).
- **Sources**: as cited.

### Konnector (cluster onboarding)
- **What**: registers the NKP workload cluster in Prism Central; Flow CNI requires it ("You must onboard the
  Kubernetes clusters to Prism Central to use Flow CNI") [portal: Flow Container Network Interface Deployment Environments].
- **NKP role / name**: CAREN addon `konnectorAgent` (default on) [live, map §3.1].
- **Deployed by**: CAREN; **Default**: on. Without PC registration Flow CNI cannot see the cluster.

### MetalLB (egress service backend)
- **What**: provides the `LoadBalancer` IP that an `EgressService` uses as the source IP.
- **Default in NKP 2.19 on AHV**: on (`addons.serviceLoadBalancer.provider: MetalLB`) [live].
- **Constraint**: Flow CNI supports egress services **only with MetalLB in L2Advertisement mode**
  [portal: Deploying Egress Service with Flow Container Network Interface].

---

## Relationships

- Flow CNI -> Prism Central Network Controller: every VPC, subnet and NAT gateway object lives in PC; the
  cluster only carries the CRs that PC writes.
- Flow CNI -> Konnector/PC onboarding: without PC registration there is no VPC attachment
  [portal: Flow Container Network Interface Deployment Environments].
- Flow CNI -> AHV VLAN Basic subnets: NKP clusters for Flow CNI must be on AHV-managed (VLAN Basic) subnets only
  [portal: Flow Container Network Interface Prerequisites].
- Flow CNI -> CAAPH `HelmChartProxy`: the guide installs the chart with a HelmChartProxy in the **cluster
  namespace**, selected by `cluster.x-k8s.io/cluster-name` [portal: Preparing Kubernetes Clusters with Flow Container Network Interface].
- Flow CNI -> MetalLB `IPAddressPool` + `L2Advertisement`: required for `EgressService` (LoadBalancer IP as source IP).
- Flow CNI -> OVN `EgressIP`: node label `k8s.ovn.org/egress-assignable=""` makes a node an egress node.
- Flow CNI **replaces** Cilium: the default `cni` addon must be deleted, therefore no Cilium/Hubble and no
  kube-proxy replacement of the Cilium kind; `kubeProxy.mode` behaviour is **UNKNOWN** for Flow clusters.
- Flow CNI -/-> NKP LoadBalancer IP allocation: "Flow CNI does not manage the allocation of LoadBalancer IP
  addresses" [portal: Multiple VPC Support for Kubernetes Clusters] → MetalLB still owns service IPs.
- Flow CNI -> VPC objects are **not** managed through Kubernetes CRs: "Direct lifecycle management of VPCs
  through Kubernetes custom resources is not supported" [portal: Container-only and Hybrid VPC Limitations].
- Network Controller -> LCM (connected) or LCM dark-site web server (air-gap) for install/upgrade.

---

## Install procedure on NKP (as documented)

Source for every step: [portal: Preparing Kubernetes Clusters with Flow Container Network Interface] unless noted.
Connected site, Flow CNI 1.1.0+:

1. **Meet the prerequisites.** NKP **2.18 or later on Rocky Linux nodes**, AOS 7.6+, AHV 11.2+, Prism Central
   **pc.7.6+**, Network Controller/Flow Controller **7.6.0+**, Flow in *Integrated with Prism Central* mode,
   cluster subnets = **VLAN Basic (AHV-managed)**, Helm installed on the bastion
   [portal: Flow Container Network Interface Prerequisites].
2. **Create the NKP management cluster** (`nkp install kommander`, or an existing one).
3. **Create the Flow CNI image-pull credential token.** Downloads portal (`portal.nutanix.com/page/downloads/list`)
   → *Flow Networking and security* → component selector *Flow Container Network Interface (Flow CNI)* →
   **Generate Access Token** → *Manage Docker Hub Access Token* shows the **username** and **Access Token 1**
   (`Show` → clone icon). The token is the password. [portal: Generating the Credentials for the Flow CNI Image Pull]
   A second token slot exists; only one is needed.
4. **Build the base64 auth value**: `value1=$(echo -n '<username>:<access-token>' | base64)`
   [portal: Creating the Base64 Authorization Value → `value1=Base64 encode 'username:password'`]. Scrub: never
   write the real value into a repo.
5. **Generate the workload cluster manifest, do not create yet**:
   ```
   nkp create cluster nutanix \
     --cluster-name ${CLUSTER_NAME} \
     --control-plane-endpoint-ip ${CP_ENDPOINT_IP} \
     --control-plane-prism-element-cluster ${PE_CLUSTER} \
     --control-plane-subnets ${SUBNET} \
     --control-plane-vm-image ${NKP_IMAGE} \
     --endpoint ${PC_ENDPOINT} \
     --worker-prism-element-cluster ${PE_CLUSTER} \
     --worker-subnets ${SUBNET} \
     --worker-vm-image ${NKP_IMAGE} \
     --csi-storage-container ${CSI_STORAGE_CONTAINER} \
     --csi-hypervisor-attached-volumes=true \
     --kubernetes-service-load-balancer-ip-range ${LB_RANGE} \
     --kubernetes-pod-network-cidr ${POD_CIDR} \
     --kubernetes-service-cidr ${SVC_CIDR} \
     --registry-mirror-url https://registry-1.docker.io \
     --registry-mirror-username ${DOCKER_USER} \
     --registry-mirror-password ${DOCKER_TOKEN} \
     --ssh-public-key-file ${SSH_KEY_FILE} \
     --ssh-username <user> \
     --dry-run --output=yaml > cluster-${CLUSTER_NAME}-install.yaml
   ```
6. **Delete the CNI addon from the Cluster object** (this is what removes Cilium):
   ```
   yq eval '(select(.kind == "Cluster") | del(.spec.topology.variables[0].value.addons.cni)) // select(.kind != "Cluster")' > cluster-${CLUSTER_NAME}-install.yaml
   ```
   *Doc defect*: the command has no input file. yq reads nothing, prints its usage text, and the `>` redirect
   empties the manifest. The expression itself is correct. Working form (tested with mikefarah yq v4.54.1 on a
   multi-document manifest; the non-Cluster documents stay unchanged):
   ```
   yq -i '(select(.kind == "Cluster") | del(.spec.topology.variables[0].value.addons.cni)) // select(.kind != "Cluster")' cluster-${CLUSTER_NAME}-install.yaml
   # safer if clusterConfig is not variables[0]:
   yq -i 'del(select(.kind == "Cluster") | .spec.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni)' cluster-${CLUSTER_NAME}-install.yaml
   ```
   Do not copy the guide command verbatim.
7. **Append the Flow CNI `HelmChartProxy`** to the same file:
   ```yaml
   apiVersion: addons.cluster.x-k8s.io/v1alpha1
   kind: HelmChartProxy
   metadata:
     name: flow-cni                # guide: "<name>", e.g. flow-cni
     namespace: <cluster-namespace>   # MUST equal the Cluster's namespace in the manifest
   spec:
     clusterSelector:
       matchLabels:
         cluster.x-k8s.io/cluster-name: <workload-cluster-name>
     repoURL: https://nutanix.github.io/helm-releases/
     chartName: nutanix-flow-cni
     version: <flow-cni-version>    # must be compatible with the NKP version
     namespace: flow-cni-system
     options:
       waitForJobs: true
       wait: true
       timeout: 30m
       install:
         createNamespace: true
     valuesTemplate: |
       nutanix-core-flow-ovn-kubernetes:
         k8sAPIServer: "https://<control-plane-endpoint-ip>:6443"
         podNetwork: "192.168.0.0/16/24"
         serviceNetwork: "10.96.0.0/12"
       global:
         dockerConfigSecret:
           registry: docker.io
           auth: <base64>            # username:access-token, step 4
           create: true
         imagePullSecretName: "flow-cni-secret"
       imagePullSecrets:
         - name: flow-cni-secret
   ```
   Field rules from the guide: `metadata.namespace` must equal the cluster manifest namespace; `version` must
   match the NKP version; `auth` is the base64 of username + access token; `k8sAPIServer` is the control plane IP
   from the manifest; `podNetwork` is the pod CIDR that Flow CNI slices into per-node subnets (default
   `192.168.0.0/16/24`); `serviceNetwork` default `10.96.0.0/12`. All CIDRs must be unique and non-overlapping
   across clusters and nodes.
   `podNetwork` format: `192.168.0.0/16/24` is **not a typo**. It is the OVN-Kubernetes `cluster-subnets` form
   `<IP>/<prefix>/<hostsubnet-prefix>` (upstream example `10.128.0.0/14/23`) [web: ovn-kubernetes config package]:
   cluster pod CIDR `192.168.0.0/16`, one `/24` per node. Keep `<IP>/<prefix>` equal to `--kubernetes-pod-network-cidr`
   and `serviceNetwork` equal to `--kubernetes-service-cidr` (consistency rule derived, not stated in the guide).
   A field guide writes `podNetwork: "${POD_CIDR}/24"` with `POD_CIDR` = base address only [field]; that drops the
   cluster prefix and is unverified — use the three-part form.
8. **Create the workload cluster from the modified manifest**: with the management-cluster kubeconfig,
   `kubectl apply --server-side=true -f cluster-${CLUSTER_NAME}-install.yaml` (the guide defers to "Creating Advanced
   CLI Clusters"; the dark-site page uses this exact `kubectl apply`). `nkp create cluster` has **no** `-f` flag in
   2.19 [live: `nkp create cluster nutanix --help`].
9. **Onboard the workload cluster to Prism Central** (Konnector).
10. **Optional, after the cluster is up**: `EgressIP` or `EgressService` custom resources for deterministic egress.
11. **Verify**: `kubectl get helmchartproxy -n <cluster-namespace>` (READY `True`), then on the workload cluster
    `kubectl get pods -n flow-cni-system` and `kubectl get nodes -o wide` (per-node pod subnets).

Dark site (air-gap) — Flow CNI 1.1.0+, source [portal: Deploying Flow CNI in a Dark Site]:

1. Deploy **Harbor** on the management cluster (`ncr-system` namespace).
2. Read the Harbor admin password: `kubectl get secrets -n ncr-system harbor-admin-password -o json`, then
   decode `HARBOR_ADMIN_PASSWORD` with `base64 -d`.
3. Generate the Harbor credential blob for the chart values:
   `echo -n "<harbor_user>:<harbor_password>" | base64 > auth.txt` and build `config.json` with
   `{"auths":{"<harbor-ip>":{"auth":"<base64>"}}}`.
4. Push the NKP bundles into Harbor (`./cli/nkp push bundle`):
   - `--bundle ./container-images/kommander-image-bundle-v<version>.tar --to-registry <harbor-ip>:5000/library --to-registry-username admin --to-registry-password <pw> --to-registry-ca-cert-file <harbor-ca.crt>`
   - the same for `konvoy-image-bundle-v<version>.tar`.
5. Export the Harbor CA: `kubectl get secret harbor-root-ca -n ncr-system -o jsonpath='{.data.tls\.crt}' | base64 -d > harbor-ca.crt`.
   *Doc order defect*: step 4 already uses `harbor-ca.crt`. Run this step **before** step 4.
6. Download the **CNI dark-site bundle** (`flow-cni-1.1.0`) from the Nutanix Support Portal and push it:
   `nkp push bundle --bundle flow-cni-1.1.0 --to-registry <harbor-ip>:5000/library --to-registry-insecure-skip-tls-verify --to-registry-username <user> --to-registry-password <pw>`
   → pushes 7 images and copies `nutanix-flow-cni:1.1.0`.
7. Run the `nkp create` dry-run with **all registry-mirror parameters pointing at Harbor**.
8. Append the Flow CNI `HelmChartProxy` and **remove the default Cilium configuration** from the generated YAML.
   The guide does not show the dark-site `HelmChartProxy` values. Derived (not in the guide, verify): `repoURL` must
   point at the Harbor copy of the chart (`oci://<harbor-ip>:5000/library`), and `dockerConfigSecret.registry`/`auth`
   must be the Harbor host and the `auth.txt` value from step 3, not `docker.io`.
9. `kubectl apply -f cluster-<workload>-install.yaml --server-side=true` with the management-cluster kubeconfig.
10. Verify the `HelmChartProxy` status in the workload cluster namespace.

Air-gap controller side (before any of the above) [portal: Deploying the Network Controller at a Dark Site]:
download the Network Controller LCM bundle + Nutanix compatibility bundle, serve them from the LCM dark-site
web server at `http://<lcm-web-server>/release`, set `Admin Center > LCM > Settings > Source > Dark Site`,
then `mspctl controller airgap enable --url=http://<lcm-web-server>/release`, `mspctl controller airgap get`,
and confirm `is_darksite: True` from `configure_lcm --print | grep -i "msp\|atlas\|dark"`. The remaining NC
deploy steps are the connected-site steps. Upgrade path: LCM `Inventory > Perform Inventory` → select the Flow
component → `Pre-Upgrade > Upgrade Prechecks` → `View Upgrade Plan > Apply Updates`
[portal: Upgrading the Network Controller at a Dark Site].

---

## Prerequisites matrix

| Item | Flow CNI **1.0.0** (VM extension to k8s VPCs) | Flow CNI **1.1.0+** (VM-only / container-only / hybrid) |
|---|---|---|
| NKP | **2.15 or later**, nodes on **Rocky Linux** | **2.18 or later**, nodes on **Rocky Linux** (VPC requirements page lists "2.16, 2.18 or later" — inconsistent) |
| AOS | 7.5 or later | 7.6 or later |
| AHV | 11.0 or later | 11.2 or later |
| Prism Central | pc.7.5 or later | pc.7.6 or later |
| Flow component | Network Controller **7.0.0+** | Network Controller **7.6.0+** / Flow Controller **7.6.0+** |
| Prism Central size | S, L or **XL** | S, L or **XL**; the VPC-creation page requires **XL** |
| Node OS | Rocky Linux | Rocky Linux |
| Flow mode | Integrated with Prism Central (Network Controller) | Integrated with Prism Central |
| Subnet types | VLAN **Basic (AHV-managed)** for nodes | VLAN Basic for nodes; VPC external subnets VLAN (NAT / no-NAT) + overlay external subnets for transit |
| MTU | vs0 jumbo (9000 recommended, allowed 1500–9000); guest advertised **1442** (1500 − 58 Geneve) | same; CAREN default Flow overlay MTU **1350** to fit a 1442-byte `breth0` [web: CAREN CNI docs] |
| Ports | **UNKNOWN** — the guide defers to the separate *Ports and Protocols* tool ("For information on the ports and protocols used for Flow Virtual Networking, see Ports and Protocols") | same |
| PC resources | 2 GB memory **per AHV host** when NC is enabled; +3 GB/2 vCPU per PC VM on **S**, +4 GB/3 vCPU on **L** | same |
| Other | Helm on the deploy host; the cluster manifest YAML; the Flow CNI YAML; the `nutanix-flow-cni` Helm package; access token for `docker.io/nutanix`; cluster onboarded to PC with the same cluster name and namespace in all custom resources | same + unique pod CIDR per VPC; namespace labels without existing pods |

MTU ladder (VPC constructs) [portal: Maximum Transmission Unit Requirements]:
VPC 1442 · VPC + subnet extension 1392 · VPC + VPN 1356 · VPC + VTEP + VPN 1306.

---

## VPC model

- **Three VPC scopes**: VM-only, **container-only**, **hybrid** (VM VPC federated with a Kubernetes VPC)
  [portal: Flow Container Network Interface On NKP Clusters].
- **Shared Services VPC (SSVPC)**: created by Flow CNI on every cluster at deployment. Hosts cluster-wide
  services (CoreDNS, service-mesh controllers). Its pod CIDR is the `podNetwork` given at install time.
  Pods in namespaces not mapped to another VPC stay in the SSVPC. Pods that exist **before** a namespace is
  mapped never move. [portal: Multiple VPC Support for Kubernetes Clusters]
- **Additional VPCs** (created in Prism Central): fields = Kubernetes Cluster, **Namespace Scope**
  (`Manually selected namespaces` | `All namespaces`), **Namespace(s)** (label Key=Value pairs —
  the selector is on namespace labels, e.g. `kubernetes.io/metadata.name=<ns>`), **Gateway Node(s)**
  (node labels; Flow CNI uses these workers as VPC↔cluster gateways, pick more than one),
  **Pod CIDR** (unavailable when scope = All namespaces). [portal: Creating a Container-only VPC for Kubernetes Containers]
- **Model rule**: one hybrid model per cluster — either map *all* namespaces to one VPC, or map *sets* of
  namespaces to one or more extra VPCs. Both models on one cluster is unsupported
  [portal: Container-only and Hybrid VPC Requirements].
- **Traffic rules**: intra-VPC over Geneve with node IPs as outer headers; any VPC → SSVPC allowed;
  SSVPC → isolated VPC **blocked** (needs a hybrid VPC with `All namespaces`); direct pod-to-pod across two
  VPCs is treated as north-south and goes through an external gateway; ingress via k8s LoadBalancer/NodePort
  only (Flow CNI does not allocate LB IPs) [portal: Multiple VPC Support for Kubernetes Clusters].
- **IPAM**: one unique pod CIDR per VPC per cluster (including the SSVPC); Flow CNI slices it into per-node
  subnets; the **service CIDR is cluster-wide and shared**, VPCs cannot have their own.
- **Transit VPC**: hub VPC in a hub-and-spoke design; uplink must be a **VLAN** external network (a transit
  VPC cannot attach to another transit VPC); spokes use **overlay external subnets** (only transit VPCs may use
  them); ErPs must be configured per guest VPC or the transit BGP gateway will not advertise them (alert 802007)
  [portal: Transit VPCs]. A VPC supports **1 NAT + up to 4 no-NAT VLAN external subnets** with ECMP; requires
  PC 7.6+ and ANC 7.6.0+; BGP Additional Paths needed for >1 no-NAT subnet behind a BGP gateway
  [portal: Multiple External Subnets for VPCs].
- **Object model / ownership**: VPCs are Prism Central objects (UI or **v4 APIs only** — "Direct lifecycle
  management of VPCs through Kubernetes custom resources is not supported"). Flow CNI writes the underlying
  Kubernetes custom resources on the target cluster for each VPC. [portal: Container-only and Hybrid VPC Limitations]
  The concrete CRD names are **UNKNOWN** (not printed in the guide) — the only documented CRs are `EgressIP`,
  `EgressService`, plus the install `HelmChartProxy`.
- **Namespace ↔ VPC mapping is label-based and one-way**: a namespace selects a VPC by labels; a namespace
  already mapped to a VPC cannot be mapped to another; a namespace with existing pods keeps them in the SSVPC.
- **Prism Central side objects**: VPC, external subnet (VLAN or overlay, NAT or no-NAT), overlay subnet,
  NAT/no-NAT gateway (up to 4 active hosts), BGP gateway, ErP.

---

## Egress

Default behaviour: pod → external uses **SNAT to the node IP**, and *the SNAT IP is the same for all VPCs on
the cluster* [portal: Multiple VPC Support for Kubernetes Clusters]. Two mechanisms give a deterministic source IP
[portal: Egress Traffic Control for Flow Container Network Interface].

**EgressIP** (`k8s.ovn.org/v1`) — one IP (or a list) for selected pods/namespaces
[portal: Deploying Egress IP Address with Flow Container Network Interface]:
```yaml
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata: { name: <name> }
spec:
  egressIPs: [ <ip> ]
  podSelector:
    matchLabels: { app: <label> }
  namespaceSelector:
    matchLabels: { kubernetes.io/metadata.name: <namespace> }
```
then `kubectl label node <node> k8s.ovn.org/egress-assignable=""`. To persist across node replacement, add the
labels to the MachineDeployment template:
`node.cluster.x-k8s.io/egress-assignable: ""` and `node.cluster.x-k8s.io/egressnode: "true"`.
Fields: `metadata.name`, `spec.egressIPs[]`, `spec.podSelector` (matchLabels), `spec.namespaceSelector` (matchLabels).
One `EgressIP` per VPC if each VPC needs its own source IP.

**EgressService** (`k8s.ovn.org/v1`) — binds egress source IP to a `LoadBalancer` service IP; requires
**MetalLB in L2Advertisement mode** [portal: Deploying Egress Service with Flow Container Network Interface]:
1. `IPAddressPool` (`metallb.io/v1beta1`) with `spec.addresses: [<ip>/32]` in `metallb-system`.
2. `Service` type `LoadBalancer` with annotation `metallb.io/ipaddresspool: <pool>`.
3. `EgressService` with `metadata.name`/`metadata.namespace` **equal to the Service**, `spec.sourceIPBy: "LoadBalancerIP"`,
   `spec.nodeSelector.matchLabels: { egressnode: "true" }`.
4. `L2Advertisement` with `spec.ipAddressPools: [<pool>]` and
   `spec.nodeSelectors[].matchLabels: { egress-service.k8s.ovn.org/<namespace>-<service-name>: "" }` —
   OVN applies that label to the chosen egress nodes itself.
5. `kubectl label node <worker-node> egressnode=true` (control-plane nodes are usually excluded by MetalLB).

Field reference [portal: Egress Traffic Configuration Fields]: `EgressIP` = `metadata.name`, `spec.egressIPs`,
`spec.podSelector`, `spec.namespaceSelector`; `EgressService` = `metadata.name`, `metadata.namespace`,
`spec.sourceIPBy` (must be `LoadBalancerIP`), `spec.nodeSelector`; `IPAddressPool` = `metadata.name`,
`metadata.namespace`, `spec.addresses`; `L2Advertisement` = `spec.ipAddressPools`, `spec.nodeSelectors`;
`Service` = `metadata.annotations[metallb.io/ipaddresspool]`, `spec.selector`, `spec.ports`, `spec.type: LoadBalancer`.

---

## Verdict for NKP 2.19

**Supported — but only on AHV, only with Rocky Linux nodes, and the guide's install method is a manifest edit,
not a CLI flag.**

Evidence, strongest first:

1. **Live 2.19.0 ClusterClass accepts `Flow`.** `kubectl get clusterclass nkp-nutanix-v2.19.0` in namespaces
   `kommander`, `kommander-default-workspace`, `default` all give
   `addons.cni.provider.enum = ["Calico","Cilium","Flow"]`, with description
   *"NutanixCNI defines CNI configuration for Nutanix clusters, which additionally support Flow."* [live]
   The same field on `nkp-eks-v2.19.0`, `nkp-aws-v2.19.0`, `nkp-host-agent-v2.19.0` is
   `["Calico","Cilium"]` — Flow is **AHV-only** [live].
   `addons.cni` also exposes `imagePullCredentials.secretRef.name`, `strategy` (`ClusterResourceSet|HelmAddon`,
   default `HelmAddon`) and `values.sourceRef` [live] — exactly the CAREN Flow surface
   [web: CAREN CNI docs].
   ⚠️ This **corrects the component map §6/§7 entry**: Flow CNI *is* a ClusterClass choice in 2.19.0.
2. **No CLI surface.** `nkp create cluster nutanix --help` contains zero `cni`/`flow` flags [live], so CNI is
   only selectable through the cluster config YAML (`--dry-run --output=yaml` then edit).
3. **The official guide does not use the ClusterClass field.** Its documented procedure deletes
   `spec.topology.variables[0].value.addons.cni` and appends a `HelmChartProxy` for `nutanix-flow-cni`
   [portal: Preparing Kubernetes Clusters with Flow Container Network Interface]. That method is version-agnostic
   (it only needs CAAPH, present in NKP 2.19 [live]) and needs no CAREN enum value — so it works even where the
   enum would not (2.16–2.17, EKS).
4. **Version gate:** Flow CNI 1.1.0+ requires **NKP 2.18 or later on Rocky Linux**, AOS 7.6+, AHV 11.2+,
   pc.7.6+, NC/Flow Controller 7.6.0+ [portal: Flow Container Network Interface Prerequisites]. 2.19 satisfies the
   NKP release line; **the live 2.19 lab cluster runs Ubuntu 24.04.5, which does not meet the Rocky Linux
   requirement** [live]. Flow CNI therefore needs a *Rocky Linux* NKP image (`--worker-vm-image`/`--control-plane-vm-image`).
   NKP 2.19 offers a Nutanix **pre-built Rocky Linux 9.8** image (and Ubuntu 24.04) [pdf p.55], downloaded from the
   portal like any NKP node image. The extracted bundle top level has only the Ubuntu 24.04 ISO, but `image-artifacts/`
   carries `containerd-...-rocky-9.8-x86_64.tar.gz` for custom NIB builds [live]. So a Rocky image **is available** for 2.19.
5. **NKP 2.19's own PDF never mentions Flow CNI** — no hit for "Flow CNI", "Flow Container Network", and the
   only "Flow Virtual Networking" hits are subnet/float-IP cross-references [pdf 2.19]. So Flow CNI is
   **documented only in the Flow Virtual Networking Guide**, not in the NKP guide. Treat it as a
   Flow-documented, NKP-2.19-schema-accepted, Nutanix-supported feature that NKP's own docs stay silent about.
6. **Networking prerequisites that break on the live lab:** nodes must sit on **VLAN Basic (AHV-managed)**
   subnets and the cluster must be **onboarded to Prism Central** with the same cluster name/namespace in all
   CRs [portal: Flow Container Network Interface Prerequisites]. pc.7.5 (still allowed by NKP 2.19) is **not enough**
   — Flow CNI 1.1.0 needs pc.7.6+.
7. **Where Flow CNI fits the live enum vs. what actually gets installed:** a default 2.19 AHV install selects
   `Cilium`; the management namespace holds 10 `HelmChartProxy` objects and **none** is `flow-cni` [live].
   So `Flow` is available but never default; choosing it is an explicit create-time decision.

Practical rule for the skills:
- Path A (documented, safest, works 2.15→2.19): `--dry-run --output=yaml`, delete `addons.cni`, append the
  `HelmChartProxy` with `nutanix-flow-cni` + docker.io auth, then create. Air-gap adds the
  `flow-cni-1.1.0` bundle push into Harbor.
- Path B (schema-supported, no community-doc'd NKP support statement): `addons.cni: {provider: Flow, strategy: HelmAddon}`
  in the cluster config, with `imagePullCredentials.secretRef` for `docker.io/nutanix`.
- Either path: **Rocky Linux nodes**, pc.7.6+, AHV 11.2+, NC 7.6+, Flow integrated mode, VLAN Basic subnets,
  Konnector on.

---

## Version deltas

| Version | Flow CNI / Flow VN state per sources |
|---|---|
| NKP ≤ 2.14 / NC < 7.0 | not supported (Flow CNI 1.0.0 starts at NC 7.0.0, NKP 2.15) [portal: Flow Container Network Interface Prerequisites] |
| NKP 2.15–2.16 / NC 7.0–7.5 | Flow CNI 1.0.0: only "extend VPCs with VM configurations" to NKP workload clusters; single (Shared Services) VPC model [portal: Flow Container Network Interface Prerequisites]. Field/raw notes date the first NKP support at ≥ 2.17 [field] — the portal says **2.15**; the portal wins. |
| NKP 2.17 | raw `01`/`02` note "Flow CNI since 2.17" and CAREN `provider: Flow` [field]. The guide's compatibility list jumps 2.16 → 2.18, so 2.17 is **not** named. Status **UNKNOWN/ambiguous**. |
| NKP 2.18 / NC 7.6 / pc.7.6 | Flow CNI **1.1.0**: VM-only, container-only and hybrid VPCs, **multiple VPCs** per cluster, namespace→VPC mapping, egress IP + egress service. Field used chart 1.3.0 on 2.18 [portal: Flow Container Network Interface Prerequisites][field]. |
| NKP 2.19 | Live ClusterClass enum = `["Calico","Cilium","Flow"]` on AHV classes only [live]. Guide 7.6 still documents the HelmChartProxy install (no ClusterClass mention). New in the 7.6 docs: multiple VPC support, transit VPC, multiple external subnets with ECMP, egress, **Flow CNI on OpenShift** (1.1.0+, cluster network type `NutanixFlow`) [portal: Flow Container Network Interface on OpenShift Clusters]. Exact Flow CNI chart version paired with 2.19: **UNKNOWN** (release notes login-gated). |
| 2.19 map correction | Map §6 "Flow CNI — Not in 2.19.0, enum allows only Calico and Cilium" is **wrong**; only Calico/Cilium is true for EKS/AWS/host-agent classes. Fix the map and live SUMMARY item 4. |

### OpenShift (one line, per instructions)
Flow CNI 1.1.0+ is also supported on **Red Hat OpenShift** (IPI on AHV, Cluster Network Type `NutanixFlow`,
bootstrap-manifests bundle + dark-site bundle from the portal, then transition to the certified Flow CNI
Operator) [portal: Flow Container Network Interface on OpenShift Clusters].

---

## Gaps / open questions

1. **Exact Flow CNI chart version for NKP 2.19** — Flow VN 7.6 release notes are behind portal login
   (`Nutanix-Flow-Virtual-Networking-Release-Notes-v7_6_0` redirects to `my.nutanix.com` login) → **UNKNOWN**.
   Field data: 1.3.0 was used on 2.18 [field].
2. ~~Rocky Linux image for NKP 2.19~~ — **resolved**: pre-built Rocky Linux 9.8 image [pdf p.55]; Rocky 9.8
   containerd artifacts in the bundle for NIB [live]. The lab cluster itself is Ubuntu, so a Flow CNI test needs a
   new cluster on the Rocky image.
3. **Does the packaged CAREN v0.62.7 accept `provider: Flow`?** The enum in the live ClusterClass says yes
   (the schema is generated from the packaged CAREN), but no Flow cluster was created (read-only lab) → the
   runtime handler path is **UNVERIFIED**. Upstream changelog shows "feat: add Nutanix Flow CNI provider (#1519)";
   the release that contains #1519 was not confirmed → **UNKNOWN**.
4. **VPC CRD names.** The guide says VPC lifecycle is PC-only and Flow CNI writes Kubernetes custom resources
   per VPC, but never names them → **UNKNOWN**. Do not teach CR-level VPC management.
5. **Ports/protocols for Flow CNI** — the guide delegates to the separate *Ports and Protocols* tool; no table
   in the doc → **UNKNOWN**.
6. **Standalone Flow Controller vs Flow CNI** — the prerequisites note says "Flow Controller (Standalone)
   supports Flow CNI 1.1.0 or later", but the VPC-requirements page says "Flow deployed in the Standalone mode
   does not support Flow CNI" [portal: Flow Container Network Interface Prerequisites / Container-only and Hybrid VPC Requirements].
   **Contradiction in the official doc.** Recommend Integrated mode only.
7. **`kubeProxy.mode` and kube-proxy presence on a Flow cluster** — not documented; Flow CNI replaces the cni
   addon, so NKP's `kubeProxy.mode: disabled` default (tuned for Cilium) may be wrong for Flow → **UNKNOWN**.
8. **Hubble/Cilium-dependent NKP features** (Hubble relay platform app, Cilium LB-IPAM) obviously do not exist
   on a Flow cluster; what NKP platform apps assume Cilium is **UNKNOWN** — a likely support trap.
9. **Node CPU/memory overhead**: upstream says Flow CNI/OVN-Kubernetes needs more than Cilium or Calico
   (quick-start uses 4 vCPU / 8 Gi) [web: CAREN CNI docs]. NKP has no documented equivalent.
10. **MTU**: guide says 1442 guest MTU; CAREN's Flow defaults force `defaultMTU`/overlay MTU **1350** to fit a
    1442-byte `breth0` [web: CAREN CNI docs]. When using the guide's `HelmChartProxy` (not the CAREN handler)
    the MTU must be set by hand in `valuesTemplate` — the guide does **not** mention MTU at all. Flag as a
    real deployment risk.
11. **Licence tier** for Flow CNI on NKP (Starter/Pro/Ultimate) — not stated anywhere read → **UNKNOWN**.
    Note the Flow VN Network Controller itself is a PC/AOS-level entitlement, not an NKP app.
12. **Guide doc defects to not copy verbatim**: (a) the `yq eval` command has no input file, so the redirect empties
    the manifest — use `yq -i '<expr>' <file>` (step 6); (b) several lines (`--control-plane-endpoint-ip`,
    `--control-plane-prism-element-cluster`, `--worker-prism-element-cluster`, `--kubernetes-service-load-balancer-ip-range`)
    have a trailing space after `\`, which breaks the shell line continuation; (c) the sample uses `--ssh-username` with a
    personal user name — use your own; (d) dark-site step order (CA export after first use).
    **Not a defect**: `podNetwork: "192.168.0.0/16/24"` is valid OVN-Kubernetes `<CIDR>/<hostsubnet-prefix>` syntax (step 7).
