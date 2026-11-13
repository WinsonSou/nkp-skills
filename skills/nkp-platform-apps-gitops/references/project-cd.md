# Project CD (GitOps sources) and Sealed Secrets

Use this file from skill `nkp-platform-apps-gitops`. Project CD deploys your own manifests from a Git repository to all clusters of a project, with Flux. It needs Ultimate (Projects and "Continuous Deployment (FluxCD)"). [pdf p.27] To make the project and its roles, use skill `nkp-identity-security`. The project secret for Git is in P3 item 1. For the cluster objects in Git (NKPCluster), use skill `nkp-upgrade` (its file `gitops.md`).

| File | Site variables |
|---|---|
| `~/nkp-<cluster>.env` | `PROJECT_NS` |

`PROJECT_NS` is the namespace of the project (P1). Append it to the cluster env file with rule 4 after P1 shows it.

## P1. Find the project namespace

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get projects -o custom-columns='NAME:.metadata.name,NAMESPACE:.status.namespaceRef.name,CLUSTERS:.spec.placement'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get gitopsrepositories -A
```

- The project namespace is the project name (first 57 characters) plus 5 random characters, unless the user set it. [pdf p.369] The namespace is on the management cluster and on every cluster of the project. [pdf p.369]
- No project: stop. The user makes it (skill `nkp-identity-security`).

## P2. How project CD works [pdf p.387-396][live 2.19.0]

- A **GitOps source** is a `GitopsRepository` (`dispatch.d2iq.io`) in the project namespace on the management cluster. The API denies it in any other namespace ("GitopsRepository can only be created in project namespace"). [live 2.19.0]
- Kommander puts a Flux `GitRepository` and a `Kustomization` with the same name in the project namespace of **each** project cluster. [pdf p.393, p.395]
- NKP makes a service account with the project name. It has rights only in the project namespace. The root Kustomization and all its HelmReleases and Kustomizations use it. [pdf p.388]
- So the repository can hold only namespaced objects in the project namespace. No `Namespace`, `ClusterRole`, `ClusterRoleBinding`, no HelmRelease or Kustomization that targets another namespace. [pdf p.396]
- Each HelmRelease and Kustomization in the repository sets `spec.serviceAccountName` to the project name. Without it, Gatekeeper denies it (skill `nkp-identity-security`, file `gatekeeper.md`, G1).
- A deleted GitOps source removes every object that it applied. [pdf p.396]

## P3. Make a GitOps source

1. **Git credentials** (not for a public repository). The user makes a project secret in the UI (project, Secrets tab). It goes to every project cluster. [pdf p.392, p.402] The keys [pdf p.394]:

| Auth | Keys |
|---|---|
| HTTPS | `username`, `password` (a token goes in `password`; GitLab and others need the username too) |
| HTTPS, self-signed CA | `username`, `password`, `caFile` |
| SSH | `identity`, `identity.pub`, `known_hosts` |

   An SSH URL has the form `ssh://user@host:port/org/repository`. The SCP form (`git@host:org/repo`) does not work. [pdf p.394] The agent never sees the secret values (rule 5).

2. **The source.** The guide uses the UI: project, Continuous Deployment (CD) tab, Create GitOps Source: ID (name, unique, cannot change), repository URL, Git ref type and branch (empty = the default branch), path (for example `./kustomize`), and the secret. [pdf p.392] Use the UI when the user can.

   For the CLI, make the object from the `v1alpha2` schema [live 2.19.0]. Ask the user for each value.

UNKNOWN (P-32): whether a `GitopsRepository` from `kubectl` (`v1alpha2`) works like one from the UI (the storage version is `v1alpha3`). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get gitopsrepositories -A -o yaml | grep -n -E '^ *(apiVersion|cloneUrl|url|path):'` on a source that the UI made.

```bash
# CHANGES  (writes the GitOps source file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; url=''; branch=''; gpath=''; secret=''
: "${name:?}" "${url:?}" "${branch:?}" "${gpath:?}" "${PROJECT_NS:?}"
f="$HOME/$CLUSTER_NAME-gitops-$name.yaml"
printf 'apiVersion: dispatch.d2iq.io/v1alpha2\nkind: GitopsRepository\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  cloneUrl: %s\n  template:\n    path: %s\n    ref:\n      branch: %s\n' "$name" "$PROJECT_NS" "$url" "$gpath" "$branch" > "$f"
[ -n "$secret" ] && printf '  secret: %s\n' "$secret" >> "$f"; cat "$f"
```

   `secret` is the name of the project secret from item 1. Leave it empty for a public repository.

3. Preview (server dry run). The webhooks that match have `sideEffects` `None` or `NoneOnDryRun`. [live 2.19.0]

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f "$HOME/$CLUSTER_NAME-gitops-$name.yaml"
```

   An error: stop and give the message to the user. Do not change the API version without the user.

4. Show the plan (the project, the repository, the path; Flux applies the manifests to every project cluster). Stop for "yes". Then apply:

```bash
# CHANGES  (creates the GitOps source; Flux deploys the repository to all project clusters)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f "$HOME/$CLUSTER_NAME-gitops-$name.yaml"
```

## P4. Check a GitOps source

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}" "${PROJECT_NS:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$PROJECT_NS" describe gitopsrepositories.dispatch.d2iq.io "$name" | sed -n '/^Events:/,$p'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$PROJECT_NS" get gitrepositories,kustomizations,helmreleases
```

- Management cluster: the event `ManifestSyncSuccess` ("manifests synced to bootstrap repo"). [pdf p.395]
- Each project cluster: the `GitRepository` and the `Kustomization` with the source name show READY `True`. [pdf p.393, p.395] Run the second line with the `CLUSTER_KUBECONFIG` of each project cluster.
- Errors are in the status of the `GitopsRepository` (management cluster) or of the `GitRepository` and `Kustomization` (project cluster). [pdf p.395] To read a message: skill `nkp-troubleshooting`, its file `flux.md`, F2.

| Message | Cause | Fix |
|---|---|---|
| `authentication required`, `401`, `403` | the secret keys (P3 item 1) | the user fixes the project secret |
| `x509` | a self-signed Git server | add `caFile` to the secret |
| `ssh: handshake failed`, `knownhosts` | the SSH keys or `known_hosts` | the user fixes the secret |
| `forbidden`, `cannot create resource ... at the cluster scope` | a cluster-scoped object in Git (P2) | the user removes it from Git |
| `admission webhook "validation.gatekeeper.sh" denied`, `must-have-sa` | a HelmRelease or Kustomization without `serviceAccountName` | the user adds it in Git (P2) |
| a Kustomization `dependency ... is not ready` | another Kustomization of the repository | P4 on that one |

- **Suspend and resume**: in the UI (project, CD tab, the three dots of the source, Suspend; later Resume). Then Flux stops the sync, and you can fix a live problem with `kubectl`. [pdf p.396] The CLI way is not in the skills.
- The controller log is `kommander/kommander-cm` on the management cluster. [pdf p.396]
- The Flux controllers in the project namespace are needed. Do not remove them. [pdf p.396]

## P5. Sealed Secrets (secrets in the Git repository)

Sealed Secrets lets a secret go into Git in encrypted form. A controller on the cluster decrypts it into a normal Secret. [pdf p.389] NKP does not ship it: the guide uses upstream v0.18.1. [pdf p.389] Another way for secrets is External Secrets (skill `nkp-identity-security`).

**Files.** Air-gapped site: the manifest, the controller image, and the `kubeseal` tarball are in skill `nkp-airgap`, its file `prestage.md` (items P2 and P3, with the SHA-256 checks). Do P3 there first (the image goes into the registry). Connected site: the same files from the URLs in that skill (its file `download-urls.txt`). Use only v0.18.1, so that the CLI and the controller match.

1. **Install `kubeseal` on the operator host.** The download is a tarball, not the binary. [field] List it first:

```bash
# READ-ONLY
tgz=''; : "${tgz:?}"
tar -tzf "$tgz"
```

   `tgz` is the path of `kubeseal-0.18.1-linux-amd64.tar.gz` after the SHA-256 check. If the list has `kubeseal`, show the plan, stop for "yes":

```bash
# CHANGES  (extracts kubeseal and installs it to /usr/local/bin on the operator host)
tgz=''; : "${tgz:?}"
d=$(mktemp -d) && tar -xzf "$tgz" -C "$d" kubeseal && sudo install -m 755 "$d/kubeseal" /usr/local/bin/kubeseal && rm -r "$d"
kubeseal --version
```

2. **Install the controller** on each cluster that gets sealed secrets (each project cluster). It runs in `kube-system`. [pdf p.389] Do the asset check of skill `nkp-airgap` (its file `prestage.md`, "Use an asset") first. Set `dir` to the absolute path of the `nkp-airgap` skill folder. Show the plan (the cluster; RBAC, a CRD, and a Deployment in `kube-system`), stop for "yes":

```bash
# CHANGES  (installs the Sealed Secrets controller v0.18.1 in kube-system)
source ~/nkp-<cluster>.env 2>/dev/null
dir=''; : "${dir:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$dir/assets/sealed-secrets-controller-v0.18.1.yaml"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system rollout status deploy/sealed-secrets-controller --timeout 5m
```

   Air-gapped: the image `docker.io/bitnami/sealed-secrets-controller:v0.18.1` comes through the registry mirror. An `ImagePullBackOff`: skill `nkp-airgap`.

3. **Get the public certificate** (it is not a secret; the user can commit it). [pdf p.389] The CHANGES block writes a local file:

```bash
# CHANGES  (writes the public sealing certificate to a local file)
source ~/nkp-<cluster>.env 2>/dev/null
KUBECONFIG="$CLUSTER_KUBECONFIG" kubeseal --fetch-cert > "$HOME/$CLUSTER_NAME-sealed-secrets.pem"
```

   Each controller makes its own key. A sealed secret works only on the cluster whose certificate sealed it. [field] For a project with several clusters, seal once for each cluster, or give all clusters the same key (backup and restore, item 6).

4. **Seal a secret.** The value is a secret, so the user runs this in their own terminal. The user first writes the value into a file (mode 600). The block reads the certificate from `$HOME` (item 3): the user runs it as the same user on the operator host, or copies the `.pem` file to their `$HOME` first. The block prints only the sealed (encrypted) YAML into `secrets.yaml`. [pdf p.390]

```bash
# USER-TERMINAL  (the user runs it; it reads a secret value from a file)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; key=''; valuefile=''; : "${name:?}" "${key:?}" "${valuefile:?}" "${PROJECT_NS:?}"
echo '---' >> secrets.yaml
kubectl create secret -n "$PROJECT_NS" generic "$name" --dry-run=client -o yaml --from-file="$key=$valuefile" | kubeseal --format yaml --cert "$HOME/$CLUSTER_NAME-sealed-secrets.pem" >> secrets.yaml
```

   Then the user removes the `creationTimestamp` lines from the new entry, deletes the value file, and commits `secrets.yaml` to the Git repository of the GitOps source. Flux applies it. [pdf p.390]

5. **Check** (no secret data is shown):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}" "${PROJECT_NS:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$PROJECT_NS" get sealedsecrets "$name"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$PROJECT_NS" get secret "$name"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system logs -l name=sealed-secrets-controller --tail 30
```

   Done when: the Secret exists. The SealedSecret exists, but no Secret: read the controller log (a wrong certificate is the usual cause). [pdf p.390]

6. **Keys.** The controller makes a new key every 30 days. Get the certificate again after that (item 3) and commit it. Old sealed secrets still work. [pdf p.390-391] `--key-renew-period=0` in the controller command turns the renewal off. [pdf p.391] Back up the keys: if the cluster is lost, the sealed secrets in Git cannot be decrypted. The backup file holds the private keys, so the user runs it and keeps the file in a safe place (for example a vault):

```bash
# USER-TERMINAL  (the user runs it; it writes the private sealing keys to a file)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get secret -o name | grep sealed-secrets-key | xargs kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get -o yaml > sealing-key.yaml)
```

   To restore: the user applies the key files before the controller starts. If it runs, the user deletes its pod (`-l name=sealed-secrets-controller`) after the apply. [pdf p.391]

7. **Remove a sealed secret**: the user removes it from `secrets.yaml` in Git. Then delete the SealedSecret and the Secret (CHANGES, plan and "yes"): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$PROJECT_NS" delete sealedsecret <name>`, then `delete secret <name>`. [pdf p.390]
