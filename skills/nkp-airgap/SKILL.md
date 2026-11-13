---
name: nkp-airgap
description: >
  NKP air-gap and registry: the air-gapped bundle (contents, move, extract, check), registry mode
  (internal mirror, Harbor or site mirror, Docker Hub credentials), nkp push bundle seeding,
  containerd mirrors on nodes, offline catalog bundles, OS package bundles and NIB image builds,
  pre-stage files not in the bundle (Gatekeeper library, Sealed Secrets, Trivy DB), registry ImagePullBackOff or x509.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-02"
  sources: "live 2.19.0, pdf 2.19"
---

# NKP air-gap, bundle, and registry

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

Site variables of this file (rule 4; same use as the rules table):

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `EXTRA_BUNDLE` |
| `~/nkp-site.env` secrets | `REGISTRY_PUSH_USERNAME` `REGISTRY_PUSH_PASSWORD` |

## Which part to use

| Job | Go to |
|---|---|
| Bring the bundle to the site, extract it, check it, install the CLI | Steps 1 and 2 |
| Choose how nodes get images | Step 3 |
| Fill (seed) a registry | Step 4 |
| Check the registry setup on the nodes (`ImagePullBackOff`, `x509`) | Step 5 |
| Check that the site mirror has an image (`tags/list`), before you use it in a manifest | [references/nodes.md](references/nodes.md), last section |
| Offline catalogs (NDK, AI apps, own apps), extra images with `nkp create bundle` | [references/catalogs.md](references/catalogs.md) |
| OS package bundles, custom node images with NIB (Nutanix Image Builder) | [references/os-images.md](references/os-images.md) |
| Files that are not in the bundle (Gatekeeper library, Sealed Secrets, Trivy DB, NDK files, Flow CNI) | [references/prestage.md](references/prestage.md) |

A **connected host** is a machine with internet access outside the air gap. Line 1 of its blocks is `# USER-TERMINAL  (connected host ...)`: give the block to the user to run there, and never run it. On that host, the user makes a `~/nkp-site.env` with only the variables that the block uses, and adds secrets with an editor (rule 5).

For the cluster create flags and for offline Kommander (`nkp install kommander --init --airgapped`), use skill `nkp-install`.

## Step 1: Bring the bundle to the site

The user downloads the air-gapped bundle and the NKP CLI from the Nutanix portal on a connected host. Portal download URLs expire soon. To resume, use a new URL with `curl -C -` or `wget -c`. [pdf p.17-18]

- File name pattern: `nkp-bundle_v<version>_linux_amd64.tar.gz`. The 2.19.0 file is 37.7 GB. [live 2.19.0] The 2.19 guide writes `nkp-air-gapped-bundle_<version>_linux_amd64.tar.gz`. [pdf p.73, p.996]
- The extracted folder is about 37.5 GB. Make sure that the disk has room for the tarball and the folder (about 76 GB). [live 2.19.0]

1. On the connected host, the user runs `sha256sum <tarball> > nkp-bundle.sha256` in the tarball folder.
2. The user moves the tarball and `nkp-bundle.sha256` to the operator host (USB disk or an internal file share). [pdf p.18]
3. Ask the user for the folder that holds the tarball. `BUNDLE_DIR` is that folder plus `/nkp-v<version>` (for 2.19.0: `nkp-v2.19.0` [live 2.19.0]). Append `BUNDLE_DIR` to `~/nkp-site.env` (rule 4). Keep only one bundle tarball in that folder.
4. Check the free space, then check and extract:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
df -h "$(dirname "$BUNDLE_DIR")"
ls -l "$(dirname "$BUNDLE_DIR")"/nkp-bundle_v*_linux_amd64.tar.gz
```

```bash
# CHANGES  (checks the tarball, then extracts about 37 GB into the folder)
source ~/nkp-site.env 2>/dev/null
( cd "$(dirname "$BUNDLE_DIR")" && sha256sum -c nkp-bundle.sha256 && tar -xzf "$(ls nkp-bundle_v*_linux_amd64.tar.gz | tail -1)" )
```

If `sha256sum -c` prints `FAILED`, the copy is damaged. Stop and ask the user to copy the file again. On macOS, use `shasum -a 256` in place of `sha256sum`.

5. Install the CLI and kubectl from the bundle. `sudo -n` fails when sudo needs a password. Then give the user the same `install` line to run.

```bash
# CHANGES  (copies nkp and kubectl from the bundle into /usr/local/bin)
source ~/nkp-site.env 2>/dev/null
sudo -n install -m 0755 "$BUNDLE_DIR/cli/nkp" "$BUNDLE_DIR/kubectl" /usr/local/bin/
```

Done when: `nkp version` shows the `nkp` line with the bundle version. The CLI version must be the same as the NKP version that you install or upgrade to. [pdf p.1018]

## Step 2: Check the bundle

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls -l "$BUNDLE_DIR" "$BUNDLE_DIR/container-images" "$BUNDLE_DIR/image-artifacts" "$BUNDLE_DIR/image-artifacts/images"
"$BUNDLE_DIR/cli/nkp" version
( cd "$BUNDLE_DIR" && sha256sum -c nkp-*-release-amd64.iso.sha256 )
```

Contents. Use the patterns. The 2.19.0 names are from the real bundle. [live 2.19.0]

| Pattern | 2.19.0 name | Use |
|---|---|---|
| `cli/nkp`, `kubectl` | same | the CLI (step 1) |
| `konvoy-bootstrap-image-*.tar` | `konvoy-bootstrap-image-v2.19.0.tar` | kind bootstrap image (skill `nkp-install`) |
| `nkp-image-builder-image-*.tar` | `nkp-image-builder-image-v2.19.0.tar` | NIB container ([references/os-images.md](references/os-images.md)) |
| `nkp-*-release-amd64.iso` + `.sha256` + `.metadata.json` | `nkp-ubuntu-24.04-release-amd64.iso` | host OS ISO (NKP Metal [field]) |
| `container-images/konvoy-image-bundle-*.tar` | `konvoy-image-bundle-v2.19.0.tar` (122 images) | cluster images. Always needed. |
| `container-images/kommander-image-bundle-*.tar` | `kommander-image-bundle-v2.19.0.tar` (273 images) | platform apps, also Insights, Trivy DB, Harbor, `nkp diagnose` collector. Always needed. |
| `container-images/nkp-release-specs-*.tar` | `nkp-release-specs-v2.19.0.tar` | release metadata. Always needed. [pdf p.723] |
| `container-images/kubernetes-os-*.tar` | `kubernetes-os-ubuntu-24.04-nkp-v2.19.0-v1.36.2_linux_amd64.tar` | machine OS image as an OCI artifact. `nkp create cluster metal --kubernetes-image-uri` reads it from the mirror. [live 2.19.0] The AHV push example also pushes it. [pdf p.715] |
| `container-images/*product-catalog*.tar` | `nkp-nutanix-product-catalog-image-bundle-2.19.tar` | NDK catalog. Only for NDK on Nutanix. [pdf p.723, p.946] |
| `container-images/*ai-applications-catalog*.tar` | `nkp-ai-applications-catalog-image-bundle-2.19.tar` | AI catalog apps (skill `nkp-gpu-ai`) |
| `image-artifacts/containerd-*-<os>-x86_64[_fips].tar.gz` | containerd 2.3.1-d2iq.1 for each OS | NIB and pre-provisioned hosts |
| `image-artifacts/images/kubernetes-images-*.tar` | `kubernetes-images-1.36.2-d2iq.1[-fips].tar` | NIB and pre-provisioned hosts |

- The bundle does **not** have the OS distribution packages. Build them with `nkp create package-bundle` ([references/os-images.md](references/os-images.md)). [pdf p.59-60]
- The 2.19.0 bundle has no `nib/`, `kib/`, `application-charts/`, or `application-repositories/` folder. [live 2.19.0] If a guide page names `nib/artifacts`, use `image-artifacts`.
- The guide names the NDK catalog `nutanix-product-catalog-<version>-airgapped.tar`. The 2.19.0 file name is different. [pdf p.723][live 2.19.0] Always use `ls`.

To list the images in one image bundle (the tar has a registry layout [live 2.19.0]):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
tar -tf "$(ls "$BUNDLE_DIR"/container-images/konvoy-image-bundle-*.tar)" | sed -n 's#^docker/registry/v2/repositories/\(.*\)/_manifests/tags/\([^/]*\)/current/link$#\1:\2#p' | sort -u
```

Done when: `ls` shows one file for each "Always needed" row and the bootstrap image, `nkp version` works, and the ISO check prints `<iso name>: OK`. [live 2.19.0]

## Step 3: Choose the registry mode

| Mode | Use it when | How nodes get images |
|---|---|---|
| Internal registry mirror | air-gapped, no site registry | `nkp create cluster ... --bundle` pushes the bundles into a registry inside the new cluster. [pdf p.722-723] |
| Site registry mirror | the site has Harbor, Nexus, Artifactory, or ECR (air-gapped or connected) | Seed it first (step 4A). The create uses `--registry-mirror-url`, `--registry-mirror-cacert`, `--registry-mirror-username`, `--registry-mirror-password`. [pdf p.723] |
| Docker Hub credentials | connected, no mirror | NKP pulls from `docker.io/nutanix` with the Nutanix Docker Hub token: `--nutanix-registry-username`, `--nutanix-registry-password`. [pdf p.675-677] |

- Use one mode only. Never use `--bundle` and `--registry-mirror-*` in one create. [pdf p.725]
- `--registry-url`, `--registry-username`, `--registry-password`, `--registry-cacert` are not a mirror. They give credentials for one upstream registry, for example to get a higher Docker Hub pull limit. [pdf p.723]
- `--airgapped` is a separate flag of `nkp create cluster nutanix` and `nkp install kommander` only. `nkp create cluster preprovisioned` and `metal` do not have it. [live 2.19.0] For another provider, check `nkp create cluster <provider> --help`. It runs the NKP UI and apps in air-gap mode. [pdf p.723] The registry must be reachable from the operator host **and** from every node subnet. [pdf p.713]
- Supported site registries: Harbor later than v2.1.1-5f52168e (OCI support), Nexus, JFrog Artifactory later than 7.11, AWS ECR. [pdf p.991-992] Catalogs need an OCI-compliant registry. [pdf p.357]
- A Nutanix organization can have only two Docker Hub tokens. Air-gapped clusters never pull from Docker Hub. [pdf p.675] To change the token on a connected site: `nkp update cluster nutanix-registry-credentials` with `--cluster-name`, `--namespace`, `--nutanix-registry-username`, `--nutanix-registry-password`, `--kubeconfig`, or `--all-namespaces` for every cluster. [pdf p.677] For the upgrade gate, use skill `nkp-upgrade`.

The create commands are in skill `nkp-install`. Done when: the user agrees to one mode.

## Step 4: Seed a registry

`nkp push bundle` needs a lot of temporary disk space (`df -h "${TMPDIR:-/tmp}"`). For `TMPDIR`, see skill `nkp-install`. [pdf p.694] Set `IMAGE_BUNDLES` (the three "Always needed" bundles) one time. The block stops if a file is missing:

```bash
# CHANGES  (appends IMAGE_BUNDLES to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
b="$BUNDLE_DIR/container-images"; k="$(ls "$b"/konvoy-image-bundle-*.tar)"; m="$(ls "$b"/kommander-image-bundle-*.tar)"; r="$(ls "$b"/nkp-release-specs-*.tar)"; test -f "$k" && test -f "$m" && test -f "$r" && echo "export IMAGE_BUNDLES='$k,$m,$r'" >> ~/nkp-site.env
```

To push one more bundle file (a catalog, `kubernetes-os-*.tar`, a bundle from references/prestage.md), ask the user for the path, append it as `EXTRA_BUNDLE` to `~/nkp-site.env` (rule 4), and use the "extra bundle" block in 4A or 4B. Add the NDK catalog bundle only for NDK, and the AI catalog bundle only for AI apps.

### 4A. Site registry mirror

1. Values: `REGISTRY_URL` (scheme, host, optional port, optional path, for example `https://<host>/<project>` [pdf p.713]) and `REGISTRY_CA_FILE`. The push needs an account that can write: the user adds `REGISTRY_PUSH_USERNAME` and `REGISTRY_PUSH_PASSWORD` with the editor block below (rule 5). The pull account for the nodes is `REGISTRY_MIRROR_USERNAME` and `REGISTRY_MIRROR_PASSWORD` (skill `nkp-install`).
2. Harbor: the first path part of `REGISTRY_URL` is the Harbor project. The Harbor admin makes it before the push. [field]
```bash
# USER-TERMINAL  (the user adds the push account lines with an editor)
vi ~/nkp-site.env
```

3. Get the CA file from the registry admin. Only if there is none: the block below saves the **first** certificate that the registry sends. That works only for a self-signed registry certificate. Ask the registry admin to confirm the fingerprint. `REGISTRY_URL` must start with `https://`.

```bash
# CHANGES  (writes the registry certificate to REGISTRY_CA_FILE)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; case "$h" in *:*) ;; *) h="$h:443";; esac; openssl s_client -showcerts -connect "$h" </dev/null 2>/dev/null | openssl x509 -outform PEM > "$REGISTRY_CA_FILE"
openssl x509 -in "$REGISTRY_CA_FILE" -noout -subject -issuer -fingerprint -sha256
```

4. Check access. HTTP code `200` or `401` means that the registry answers and the CA is correct.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; curl -s -o /dev/null -w '%{http_code}\n' --cacert "$REGISTRY_CA_FILE" "https://${h%%/*}/v2/"
for v in REGISTRY_PUSH_USERNAME REGISTRY_PUSH_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

5. Push. The CLI takes the password only as a flag, so other users on the host can see it in the process list. [live 2.19.0] Tell the user this.

```bash
# CHANGES  (pushes all images in IMAGE_BUNDLES into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$IMAGE_BUNDLES" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

Extra bundle (one file in `EXTRA_BUNDLE`):

```bash
# CHANGES  (pushes the images of one extra bundle file into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$EXTRA_BUNDLE" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

- Harbor can print `UNAUTHORIZED: project not found, name: mesosphere`. This is a false positive. The image is pushed. [pdf p.992]
- To push again after a failure, add `--on-existing-tag skip`. The default is `overwrite`. `--image-push-concurrency` (default 1) pushes more images at the same time. [live 2.19.0]
- AWS ECR: the operator host must be logged in to AWS. Use the ECR address as `--to-registry`. `--ecr-lifecycle-policy-file` sets a lifecycle policy on new repositories. [pdf p.991][live 2.19.0]
- `--to-registry-insecure-skip-tls-verify` skips the TLS check. Use it only when the user asks for it. [live 2.19.0]

Done when: the push ends without an error (other than the Harbor false positive). Ask the user to confirm the new repositories in the registry UI.

### 4B. Internal registry mirror

The create with `--bundle` fills the internal mirror (skill `nkp-install`). Use this push only to add bundles later, for example a catalog bundle or the bundles of a new NKP version before an upgrade (skill `nkp-upgrade`). [pdf p.946]

```bash
# CHANGES  (pushes the bundles into the internal registry mirror of the management cluster)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$EXTRA_BUNDLE" --to-internal-registry-mirror --kubeconfig "$MGMT_KUBECONFIG"
```

For the bundles of a new NKP version, use `"$IMAGE_BUNDLES"` in place of `"$EXTRA_BUNDLE"` after `IMAGE_BUNDLES` is set for that version.

Done when: the push ends without an error.

## Step 5: Check the registry setup on the nodes

Use this step for `ImagePullBackOff` or `x509` errors after a push worked. Follow [references/nodes.md](references/nodes.md). CAREN writes the registry files on each node at bootstrap, so a registry change reaches only new machines. [live 2.19.0] To change the mirror, the registry, or its CA on a running cluster, use skill `nkp-cluster-lifecycle` (variables.md, V8).

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff`; the push worked | The node subnet cannot reach the registry. [pdf p.713] | Check routes and firewall from a node (references/nodes.md). |
| `x509: certificate signed by unknown authority` on a node | Wrong or missing `--registry-mirror-cacert`. | Correct `REGISTRY_CA_FILE`. New machines get it (skill `nkp-cluster-lifecycle`). |
| Pull of one image fails, others work | The image is not in a pushed bundle. | List the bundle (step 2). Add the image with `nkp create bundle` (references/catalogs.md). |
| `no space left on device` during push | Small temporary folder. [pdf p.694] | Set `TMPDIR` (skill `nkp-install`). |
| Harbor `project not found, name: mesosphere` | False positive. [pdf p.992] | Ignore it. |
| `nkp diagnose` node collector does not start | `nkp diagnose` (v0.14.0) asks for `dkp-diagnostics-node-collector:v0.14.0`. The bundle has `v0.12.0`. [live 2.19.0] | references/prestage.md, item P5. |
| Create rejects the registry flags | `--bundle` and `--registry-mirror-*` together. [pdf p.725] | Use one mode (step 3). |

## Changes from earlier versions

- Earlier bundles had the OS distribution packages. 2.19 does not. [pdf p.73, p.1013] From 2.16, seeding before the create is optional (internal registry mirror). [pdf p.996]
- Guide pages for older bundles show `nib/`, `kib/`, and `application-charts/` folders. [pdf p.711, p.770] The 2.19.0 bundle has none; the charts are OCI artifacts in the image bundles. [live 2.19.0]
