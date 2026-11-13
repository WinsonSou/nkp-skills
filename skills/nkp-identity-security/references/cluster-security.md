# Cluster security: Pod Security, encryption at rest, node users, FIPS, CIS

Use this file from skill `nkp-identity-security`. The first three items are `clusterConfig` variables of the ClusterClass (`nkp-<infra>-v2.19.0`). You change them in the NKPCluster with skill `nkp-cluster-lifecycle`, step 3 (the "Cluster field" block, its dry run, the plan, the watch). This file gives the field, the value, and the effect.

Read the current values first:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o json | jq -c '.spec.capiCluster.topology | {version, vars: [.variables[] | select(.name=="clusterConfig") | .value | {encryptionAtRest, podSecurityAdmission, users: [.users[]? | {name, sudo, keys: (.sshAuthorizedKeys | length), hashedPassword: (has("hashedPassword"))}]}]}'
```

The block prints no password hash. It shows only if one is set.

## C1. Pod Security Admission (`podSecurityAdmission`)

Facts [live 2.19.0]:
- Fields: `enforce`, `audit`, `warn` (each a level; default `privileged`), and `exemptions` with `namespaces` (default `[kube-system]`), `runtimeClassNames`, `usernames` (each max 64 items).
- Not set (the default): the API server has no Pod Security configuration. Then only namespace labels act.
- The schema has no list of levels. The API accepts a wrong word such as `strict`. Use only `privileged`, `baseline`, or `restricted`.
- NKP labels `kommander`, `metallb-system`, `node-feature-discovery`, `ntnx-system` with `pod-security.kubernetes.io/enforce=privileged`. These keep working under a cluster default. `kube-system` is in the default exemptions.
- On the 2.19.0 management cluster, a `baseline` label on any other namespace gives no warning. A `restricted` label gives warnings in 11 NKP namespaces (CAPI providers, `caren-system`, `kommander-flux`, `git-operator-system`, `kube-federation-system`, `container-object-storage-system`, workspace namespaces).

So: `enforce: baseline` is safe for the NKP namespaces. Use `restricted` only for `warn` and `audit`, not for `enforce`.

1. Test the level on the namespaces first. A server dry run of a namespace label shows the pods that the level rejects:

```bash
# READ-ONLY  (server dry runs of a namespace label: change nothing)
source ~/nkp-<cluster>.env 2>/dev/null
level=''
: "${level:?}"
for ns in $(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns -o json | jq -r '.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | .metadata.name'); do [ "$ns" = kube-system ] && continue; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" label --dry-run=server --overwrite ns "$ns" pod-security.kubernetes.io/enforce="$level" 2>&1 | grep -i '^warning' | sed "s|^|$ns: |"; done
```

No output: no running pod breaks. Each line names a namespace that needs a `privileged` label or an exemption.

2. Patch with skill `nkp-cluster-lifecycle`, step 3, "Cluster field": `field='podSecurityAdmission'`, `value='{"enforce":"baseline","warn":"restricted","audit":"restricted"}'`. Add `exemptions` only when step 1 shows namespaces. Then the value must have the full list, with `kube-system`: `"exemptions":{"namespaces":["kube-system","<ns>"]}`. The dry run adds the default exemption when you leave it out. [live 2.19.0]
3. Effect for the plan: the API server admission file changes, so the control-plane nodes are replaced, one by one.

- UNKNOWN (P-44): whether a `podSecurityAdmission` change replaces only the control-plane nodes or all nodes. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"` 10 minutes after the change (a new AGE means a new machine).

Done when: step 3d of skill `nkp-cluster-lifecycle` passes. Then a test pod in a new namespace shows the warnings of the level.

A label on one namespace (`kubectl label ns <ns> pod-security.kubernetes.io/enforce=<level>`, CHANGES) is plain Kubernetes. It is faster and replaces no node. Do not change the labels of the NKP namespaces above.

## C2. Encryption at rest (`encryptionAtRest`)

Facts [live 2.19.0]:
- The API server encrypts Secrets and ConfigMaps in etcd. Field: `providers`, a list with one item: `{"aescbc":{}}` (the schema default) or `{"secretbox":{}}`.
- The live management cluster has `secretbox`. The key file is `/etc/kubernetes/pki/encryptionconfig.yaml` on each control-plane node, from the Secret `<cluster>-encryption-config` in the workspace namespace. It holds the key. Never print it.
- Check that it is on:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get pods -l component=kube-apiserver -o jsonpath='{range .items[*]}{.metadata.name}: {range .spec.containers[0].command[*]}{@}{" "}{end}{"\n"}{end}' | grep -o -- '--encryption-provider-config=[^ ]*'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get secret "$CLUSTER_NAME-encryption-config"
```

Rule: set the provider at create time and do not change it later. A change of the provider on a running cluster is not in the skills. The API accepts it [live 2.19.0], but the data in etcd stays encrypted with the old provider.

- UNKNOWN (P-45): whether the encryption config that CAREN writes keeps the old provider (so the API server can still read old data) after a provider change. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get secret "$CLUSTER_NAME-encryption-config" -o json | jq -r '.data | keys[]'` (key names only), then ask Nutanix.

To set it at create time: the create flags have no encryption flag. [live 2.19.0] It is on by default. For another provider, edit `encryptionAtRest` in the dry-run YAML of the create (skill `nkp-install`).

## C3. Node OS users and SSH keys (`users`)

Facts [live 2.19.0]:
- A list (max 32) of users that cloud-init makes on each node: `name` (required), `sshAuthorizedKeys` (list, max 100), `sudo` (a sudoers line), `hashedPassword` (crypt(5) form).
- NKP makes the user `konvoy` with `sudo: "ALL=(ALL) NOPASSWD:ALL"` and the key from `--ssh-public-key-file`. [live 2.19.0] `--ssh-username` changes the name. [live 2.19.0]
- The list goes to the control-plane and the worker templates. So a change replaces all nodes of the cluster. Say this in the plan.

Change (for example a new SSH key, or a second admin):
1. Read the list (the first block of this file). `add` replaces the whole list. Keep `konvoy`, or the user loses SSH access. If a user shows `hashedPassword: true`, stop: the block below would print the hash. That case is not in the skills.
2. Ask the user for the new public key file. Make the value with `jq`, so that the key text is quoted correctly:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
newkey=''
: "${newkey:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o json | jq -c --rawfile k "$newkey" '[.spec.capiCluster.topology.variables[] | select(.name=="clusterConfig") | .value.users[]] | map(if .name == "konvoy" then .sshAuthorizedKeys += [($k | rtrimstr("\n"))] else . end)'
```

3. Use the output as `value`, with `field='users'`, in skill `nkp-cluster-lifecycle`, step 3, "Cluster field".
- A `hashedPassword` is a secret, and the `jq` value and the dry-run diff would show it. Setting a node password is not in the skills. Use SSH keys.
- Done when: step 3d passes, and the user can log in to a new node with the new key (USER-TERMINAL, the node host).

## C4. FIPS 140-3

- FIPS mode is set only at create time. You cannot turn it on or off later. Make a new cluster. [pdf p.988] It needs Pro or Ultimate. [pdf p.28]
- The OS image must be a FIPS image: RHEL (the guide also names CentOS). [pdf p.988] The Nutanix pre-built images (Rocky, Ubuntu) are not FIPS. [pdf p.55-56] Build a FIPS image with NIB `--fips` (skill `nkp-airgap`, file `os-images.md`).
- Nutanix AHV: `nkp create cluster nutanix --fips` ("The OS images used by the cluster must be prepared with FIPS mode enabled"). [live 2.19.0] Add the flag as a line in the create script of skill `nkp-install`.
- AWS, vSphere: the guide uses `--kubernetes-version=v<k8s>+fips.0`, `--etcd-version=<etcd>+fips.0`, `--kubernetes-image-repository=docker.io/mesosphere`, `--etcd-image-repository=docker.io/mesosphere` (AWS also `--ami`). [pdf p.988-989] Pre-provisioned: a Secret `<cluster>-fips-overrides` from `fips.yaml` on the bootstrap cluster (skill `nkp-install`, pre-provisioned file). [pdf p.989]
- Air-gapped: the bundle has FIPS parts: `kubernetes-images-1.36.2-d2iq.1-fips.tar`, `containerd-*_fips.tar.gz` for RHEL and Oracle Linux, `mesosphere/kube-proxy:v1.36.2_fips.0`, `mesosphere/kfips:v0.6.2`. [live 2.19.0]
- Is a cluster FIPS? The Kubernetes version has `+fips.0` (skill `nkp-upgrade`). The first block of this file prints `version`.

Validate with `nkp check cluster fips`. It compares file signatures on the nodes with the signature files in the `nkp` binary. [pdf p.989] Flags: `--kubeconfig`, `--namespace` (default `default`), `--signature-file`, `--signature-configmap`, `--timeout` (default 10m). It stores the result in a ConfigMap (`--output-configmap`, default `check-cluster-fips-output`, deprecated). [live 2.19.0]

```bash
# CHANGES  (runs the FIPS check on the cluster; it makes check objects and a result ConfigMap in namespace default)
source ~/nkp-<cluster>.env 2>/dev/null
nkp check cluster fips --kubeconfig "$CLUSTER_KUBECONFIG"
```

- UNKNOWN (P-46): the objects that `nkp check cluster fips` makes on the cluster, its output, and its exit code. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n default get pods,jobs,configmaps` after the check.

## C5. CIS

- The Nutanix pre-built images (Rocky Linux 9.8, Ubuntu 24.04): the OS is CIS Level 1. The NKP and Kubernetes parts follow CIS Level 2. [pdf p.55] Custom images: CIS hardening is not supported. [pdf p.56]
- The 2.19.0 API server runs with: `--profiling=false`, `--service-account-lookup=true`, admission plugins `DenyServiceExternalIPs,EventRateLimit,NodeRestriction`, an audit log at `/var/log/audit/kube-apiserver-audit.log` (30 days, 90 files, 100 MB), six ECDHE TLS cipher suites, and the encryption config (C2). [live 2.19.0]
- The bundle has the image `aquasec/kube-bench:v0.14.0`. [live 2.19.0] The guide has no kube-bench steps. A kube-bench run is not in the skills.
- More hardening by an edit of the ClusterClass templates is not in the skills. A field note does it [field], but the next upgrade replaces the class.
