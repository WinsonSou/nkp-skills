# Controller logs and the bootstrap (kind) cluster

Use this file from skill `nkp-troubleshooting`.

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `BOOTSTRAP_KUBECONFIG` |

`BOOTSTRAP_KUBECONFIG` is the kubeconfig file of the kind bootstrap cluster on the operator host. Append it with rule 4 only after the user or the check in B2 confirms the path.

## Controllers [live 2.19.0]

All run on the management cluster. Before the pivot, the CAPI, provider, and CAREN controllers run on the bootstrap cluster (B3).

| Layer | Namespace | Deployment | Reads or does |
|---|---|---|---|
| CAPI core | `capi-system` | `capi-controller-manager` | Cluster, Machine, MachineDeployment, MachineSet, MHC, topology |
| kubeadm control plane | `capi-kubeadm-control-plane-system` | `capi-kubeadm-control-plane-controller-manager` | KubeadmControlPlane, etcd members, certificates |
| kubeadm bootstrap | `capi-kubeadm-bootstrap-system` | `capi-kubeadm-bootstrap-controller-manager` | cloud-init data of each machine |
| CAPX (AHV) | `capx-system` | `capx-controller-manager` | NutanixCluster, NutanixMachine, the VMs in Prism Central |
| CAREN | `caren-system` | `cluster-api-runtime-extensions-nutanix` | ClusterClass variables, topology patches, addon setup, preflight |
| CAAPH | `caaph-system` | `caaph-controller-manager` | HelmChartProxy, HelmReleaseProxy (cluster addons) |
| CAREN chart registry | `caren-system` | `helm-repository` | serves the addon charts (OCI) |
| NKPCluster | `kommander` | `nkp-cluster-controller-manager` | NKPCluster → CAPI Cluster and KommanderCluster |
| Kommander | `kommander` | `kommander-cm`, `kommander-appmanagement`, `kommander-operator` | workspaces and clusters, apps, the Kommander install |
| Flux | `kommander-flux` | `source-controller`, `kustomize-controller`, `helm-controller` | sources, Kustomizations, HelmReleases |
| Pre-provisioned | `cappp-system` | `cappp-controller-manager` | pre-provisioned hosts |
| Metal | `cluster-api-provider-host-agent-system` | `capi-host-agent-controller-manager` | Metal hosts |
| Other providers | `capa-system`, `capz-system`, `capg-system`, `capv-system` | `capa-`, `capz-`, `capg-`, `capv-controller-manager` | AWS, Azure, GCP, vSphere |

## L1. Controller health and log

Set `ns` and `deploy` from the table. Set `filter` to the object name (for example the machine name), or leave it empty for the errors only.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ns=''; deploy=''; filter=''; where='mgmt'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; bootstrap) kc="$BOOTSTRAP_KUBECONFIG";; *) kc='';; esac
: "${ns:?}" "${deploy:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get deploy "$deploy" -o wide
kubectl --kubeconfig "$kc" -n "$ns" get pods -o wide
kubectl --kubeconfig "$kc" -n "$ns" logs "deploy/$deploy" --all-containers --since 2h --timestamps | grep -i -E "${filter:-error|fail|denied|timeout}" | tail -40
```

- Pods not `Running`, or restarts that go up: run `kubectl describe pod` on the pod first. A controller that is down stops every object it owns (also the finalizers).
- `--since 2h` keeps the output small. For an old problem, ask the user for the time and change it.
- The pod restarted: add `--previous` to the `logs` command to read the log before the restart.
- Before the pivot, set `where` to `bootstrap` (B3).

## L2. Known log messages

| Controller | Log text | Owner of the fix |
|---|---|---|
| CAPX | `401`, `Authentication required`, `invalid credentials` | Prism Central credentials: skill `nkp-install`; the PC admin |
| CAPX | image `not found`, `failed to find image` | the VM image: skill `nkp-install` or skill `nkp-upgrade` |
| CAPX | subnet or IP pool errors, `no free IP` | Prism Central admin (IPAM pool) |
| CAPX | `x509` to Prism Central | Prism Central CA (`PC_CA_FILE`): skill `nkp-install` |
| CAREN | a variable or patch error that names a `clusterConfig` or `workerConfig` field | skill `nkp-cluster-lifecycle` (its file `variables.md`) |
| CAAPH | `failed to install`, chart pull error from `helm-repository.caren-system.svc` | the addon owner (SKILL.md step 3); registry: skill `nkp-airgap` |
| kubeadm control plane | `etcd` member or health errors | control-plane nodes: [rollouts.md](rollouts.md), R5. Etcd repair is not in the skills. |
| NKPCluster | webhook `denied` | skill `nkp-cluster-lifecycle` |

These texts are typical, not exact. [field] Always quote the real log line to the user.

## Bootstrap cluster

The bootstrap cluster is a kind cluster on the operator host. `nkp create cluster ... --self-managed` makes it, creates the new cluster from it, moves the CAPI objects (the pivot), and deletes it. [pdf p.22-23] The kind cluster name is `konvoy-capi-bootstrapper`. [live 2.19.0]

### B1. Is it running?

```bash
# READ-ONLY
docker ps -a --filter name=konvoy-capi-bootstrapper --format '{{.Names}} {{.Status}} {{.Image}}'
docker image ls --format '{{.Repository}}:{{.Tag}}' | grep konvoy-bootstrap
```

On Podman, use `podman` in place of `docker`.

- No container and the create failed early: the operator host requirements (CPU, memory, cgroups v2, container engine) are in skill `nkp-install`, step "Check the operator host". On an air-gapped site, the image `mesosphere/konvoy-bootstrap:<version>` must be loaded, or the create needs `--bootstrap-cluster-image` (skill `nkp-install`). [live 2.19.0]
- The container is `Exited`: read the last 100 lines of its log:

```bash
# READ-ONLY
docker logs --tail 100 konvoy-capi-bootstrapper-control-plane
```

The container name follows the kind form `<cluster>-control-plane`. [field]

### B2. Find the bootstrap kubeconfig

UNKNOWN (A-21): the kubeconfig file of the bootstrap cluster during `nkp create cluster --self-managed`. The guide uses `${CLUSTER_NAME}-bootstrap.conf` [pdf p.683]; `nkp create bootstrap --kubeconfig <file>` writes the file that you give [pdf p.667]; a field run found a bootstrap context in `~/.kube/config`. Find out with: `ls -l ./*bootstrap*.conf ~/.kube/config && kubectl config get-contexts`.

```bash
# READ-ONLY
ls -l ./*bootstrap*.conf ~/.kube/config 2>/dev/null
kubectl config get-contexts
```

A context or file with `konvoy-capi-bootstrapper` or `bootstrap` in the name is the bootstrap cluster. Ask the user to confirm the path. Then append `BOOTSTRAP_KUBECONFIG` (rule 4).

### B3. Read the create on the bootstrap cluster

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
: "${BOOTSTRAP_KUBECONFIG:?}"
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get nodes
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get clusters.cluster.x-k8s.io,kubeadmcontrolplanes,machines -A
```

- Pods not `Running` (for example `ImagePullBackOff` on an air-gapped site): the bootstrap image or the registry. Use skill `nkp-airgap`.
- Machines not `Running`: do [rollouts.md](rollouts.md), R1 to R5, with `MGMT_KUBECONFIG` replaced by `BOOTSTRAP_KUBECONFIG` and `-A` in place of `-n "$WORKSPACE_NS"`. For the controller logs, do L1 with `where` set to `bootstrap`.
- The machines are `Running` and the new cluster answers, but the create stops: the pivot or the Kommander install failed. Collect the bundle with [diagnose.md](diagnose.md), section D2, before any cleanup. A bootstrap delete removes the evidence.

### B4. Clean up

Only after the user has the evidence (B3 and the bootstrap bundle). The cleanup command `nkp delete bootstrap` is in skill `nkp-install` ("If the install fails"). Its default `--kind-cluster-name` is `konvoy-capi-bootstrapper`. [live 2.19.0] If B3 listed machines, their VMs exist. A bootstrap delete does not delete them, and then nothing tracks them. [field] Tell the user in the plan. The VM list is in B3 (`machines`). A cluster delete from the bootstrap cluster is not in the skills. Without it, the user deletes the VMs by hand in Prism Central.

Done when: you have the failing object or log line and its owner skill, or the user has the bootstrap bundle.
