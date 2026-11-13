---
name: nkp
description: >
  NKP (Nutanix Kubernetes Platform; also Konvoy, Kommander, D2iQ DKP) router and architecture map.
  Load first for any NKP question: what a component, namespace, or CRD is, which license tier has a
  feature, how the parts connect, or which nkp-* skill does a job.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-02"
  sources: "live 2.19.0, pdf 2.19"
---

# NKP router

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

## How to use this skill

1. Find the job in the table "Job → skill". Load that skill.
2. If the job touches two skills, load the skill that is higher in the table first. Follow its pointers.
3. Check your skill list (or the folders next to this skill). Do not guess. If the skill is not there, tell the user: "Skill `<name>` is not installed." Then give only READ-ONLY checks from this skill. Label them "(not from a skill)". Give no CHANGES command. Stop.
4. For a "what is X" question, use the map below and [references/components.md](references/components.md).
5. Prism Central actions (free IP check, floating IPs, volume groups, PC values, credential checks) are in the companion `nutanix-*` skills (ADR 0004), for example skill `nutanix-networking` and skill `nutanix-storage`. Each NKP skill names the companion skill and the RECIPES heading. If the companion skill is not installed, the user does the step in Prism Central. Run a companion recipe in a marked bash block: line 1 `# READ-ONLY` or `# CHANGES`, line 2 `source ~/nkp-site.env 2>/dev/null`, then `python3 - <<'PY'` with the recipe code. The first Python line is the import line of skill `nutanix-api` step 2, with the real folder of that skill (never a `<...>` text). Never show recipe code in a block without a mark.

Done when: you named one skill for the job, or you gave the "not installed" answer.

## Job → skill

| Job | Skill |
|---|---|
| Architecture, names, namespaces, "what is X", the license tier of a feature | `nkp` |
| Create a management or workload cluster: bootstrap, create, pivot, Kommander | `nkp-install` |
| Air-gap: bundle contents, `nkp push bundle`, registry mirror, seeding, OS package bundles, custom images, offline catalog bundles | `nkp-airgap` |
| Day 2 on a cluster: NKPCluster edits, ClusterClass and CAREN variables, node pools, scale, autoscaler, MachineHealthChecks, certificate renewal, Metal hosts, delete a cluster | `nkp-cluster-lifecycle` |
| Upgrade NKP, Kommander, management or workload clusters; version order and gates; GitOps-managed clusters, Docker Hub credentials gate | `nkp-upgrade` |
| Something is broken: debug ladder, `nkp diagnose`, symptom → skill index; stuck rollout, stuck delete or finalizers, HelmRelease not Ready, controller logs, bootstrap failure | `nkp-troubleshooting` |
| Cilium, Calico, Hubble, MetalLB, kube-vip, Nutanix CCM, Traefik, cert-manager, ingress certificate, custom domain, proxy, MTU | `nkp-networking` |
| Platform apps, AppDeployment overrides, catalogs (OCI), Flux, project CD | `nkp-platform-apps-gitops` |
| Dex and identity providers, RBAC, workspaces and projects, Gatekeeper, FIPS details, CIS, External Secrets, apply or change a license | `nkp-identity-security` |
| Nutanix CSI, StorageClasses, Rook Ceph, COSI, Velero backup and restore | `nkp-storage-backup` |
| Prometheus, alerts, Grafana, Thanos, Karma, logging, Loki | `nkp-observability` |
| NVIDIA and AMD GPU operators, DRA, MIG, time-slicing, AI Catalog, NAI | `nkp-gpu-ai` |
| Nutanix Flow CNI (AHV only) | `nkp-flow-cni` |
| NKP cluster inside a Flow VPC (overlay subnet, floating IPs) | `nkp-vpc` |
| NDK (Nutanix Data Services for Kubernetes): install, snapshots, replication, failover | `nkp-ndk` |
| General Kubernetes (kubectl, workloads, networking, storage, RBAC, debug) that is not NKP-specific | `kubernetes-core` |

## What NKP is

- NKP has three parts. **Konvoy** does the cluster lifecycle on Cluster API. **Kommander** does fleet and app management on Flux, and it serves the NKP UI. **NIB** (Nutanix Image Builder) builds node OS images.
- One CLI does all jobs: `nkp`. Its sub-tools are `catalog`, `diagnose`, `imagebuilder`, `kommander`, `konvoy`, `konvoybundlepusher`, `mindthegap`. [live 2.19.0]
- The CLI version must be the same as the NKP version that you install or upgrade to.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
```

## Layers

| Layer | Runs where | Main parts |
|---|---|---|
| Operator host (bastion) | outside the clusters | `nkp` CLI, Docker or Podman, kind bootstrap cluster, NIB container, air-gap bundle, site env file |
| Infrastructure | outside | Prism Central + AHV, Foundation Central (Metal), vSphere, AWS, Azure, GCP, pre-provisioned hosts (SSH) |
| Lifecycle (Konvoy) | management cluster | CAPI core, kubeadm bootstrap and control plane, ClusterClass + NKPCluster, CAREN, infra providers, CAAPH |
| Fleet (Kommander) | management cluster | `kommander-cm`, `kommander-ui`, `kommander-appmanagement`, Flux (`kommander-flux`), git-operator, KubeFed |
| Cluster addons (from CAREN) | every cluster | CNI, CSI, CCM, MetalLB, kube-vip, NFD, cluster autoscaler, konnector-agent, COSI, snapshot controller |
| Platform apps (from Kommander) | every cluster, per workspace | Traefik, cert-manager, Gatekeeper, Dex, kube-oidc-proxy, Traefik Forward Auth, Reloader, External Secrets, Pro and Ultimate apps |

## Cluster types

- **Bootstrap cluster**: a temporary kind cluster on the operator host. It creates the first cluster. Then you delete it.
- **Management cluster**: self-managed after the pivot. It holds the CAPI objects for itself and for its workload clusters. Its NKPCluster is in namespace `kommander`. [live 2.19.0]
- **Workload cluster**: managed (NKP created it) or attached (another tool created it). Its NKPCluster is in a workspace namespace, for example `kommander-default-workspace`. [pdf p.489, p.733]

## Key relationships

- `nkp` → kind bootstrap → CAPI + provider + CAREN → infrastructure → pivot (`nkp move capi-resources`) → self-managed management cluster.
- **NKPCluster** (`clusters.nkp.nutanix.com/v1alpha1`) owns the CAPI `Cluster` and the `KommanderCluster`. [live 2.19.0]
- **Rule: edit the NKPCluster. Never edit the CAPI `Cluster`.** A webhook rejects a direct edit of `Cluster.spec.topology` with "CAPI Cluster topology spec is managed by NKPCluster". [pdf p.1048] For the edit steps, use skill `nkp-cluster-lifecycle`.
- ClusterClass names follow `nkp-<infra>-v<nkp-version>`, for example `nkp-nutanix-v2.19.0`. Each class has two variables: `clusterConfig` and `workerConfig` (the CAREN variable surface). [live 2.19.0]
- The guide names Nutanix AHV and EKS as ClusterClass providers. [pdf p.1019] Its non-ClusterClass upgrade chapter lists AWS, Azure, GCP, vSphere, and pre-provisioned. [pdf p.1025] But the live management cluster also has the classes `nkp-aws-v2.19.0` and `nkp-host-agent-v2.19.0`. [live 2.19.0]
- UNKNOWN (P-06): which providers make ClusterClass clusters in 2.19. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters -A -o custom-columns=NAME:.metadata.name,CLASS:.spec.topology.classRef.name`.
- CAREN installs the addons through CAAPH `HelmChartProxy` objects. The addon charts come from an in-cluster OCI registry in `caren-system`. [live 2.19.0]
- App delivery: `AppDeployment` (workspace namespace) → `ClusterApp` (platform app, cluster-scoped) or `App` (catalog app) → Flux `Kustomization` → `HelmRelease` → target cluster. [live 2.19.0]
- On AHV, **MetalLB** gives service `LoadBalancer` IPs. The Nutanix CCM gives node metadata only. kube-vip holds only the control-plane VIP. [live 2.19.0]
- Ingress: Traefik service `kommander/kommander-traefik` gets the first MetalLB IP. [live 2.19.0]
- Identity: external IdP → Dex → Traefik Forward Auth (UI) and kube-oidc-proxy (kubectl).

## License tiers

Nutanix licenses NKP by core. You cannot go to a lower tier after registration. [pdf p.26] To apply or change a license, use skill `nkp-identity-security`.

| Tier | Scope |
|---|---|
| Starter | Nutanix AHV only, one provider. The guide supports only the Nutanix Rocky Linux image [pdf p.715], but Ubuntu 24.04 works on Starter [live 2.19.0]. No monitoring apps and no logging apps. [pdf p.26-28] |
| Pro | One infrastructure provider, many clusters of that provider. Adds observability, logging, Harbor, Velero, Istio, GPU operators, Headlamp. [pdf p.295-297] |
| Ultimate | Many providers, attached external clusters, EKS and AKS lifecycle, Projects, multi-tenant logging, Thanos, Karma, central Grafana, OpenCost, NKP Insights. [pdf p.295-297] |

- The default key is Starter on AHV and Pro on other infrastructure. [pdf p.28]
- The ClusterApp annotation `apps.kommander.d2iq.io/licensing` gives the tier of each app. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps -o custom-columns='NAME:.metadata.name,TIER:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing'
```

## Find versions without the release notes

One app can have three different versions: the catalog version, the chart version, and the image version. The image tag is the upstream version. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmreleases -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmchartproxies -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u
```

- `clusterapps`: catalog versions. `appdeployments`: the apps that each workspace enables.
- `helmreleases`: the status text has the chart version. `helmchartproxies`: the CAREN addon charts.
- The pod image list: the upstream versions.

## Namespaces and components

The namespace table, the component tables, and the API groups are in [references/components.md](references/components.md).
