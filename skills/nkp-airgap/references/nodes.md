# Check the registry setup on the nodes

Use this file from skill `nkp-airgap`, step 5, and to check that the site mirror has an image (last section).

CAREN writes the registry files on each node at bootstrap (`preKubeadmCommands`). [live 2.19.0] So a registry change reaches only new machines. To change the mirror, the registry, or the registry CA of a running cluster, use skill `nkp-cluster-lifecycle`, file `variables.md`, V8. It owns this change and says which change rolls the nodes.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters "$CLUSTER_NAME" -o jsonpath='{..globalImageRegistryMirror.url}{"\n"}{..imageRegistries[*].url}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplane -l cluster.x-k8s.io/cluster-name="$CLUSTER_NAME" -o jsonpath='{range .items[*].spec.kubeadmConfigSpec.files[*]}{.path}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'ImagePullBackOff|ErrImagePull' || echo "no image pull errors"
```

- Line 1 shows the site mirror URL. An empty line means no site mirror.
- The file list has `/etc/containerd/certs.d/_default/hosts.toml` (the mirror for all registries), `/etc/containerd/certs.d/<registry-host>/ca.crt`, `/etc/caren/containerd/patches/registry-config.toml`, and the kubelet credential provider files in `/etc/kubernetes/`. [live 2.19.0] Older field notes name `/etc/containerd/konvoy-conf.d/konvoy-mirror.toml`. 2.19.0 does not use it.

On one node: the user logs in with SSH as user `konvoy` with the private key of `SSH_PUBKEY_FILE`. [live 2.19.0] Give this block to the user. Do not run it on the operator host:

```bash
# USER-TERMINAL  (on a node; the user runs it over SSH)
sudo cat /etc/containerd/certs.d/_default/hosts.toml
sudo ls /etc/containerd/certs.d/
sudo cat /etc/caren/containerd/patches/registry-config.toml
sudo journalctl -u containerd --since "30 min ago" | grep -i -E 'pull|x509|401|403' | tail -20
```

- `hosts.toml` has `[host."https://<registry-host>/v2/<path>"]`, `capabilities = ["pull", "resolve"]`, the `ca` path, and `override_path = true`. `override_path` is needed when the mirror URL has a path. [live 2.19.0]
- Never print `/etc/kubernetes/static-image-credentials.json`. It holds the registry credentials.

Done when: the URL is correct, `hosts.toml` points to the mirror, and there are no image pull errors.

## Check that the site mirror has an image

Use this before you put an image in a manifest on an air-gapped site (for example a smoke test). Do not guess an image path, and never pull from the internet. The mirror project is the path part of `REGISTRY_URL`. An image `docker.io/<path>:<tag>` is at `<project>/<path>` in the mirror. [live 2.19.0] Example: `docker.io/library/nginx` → 404, but `docker.io/nginxinc/nginx-unprivileged` (tag `1.29.5-alpine`) and `docker.io/library/busybox` (tag `1`) are there, from the NKP bundle. [live 2.19.0] So use an image that a pushed bundle has. In a manifest, write the image as `docker.io/<path>:<tag>`: the node mirror config sends `docker.io` pulls to the mirror. [live 2.19.0]

UNKNOWN (A-30): the mirror path of an image from a registry other than `docker.io` (for example `registry.k8s.io/pause`): with or without the registry host. Find out with: `repo='registry.k8s.io/pause'`, then `repo='pause'`, in the first block below (the `http=200` line gives the path).

Set `repo` to the path below `docker.io/` (for example `library/busybox`), without the tag. The block reads the pull account (`REGISTRY_MIRROR_USERNAME`, `REGISTRY_MIRROR_PASSWORD`) from `~/nkp-site.env`. curl reads the account from a here-string (`<<<`), so the password does not show in the process list.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
repo=''; : "${repo:?set repo, for example library/busybox}"
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"; p="${h#"$host"}"; p="${p#/}"; p="${p:+$p/}"
url="https://$host/v2/$p$repo/tags/list"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file /dev/stdin -w '\nhttp=%{http_code}\n' "$url" <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD"
```

- `http=200` and `{"name":...,"tags":[...]}`: the mirror has the image. Use one of the listed tags. [live 2.19.0]
- `http=404`: the mirror does not have it. Choose an image from a pushed bundle (SKILL.md step 2 lists it), or add the image with `nkp create bundle` (references/catalogs.md).
- `http=401`: wrong pull account. `x509` error: wrong `REGISTRY_CA_FILE`.
- Use the plain `/v2/` path. The Harbor UI API (`/api/v2.0/...`) needs `%252F` in a repository name. [live 2.19.0]

Cross-check with the images that the cluster already runs:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{range .spec.initContainers[*]}{.image}{"\n"}{end}{end}' | sort -u
```

UNKNOWN (A-31): if the site mirror lets the pull account list all repositories with `GET /v2/_catalog`. Find out with: `url="https://$host/v2/_catalog"` in place of the `url=` line of the first block (`http=401` or `403` means that this account cannot list; then use `tags/list`).
