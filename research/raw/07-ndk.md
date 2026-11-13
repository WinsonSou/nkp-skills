# NDK — Nutanix Data Services for Kubernetes 2.3 (on NKP 2.19)

Reference version: **NDK 2.3** (guide product release date 2026-08-20, last updated 2026-10-14) [portal: Overview of NDK].
NKP 2.19 ships NDK 2.3 as a **workspace catalog application** [pdf p.337-340].
Guide scope: NKP, OpenShift, EKS-A. On NKP, NDK uses the CSI driver that NKP already ships [portal: Install the CSI Drivers].

Source marks: `[portal: <page title>]` = NDK 2.3 guide page on portal.nutanix.com; `[pdf p.N]` = NKP 2.19 PDF.
All example IPs, FQDNs and cluster names are replaced with placeholders.

---

## Components

### ndk-manager (NDK controller manager)
- **What**: Main controller. Reconciles `dataservices.nutanix.com` CRs (Application, ApplicationSnapshot, ProtectionPlan, replication, failover).
- **Upstream**: Nutanix proprietary. Image `ndk/manager:2.3.0` [portal: Installing NDK in an Air-Gapped Environment].
- **NKP role / name**: catalog app `ndk`; Deployment `ndk-controller-manager` in `ntnx-system` [portal: Enabling Multinamespace Support].
- **Runs on**: management cluster and workload clusters (any cluster that runs NDK).
- **Deployed by**: NKP catalog application (Flux HelmRelease) or Helm chart directly.
- **Default**: optional; licence Pro / Ultimate / NKPFS [pdf p.338].
- **Version in 2.19**: 2.3.
- **Depends on / talks to**: Nutanix CSI (snapshot + volume CRs), Prism Central API, `ntnx-system` secret with PC credentials.
- **Air-gap notes**: mirror `ndk/manager:2.3.0`; set `manager.repository`.
- **Key CRDs / namespaces / CLI**: `-n ntnx-system`; ConfigMap `ndk-manager-config`; flags via `config.controllerManagerConfig.flags` [portal: Enabling Multinamespace Support].
- **Sources**: [portal: Install NDK], [portal: Viewing Configuration Values and Certificates], [pdf p.337-340]

### ndk-infra-manager
- **What**: Infrastructure controller. Manages Prism Element / Prism Central storage interactions (volume groups, snapshots).
- **Upstream**: Nutanix proprietary. Image `ndk/infra-manager:2.3.0` [portal: Installing NDK in an Air-Gapped Environment].
- **NKP role / name**: part of the same `ndk` Helm release.
- **Runs on**: every cluster with NDK.
- **Deployed by**: catalog app / Helm chart.
- **Default**: always on with NDK.
- **Version in 2.19**: 2.3.
- **Depends on / talks to**: `StorageCluster` CR UUIDs, Prism Central, CSI.
- **Air-gap notes**: mirror image; `infraManager.repository`.
- **Key CRDs / namespaces / CLI**: `StorageCluster` CR (`storageServerUuid`, `managementServerUuid`).
- **Sources**: [portal: Setting Up the Storage Cluster Instances], [portal: Installing NDK in an Air-Gapped Environment]

### ndk-job-scheduler
- **What**: Runs `JobScheduler` (`scheduler.nutanix.com/v1alpha1`) schedules that start snapshot / replication work.
- **Upstream**: Nutanix proprietary. Image `ndk/job-scheduler:2.3.0`.
- **NKP role / name**: part of the `ndk` Helm release.
- **Runs on**: every cluster with NDK.
- **Deployed by**: catalog app / Helm chart.
- **Default**: always on with NDK.
- **Version in 2.19**: 2.3.
- **Depends on / talks to**: `ProtectionPlan`, `ApplicationSnapshot`.
- **Air-gap notes**: mirror image; `jobScheduler.repository`.
- **Key CRDs / namespaces / CLI**: `kubectl api-resources --api-group=scheduler.nutanix.com` → `jobschedulers`.
- **Sources**: [portal: Creating a JobScheduler CR], [portal: Uninstalling NDK Removing the Resources]

### kube-rbac-proxy and kubectl sidecars
- **What**: Authenticate/authorize controller metrics and API access; provide a pinned `kubectl` binary for the controller.
- **Upstream**: `brancz/kube-rbac-proxy` (v0.22.1); Kubernetes `kubectl` 1.36.3.
- **NKP role / name**: images `ndk/kube-rbac-proxy:v0.22.1`, `ndk/kubectl:1.36.3` in the same release.
- **Runs on**: every cluster with NDK.
- **Deployed by**: catalog app / Helm chart.
- **Default**: always on.
- **Version in 2.19**: kube-rbac-proxy v0.22.1, kubectl 1.36.3.
- **Depends on / talks to**: Kubernetes API.
- **Air-gap notes**: mirror both images; `kubeRbacProxy.repository/tag`, `kubectl.repository/tag`.
- **Key CRDs / namespaces / CLI**: none.
- **Sources**: [portal: Installing NDK in an Air-Gapped Environment]

### NDK UI (optional web console)
- **What**: Web console to connect remote sites, define and protect applications, snapshot, restore, PFO/UPFO.
- **Upstream**: Nutanix proprietary. Image `ndk/ui:2.3.0`.
- **NKP role / name**: disabled by default in the `ndk` chart (`ui.enable=false`); enabled per cluster [portal: NDK UI Installation].
- **Runs on**: one UI instance per Kubernetes cluster that you want to administer ("single-cluster scope").
- **Deployed by**: `helm upgrade` of the existing NDK release with `ui.enable=true` (NKP catalog values override also possible) [pdf p.342-343].
- **Default**: disabled. Needs CSI 3.8+ and NDK 2.3+.
- **Version in 2.19**: 2.3.0.
- **Depends on / talks to**: Ingress controller + TLS (SECRET / ISSUER / SELF_SIGNED), cert-manager for ISSUER/SELF_SIGNED, Kubernetes RBAC impersonation, port **347** to remote clusters [portal: NDK UI Prerequisites].
- **Air-gap notes**: push `ndk/ui:2.3.0` to the private registry, then `helm upgrade --reuse-values --set ui.enable=true --set ui.repository=...` [portal: Installing NDK UI in an Air-Gapped Environment]. `htpasswd` must exist on the workstation.
- **Key CRDs / namespaces / CLI**: users in `config.uiConfig.secrets.usersConfig` (`users.json`, bcrypt); TLS secret `ndk-ui-tls` in `ntnx-system`; roles `ADMIN`, `VIEWER`. No SSO, no LDAP/AD [portal: NDK UI Limitations and Requirements].
- **Sources**: [portal: NDK UI Installation], [portal: Installing NDK UI in an Air-Gapped Environment], [portal: Signing in to the NDK UI], [pdf p.342-343]

### ndkcli
- **What**: Kubectl-style CLI that writes NDK CRs (Application, ApplicationSnapshot, ProtectionPlan, failover, restore) and creates dependent CRs (Remote, ReplicationTarget) for you.
- **Upstream**: Nutanix proprietary. Ships in the NDK CLI bundle from the portal; `darwin-arm64` and `linux-amd64` builds [portal: Downloading NDK CLI Bundle].
- **NKP role / name**: standalone binary, or kubectl plugin `kubectl-ndk` (Nutanix recommends standalone) [portal: Enabling ndkcli as a kubectl Plugin (optional)].
- **Runs on**: admin workstation / jump host.
- **Deployed by**: manual download from the NDK download page.
- **Default**: optional (available from NDK 2.1).
- **Version in 2.19**: matches NDK 2.3.
- **Depends on / talks to**: kubeconfig contexts only; multi-cluster via `KUBECONFIG=a.cfg:b.cfg` + `kubectl config use-context` [portal: Working with Multiple Clusters Using kubeconfig].
- **Air-gap notes**: bundle download needs the portal once; keep the binary inside the air gap.
- **Key CRDs / namespaces / CLI**: `ndkcli create storagecluster|application|snapshot|replicationtarget|protectionplan|fsreplicationrelation`, `ndkcli protect application`, `ndkcli replicate snapshot`, `ndkcli perform failover|restore`, `--dry-run=client -o yaml` [portal: NDK CR Created through ndkcli].
- **Sources**: [portal: NDK CLI (ndkcli)], [portal: NDK CR Created through ndkcli]

### NDK recipe job image (async failover / failback engine)
- **What**: Kubernetes Job image that performs async PFO, UPFO, restore, reset-replication and UPFO cleanup.
- **Upstream**: Nutanix proprietary. `ndk/recipes:2.3.0` (chart example reference `nutanix/ndk-recipe:2.3.0`).
- **NKP role / name**: not a controller. Runs as `batch/v1 Job` in a **recipe namespace** that must differ from the application namespace.
- **Runs on**: the recovery cluster (and source cluster for cleanup), one Job per operation.
- **Deployed by**: apply of `migrate-job.yaml` / `failover-job.yaml` / `restore-job.yaml` / `reset-replication-job.yaml` / `upfo-async-cleanup-job.yaml` from `ndk-2.3.0-recipes.tar`.
- **Default**: needed only for **asynchronous** failover. Sync and NearSync failover use CRs, not recipes [portal: Failover (async)].
- **Version in 2.19**: 2.3.0.
- **Depends on / talks to**: source/target kubeconfig secrets, Prism Central credential secrets, `migrate-config`/`failover-config`/`restore-config`/`reset-replication-config`/`upfo-async-cleanup-config` ConfigMaps.
- **Air-gap notes**: `docker load` → tag → push `ndk/recipes:2.3.0`; create `imagePullSecret` in the recipe namespace [portal: Preparing the Environment for NDK Recipes].
- **Key CRDs / namespaces / CLI**: ConfigMaps above; secrets `source-kubeconfig-secret`, `target-kubeconfig-secret`, `ndk-failover-primary-pc-creds`, `ndk-failover-secondary-pc-creds`.
- **Sources**: [portal: Preparing the Environment for NDK Recipes], [portal: Applying Planned Failover], [portal: Applying Unplanned Failover]

### NDK CRDs (`dataservices.nutanix.com`, `scheduler.nutanix.com`)
- **What**: API surface that holds all NDK state. CRDs are installed by the Helm chart, and are **immutable** except the Application CR [portal: NDK Custom Resources].
- **Upstream**: Nutanix proprietary; CRD YAML in `../ndk-<version>/chart/crds/` of the NDK package.
- **NKP role / name**: ship inside the `ndk` chart; **not** removed by `helm uninstall` [portal: Uninstalling NDK Removing the Resources].
- **Runs on**: every cluster with NDK.
- **Deployed by**: Helm chart (`crds/`).
- **Default**: always installed with NDK.
- **Version in 2.19**: `v1alpha1` for both groups.
- **Depends on**: Kubernetes API only. You can create CRs even without NDK (CRDs alone) [portal: Configure NDK].
- **Air-gap notes**: none separate from the chart.
- **Key CRDs / namespaces / CLI**: see the Custom resources section below.
- **Sources**: [portal: NDK Custom Resources], [portal: Configure NDK]

### Nutanix CSI driver (dependency, not part of NDK)
- **What**: Provides Nutanix Volumes (block), Files (NFS) and CN-RWX persistent volumes, plus volume snapshots. NDK needs it for all data movement.
- **Upstream**: `nutanix/nutanix-csi-driver`.
- **NKP role / name**: CAREN addon in ns `ntnx-system`; **do not install CSI on NKP — it is packaged with NKP** [portal: Install the CSI Drivers].
- **Runs on**: workload (and management) clusters on AHV.
- **Deployed by**: NKP cluster addon.
- **Default**: on with NKP on Nutanix infrastructure.
- **Version in 2.19**: **NDK 2.3 needs CSI ≥ 3.7.1; NDK UI needs CSI ≥ 3.8** [pdf p.338], [portal: Prerequisites and Limitations for NDK].
- **Depends on / talks to**: Prism Central credentials secret `nutanix-csi-credentials` in `ntnx-system`.
- **Air-gap notes**: CSI images come with the NKP bundle.
- **Key CRDs / namespaces / CLI**: `VolumeSnapshotClass`, `VolumeSnapshot`; secret `nutanix-csi-credentials`.
- **Sources**: [portal: Install the CSI Drivers], [portal: Installing NDK in a Non-Air-Gapped Environment], [pdf p.338]

### cert-manager (conditional dependency)
- **What**: Issues and renews TLS certificates for NDK server TLS, mTLS and the NDK UI.
- **Upstream**: `cert-manager/cert-manager`.
- **NKP role / name**: **already present on NKP — do not install it for NDK** [portal: Installing Cert-Manager].
- **Runs on**: every cluster that uses ISSUER or SELF_SIGNED mode.
- **Deployed by**: NKP platform (non-NKP: `kubectl apply -f cert-manager.yaml`).
- **Default**: on with NKP.
- **Version in 2.19**: NKP default.
- **Depends on / talks to**: `Issuer` / `ClusterIssuer` resources that NDK references by name.
- **Air-gap notes**: NKP ships the images; no manual download.
- **Key CRDs / namespaces / CLI**: `kubectl get issuer <name> -n ntnx-system`.
- **Sources**: [portal: Installing Cert-Manager]

### intercom service (`ndk-intercom-service`) + load balancer
- **What**: `type: LoadBalancer` gRPC service on port **2021** that cross-cluster replication and the recipe jobs connect to.
- **Upstream**: Kubernetes Service; Nutanix recommends MetalLB, or kube-vip; NKP ships MetalLB [portal: NDK Custom Resources — Service type: LoadBalancer].
- **NKP role / name**: created by the `ndk` chart in `ntnx-system`; NKP MetalLB pool must have a free IP.
- **Runs on**: every cluster with NDK.
- **Deployed by**: chart; optional overrides `intercomService.type`, `loadBalancerClass`, `loadBalancerIP` [pdf p.341-342].
- **Default**: on.
- **Version in 2.19**: n/a.
- **Depends on / talks to**: MetalLB address pool; TLS mode of the NDK install.
- **Air-gap notes**: no images.
- **Key CRDs / namespaces / CLI**: `kubectl get svc ndk-intercom-service -n ntnx-system` → `EXTERNAL-IP`, `2021:30xxx/TCP`.
- **Sources**: [portal: NDK Custom Resources], [portal: Installing NDK and Skipping TLS Verification], [pdf p.341-342]

---

## Custom resources

All NDK kinds are `dataservices.nutanix.com/v1alpha1` unless noted. CRDs are immutable except `Application` [portal: NDK Custom Resources].

| Kind | apiGroup/version | Scope | Purpose | Key fields |
|---|---|---|---|---|
| `StorageCluster` | `dataservices.nutanix.com/v1alpha1` | Cluster | Registers the Prism Element + Prism Central UUID pair (the storage fabric) | `spec.storageServerUuid`, `spec.managementServerUuid` |
| `Application` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Data protection unit: groups workloads, config and PVCs | `spec.applicationSelector.resourceLabelSelectors[].labelSelector/includeResources/excludeResources`, `spec.applicationSelector.namespaceSelectors.includeNamespaces`, `spec.start`, `spec.useExistingConfig` |
| `ApplicationSnapshot` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Point-in-time snapshot request | `spec.source.applicationRef.name`, `spec.expiresAfter`, `spec.forceDeleteFilesSnapshot` |
| `ApplicationSnapshotContent` | `dataservices.nutanix.com/v1alpha1` | **Cluster** | Auto-created infrastructure record bound to a snapshot | `spec.applicationSnapshotRef`, `status.applicationSnapshotSummary.volumeClaimHandleMapByNamespace` |
| `ApplicationSnapshotReplication` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Replicates one snapshot to one target | `spec.applicationSnapshotName`, `spec.replicationTargetName` |
| `ApplicationSnapshotRestore` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Restores a (local or replicated) snapshot | `spec.applicationSnapshotName`, `spec.applicationSnapshotNamespace` (optional, cross-namespace) |
| `Remote` | `dataservices.nutanix.com/v1alpha1` | Cluster | Address + trust of the peer cluster's intercom service | `spec.clusterName`, `spec.ndkServiceIp`, `spec.ndkServicePort`, `spec.tlsConfig.skipTLSVerify/caBundle/enableMTLS/mTLSClientConfig` |
| `ReplicationTarget` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Binds a source namespace to a target namespace on a Remote | `metadata.namespace`, `spec.namespaceName`, `spec.remoteName`, `spec.serviceAccountName` |
| `JobScheduler` | **`scheduler.nutanix.com/v1alpha1`** | Namespaced | Schedule for snapshot / replication jobs | `spec.interval`, `.daily`, `.weekly`, `.monthly`, `.cronSchedule`, `.startTime`, `spec.timeZoneName` |
| `ProtectionPlan` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Snapshot schedule + retention + replication policy | `spec.protectionType` (`async`/`sync`/`nearSyncDR`), `spec.scheduleName`, `spec.retentionPolicy.retentionCount`, `spec.replicationConfigs[].replicationTargetName`, `spec.rpo` |
| `AppProtectionPlan` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Binds ProtectionPlan(s) to one Application | `spec.applicationName`, `spec.labels`, `spec.protectionPlanNames[]` |
| `HAApplication` / `HAA` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Auto-created for sync plans; holds HA state machine (conditions `Serving`, `Synchronized`, `Independent`) | finalizer `dataservices.nutanix.com/haac-owned-haa` |
| `HAApplicationContent` / `HAAC` | `dataservices.nutanix.com/v1alpha1` | Cluster | Auto-created sync companion record | — |
| `AppNearSyncProtection` / `nsp` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Auto-created per NearSync pair; health `Protected`/`RPOMet` | `status.conditions[]` |
| `AppNearSyncProtectionContent` / `nspc` | `dataservices.nutanix.com/v1alpha1` | Cluster | NearSync companion record | — |
| `AppPlannedFailover` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Planned failover request (sync / NearSync) | `spec.applicationName` |
| `AppUnplannedFailover` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Unplanned failover request | `spec.applicationName`, annotation `dataservices.nutanix.com/near-sync-force-allow-upfo` |
| `FileServerReplicationRelationships` / `FSRR` | `dataservices.nutanix.com/v1alpha1` | Cluster | 1:1 primary↔recovery file server mapping for Files replication | `spec.remoteName`, `spec.relationships[].primaryFileserverFQDN/recoveryFileserverFQDN` |
| `FilesReplicationPolicy` / `FRP` | `dataservices.nutanix.com/v1alpha1` | Namespaced | Smart DR policy. **Created by NDK only, never manually** | `spec.replicationConfigurations`, `spec.replicationSchedule` |

[portal: NDK Custom Resources], [portal: Creating an Application Protection Plan Policy], [portal: Monitor Health Status], [portal: Asynchronous Data Protection], [portal: Configuring Asynchronous Replication]

### StorageCluster

```yaml
apiVersion: dataservices.nutanix.com/v1alpha1
kind: StorageCluster
metadata:
  name: primary-cluster           # one CR per cluster (primary AND replication)
spec:
  storageServerUuid: <PRISM_ELEMENT_UUID>    # ncli cluster info  (CVM)
  managementServerUuid: <PRISM_CENTRAL_UUID> # ncli cluster info  (PCVM)
```

Get the UUIDs: `ncli cluster info` on the CVM (`Cluster UUID`), and on the Prism Central VM.
Apply: `kubectl apply -f storage-cluster.yaml -n ntnx-system` [portal: Setting Up the Storage Cluster Instances],
[portal: Setting Up Cluster and Application Environment for Replication].

### Application

```yaml
# single namespace, by label + explicit kinds
apiVersion: dataservices.nutanix.com/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: app-ns
spec:
  applicationSelector:
    resourceLabelSelectors:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: myapp
        includeResources:
          - group: ""
            kind: PersistentVolumeClaim
  start: true
  useExistingConfig: false
```

```yaml
# multi namespace (needs --enable-multins on BOTH clusters)
apiVersion: dataservices.nutanix.com/v1alpha1
kind: Application
metadata:
  name: my-multi-ns-app
  namespace: frontend-ns
spec:
  applicationSelector:
    namespaceSelectors:
      includeNamespaces:
        - frontend-ns
        - backend-ns
```

Constraints: `includeNamespaces` must contain all namespaces (also the CR's own namespace if you want it), no duplicates,
and not only the CR's own namespace [portal: Limitations (multinamespace)].
`applicationSelector: {}` selects **all** resources in the namespace — Nutanix advises against it
[portal: Creating an Application CR using YAML], [portal: NDK Custom Resources].

### ApplicationSnapshot / ApplicationSnapshotRestore

```yaml
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ApplicationSnapshot
metadata:
  name: my-app-snap-1
  namespace: app-ns
spec:
  source:
    applicationRef:
      name: my-app
  expiresAfter: 24h        # m or h; max 1440h (60 days); out-of-band snapshots only
---
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ApplicationSnapshotRestore
metadata:
  name: my-app-restore-1
  namespace: app-ns
spec:
  applicationSnapshotName: my-app-snap-1
  applicationSnapshotNamespace: other-ns   # optional; needs a ReferenceGrant
```

Check: `kubectl get applicationsnapshot -n app-ns` → `READYTOUSE true`, `BOUND SNAPSHOT CONTENT asc-...`
[portal: Generating Application Snapshots], [portal: Restoring Application Snapshot].

### Remote

```yaml
# server-side TLS (production)
apiVersion: dataservices.nutanix.com/v1alpha1
kind: Remote
metadata:
  name: dc2-remote
spec:
  clusterName: dc2.example.com        # must equal the SAN/DNS name in the peer certificate
  ndkServiceIp: "<INTERCOM_LB_IP>"    # EXTERNAL-IP of ndk-intercom-service on the peer
  ndkServicePort: 2021
  tlsConfig:
    skipTLSVerify: false
    caBundle: <BASE64_CA_BUNDLE>
```

Variants: no TLS → omit `tlsConfig`; skip verification → `skipTLSVerify: true`;
mTLS → `tlsConfig.enableMTLS: true` plus optional
`mTLSClientConfig: {secretName: <name>, secretNamespace: ntnx-system}` (keys `tls.crt`, `tls.key`, `ca.crt`;
default mount `/etc/certs`, Helm key `tls.server.certMountLocation`) [portal: Creating a Remote CR on the Primary Cluster].
Health: `kubectl get remote -A` → `AVAILABLE True` [portal: Creating a Remote CR on the Primary Cluster].

### ReplicationTarget

```yaml
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ReplicationTarget
metadata:
  name: dc2-target
  namespace: app-ns                 # SOURCE namespace of the application
spec:
  namespaceName: app-ns             # namespace on the TARGET cluster
  remoteName: dc2-remote
  serviceAccountName: default       # optional
```

Check: `kubectl get replicationtargets -n app-ns` → `AVAILABLE True`.
Note: the guide also shows `spec.targetNamespace` in one overview page; `namespaceName` is the schema field
[portal: Creating a ReplicationTarget CR on the Primary Cluster], [portal: Setting Up Cluster and Application Environment for Replication].

### JobScheduler (scheduler.nutanix.com)

```yaml
apiVersion: scheduler.nutanix.com/v1alpha1
kind: JobScheduler
metadata:
  name: hourly
  namespace: app-ns
spec:
  interval:
    minutes: 60
  startTime: "2030-01-01T00:00:00Z"   # optional, must be in the future (RFC3339)
  timeZoneName: "UTC"                 # IANA name; default = startTime offset, else UTC
```

Other forms: `daily: {time: "10:00"}`, `weekly: {days: MON-FRI, time: "10:00"}`,
`monthly: {dates: "1,3,5", time: "10:00"}`, `cronSchedule: "5 4 * * mon"`,
one-time `startTime` with no interval [portal: NDK Custom Resources], [portal: Creating a JobScheduler CR].

### ProtectionPlan (async / sync / NearSync)

```yaml
# asynchronous: schedule + retention + one or more targets
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ProtectionPlan
metadata:
  name: async-1h
  namespace: app-ns
spec:
  protectionType: async
  scheduleName: hourly
  retentionPolicy:
    retentionCount: 10          # 1..15
  replicationConfigs:
    - replicationTargetName: dc2-target
    - replicationTargetName: dc3-target   # async allows 1-to-many
---
# synchronous: no scheduleName, no retention, exactly one target
spec:
  protectionType: sync
  replicationConfigs:
    - replicationTargetName: dc2-target
---
# NearSync: no scheduleName, no retention, rpo 10-15m, one target
spec:
  protectionType: nearSyncDR
  rpo: 10m
  replicationConfigs:
    - replicationTargetName: dc2-target
```

Local-only plan (retention, no replication): omit `protectionType` and `replicationConfigs`, keep `scheduleName` + `retentionPolicy`
[portal: Creating a Protection Plan without Replication Policy]. `retentionPolicy.labelSelector` / `spec.labels` /
`spec.annotations` tag the created ApplicationSnapshots [portal: Creating a Protection Plan with Replication Policy].

### AppProtectionPlan

```yaml
apiVersion: dataservices.nutanix.com/v1alpha1
kind: AppProtectionPlan
metadata:
  name: my-app-plan
  namespace: app-ns
spec:
  applicationName: my-app
  labels:
    appName: my-app
  protectionPlanNames:
    - async-1h
    - sync-dc2          # only ONE sync plan per application
```

Only one `sync` plan per application. For async you can list several. With a sync plan NDK creates `HAApplication` and
`HAApplicationContent` [portal: Creating an Application Protection Plan Policy].

### Failover CRs (sync / NearSync)

```yaml
apiVersion: dataservices.nutanix.com/v1alpha1
kind: AppPlannedFailover
metadata:
  name: app-pfo
  namespace: <TARGET_NAMESPACE>       # apply on the NON-serving site
spec:
  applicationName: my-app
---
apiVersion: dataservices.nutanix.com/v1alpha1
kind: AppUnplannedFailover
metadata:
  name: app-upfo
  namespace: <TARGET_NAMESPACE>
annotations:
  dataservices.nutanix.com/near-sync-force-allow-upfo: "true"   # NearSync only, bypasses NSP precheck
spec:
  applicationName: my-app
```

[portal: Configuring Synchronous Replication], [portal: Applying Unplanned Failover (NearSync)]

### FSRR (Files only)

```yaml
kind: FileServerReplicationRelationships
apiVersion: dataservices.nutanix.com/v1alpha1
metadata:
  name: fsrr-dc2
spec:
  remoteName: dc2-remote
  relationships:
    - primaryFileserverFQDN: fs1.example.com
      recoveryFileserverFQDN: fs2.example.com
```

Strict 1:1 per file server; multi-target is not supported; the StorageClasses must point to those same file servers
[portal: NDK Custom Resources], [portal: Creating File Server Replication Relationship].

### Annotations that change behaviour

| Annotation | Object | Effect |
|---|---|---|
| `dataservices.nutanix.com/skip-pre-termination-snapshot: "true"` | Application | Skip the automatic pre-PFO snapshot (NDK ≥2.2); also unblocks `PreTerminationSnapshotFailed` |
| `dataservices.nutanix.com/exclude-from-deletion: "true"` | any selected resource | Keep operator-owned CRs (e.g. KafkaTopic) during `start: false` / PFO |
| `dataservices.nutanix.com/cleanup-volumes: "true"` | Application | Delete underlying volumes during NearSync UPFO cleanup on the stale primary |
| `dataservices.nutanix.com/application-conflict-resolved: "true"` | Application (active site) | Signal that split-brain cleanup is complete |
| `dataservices.nutanix.com/near-sync-force-allow-upfo: "true"` | AppUnplannedFailover | Bypass NSP precheck, force UPFO |
| `dataservices.nutanix.com/fileserver-ha: enabled` | StorageClass (Files) | Mark file volumes `HAEnabled` for sync |

[portal: NDK Custom Resources], [portal: Applying Planned Failover], [portal: Reestablishing Near-Synchronous After an Unplanned Failover], [portal: Synchronous Data Protection]

---

## Prerequisites and limits

### Software

| Item | Requirement | Source |
|---|---|---|
| NDK | 2.3 (this guide); NKP 2.19 catalog ships 2.3 | [portal: Overview of NDK], [pdf p.337-340] |
| NKP licence | **Pro, Ultimate or NKPFS** | [pdf p.338] |
| Nutanix CSI | **≥ 3.7.1** for NDK 2.3; **≥ 3.8** for the NDK UI; ≥3.7.0 for NearSync; ≥3.3.8 for Files; ≥3.0 for block | [pdf p.338], [portal: Prerequisites and Limitations for NDK], [portal: Supported Replication Topologies and Storage Prerequisites] |
| AOS / Prism Central | AOS **7.5+** and **pc.7.5+**; **7.5.1+** for NearSync and multinamespace; PC **7.5.1+** for multinamespace | [pdf p.338], [portal: Enabling Multinamespace Support] |
| Kubernetes | distributions: NKP, OpenShift, EKS-A. All clusters must use the **same** distribution. K8s ≥1.26 for multinamespace | [portal: Prerequisites and Limitations for NDK], [portal: Provision the Kubernetes Clusters] |
| Prism Central user | **admin**, or a non-admin user with the **Prism Admin** role (policies ≥ pc.2024.3). Fine-grained RBAC not supported | [pdf p.338], [portal: NDK Non-Admin User Support] |
| Kubernetes Management | enabled on PC 7.5+ (auto); PC 7.3 needs manual deploy | [portal: Enable Kubernetes Management and Install Helm] |
| Helm / kubectl | on the admin machine. `htpasswd` for the UI | [portal: Install NDK], [portal: NDK UI Prerequisites] |
| cert-manager | **already on NKP**; required on other distributions before NDK | [portal: Installing Cert-Manager] |
| iSCSI | `iscsi-initiator-utils` on all worker nodes (`rpm -q iscsi-initiator-utils`) | [pdf p.338] |
| StorageClass and AOS Storage Container | **exact same names** on primary and replication clusters (block); Files: same SC name and, for sync, same AOS container name holding the FSVMs | [portal: Supported Replication Topologies and Storage Prerequisites] |
| Docker Hub token | Nutanix Support Portal access token (`nutanixndk`); **max 2 tokens per organization** | [pdf p.338], [portal: Generating Nutanix Docker Hub Access Tokens] |
| Multinamespace | NDK **≥2.2**, PC/AOS ≥7.5.1, K8s ≥1.26, `--enable-multins=true` | [portal: Enabling Multinamespace Support] |

### Prism Element / Prism Central topology

- One-to-one: primary and replication Kubernetes clusters on the **same** Prism Element. Allowed; Nutanix does **not** recommend it for production, and Nutanix DR constructs are not supported inside one Prism Element [portal: Prerequisites and Limitations for NDK].
- One-to-many: one primary PE + one or more replication PEs, each on the same supported AOS version [portal: Prerequisites and Limitations for NDK].
- Single PC managing both PEs, or two PCs with **paired Availability Zones** (status must be `Reachable`, see KB-8252) [portal: Prerequisites and Limitations for NDK].
- **Synchronous replication requires a single Prism Central** (the Witness runs inside Prism Central) [portal: Synchronous Data Protection].
- Assign a **VIP to the Prism Element clusters** for iSCSI Data Services; for 3-VM scale-out PC, configure the **Prism Central VIP** [pdf p.338], [portal: Prerequisites and Limitations for NDK].

### Networks and ports

| Port / need | Purpose | Source |
|---|---|---|
| `2021` (recommended) on `ndk-intercom-service` `type: LoadBalancer` | cross-cluster NDK gRPC | [portal: Creating a Remote CR on the Primary Cluster] |
| `347` | NDK UI remote-site registration/replication | [portal: NDK UI Prerequisites] |
| `2030, 2036, 2073, 2090, 8740` between Prism Elements | Synchronous replication (`allssh 'modify_firewall ...'`). On a segmented DR network use the DR interface (e.g. `ntnx0`), not `eth0` | [portal: Synchronous Data Protection] |
| `insights.nutanix.com:443` outbound | Pulse telemetry (optional) | [portal: Network connectivity requirements] |
| ≥1 free MetalLB IP | intercom LoadBalancer | [pdf p.338], [portal: NDK Custom Resources] |
| Internet on the kubectl machine | stated NDK prerequisite; not satisfied in an air gap — see Gaps | [portal: Prerequisites and Limitations for NDK] |

### Scale and behaviour limits

- `ApplicationSnapshot` is aborted when configuration/metadata space is **> 8 MB** (stored as a Secret in etcd). Volume data is not part of that limit [portal: Prerequisites and Limitations for NDK].
- `retentionCount` **1..15**; the **target** cluster keeps at most **15** replicated snapshots regardless of source retention — set a ProtectionPlan on the target to keep fewer [portal: Creating a Protection Plan without Replication Policy].
- `expiresAfter` max **1440h (60 days)**; applies to out-of-band snapshots only, not policy snapshots [portal: NDK Custom Resources].
- Crash consistency per volume; **group consistency only for block volumes**. No group consistency across multiple file volumes or between file and block volumes [portal: Asynchronous Limitations].
- Async + NearSync on the same application: **not allowed**. Sync + NearSync to the **same** target cluster: **not allowed** [portal: Asynchronous Limitations], [portal: Using Multiple Replication Types (3DC Topology)].
- Hypervisor-attached block volumes are not protected or recovered by sync replication [portal: Synchronous Limitations].
- NearSync keeps only the newest state: no point-in-time restore, no retention [portal: Near-Synchronous Limitations].
- Multinamespace: no UI, no cross-namespace restore, `--enable-multins` needed on source **and** remote, all namespaces must already exist on the target [portal: Limitations (multinamespace)].
- NDK UI: max **2 protection plans** per application; no Files-backed apps; no StorageCluster/StorageClass/AppRecipe creation; no cross-namespace replication [portal: NDK UI Limitations and Requirements].
- One NDK instance per cluster; NDK is **cluster-scoped** [pdf p.339-340].
- `ntnx-system` is reserved for Nutanix components. Never put application workloads or protection CRs there [portal: Install NDK].

---

## Install on NKP

### A. Catalog path (NKP 2.19, preferred)

Two supported variants: air-gapped and non-air-gapped. The catalog app is a **cluster-scoped** application in a workspace.

**Air-gapped, exact steps** [pdf p.340], [portal-equivalent: NKP PDF section "Nutanix Data Services for Kubernetes in Workspace"]:

1. Clone the product catalog repository: `git clone https://github.com/nutanix-cloud-native/nkp-nutanix-product-catalog.git`
2. `cd nkp-nutanix-product-catalog/`
3. `docker login --username nutanixndk` (password = the Portal access token).
4. Create the bundle:
   `nkp create catalog-bundle --airgapped --apps=ndk="<ndk-version>"`
5. Push it to the configured registry mirror:
   `nkp push bundle --bundle ndk-<ndk-version>-airgapped.tar --to-registry=${REGISTRY_URL} --to-registry-username=${REGISTRY_USERNAME} --to-registry-password=${REGISTRY_PASSWORD}`
   *PDF defect*: the PDF prints `--to-registry-mirror-url/-username/-password`. The 2.19 CLI rejects them
   (`ERR unknown flag: --to-registry-mirror-url`); the real flags are `--to-registry`, `--to-registry-username`,
   `--to-registry-password` (+ `--to-registry-ca-cert-file` or `--to-registry-insecure-skip-tls-verify`) [live: `nkp push bundle --help`].
6. Create the catalog application (copy the command printed by `nkp create catalog-bundle`):
   `nkp create catalog-application --url oci://<registry-url>/nkp-nutanix-product-catalog/ndk --tag <ndk-version> --workspace kommander-workspace`
   Adding it to `kommander-workspace` propagates it to all workspaces.
7. NKP UI → select the target workspace → cluster widget **View Details** → **Applications** tab → **Nutanix Data Services for Kubernetes** → **Enable**.
8. In **General**: pick at least one target cluster, then put the configuration override in **Workspace Application Configuration Override**.
9. **Enable**.

Related NKP air-gap fact: the NKP air-gapped bundle also carries `nutanix-product-catalog-<nkp-version>-airgapped.tar`.
It holds **only NDK images**, must be pushed **only if you deploy NDK**, and is supported on Nutanix infrastructure only
[pdf p.714-715], [pdf p.238-244].

**Minimum catalog override (non-air-gapped or air-gapped with Docker Hub reachability)**:

```yaml
imageCredentials:
  credentials:
    registry: https://index.docker.io/v1/      # or your private registry URL
    username: <username>
    password: <access-token>
    email: <email>
# OR reference an existing secret (must exist in the NDK namespace):
imageCredentials:
  imagePullSecretName: <image-pull-secret-name>
```

Create that secret yourself when you use `imagePullSecretName`:

```bash
cat > config.json <<'EOF'
{"auths":{"https://index.docker.io/v1/":{"auth":"<base64(user:token)>","email":"<email>"}}}
EOF
kubectl create secret generic <image-pull-secret> -n ntnx-system \
  --from-file=.dockerconfigjson=./config.json --type=kubernetes.io/dockerconfigjson
kubectl get secret <image-pull-secret> -n ntnx-system
```

**Important**: the secret is **not** propagated. Create it on **every** workload cluster that runs NDK [pdf p.339].

**Air-gapped caveat**: the catalog path above still logs in to Docker Hub to build the bundle. Build the bundle on a
connected machine, then move the tar in. In a closed network, mirror the images and point `imageCredentials` at your
registry (see the Helm path).

### B. Helm path (guide's own procedure — works with no catalog at all)

**Air-gapped** [portal: Installing NDK in an Air-Gapped Environment]:

```bash
# 1. bundle from the NDK download page, then:
tar -xzvf ndk-2.3.0.tar.gz && cd ndk-2.3.0
#    layout: ndk-2.3.0/{chart/, ndk-2.3.0.tar, ndk-2.3.0-recipes.tar}

export REGISTRY_URL=<private-registry>
export NDK_REPO=ndk                 # create a project named "ndk" (e.g. in Harbor)
export K8S_CLUSTER_NAME=<cluster-name>

docker image load -i ndk-2.3.0.tar
for i in manager:2.3.0 infra-manager:2.3.0 job-scheduler:2.3.0 \
         kube-rbac-proxy:v0.22.1 kubectl:1.36.3 ui:2.3.0; do
  docker tag ndk/${i} ${REGISTRY_URL}/${NDK_REPO}/${i}
  docker push ${REGISTRY_URL}/${NDK_REPO}/${i}
done

kubectl create namespace ntnx-system     # or use --create-namespace

helm install ndk -n ntnx-system chart/ \
  --set manager.repository=${REGISTRY_URL}/${NDK_REPO}/manager \
  --set infraManager.repository=${REGISTRY_URL}/${NDK_REPO}/infra-manager \
  --set jobScheduler.repository=${REGISTRY_URL}/${NDK_REPO}/job-scheduler \
  --set ui.repository=${REGISTRY_URL}/${NDK_REPO}/ui \
  --set kubeRbacProxy.repository=${REGISTRY_URL}/${NDK_REPO}/kube-rbac-proxy \
  --set kubeRbacProxy.tag=v0.22.1 \
  --set kubectl.repository=${REGISTRY_URL}/${NDK_REPO}/kubectl \
  --set kubectl.tag=1.36.3 \
  --set tls.server.clusterName=${K8S_CLUSTER_NAME} \
  --set config.secret.name=nutanix-csi-credentials \
  --set imageCredentials.imagePullSecretName=ndk-image-pull-secret
```

- On **NKP** the CSI driver already created `nutanix-csi-credentials` in `ntnx-system` — pass `--set config.secret.name=nutanix-csi-credentials`.
- On a **non-NKP** cluster create it yourself:
  `kubectl create secret generic nutanix-csi-credentials -n ntnx-system --from-literal=key=<PC_IP:9440:user:password>`.
- Private registry with a private CA: install the CA on the nodes **before** NDK.
- Anonymous pull: omit `imageCredentials`.
- `ndk-image-pull-secret` can be auto-created by the chart from `imageCredentials.credentials.*`.

**Non-air-gapped** [portal: Installing NDK in a Non-Air-Gapped Environment]:

```bash
helm repo add ntnx-charts https://nutanix.github.io/helm-releases/ && helm repo update ntnx-charts
helm install ndk -n ntnx-system ntnx-charts/ndk --version <version> \
  --set imageCredentials.credentials.username=<docker-user> \
  --set imageCredentials.credentials.email=<email> \
  --set imageCredentials.credentials.password=<token> \
  --set tls.server.clusterName=<cluster-name> \
  --set config.secret.name=nutanix-csi-credentials
```

**Order of work on two clusters**: install NDK on the **replication** cluster first (choosing the TLS mode), read the
`ndk-intercom-service` external IP, then install on the **primary** cluster with the matching TLS mode, then create
`StorageCluster` on both, then `Remote` + `ReplicationTarget` on the primary [portal: Installing NDK on the Replication Cluster],
[portal: Installing NDK on the Primary Cluster].

### TLS options

| Mode | Helm flags | Notes |
|---|---|---|
| No TLS | `--set tls.server.enable=false` | test only |
| Server TLS, skip verify | `--set tls.server.clusterName=<dns-name>` | no CA check; `Remote.tlsConfig.skipTLSVerify: true` |
| Server TLS, SECRET | `--set tls.server.mode=SECRET --set tls.server.secretName=<secret>` | secret keys `tls.crt`, `tls.key` |
| Server TLS, ISSUER | `--set tls.server.mode=ISSUER --set tls.server.issuer.issuerName=<issuer>` | cert-manager; 90-day certs, auto-renew at ~2/3 of life |
| mTLS (either mode) | add `--set tls.server.enableMTLS=true` | secret/issuer must also carry `ca.crt`; the **same CA** must sign both clusters |

- Default when you set no mode: **SELF_SIGNED** via cert-manager. Not supported for production [portal: Installing NDK with Server Side TLS Using CA-signed Certificates].
- `<clusterName>` must be **unique** across all paired NDK instances and must match the certificate SAN, otherwise
  `Remote` verification fails [portal: Installing NDK and Skipping TLS Verification].
- NDK does not manage the certificate lifecycle; renewed certificates do not restart pods and do not require `Remote` edits,
  as long as the CA bundle in `Remote` signed the peer certificate.
- Default server secret name when `secretName` is unset: `ndk-server-cert`. In SECRET mode any `clusterName` you pass is ignored.
- Optional custom load balancer: `intercomService.type=LoadBalancer` + **both** `loadBalancerClass` and `loadBalancerIP`
  (one alone is invalid; if both are absent MetalLB picks a free pool IP).

[portal: Installing NDK without TLS Encryption], [portal: Installing NDK and Skipping TLS Verification],
[portal: Installing NDK with Server Side TLS Using CA-signed Certificates], [portal: Installing NDK with Mutual TLS using CA-signed Certificates],
[portal: Viewing Configuration Values and Certificates], [pdf p.341-342]

### Authentication: CSI secret vs Prism Central service account

| Model | How | Source |
|---|---|---|
| CSI secret (default) | NDK reuses `nutanix-csi-credentials` in `ntnx-system`: `config.secret.name=nutanix-csi-credentials`. Same PC credentials as CSI | [portal: Installing NDK in a Non-Air-Gapped Environment] |
| Separate NDK secret | `config.secret.name=<my-secret>` with keys `host`, `port`, `key_type: "api-key"`, `key_value`, `auth_type: "service-auth"` | [portal: Installing NDK Using a Service Account Independently of the CSI Secret] |
| Basic auth | username/password in the secret (`key=<PC_IP:9440:user:password>`) | [portal: Installing NDK in an Air-Gapped Environment] |
| Service account | PC ≥7.5 + NDK ≥2.1: Prism Central **service account** API keys (IAM → Service Accounts → + Add New Key). Scope: `Prism Admin` role, Full Access. Keys can expire | [portal: Service Account Support for NDK], [portal: Creating a Service Account for NDK], [portal: Creating an Authorization Policy for NDK] |

DR caveat: with multiple Prism Centrals the service account (NDK or CSI) must have the **same name on every Prism Central**
[portal: Service Account Support for NDK].

### Optional after install

- **Prometheus alerts**: install Prometheus Operator + Kubernetes Event Exporter, then
  `kubectl apply -f ndk-alert-config.yaml` (source: `nutanix-cloud-native/ndk-config-samples`, `Alert/ndk-alert-config.yaml`)
  [portal: Installing NDK Alerts YAML file for Prometheus].
- **Pulse telemetry**: `--set pulseTelemetry=true` (default **false**). Reports every 24 h to Nutanix Insights over HTTPS 443.
  Verify: `helm status ndk -n ntnx-system` → NOTES shows `NDK Pulse Telemetry enabled: true`
  [portal: NDK Pulse Telemetry], [portal: Enabling Pulse Telemetry], [portal: Verifying Pulse Telemetry Status].
  Collected: NDK version, object UUIDs/UIDs, UTC timestamps, aggregate counters, protection config, operation status,
  anonymised service IPs (last octet dropped). Not collected: names, secrets, workload data, PII [portal: Telemetry Data Summary].
- **Multinamespace**: `--set "config.controllerManagerConfig.flags={--enable-multins}"`, verify with
  `kubectl describe pod -n ntnx-system ndk-controller-manager-<id> | grep -i multins`
  [portal: Enabling Multinamespace Support].

---

## Replication types

| Factor | Asynchronous | Synchronous | Near-Synchronous |
|---|---|---|---|
| RPO | ≥ 1 hour | **0** (no data loss) | **10–15 min** (LWS every 20–30 s) |
| Network | none / WAN OK | **RTT < 5 ms**, same region | none / WAN OK |
| Prism Central | one or two (paired) | **single PC only** | one or two (paired) |
| Storage | Block, Files, CN-RWX | Block, Files, CN-RWX | **Block and CN-RWX only** |
| Direction | bidirectionally configurable | bidirectional active-standby | **unidirectional** (primary→DR only) |
| Targets | 1-to-many (Files: 1:1) | 1:1 | 1:1 |
| Failover method | **NDK Recipes (Kubernetes Jobs)** | `AppPlannedFailover` / `AppUnplannedFailover` CRs | same CRs |
| Failback | moderate (reset direction + cleanup jobs) | low (annotation on HAA) | **high** (delete stale resources, reconfigure reverse) |

[portal: Choose a Replication Type], [portal: Supported Replication Topologies and Storage Prerequisites], [portal: NDK Replication and Supported Storage Types]

### Asynchronous

- Config: `ProtectionPlan{protectionType: async, scheduleName, retentionPolicy, replicationConfigs[]}` + `AppProtectionPlan`.
- Validation of the pipeline: `ApplicationSnapshot` → `ApplicationSnapshotReplication` → the snapshot appears on the target
  with `READY true`; restore with `ApplicationSnapshotRestore`.
- **Failover is recipe-based**: async does not use `AppPlannedFailover`/`AppUnplannedFailover`.
  - PFO → `migrate-job.yaml` (`-op_name=migrate`), config in `migrate-config.yaml`.
  - UPFO → `failover-job.yaml` (`-op_name=failover`), config in `failover-config.yaml`.
  - Source-reachable UPFO with cleanup → add `-cleanup_source_upfo` and set `source_namespace`.
  - Files, PFO failed after the failover step → `restore-job.yaml` (`-op_name=restore`, `restore-config.yaml`).
  - Files, after UPFO → `reset-replication-job.yaml` (`-op_name=reset-replication`, `-reset_replication_direction=secondary-to-primary`).
  - Failback cleanup on the old primary → `upfo-async-cleanup-job.yaml` (`-op_name=upfo_async_cleanup`).
- Per-volume crash consistency only; UPFO reuses the newest available volume snapshot even if volumes are not in sync.
  If `app_pplan_name` and `app_snapshot_name` are both given, the recipe fails. Give exactly one.
- Recipe namespace **must differ** from the application namespace. `activeDeadlineSeconds: 21600` (6 h) in the shipped jobs.
- Files: `FSRR` is mandatory; `FRP` is created by NDK only (Smart DR); manual FRP creation is not supported.

[portal: Asynchronous Data Protection], [portal: Configuring Asynchronous Replication], [portal: Applying Planned Failover],
[portal: Applying Unplanned Failover], [portal: Resetting Replication for UPFO and Files Storage], [portal: Asynchronous Limitations]

### Synchronous

- Prerequisites: two Kubernetes clusters on two Prism Elements, **one Prism Central** (Witness inside PC), PC **DR enabled**
  (Settings → Enable Disaster Recovery), RTT **< 5 ms**, firewall ports **2030, 2036, 2073, 2090, 8740**, identical
  StorageClass names, identical AOS Storage Container names [portal: Synchronous Data Protection].
- Config: `ProtectionPlan{protectionType: sync}` + `AppProtectionPlan` → NDK creates `HAApplication` + `HAApplicationContent`.
- Health gate before PFO (both sites):
  - primary: `Serving=True/Active`, `Synchronized=True/Synced`, `Independent=False/Paired`
  - secondary: `Serving=False/Standby`, `Synchronized=True/Synced`, `Independent=False/Paired`
- PFO: apply `AppPlannedFailover` on the **non-serving** site. Since NDK 2.2 NDK first takes an ApplicationSnapshot on the
  primary (safety backup, not zero-loss) unless you annotate `skip-pre-termination-snapshot: "true"`.
- UPFO: apply `AppUnplannedFailover` on the secondary. Conditions become `Serving=True/Active`,
  `Synchronized=False/PeerNotAvailable`, `Independent=True/Independent` and then **freeze** until full sync returns.
- Failback: bring the primary back, NDK auto-re-establishes sync, then apply `AppPlannedFailover` on the primary.
- `usePEFallback: true` in CSI can leave PVs stuck `Terminating` during sync UPFO. Set `usePEFallback: false` in the CSI `values.yaml`.

[portal: Configuring Synchronous Replication], [portal: Conditions], [portal: Monitor Health Status],
[portal: Planned Failover (sync)], [portal: Unplanned Failover (sync)], [portal: Synchronous Limitations]

### Near-Synchronous

- Requirements: AOS/PC ≥7.5.1, NDK ≥2.2, CSI ≥3.7.0, matching StorageClass names, identical AOS container names, and a
  **VIP on the remote Prism Element** (without it the primary can wrongly report `Protected=True`).
- Config: `ProtectionPlan{protectionType: nearSyncDR, rpo: 10m..15m}` + `AppProtectionPlan` → NDK creates `AppNearSyncProtection` (`nsp`).
- Steady state check on **both** clusters: `kubectl get nsp -n <ns> -o yaml` → `type: Protected`, `status: "True"`, `reason: RPOMet`.
  `AppConfigRPONotMet` / `VolumeRPONotMet` = lagging, wait.
- PFO: `AppPlannedFailover` on the secondary. NSP `Protected` must be True on both sites or the PFO is refused.
- UPFO: `AppUnplannedFailover` on the secondary. Allowed by default only when NSP shows failure; override with
  `dataservices.nutanix.com/near-sync-force-allow-upfo: "true"`.
- Recovery after UPFO (split-brain): on the stale primary annotate `cleanup-volumes: "true"`, set `spec.start: false`,
  wait for `Active`/`Terminated`, delete the Application CR; on the active site annotate
  `application-conflict-resolved: "true"`; then re-create protection in the reverse direction (or pre-configure a reverse
  `AppProtectionPlan` so it resumes automatically).
- CN-RWX PVC: standard `storageType: NutanixVolumes` StorageClass + `accessModes: [ReadWriteMany]`; the file operator provisions a
  block volume behind an NFS-Ganesha pod.

[portal: Near-Synchronous Data Protection], [portal: Configuring Near-Synchronous Replication],
[portal: Verifying Steady State Before Failover], [portal: Applying Planned Failover (NearSync)],
[portal: Applying Unplanned Failover (NearSync)], [portal: Reestablishing Near-Synchronous After an Unplanned Failover],
[portal: Configuring StorageClass and PVC], [portal: Near-Synchronous Limitations]

### 3DC (multiple replication types on one application)

Valid: `sync → DC2` + `async → DC3`; `sync → DC2` + `nearSyncDR → DC3`. Both plans go in one `AppProtectionPlan`.
Invalid: NearSync + Async on the same application; two plan types pointing at the **same** target cluster; more than one
sync plan per application. Async snapshots may not be crash-consistent while a sync plan also runs.

[portal: Using Multiple Replication Types (3DC Topology)], [portal: Applying Asynchronous Replication to Apps with Synchronous Replication],
[portal: Applying NearSync Replication to Apps with Synchronous Replication]

---

## Day-2 runbooks

### 0. Common inspection commands

```bash
helm get values ndk -n ntnx-system                     # TLS mode, secret, clusterName
kubectl get configmap ndk-manager-config -n ntnx-system -o jsonpath='{.data.controller_manager_config\.yaml}'
kubectl get secret <secretName> -n ntnx-system -o jsonpath='{.data.tls\.crt}' | base64 --decode
kubectl get issuer <issuerName> -n ntnx-system
kubectl get svc ndk-intercom-service -n ntnx-system
kubectl get svc ndk-intercom-service -n ntnx-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get remote -A
kubectl get replicationtargets -n <ns>
kubectl get applicationsnapshot -n <ns>
kubectl get applicationsnapshotreplication -n <ns>
kubectl get nsp -n <ns> -o yaml
kubectl get haa -n <ns>
```
[portal: Viewing Configuration Values and Certificates], [portal: Creating a Remote CR on the Primary Cluster]

### 1. Snapshot (out-of-band)

```bash
kubectl apply -f applicationsnapshot.yaml     # spec.source.applicationRef.name + expiresAfter
kubectl get applicationsnapshot -n <ns>       # READYTOUSE true
# or
ndkcli create snapshot my-app-snap-1 --application=my-app --expires-after=24h -n <ns>
```
[portal: Generating Application Snapshots], [portal: Creating an ndkcli snapshot]

### 2. Replicate a snapshot

```bash
kubectl apply -f applicationsnapshotreplication.yaml   # applicationSnapshotName + replicationTargetName
kubectl get applicationsnapshotreplication -n <ns>     # PROGRESS 100, READY true
# or
ndkcli replicate snapshot my-snap --replication-target=dc2-target
kubectl get applicationsnapshots          # on the target cluster
```
[portal: Replicating an Application Snapshot to the Replication Cluster]

### 3. Restore (same namespace)

```bash
kubectl delete -f <application>.yaml            # Nutanix recommends deleting the app first
kubectl delete pvc --all --namespace=<ns>
kubectl get applicationsnapshot -n <ns>         # or applicationsnapshotreplication on the target
kubectl apply -f applicationsnapshotrestore.yaml
# or
ndkcli perform restore my-restore --application=my-app -n <ns>
```
Restore always lands in the snapshot's namespace [portal: Restoring Application Snapshot], [portal: Restoring an Application].

### 4. Cross-namespace restore (single-namespace apps only)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/raw/main/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl get crd | grep 'referencegrants.gateway.networking.k8s.io'
# ReferenceGrant in the SOURCE namespace:
#   from: {group: dataservices.nutanix.com, kind: ApplicationSnapshotRestore, namespace: <TARGET_NS>}
#   to:   {group: dataservices.nutanix.com, kind: ApplicationSnapshot, name: <SNAPSHOT>}
kubectl apply -f reference-grant.yaml
# then ApplicationSnapshotRestore in the TARGET namespace with spec.applicationSnapshotNamespace: <SOURCE_NS>
```
The CRD download needs the internet — carry the YAML into the air gap. On NKP 2.19 the CRD
`referencegrants.gateway.networking.k8s.io` was already present on the lab management cluster [live] —
check with `kubectl get crd` first and skip the download.
[portal: Configuring Cross-Namespace Restore], [portal: NDK Custom Resources]

### 5. Failover — synchronous / NearSync

```bash
# on the RECOVERY (non-serving) cluster, steady state verified first
kubectl apply -f app-pfo.yaml     # kind: AppPlannedFailover,  spec.applicationName
kubectl apply -f app-upfo.yaml    # kind: AppUnplannedFailover (add the force annotation for NearSync)
# optional, on the protected cluster, before PFO:
kubectl annotate application <app> dataservices.nutanix.com/skip-pre-termination-snapshot=true -n <ns>
# ndkcli form
ndkcli perform failover app-pfo --type=planned --application=<app> -n <ns>
ndkcli perform failover app-upfo --type=unplanned --application=<app> -n <ns>
```
[portal: Planned Failover (sync)], [portal: Unplanned Failover (sync)], [portal: Performing a Failover],
[portal: Applying Planned Failover (NearSync)]

### 6. Failover — asynchronous (recipes)

```bash
tar -xvf ndk-2.3.0/ndk-2.3.0-recipes.tar              # -> ndk-2.3.0-recipes/ (file is in the extracted NDK bundle)
# (air-gap) docker load -i ndk-2.3.0-recipes/ndk-2.3.0-recipes-img.tar
# (air-gap) docker tag ndk/recipes:2.3.0 <reg>/ndk/recipes:2.3.0 && docker push <reg>/ndk/recipes:2.3.0
kubectl -n <RECIPE_NS> create secret generic source-kubeconfig-secret --from-file=config=<SOURCE_KUBECONFIG> --save-config --dry-run=client -o yaml | kubectl apply -f -
kubectl -n <RECIPE_NS> create secret generic target-kubeconfig-secret --from-file=config=<TARGET_KUBECONFIG> --save-config --dry-run=client -o yaml | kubectl apply -f -
# Files only: kubectl -n <RECIPE_NS> create secret generic ndk-failover-primary-pc-creds  --from-literal=key=$(echo -n "<PC:9440:user:pass>" | base64)
# Files only: kubectl -n <RECIPE_NS> create secret generic ndk-failover-secondary-pc-creds --from-literal=key=$(echo -n "<PC:9440:user:pass>" | base64)

kubectl -n <RECIPE_NS> apply -f migrate-config.yaml && kubectl -n <RECIPE_NS> apply -f migrate-job.yaml    # PFO
kubectl -n <RECIPE_NS> apply -f failover-config.yaml && kubectl -n <RECIPE_NS> apply -f failover-job.yaml  # UPFO
kubectl -n <RECIPE_NS> apply -f restore-config.yaml && kubectl -n <RECIPE_NS> apply -f ndk-restore-job.yaml # Files, PFO failed late
kubectl -n <RECIPE_NS> apply -f reset-replication-config.yaml && kubectl -n <RECIPE_NS> apply -f reset-replication-job.yaml
kubectl -n <RECIPE_NS> logs ndk-<migrate|failover|reset-replication>-job-*    # ends with "STEP: Failover completed successfully"
```
Job YAML knobs: `image: <registry>/ndk/recipes:2.3.0`, `imagePullSecrets`, `args: [-op_name=...]`,
`activeDeadlineSeconds: 21600`, `backoffLimit: 0`.
[portal: Preparing the Environment for NDK Recipes], [portal: Applying Planned Failover], [portal: Applying Unplanned Failover],
[portal: Monitor the Failover Job]

### 7. Failback

1. Files after UPFO: `reset-replication-job.yaml` (`-reset_replication_direction=secondary-to-primary`).
2. On the secondary create `Remote` + `ReplicationTarget` pointing back at the primary.
3. On the secondary create the `Application` CR and (for scheduled protection) an `AppProtectionPlan`.
4. Files: create an `FSRR` with the secondary file server as primary and the primary file server as recovery.
5. Files: delete the stale `AppProtectionPlan` on the primary:
   `kubectl get appprotectionplan -n <ns> -o jsonpath='{range .items[?(@.spec.applicationName=="<app>")]}{.metadata.name}{"\n"}{end}' | xargs kubectl delete appprotectionplan -n <ns>`
6. Clean the stale resources on the primary: `upfo-async-cleanup-config.yaml` + `ndk-upfo-async-cleanup-job` (`-op_name=upfo_async_cleanup`).
   That job patches file PVs to `Retain`, deletes the application resources, then deletes the PVs.
7. Run PFO from the secondary target back to the primary.
   [portal: Configuring Failback to the Primary Cluster]

Sync failback is much shorter: wait for `Synchronized=True` on both sites again, then `AppPlannedFailover` on the primary.

### 8. Delete a protected application

```bash
kubectl delete application <app> -n <ns>     # NDK >=2.2 cascades plan/replication cleanup
```
Run it on the **primary**, never on a recovery site. Unprotect first in the NDK UI.
If the management plane was broken, the secondary keeps an orphan `HAA`:
```bash
kubectl get haa <haa> -o=json | jq 'del(.metadata.finalizers[] | select (. == "dataservices.nutanix.com/haac-owned-haa"))' | kubectl apply -f -
kubectl delete haa <haa>          # also deletes the HAAC
```
[portal: Deleting a Protected Application], [portal: Deleting the HAA Resource], [portal: Understanding Network Break Scenarios in Synchronous Replication]

### 9. Delete a base snapshot and restart replication (Files)

1. Delete the remote replicated ApplicationSnapshot. 2. Edit the snapshot, set `forceDeleteFilesSnapshot: true`.
3. Delete the `FilesReplicationPolicy` (change retention to `Delete`, or remove the share). 4. Delete the remote share in Prism Central / AFS CLI.
[portal: Deleting a Base Snapshot and Restart Replication]

### 10. Upgrade

```bash
# air-gapped: unpack the new bundle, tag+push its images, then
helm upgrade ndk -n ntnx-system <chart-location> \
  --set tls.server.clusterName=<cluster-name> \
  --set config.secret.name=nutanix-csi-credentials
# non-air-gapped
helm repo add ntnx-charts https://nutanix.github.io/helm-releases/ && helm repo update ntnx-charts
helm upgrade ndk -n ntnx-system ntnx-charts/ndk --version <version> \
  --set tls.server.clusterName=<cluster-name> \
  --set config.secret.name=nutanix-csi-credentials
```
- On NKP the two `--set` values are **mandatory**.
- Image-pull credentials must be passed **again** during the upgrade; if they are missing Helm deletes the existing image
  pull secret and does not recreate it. Fix: re-run with `--set imageCredentials.credentials.*` (new portal token).
- A new NDK version may require a newer Prism Central or CSI — upgrade those too.
[portal: Upgrade NDK]

### 11. Collect support logs

`KB-16326` holds the current support-bundle script and configuration files for NDK [portal: Collect Support logs for NDK].
Air gap: download the KB bundle once and keep it in the repo — the KB itself needs the internet.

### 12. Uninstall

```bash
# keep all NDK resources (CRDs, CRs, snapshots)
helm uninstall ndk -n ntnx-system

# remove everything
kubectl api-resources --api-group=dataservices.nutanix.com
kubectl delete <api-resource-type> --all --all-namespaces
kubectl get crd | grep dataservices.nutanix.com
kubectl delete crd <crd-name>                       # one per CRD; cluster-wide
kubectl get {app|asc|appsnaprep|asr|as|appplan|pplan|remote|replicationtargets|storageclusters} -A
kubectl api-resources --api-group=scheduler.nutanix.com
kubectl delete jobschedulers --all --all-namespaces
helm uninstall ndk -n ntnx-system
```
CRDs survive `helm uninstall`; delete them explicitly. Do the cleanup **before** the uninstall of the release.
[portal: Uninstall NDK], [portal: Uninstalling NDK without Removing the Resources], [portal: Uninstalling NDK Removing the Resources]

---

## Troubleshooting

### Conditions to read first

| Object | Conditions | Meaning |
|---|---|---|
| `Application` | `Active` (`Reason=Terminated` after stop), split-brain conflict with peer | per-application state |
| `ApplicationSnapshot` | `Progressing`, `AppConfigAcquired`, `VolumeSnapshotsCreated`, `ApplicationSnapshotFinalized`, `status.readyToUse` | snapshot pipeline |
| `ApplicationSnapshotContent` | same four conditions plus `readyToUse`; `reason: ApplicationSnapshotReady` | infrastructure record |
| `HAA` (sync) | `Serving` (`Active`/`Standby`), `Synchronized` (`Synced`/`SyncInProgress`/`OutOfSync`/`SyncFailed`/`PeerNotAvailable`), `Independent` (`Independent`/`Paired`/`Unknown`) | sync health |
| `nsp` (NearSync) | `Protected` (`True`/`RPOMet`, `AppConfigRPONotMet`, `VolumeRPONotMet`) | RPO health |

[portal: Conditions], [portal: Monitor Health Status], [portal: NDK Custom Resources], [portal: Verifying Steady State Before Failover]

### Multinamespace condition reasons

| Reason | Cause / fix |
|---|---|
| `MultinamespaceFeatureDisabled` | add `--enable-multins=true` to the local controller |
| `MultinamespaceFeatureNotSupported` | local NDK < 2.2 → upgrade |
| `MultinamespaceFeatureNotEnabledOnSource` / `…OnRemote` | enable the flag on source / remote controller |
| `MultinamespaceFeatureNotSupportedOnRemote` | remote NDK < 2.2 → upgrade |
| `NamespacesNotFound` | create the missing `includeNamespaces` namespaces on the target, retry the restore |
| `MultiNSCrossNamespaceRestoreNotSupported` | restore to the original namespace names only |

[portal: Monitor Health Status of Applications Across Multiple Namespaces], [portal: Troubleshooting Multinamespace]

### Common errors and checks

| Symptom | Check / fix |
|---|---|
| `multinamespace feature not enabled` on apply | `kubectl describe pod -n ntnx-system ndk-controller-manager-<id> \| grep -i multins`; reinstall the chart with the flag |
| `should not be an empty field` / "includeNamespaces contains only the namespace associated with the application" | `includeNamespaces` must hold ≥1 namespace different from the CR namespace |
| Restore fails, `snapshot is not the latest snapshot for volume` (Files, async) | set `app_snapshot_name` in `restore-config.yaml`, run `restore-job.yaml` |
| PFO/UPFO stuck at pre-termination snapshot | annotate the Application `dataservices.nutanix.com/skip-pre-termination-snapshot: "true"` |
| `PreTerminationSnapshotFailed` on the old primary after UPFO | same annotation, then retry PFO/failback |
| Both `app_pplan_name` and `app_snapshot_name` given (async) | recipe fails: "Please provide only one of ..." — remove one |
| `Remote` `AVAILABLE False` | wrong `ndkServiceIp`/port; `clusterName` ≠ certificate SAN; `caBundle` wrong or not base64; in mTLS mode a missing/mismatched client secret |
| NearSync shows `Protected=True` on primary only, `ProtectionNotStarted` on secondary | remote Prism Element has no VIP → configure the VIP, then re-check both sites |
| NearSync PFO refused | `Protected=True/RPOMet` required on **both** clusters; wait out the RPO window |
| NearSync UPFO rejected while `Protected=True` | add `dataservices.nutanix.com/near-sync-force-allow-upfo: "true"` |
| Sync UPFO leaves PVs `Terminating` | set `usePEFallback: false` in CSI `chart/values.yaml` |
| Sync `Independent=True` after UPFO | expected; primary is unreachable. Status freezes until full sync returns |
| Orphan `HAA` on the secondary | strip the finalizer `dataservices.nutanix.com/haac-owned-haa`, then `kubectl delete haa <name>` |
| Image pull errors after upgrade | missing/invalid image pull secret, expired Docker Hub token → re-run upgrade with `imageCredentials.credentials.*`; in air gap check the internal registry credentials |
| `loadBalancerIP` rejected / no external IP | metalLB pool exhausted, or `loadBalancerIP` outside the pool, or only one of `loadBalancerClass`/`loadBalancerIP` given |
| Restore/NDK UI restore of Files-backed app | not supported in the NDK UI |
| UI: remote site "Incorrect format of the cabundle" | the pasted value is not valid base64 |
| UI: protection cannot be saved | more than 2 plans, or an unsupported combination (e.g. sync + sync) |
| UI: Failover button disabled | you must be logged into the **target** site; or an operation is in progress |
| UI: application discovers zero resources | label keys/values or resource kinds do not match; check the Resources tab |
| UI: plan status `Inactive` | the target namespace does not exist or was not selected during remote-site connection |
| Snapshot creation aborted | configuration/metadata payload > 8 MB |
| `kubectl apply` of a CR fails after an NDK version change | CRDs are immutable — upgrade the chart, do not hand-edit CRDs |

[portal: Troubleshooting Multinamespace], [portal: Troubleshoot Failover Scenario], [portal: Troubleshooting (NDK UI)],
[portal: Upgrade NDK], [portal: Troubleshoot sections of the replication pages], [pdf p.341-342]

---

## Relationships

- NDK -> Nutanix CSI: NDK protects only CSI-provisioned volumes (Volumes, Files, CN-RWX), uses CSI snapshots and AOS volume groups [portal: Install the CSI Drivers].
- NDK -> Prism Central: authentication (CSI secret / service account), metadata, DR enablement, Witness for sync, FSVMs for Files [pdf p.338], [portal: Synchronous Data Protection].
- NDK -> Prism Element: `StorageCluster` UUIDs, iSCSI data services VIP, storage containers, file servers [portal: Setting Up the Storage Cluster Instances].
- `Application` -> `ApplicationSnapshot` -> `ApplicationSnapshotReplication` -> `Remote`/`ReplicationTarget` -> target cluster [portal: Understand NDK Replication].
- `Application` -> `AppProtectionPlan` -> `ProtectionPlan` -> `JobScheduler` (async only) -> snapshots [portal: Policy-Based Application Snapshots and Replications Using YAML].
- `ProtectionPlan{sync}` -> `AppProtectionPlan` -> `HAA`/`HAAC` (health + failover state machine) [portal: Monitor Health Status].
- `ProtectionPlan{nearSyncDR}` -> `AppProtectionPlan` -> `AppNearSyncProtection`/`NSPC` [portal: Near-Synchronous Data Protection].
- `Application` (Files) -> `FSRR` -> `FRP` (auto) -> Smart DR share replication [portal: Asynchronous Data Protection].
- Async failover -> recipe Jobs -> kubeconfig secrets + PC credential secrets [portal: Preparing the Environment for NDK Recipes].
- NDK UI -> `Remote`/`ReplicationTarget` (created for you) and -> NDK CRs via Kubernetes RBAC impersonation [portal: Connecting a Remote Site].
- NKP catalog app -> OCI catalog (`nkp-nutanix-product-catalog`) -> NDK image registry credentials [pdf p.340].
- NKP air-gapped bundle -> `nutanix-product-catalog-<ver>-airgapped.tar` (NDK images only) -> registry mirror [pdf p.714-715].
- NDK -> MetalLB: intercom service external IP is the anchor of every `Remote` CR [portal: NDK Custom Resources].
- NDK -> Prometheus Operator + Event Exporter: `ndk-alert-config.yaml` [portal: Installing NDK Alerts YAML file for Prometheus].
- NDK -> Pulse/Insights: optional 24 h telemetry to `insights.nutanix.com:443` [portal: Network connectivity requirements].

---

## Version deltas

| Version | Changes recorded in the sources |
|---|---|
| **2.3** | Base of this guide. **Pulse telemetry** added (opt-in, 24 h, Insights over 443). UI images at `2.3.0`, recipes `2.3.0`, `kubectl:1.36.3`, `kube-rbac-proxy:v0.22.1`. `rpo`/NearSync docs consolidated. [portal: NDK Pulse Telemetry], [portal: Installing NDK in an Air-Gapped Environment] |
| 2.2 | **Multinamespace Application CR** (`--enable-multins`, PC/AOS 7.5.1+, K8s 1.26+); **CN-RWX** storage type (CSI 3.7.1+); PFO takes an automatic pre-termination snapshot (+ skip annotation); deleting the Application CR auto-cleans protection on both sites [portal: Enabling Multinamespace Support], [portal: NDK Replication and Supported Storage Types], [portal: Deleting a Protected Application] |
| 2.1 | **ndkcli** introduced; **Prism Central service accounts** (API keys) supported (PC 7.5+) [portal: NDK CLI (ndkcli)], [portal: Service Account Support for NDK] |
| 2.0 | Nutanix **Files** support (async + sync, no NearSync); async failover via **NDK Recipes** [portal: Install the CSI Drivers], [portal: Preparing the Environment for NDK Recipes] |
| 1.3 | Non-admin Prism Central user support (must hold `Prism Admin`); block volumes only [portal: NDK Non-Admin User Support], [portal: Supported Replication Topologies and Storage Prerequisites] |
| NKP 2.17 | NDK installable **from the NKP UI/catalog** instead of the manual tarball + k8s-agent route [pdf p.339] |
| NKP 2.19 | Catalog app `ndk` = **2.3**; OCI-only catalogs; air-gap via `nkp create catalog-bundle --airgapped --apps=ndk=<v>` [pdf p.337-340], [web: NKP 2.19 release notes] |

---

## Gaps / open questions

- **UNKNOWN**: exact NDK 2.3 ↔ NKP "Software Requirements" table (K8s versions, PC build) — the guide points to the
  **NDK Release Notes**, which are not part of the 146-page guide. CSI (3.7.1/3.8) and AOS/PC (7.5/7.5.1) are the only
  numbers stated in-guide.
- **UNKNOWN**: supported scale numbers for NDK (max applications per cluster, max snapshots, max replication targets per
  plan). Only per-snapshot (8 MB) and retention (15) limits are documented.
- **UNKNOWN**: the ASR/`ApplicationSnapshotContent` `expiresAfter` interaction with protection plans beyond "not applicable".
- `Remote` port: the guide "recommends 2021" but shows `PORT(S) 2021:30xxx/TCP`; the **UI** page says "The default port is 347"
  for remote-site registration and replication. Whether 347 is an additional UI-only service or a different default is not stated
  [portal: NDK UI Prerequisites] vs [portal: Creating a Remote CR on the Primary Cluster]. Verify on a live cluster.
  Firewall rule for the skill until verified: open both 2021 and 347 between the intercom LB IPs.
- Air-gap contradiction: "Prerequisites and Limitations for NDK" lists *"You have internet connectivity on the local machine
  where you run the kubectl commands"* (confirmed on the portal, 2026-11-01). The guide's own air-gap page ("Installing NDK in
  an Air-Gapped Environment") installs from the bundle and a private registry with no internet step. Treat the prerequisite as a
  connected-environment statement. Internet-only items the air-gapped operator must pre-stage: the NDK bundle + CLI bundle
  (portal), KB-16326 support script, `ndk-alert-config.yaml`, `grpcurl` (optional), and — for the catalog path — the
  `nkp create catalog-bundle` run, which needs `git clone` of the catalog repo and `docker login` to Docker Hub.
- The catalog air-gap path (`docker login` + `nkp create catalog-bundle`) still needs Docker Hub. For a fully closed
  environment use the Helm path with mirrored images, or confirm with Nutanix that the catalog tar + mirrored images are
  enough.
- `nkp create catalog-bundle --airgapped --apps=ndk=<v>` output example shows a possibly doubled name
  (`ndk-ndk-version-airgapped.tar`). Use the value printed by the command.
- `helm-releases` index (checked 2026-11-01) lists `ndk` chart versions 2.3.0, 2.2.0, 2.1.0, 2.0.0, 1.3.0 [web].
- Two guide pages disagree on the `ReplicationTarget` target-namespace field (`namespaceName` in the CR reference and in
  the step-by-step page, `targetNamespace` in the "Setting Up Cluster and Application Environment" page). `namespaceName`
  is the schema field in the CR tables.
- Support-bundle script for logs lives in **KB-16326** (portal) — not captured here. Air-gapped operators need it pre-staged.
- Prometheus alert YAML lives on GitHub (`ndk-config-samples`, branch `ryuk-0111-patch-1` in the guide link) — pre-stage it.
- ReferenceGrant CRD comes from the Gateway API repo — pre-stage the YAML for cross-namespace restore.
- Not verified on the live lab cluster (NDK is not installed there). All statements are portal/PDF based.
