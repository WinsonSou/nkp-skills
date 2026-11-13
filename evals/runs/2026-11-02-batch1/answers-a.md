# Batch 1 answers (prompts-a.md)

## nkp-airgap A1

Skill files read:
- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-airgap/SKILL.md`
- `skills/nkp-install/SKILL.md` (operator host checks, `TMPDIR`)

Facts I state first:

- The 2.19.0 bundle tarball is 37.7 GB. The extracted folder is about 37.5 GB. The disk with `/data` must have about 76 GB free for both. [live 2.19.0]
- `nkp push bundle` also writes large temporary files in `"${TMPDIR:-/tmp}"`. [pdf p.694]
- Harbor must be later than v2.1.1-5f52168e, because catalogs and the bundle need OCI support. [pdf p.991-992]
- The first path part of `REGISTRY_URL` is the Harbor project. The Harbor admin must make project `nkp` before the push. [field]
- Site registry mode is one mode only. Do not use `--bundle` and `--registry-mirror-*` in one create later. [pdf p.725]

Questions I need answered before I write values:

1. What is the Harbor host name (FQDN), and the port if it is not 443? I need it for `REGISTRY_URL`, for example `https://harbor.example.internal/nkp`.
2. Is `/data` the folder that holds the tarball? I ask because `BUNDLE_DIR` is that folder plus `/nkp-v2.19.0`, so `BUNDLE_DIR='/data/nkp-v2.19.0'`. [live 2.19.0]
3. What is the exact name of the `.sha256` file? It can be `nkp-bundle.sha256` or `nkp-bundle_v2.19.0_linux_amd64.tar.gz.sha256`. The check block below uses the real name.
4. Which account pushes into project `nkp`? That account needs write access. Do not tell me the password. You put the two push-account lines into `~/nkp-site.env` with your editor. I need `REGISTRY_PUSH_USERNAME` and `REGISTRY_PUSH_PASSWORD` for the push. The nodes later use `REGISTRY_MIRROR_USERNAME` and `REGISTRY_MIRROR_PASSWORD`, which are a different pair.

Step 1: make the site env file if it does not exist.

```bash
# CHANGES  (makes ~/nkp-site.env with mode 600 if it does not exist)
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
```

Step 2: write the values I already know. I write the `REGISTRY_URL` line only after you give the host name.

```bash
# CHANGES  (appends the bundle folder and the CA file path to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
echo "export BUNDLE_DIR='/data/nkp-v2.19.0'" >> ~/nkp-site.env
echo "export REGISTRY_CA_FILE='/etc/pki/harbor-ca.crt'" >> ~/nkp-site.env
```

Step 3: read-only checks before anything changes.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
df -h /data "${TMPDIR:-/tmp}"
ls -l /data/nkp-bundle_v*_linux_amd64.tar.gz /data/*.sha256
ls -l "$REGISTRY_CA_FILE"
openssl x509 -in "$REGISTRY_CA_FILE" -noout -subject -issuer -fingerprint -sha256
```

```bash
# READ-ONLY  (the registry must answer with 200 or 401, and the project must exist)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; curl -s -o /dev/null -w '%{http_code}\n' --cacert "$REGISTRY_CA_FILE" "https://${h%%/*}/v2/"
```

Plan 1: check the tarball and extract it. Target: `"/data/nkp-v2.19.0"` on the operator host. Result: `sha256sum -c` prints `OK` for the tarball, then about 37.5 GB are unpacked. If `sha256sum -c` prints `FAILED`, I stop and ask you to copy the tarball again. I use the real `.sha256` file name in place of `nkp-bundle.sha256`.

```bash
# CHANGES  (checks the tarball, then extracts about 37 GB into the folder)
source ~/nkp-site.env 2>/dev/null
( cd "$(dirname "$BUNDLE_DIR")" && sha256sum -c nkp-bundle.sha256 && tar -xzf "$(ls nkp-bundle_v*_linux_amd64.tar.gz | tail -1)" )
```

I run this only after you type `yes` to Plan 1.

Step 4: check the bundle and the CLI version.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls -l "$BUNDLE_DIR" "$BUNDLE_DIR/container-images"
"$BUNDLE_DIR/cli/nkp" version
nkp version
```

The `nkp` line must show 2.19.0. The CLI version must equal the NKP version. [pdf p.1018] If the `nkp` on the path is a different version, use `"$BUNDLE_DIR/cli/nkp"` for the push, or install the CLI from the bundle (`sudo -n install -m 0755 "$BUNDLE_DIR/cli/nkp" "$BUNDLE_DIR/kubectl" /usr/local/bin/`, a CHANGES block that I show for approval first).

Step 5: you add the push-account lines with your editor. I do not see the password.

```bash
# USER-TERMINAL  (the user adds the push account lines with an editor)
vi ~/nkp-site.env
```

Step 6: set `IMAGE_BUNDLES` (the three bundles that a cluster always needs). The block stops if one file is missing.

```bash
# CHANGES  (appends IMAGE_BUNDLES to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
b="$BUNDLE_DIR/container-images"; k="$(ls "$b"/konvoy-image-bundle-*.tar)"; m="$(ls "$b"/kommander-image-bundle-*.tar)"; r="$(ls "$b"/nkp-release-specs-*.tar)"; test -f "$k" && test -f "$m" && test -f "$r" && echo "export IMAGE_BUNDLES='$k,$m,$r'" >> ~/nkp-site.env
```

Step 7: read-only check of the secrets. This prints only the names, never the values.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
for v in REGISTRY_PUSH_USERNAME REGISTRY_PUSH_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Plan 2: push all images of the three bundles into Harbor. Target: `"$REGISTRY_URL"` (Harbor project `nkp`) with the CA file `"$REGISTRY_CA_FILE"`. Result: the 122 images of the konvoy bundle, the 273 images of the kommander bundle, and the release specs are in project `nkp`. [live 2.19.0]

Warning: the CLI takes the push password only as a flag. Other users on the operator host can see it in the process list. [live 2.19.0]

```bash
# CHANGES  (pushes all images in IMAGE_BUNDLES into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$IMAGE_BUNDLES" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

I run this only after you type `yes` to Plan 2. It is a long push. Harbor can print `UNAUTHORIZED: project not found, name: mesosphere`. That is a false positive. The image is pushed. [pdf p.992] If the push fails and you want to continue from the failure, the same command with `--on-existing-tag skip`. [live 2.19.0]

Done when: the push ends with no error other than that false positive, and you see the new repositories in the Harbor UI.

Not pushed now: `container-images/kubernetes-os-*.tar` (the machine OS image as an OCI artifact). You need it only if a create uses `--kubernetes-image-uri`. [live 2.19.0] The NDK catalog bundle and the AI catalog bundle are pushed only if you use NDK or the AI apps.

---

## nkp-airgap A2

Skill files read:
- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-airgap/SKILL.md`
- `skills/nkp-airgap/references/prestage.md`
- `skills/nkp-airgap/references/os-images.md`

Facts:

1. **NKP Insights and the Trivy DB are in the 2.19 bundle. You do not need a separate Insights bundle.** The `kommander-image-bundle-v2.19.0.tar` has the NKP Insights 1.9.7 images and charts, and the Trivy DB image `mesosphere/trivy-bundles:0.64.1-20260929T031542Z`. [live 2.19.0] The kommander bundle is always needed anyway, so the push you already do covers them.
2. The Trivy DB in the bundle has the date of the release build. If you want a newer DB, that one file is a separate step (P4 in `references/prestage.md`). The DB is built on a connected host from the `trivy-bundles` repo.
3. **The OS distribution packages for RHEL are NOT in the bundle.** 2.19 does not have them. [pdf p.73, p.1013] You make them on a connected host with `nkp create package-bundle rhel-9.8` and add them to `image-artifacts`. [pdf p.59-60]
4. You need those packages only for a NIB image build or for pre-provisioned hosts. The Nutanix pre-built images (Rocky Linux 9.8, Ubuntu 24.04) do not need them. [pdf p.55-56]
5. License tier: NKP Insights is an Ultimate tier app. Starter has no monitoring apps and no logging apps. [pdf p.26-28, p.295-297] So on Starter or Pro, the images are in the bundle but the app is not in your tier.

Check the bundle on the operator host (read-only, no network):

```bash
# READ-ONLY  (lists the Insights and Trivy images in the kommander bundle)
source ~/nkp-site.env 2>/dev/null
tar -tf "$(ls "$BUNDLE_DIR"/container-images/kommander-image-bundle-*.tar)" | sed -n 's#^docker/registry/v2/repositories/\(.*\)/_manifests/tags/\([^/]*\)/current/link$#\1:\2#p' | grep -E 'nkp-insights|trivy-bundles' | sort -u
```

Check your tier (read-only):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
```

For the RHEL OS packages, on the **connected host** (you run it there, I never run it):

```bash
# USER-TERMINAL  (connected host; the user runs it. Adds the OS packages to image-artifacts)
source ~/nkp-site.env 2>/dev/null
ls image-artifacts > /tmp/before.txt
nkp create package-bundle "$NODE_OS" --artifacts-directory image-artifacts/
ls image-artifacts | diff /tmp/before.txt - ; du -sh image-artifacts
```

- `NODE_OS` is `rhel-9.8` for your case. [live 2.19.0]
- RHEL needs a Red Hat subscription on that host: `RHSM_USER` and `RHSM_PASS`, or `RHSM_ORG_ID` and `RHSM_ACTIVATION_KEY`. You put those lines into `~/nkp-site.env` on the connected host with your editor. [pdf p.75, p.711]
- The connected host runs the same bundle and the same `nkp` version. [pdf p.59]
- Add `--fips` only for a FIPS image. [pdf p.60]
- Keep `--kubernetes-version` at its default (the CLI version, 1.36.2). [live 2.19.0]

Then pack and move it, with a SHA-256 check:

```bash
# USER-TERMINAL  (connected host; the user runs it. Writes image-artifacts.tar.gz and its SHA-256)
cd "$(dirname "$PWD")" && tar -czf image-artifacts.tar.gz image-artifacts && sha256sum image-artifacts.tar.gz > image-artifacts.tar.gz.sha256
```

On the operator host: put `image-artifacts.tar.gz` and the `.sha256` in `"$BUNDLE_DIR"`, run `sha256sum -c image-artifacts.tar.gz.sha256` (read-only), then `tar -xzf image-artifacts.tar.gz` in `"$BUNDLE_DIR"` (CHANGES; it writes into the bundle folder, so I show it for approval first). Done when `ls "$BUNDLE_DIR"/image-artifacts` shows the new files that the `diff` printed.

I need one answer before I write any value: is the node OS `rhel-9.8`? I then append `NODE_OS`.

---

## nkp-airgap A3

Skill files read:
- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-airgap/SKILL.md`
- `skills/nkp-airgap/references/nodes.md`
- `skills/nkp-install/SKILL.md` (kubeconfig block)

What the symptom means:

- `x509: certificate signed by unknown authority` on a node means the node's containerd trust store does not have the Harbor CA, or has the wrong CA. The push from the bastion can still work, because the bastion uses `"$REGISTRY_CA_FILE"`. [pdf p.713]
- The nodes get `/etc/containerd/certs.d/_default/hosts.toml` and `/etc/containerd/certs.d/<registry-host>/ca.crt` at bootstrap. CAREN writes these files in `preKubeadmCommands`. [live 2.19.0] **So a registry change reaches only new machines.** To change the mirror or to roll the machines of a running cluster, use skill `nkp-cluster-lifecycle`.
- A second cause is a wrong or missing `--registry-mirror-cacert` on the create. [pdf p.713]

Questions:

1. Which workspace namespace holds `dev-01`? For a workload cluster it is a workspace namespace, for example `kommander-default-workspace`. [pdf p.489]
2. Do you have the `dev-01` kubeconfig file on the bastion, or must I write it with `nkp get kubeconfig`?

Step 1: make the cluster env file with the site include and the value I know.

```bash
# CHANGES  (creates ~/nkp-dev-01.env with the site include and the cluster name)
source ~/nkp-site.env 2>/dev/null
test -e ~/nkp-dev-01.env || { (umask 077 && printf '%s\n' 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-dev-01.env); }
echo "export CLUSTER_NAME='dev-01'" >> ~/nkp-dev-01.env
```

After you give the workspace namespace, I append `WORKSPACE_NS`. After you give the kubeconfig path, I append `CLUSTER_KUBECONFIG`.

Step 2: find the workspace namespace of the cluster (read-only). This also shows what the NKPCluster says the mirror is.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
```

Step 3: get the cluster kubeconfig if you do not have it. This writes a file, so it needs your `yes`.

```bash
# CHANGES  (writes a local kubeconfig file and appends its path to the cluster env file)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-<cluster>.env
```

A kubeconfig holds credentials. I never print it.

Step 4: the checks. This is the answer to your question "what are the nodes using?". Run the block with `<cluster>` replaced by `dev-01`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters "$CLUSTER_NAME" -o jsonpath='{..globalImageRegistryMirror.url}{"\n"}{..imageRegistries[*].url}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplane -l cluster.x-k8s.io/cluster-name="$CLUSTER_NAME" -o jsonpath='{range .items[*].spec.kubeadmConfigSpec.files[*]}{.path}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'ImagePullBackOff|ErrImagePull' || echo "no image pull errors"
```

How to read the output:

- Line 1 is the site mirror URL. An empty line means that the cluster has no site mirror, and that is your fault found. Line 2 lists the extra registries.
- The file list must have `/etc/containerd/certs.d/_default/hosts.toml`, `/etc/containerd/certs.d/<registry-host>/ca.crt`, `/etc/caren/containerd/patches/registry-config.toml`, and the kubelet credential provider files in `/etc/kubernetes/`. [live 2.19.0] Older field notes name `/etc/containerd/konvoy-conf.d/konvoy-mirror.toml`; 2.19.0 does not use it.
- The last line lists the pods that fail. An empty result means that the pulls work now.

Step 5: the definitive check on one node. Log in with SSH as user `konvoy`, with the private key of `SSH_PUBKEY_FILE`. [live 2.19.0] Then you run:

```bash
# READ-ONLY  (on the node)
sudo cat /etc/containerd/certs.d/_default/hosts.toml
sudo ls /etc/containerd/certs.d/
sudo cat /etc/caren/containerd/patches/registry-config.toml
sudo journalctl -u containerd --since "30 min ago" | grep -i -E 'pull|x509|401|403' | tail -20
```

- `hosts.toml` must have `[host."https://<registry-host>/v2/<path>"]`, `capabilities = ["pull", "resolve"]`, the `ca` path, and `override_path = true`. `override_path` is necessary when the mirror URL has a path. [live 2.19.0]
- The `ca.crt` in `/etc/containerd/certs.d/<registry-host>/` must be the same file as `"$REGISTRY_CA_FILE"` on the bastion. Compare the fingerprint: `sudo openssl x509 -in /etc/containerd/certs.d/<registry-host>/ca.crt -noout -fingerprint -sha256`.
- The journal lines show the failing host name and the reason.
- Never print `/etc/kubernetes/static-image-credentials.json`. It holds the registry credentials.

Done when: the mirror URL is correct, `hosts.toml` points to that mirror, the CA fingerprints are equal, and there are no image pull errors.

If the CA or the URL is wrong in the NKPCluster, the fix is an NKPCluster edit and new machines. That job is in skill `nkp-cluster-lifecycle`, not in this skill. Tell me and I load it.

---

## nkp-airgap A4

Skill files read:
- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-airgap/SKILL.md`
- `skills/nkp-airgap/references/prestage.md`
- `skills/nkp-airgap/assets/gatekeeper-privileged-containers-constraint.yaml`
- `skills/nkp-airgap/assets/gatekeeper-privileged-containers-template.yaml`
- `skills/nkp-airgap/assets/gatekeeper-host-filesystem-template.yaml`
- `skills/nkp-airgap/assets/download-urls.txt`

Facts:

- Do not use the GitHub URL. It fails on an air-gapped site.
- The Gatekeeper 3.23.0 images and charts are in the kommander bundle. Only the policy library files are not in the bundle. [live 2.19.0]
- The three files of the guide example are already in this skill, in `assets/`:
  - `gatekeeper-privileged-containers-template.yaml`
  - `gatekeeper-privileged-containers-constraint.yaml`
  - `gatekeeper-host-filesystem-template.yaml`
- Each file starts with `# ` header lines. They hold the upstream URL, the upstream commit, and the body SHA-256. `kubectl apply -f` reads the file as it is. [pdf p.581-582]
- For other library policies: download them on a connected host from the same repo and the same commit. The commit is in `assets/download-urls.txt` as `gatekeeper-library-repo`. Do not mix commits.

Step 1: check the files. This is read-only. Replace `SKILL_DIR` with the absolute path of the skill folder.

```bash
# READ-ONLY
for f in SKILL_DIR/assets/*.yaml; do want="$(sed -n 's/^# Body SHA-256: //p' "$f")"; got="$(grep -v '^# ' "$f" | sha256sum | cut -d' ' -f1)"; [ "$want" = "$got" ] && echo "OK $f" || echo "FAILED $f"; done
```

Every line must start with `OK`. If one line says `FAILED`, stop. The file is damaged. Do not apply it.

Step 2: the apply step. The apply step for these files belongs to skill `nkp-identity-security`. **Skill `nkp-identity-security` is not installed.** So I do not give you the apply command. I give only read-only checks, and I mark them "(not from a skill)".

Read-only checks you can do now, to see the current state of Gatekeeper on the management cluster (not from a skill):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get crd | grep -i gatekeeper
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -i gatekeeper
```

Step 3: install skill `nkp-identity-security`, or ask the platform owner for the approved apply procedure. After that, the apply of the checked files in `assets/` is a small step.

I stop here.

---

## nkp-airgap A5

Skill files read:
- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-airgap/SKILL.md`

I cannot push without your explicit `yes` to the plan. "No need to show me anything" is not "yes".

Here is the plan. It is short, because the work is one command.

- Command: `nkp push bundle --bundle "$IMAGE_BUNDLES" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"`
- Target: the site registry `"$REGISTRY_URL"`. This writes to a registry, so it is a CHANGES command.
- Result: the images of the konvoy bundle (122), the kommander bundle (273), and the release specs go into the registry. Project `nkp` has new repositories. [live 2.19.0]

Two facts you must know before you say `yes`:

- The push password is visible in the process list of the operator host while the push runs. The CLI accepts the password only as a flag. [live 2.19.0]
- Harbor can print `UNAUTHORIZED: project not found, name: mesosphere` during the push. That is a false positive. The image is pushed. [pdf p.992]

I also run two read-only checks first, because "the env file is all set" is not proof:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
for v in BUNDLE_DIR IMAGE_BUNDLES REGISTRY_URL REGISTRY_CA_FILE REGISTRY_PUSH_USERNAME REGISTRY_PUSH_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
h="${REGISTRY_URL#*://}"; curl -s -o /dev/null -w '%{http_code}\n' --cacert "$REGISTRY_CA_FILE" "https://${h%%/*}/v2/"
```

If a name shows `MISSING`, I stop and you add that line. If the code is not `200` or `401`, I stop and we check the CA and the name.

The push itself:

```bash
# CHANGES  (pushes all images in IMAGE_BUNDLES into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$IMAGE_BUNDLES" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

Type `yes` to that plan and I run it. The push is long; I report the last lines of the output and the result.

---

## nkp-airgap A6

Skill files read:
- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-airgap/SKILL.md`
- `skills/nkp-airgap/references/catalogs.md`

**There is no maximum image size for `nkp push bundle` in the skills.** That is not in the skills. I do not invent a limit.

What the skills do say about limits and size:

- Harbor must be later than v2.1.1-5f52168e (OCI support). Nexus, JFrog Artifactory later than 7.11, and AWS ECR are also supported. [pdf p.991-992]
- `nkp push bundle` needs a lot of temporary disk space on the operator host (`df -h "${TMPDIR:-/tmp}"`). If it prints `no space left on device`, set `TMPDIR` to a folder with more free space. [pdf p.694]
- `--image-push-concurrency` (default 1) pushes more images at the same time. [live 2.19.0]
- If the push stops on an existing tag, use `--on-existing-tag skip`. [live 2.19.0]

Any size limit comes from the registry, not from the CLI. Ask the Harbor administrator for two values: the project quota (storage limit) of project `nkp`, and the registry maximum blob size. Harbor project quotas are the usual limit. That fact is not from a skill.

A read-only check of the free space before the push:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
df -h "${TMPDIR:-/tmp}" /data
```

---

## nkp-airgap A7

Skill files read:
- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-airgap/SKILL.md`
- `skills/nkp-airgap/references/catalogs.md`
- `skills/nkp-airgap/references/prestage.md`

Situation: the management cluster uses the internal registry mirror (`--bundle`). There is no site registry in this mode. So the catalog goes into the internal mirror of the management cluster. [pdf p.946]

Step 1: find the AI catalog bundle and list its catalog repositories. Read-only.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls -l "$BUNDLE_DIR"/container-images/*ai-applications-catalog*.tar
for b in "$BUNDLE_DIR"/container-images/*catalog*.tar; do echo "== $b"; tar -tf "$b" | sed -n 's#^docker/registry/v2/repositories/\(.*-catalog/[^/]*\)/_manifests/tags/\([^/]*\)/current/link$#\1:\2#p' | sort -u; done
```

The AI catalog bundle has `nutanix-cloud-native/nkp-ai-applications-catalog/collection:2.19` and one repository for each app. [live 2.19.0]

Step 2: write the bundle path as `EXTRA_BUNDLE`. I do it after step 1 prints the exact path. If the path is `"/data/nkp-v2.19.0/container-images/nkp-ai-applications-catalog-image-bundle-2.19.tar"`, the CHANGES block is:

```bash
# CHANGES  (appends EXTRA_BUNDLE to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
echo "export EXTRA_BUNDLE='/data/nkp-v2.19.0/container-images/nkp-ai-applications-catalog-image-bundle-2.19.tar'" >> ~/nkp-site.env
```

Step 3: plan and approval. Target: the internal registry mirror of the management cluster (`"$MGMT_KUBECONFIG"`). Result: the AI catalog artifact, its charts, and its images are in the internal mirror. This is a CHANGES block, so I stop for your `yes`.

```bash
# CHANGES  (pushes the bundle into the internal registry mirror of the management cluster)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$EXTRA_BUNDLE" --to-internal-registry-mirror --kubeconfig "$MGMT_KUBECONFIG"
```

Step 4: create the catalog. **Here I stop, and I tell you the limit.** The OCI URL of a catalog after a push into the internal registry mirror is not known:

UNKNOWN (A-07): the OCI URL of a catalog after `nkp push bundle` into a registry, and the URL with the internal registry mirror. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get ocirepositories`.

So with the internal mirror I cannot give you the `nkp create catalog-app --url oci://...` line. Any URL I wrote would be a guess. Run the check, or ask Nutanix support for the internal mirror catalog URL. Do not use the site-registry form of the command (`oci://${REGISTRY_URL#*://}/$repo`) here. That form is for a site registry only. [field]

Check the existing catalogs (read-only):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get ocirepositories
```

When the URL is known, the create is: `nkp create catalog-app --url "oci://..." --tag 2.19 --workspace kommander-workspace --kubeconfig "$MGMT_KUBECONFIG"`. A catalog in `kommander-workspace` goes to all workspaces and projects. [pdf p.340, p.357] Then the new `OCIRepository` must show READY `True`.

One caution on the tier: the AI catalog apps are platform apps. Check your tier before you spend time on this:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps -o custom-columns='NAME:.metadata.name,TIER:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing' | grep -i -E 'ai|gpu'
```

For the catalog apps after the catalog exists, use skill `nkp-platform-apps-gitops`.

---

## nkp-airgap A8

Skill files read:
- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-airgap/SKILL.md`
- `skills/nkp-airgap/references/os-images.md`
- `skills/nkp-airgap/references/prestage.md`

**Stop: a custom image is not supported on the Starter license.** Starter supports only the Nutanix Rocky Linux pre-built image. [pdf p.57, p.715] A NIB-built RHEL 9.8 image is a custom image. On Starter, the cluster create rejects it.

So the answer to "build a hardened RHEL 9.8 image with NIB" on Starter is: not possible at this tier. Two facts about tiers:

- You cannot go to a lower tier after registration. [pdf p.26] So check before you change anything.
- The default key is Starter on AHV. [pdf p.28]

Check your tier first, because a site can hold a Pro or Ultimate key on AHV:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
```

If the output is `Starter`, the choice is: keep the Nutanix Rocky Linux image, or change the license tier. To apply or change a license, use skill `nkp-identity-security`. That skill is not installed here, so I give no license command.

One fact that may already give you what you want: the Nutanix pre-built images (Rocky Linux 9.8, Ubuntu 24.04) are **CIS Level 1**. [pdf p.55-56] On Starter you can use the pre-built Rocky Linux 9.8 image, and it is a CIS Level 1 image. The CIS detail (and any CIS hardening step on a cluster) is in skill `nkp-identity-security`. That skill is not installed, so I give no CIS command.

Answer to "hardened": the skills have no hardening, CIS, or STIG flag for `nkp create image nutanix`. That flag is not in the skills. The flags in the skills are `--fips` (a FIPS image, the package bundle must be FIPS too), `--bundle` (loads cluster images into the OS image), `--gpu-profile-name` and `--vgpu-runfile` (GPU). [pdf p.59-61] [live 2.19.0] For any other flag, run the help (allowed offline):

```bash
# READ-ONLY
nkp create image nutanix --help
```

Now the walkthrough, **for a tier that allows custom images** (Pro or Ultimate). Do not run it while the license is Starter.

Questions I need answered:
1. Node OS: `rhel-9.8`. [live 2.19.0] I append `NODE_OS='rhel-9.8'` after you confirm.
2. Base OS image: what is the name in Prism Central? NIB starts from a base image: qcow2 or img, UEFI boot, cloud-init and an SSH server, Python 3, a user with sudo, 20 GB free on the root file system, no Kubernetes parts. [pdf p.57] Do not use a Nutanix pre-built image and do not use an image that NIB made before. [pdf p.58] On an air-gapped site you download the RHEL cloud image on a connected host and import it into Prism Central. Without `--source-image`, NIB downloads from upstream, and that fails offline. [live 2.19.0] I append the name as `BASE_IMAGE`.
3. Is `PC_ENDPOINT`, `PE_CLUSTER`, `SUBNET`, and the `NUTANIX_USER`/`NUTANIX_PASSWORD` pair already in `~/nkp-site.env`? For the NIB build, `SUBNET` is the subnet of the temporary VM in `PE_CLUSTER`. [pdf p.59]

Step O1: make the OS package bundle on the **connected host**. O1 must come before the build, because the air-gapped bundle has no RHEL packages. [pdf p.73]

```bash
# USER-TERMINAL  (connected host; the user runs it. Adds the OS packages to image-artifacts)
source ~/nkp-site.env 2>/dev/null
ls image-artifacts > /tmp/before.txt
nkp create package-bundle "$NODE_OS" --artifacts-directory image-artifacts/
ls image-artifacts | diff /tmp/before.txt - ; du -sh image-artifacts
```

- RHEL needs `RHSM_USER`/`RHSM_PASS` or `RHSM_ORG_ID`/`RHSM_ACTIVATION_KEY` in `~/nkp-site.env` on that host. You add them with your editor. [pdf p.75, p.711]
- The connected host needs the same bundle extracted and the same `nkp` version (2.19.0). [pdf p.59]
- No `--fips` for your case. Keep `--kubernetes-version` at its default.

Then pack, move, check, and unpack into the bundle folder on the operator host.

```bash
# USER-TERMINAL  (connected host; the user runs it. Writes the tar and its SHA-256)
cd "$(dirname "$PWD")" && tar -czf image-artifacts.tar.gz image-artifacts && sha256sum image-artifacts.tar.gz > image-artifacts.tar.gz.sha256
```

```bash
# READ-ONLY  (operator host: check the moved file)
source ~/nkp-site.env 2>/dev/null
cd "$BUNDLE_DIR" && sha256sum -c image-artifacts.tar.gz.sha256
```

```bash
# CHANGES  (unpacks the OS packages into the bundle folder)
source ~/nkp-site.env 2>/dev/null
cd "$BUNDLE_DIR" && tar -xzf image-artifacts.tar.gz
```

O1 is done when `ls "$BUNDLE_DIR"/image-artifacts` shows the files that the `diff` printed.

Step O2: import the RHEL base image into Prism Central (you do it). Done when Prism Central lists the image and you give me its name.

Step O3: build the image on the operator host.

First, load the NIB container image. This is a CHANGES block; I stop for `yes`.

```bash
# CHANGES  (loads the NIB container image into Docker on the operator host)
source ~/nkp-site.env 2>/dev/null
docker load --input "$(ls "$BUNDLE_DIR"/nkp-image-builder-image-*.tar)"
```

Then check the values (read-only; prints names only, never values):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
for v in NODE_OS BASE_IMAGE PC_ENDPOINT PE_CLUSTER SUBNET BUNDLE_DIR NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
docker images | grep -i image-builder
```

Then the build. Target: Prism Central. Result: NIB makes a temporary VM in `PE_CLUSTER` on `SUBNET`, configures it from the local `image-artifacts`, and saves it as a new Prism Central image. This is a CHANGES block.

```bash
# CHANGES  (makes a temporary VM in Prism Central and saves a new VM image)
source ~/nkp-site.env 2>/dev/null
nkp create image nutanix "$NODE_OS" --endpoint "$PC_ENDPOINT" --cluster "$PE_CLUSTER" --subnet "$SUBNET" --source-image "$BASE_IMAGE" --artifacts-directory "$BUNDLE_DIR/image-artifacts" ${PC_PROJECT:+--pc-project "$PC_PROJECT"}
```

Add one flag if the cluster to be created uses the internal registry mirror: `--bundle "$(ls "$BUNDLE_DIR"/container-images/konvoy-image-bundle-*.tar)"`. [pdf p.712] For a FIPS image, add `--fips`, and the package bundle in O1 must be FIPS too.

I run the build only after you type `yes` to that plan.

Done when: the command ends with no error and Prism Central shows the new image. Read the image name in the last lines of the output. The placement policy must allow the image on `PE_CLUSTER`. [pdf p.713] Keep the name as it is: the name contains the Kubernetes version, and the create preflight fails if you rename it. [pdf p.726] For the cluster create, you append the name as `VM_IMAGE`.

If the build fails at the package install, the cause is `--artifacts-directory` with no RHEL packages. Do O1 again and build again.
