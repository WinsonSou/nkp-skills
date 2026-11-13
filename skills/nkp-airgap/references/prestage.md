# Files that are not in the bundle (pre-stage list)

Use this file from skill `nkp-airgap`. The 2.19.0 bundle has the images in the table "In the bundle". The items in the table "Not in the bundle" need a file from outside. Get them on a connected host **before** the site is closed, or move them in later.

Small text files are in `assets/` of this skill. The header of each asset has the upstream URL, the version, the upstream SHA-256, and the body SHA-256. The download URLs and SHA-256 values for the other files are in [assets/download-urls.txt](assets/download-urls.txt) (format: name, URL, SHA-256).

## In the bundle (no pre-stage) [live 2.19.0]

| Item | Bundle | Note |
|---|---|---|
| Gatekeeper 3.23.0 images and charts | kommander | only the images; the policy library is not in the bundle |
| NKP Insights 1.9.7 (images, charts), Trivy DB image `mesosphere/trivy-bundles:0.64.1-20260929T031542Z` | kommander | the Trivy DB has the date of the release build |
| Harbor 2.15.1 images and chart | kommander | |
| `dkp-diagnostics-node-collector:v0.12.0`, `pause-busybox:3.6` | konvoy and kommander | see P5 |
| NDK 2.3.0 images, chart, and catalog | NDK catalog bundle | The NDK recipes image (`ndk/recipes`), `ndkcli`, and the recipe job files are not in it: they come only from the portal NDK bundle (P7). |
| AI catalog apps (JupyterHub, Kubeflow Pipelines, Kueue, KAI scheduler, Milvus operator, Slurm operator) | AI catalog bundle | |
| CRD `referencegrants.gateway.networking.k8s.io` | installed by NKP | Helm release `kommander/gateway-api-crds`, bundle version v1.3.0. No download for NDK cross-namespace restore. |

To check one image, list the bundle (SKILL.md step 2) and `grep` for the name.

## Not in the bundle

| ID | Item | Where it is | Used by |
|---|---|---|---|
| P1 | Gatekeeper library: privileged-containers template and constraint, host-filesystem template (the guide examples [pdf p.581-582]) | three gatekeeper files in `assets/` | skill `nkp-identity-security` |
| P2 | Sealed Secrets controller v0.18.1 manifest [pdf p.389] | `assets/sealed-secrets-controller-v0.18.1.yaml` | skill `nkp-platform-apps-gitops` |
| P3 | Sealed Secrets controller image and `kubeseal` CLI v0.18.1 | steps below | skill `nkp-platform-apps-gitops` |
| P4 | Newer Trivy DB for NKP Insights | steps below | skill `nkp-observability` |
| P5 | `nkp diagnose` node collector image v0.14.0 | steps below | skill `nkp-troubleshooting` |
| P6 | NDK alert rules | `assets/ndk-alert-config.yaml` (fixed copy: the upstream file is not valid YAML; the header lists the changes) | skill `nkp-ndk` |
| P7 | NDK bundle, NDK CLI bundle, NDK support script (KB-16326) | Nutanix portal, login needed | skill `nkp-ndk` |
| P8 | Flow CNI dark-site bundle (images only: the chart `nutanix-flow-cni` comes from the CAREN chart server of the management cluster; the bundle version must be the same as that chart version) | Nutanix portal, login needed | skill `nkp-flow-cni` |
| P9 | OS distribution packages | `nkp create package-bundle` (references/os-images.md) | NIB, pre-provisioned hosts |
| P10 | Base OS image (qcow2 or img) for a NIB build | the OS vendor | references/os-images.md |
| P11 | Your own app images and charts | `nkp create bundle` (references/catalogs.md) | your apps |
| P12 | NVIDIA precompiled driver image for the GPU node kernel (when the bundle has no tag for it) | steps below | skill `nkp-gpu-ai` (file `nvidia.md`, N2) |
| P13 | AMD GPU operator apps; Nutanix Enterprise AI (NAI) | not in the 2.19.0 bundles; source not known | skill `nkp-gpu-ai`: UNKNOWN D-44 (AMD), D-45 (NAI) |

For other Gatekeeper library policies, the user downloads the files on a connected host from the same repository and commit (`gatekeeper-library-repo` in `assets/download-urls.txt`).

## Use an asset

1. Check that the body of each asset has the SHA-256 in its header:

Set `dir` to the absolute path of this skill folder: the folder where you read its `SKILL.md`, for example `/home/ops/skills/nkp-airgap`. It is the only allowed edit of this block.

```bash
# READ-ONLY
dir=''; : "${dir:?}"
for f in "$dir"/assets/*.yaml; do want="$(sed -n 's/^# Body SHA-256: //p' "$f")"; got="$(grep -v '^# ' "$f" | sha256sum | cut -d' ' -f1)"; [ "$want" = "$got" ] && echo "OK $f" || echo "FAILED $f"; done
```

2. Every line must start with `OK`. If not, stop. Then the owner skill (column "Used by") gives the apply step. The header lines start with `# `, so `kubectl apply -f` reads the file as it is.

## P3. Sealed Secrets image and kubeseal

The manifest pulls `docker.io/bitnami/sealed-secrets-controller:v0.18.1`. On the connected host, the user makes an image bundle and gets the CLI (URL and SHA-256: line `kubeseal` in `assets/download-urls.txt`):

```bash
# USER-TERMINAL  (connected host; the user runs it. Writes sealed-secrets-images.txt and sealed-secrets-v0.18.1.tar)
echo 'docker.io/bitnami/sealed-secrets-controller:v0.18.1' > sealed-secrets-images.txt
nkp create bundle --images-file sealed-secrets-images.txt --output-file sealed-secrets-v0.18.1.tar
```

The user downloads the `kubeseal` tarball with the URL and checks it with `sha256sum`. The value must be the same as in `assets/download-urls.txt`. If not, stop. Move the files to the operator host (last section). Push the tar with the "extra bundle" block of SKILL.md step 4. To install `kubeseal` on a host, use skill `nkp-platform-apps-gitops`.

## P4. Newer Trivy DB for NKP Insights

The bundle Trivy DB has the date of the release build. NKP Insights uses it on an air-gapped site. [pdf p.1119][live 2.19.0] To get a newer DB:

1. On the cluster, read the Trivy image. The Trivy version is the part before `-`. [pdf p.1120]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get cronjob nkp-insights-trivy -o jsonpath='{.spec.jobTemplate.spec.template.spec.initContainers[?(@.name=="trivy")].image}{"\n"}'
```

2. On the connected host (Git, Docker, and make needed), the user clones the `trivy-bundles-repo` URL from `assets/download-urls.txt`, then runs in that folder. Put the Trivy version from step 1 in `TRIVY_VERSION`. [pdf p.1120-1121]

```bash
# USER-TERMINAL  (connected host; the user runs it in the trivy-bundles folder. Builds a Trivy bundle tar.gz)
export TRIVY_VERSION=0.64.1
make create-airgapped-image-bundle
sha256sum trivy-bundles-*.tar.gz
```

3. Move the `trivy-bundles-<version>-<date>.tar.gz` file to the operator host (last section). Push it with the "extra bundle" block of SKILL.md step 4. [pdf p.1122]
4. Set the new image in the NKP Insights app of each workspace: `trivy.image.imageFull: docker.io/mesosphere/trivy-bundles:<version>-<date>` (the node mirror serves it). For the app edit, use skill `nkp-observability`. [pdf p.1122]

Done when: the check in step 1 shows the new date.

## P5. diagnose collector

`nkp diagnose` from the 2.19.0 bundle (diagnose v0.14.0) uses `docker.io/mesosphere/dkp-diagnostics-node-collector:v0.14.0`. The image bundles have only `v0.12.0`. [live 2.19.0] So on an air-gapped site, the node collector pull fails. Two choices:

- A (recommended). On the connected host, the user makes a bundle with the v0.14.0 image. Then push it with the "extra bundle" block of SKILL.md step 4:

```bash
# USER-TERMINAL  (connected host; the user runs it. Writes diagnose-images.txt and diagnose-collector.tar)
echo 'docker.io/mesosphere/dkp-diagnostics-node-collector:v0.14.0' > diagnose-images.txt
nkp create bundle --images-file diagnose-images.txt --output-file diagnose-collector.tar
```

UNKNOWN (A-08): if the `v0.12.0` collector works with `nkp diagnose` v0.14.0. Only a lab test answers it. Find out with: `nkp diagnose default-config | grep -n 'node-collector'` (shows the tag that the CLI asks for).

- B (not tested). On the operator host, make a config file that uses the `v0.12.0` image from the bundle. For the `nkp diagnose` run with this file, use skill `nkp-troubleshooting`.

```bash
# CHANGES  (writes diagnose-airgap.yaml on the operator host)
nkp diagnose default-config | sed 's#dkp-diagnostics-node-collector:v0.14.0#dkp-diagnostics-node-collector:v0.12.0#' > diagnose-airgap.yaml
grep -n 'node-collector\|pauseImage' diagnose-airgap.yaml
```

## P12. NVIDIA precompiled driver image

Skill `nkp-gpu-ai` (file `nvidia.md`, N2) tells you when this is needed and gives the node kernel. The image name is `nvcr.io/nvidia/driver:580-<kernel>-ubuntu24.04`. For example, the tag `580-6.8.0-124-generic-ubuntu24.04` exists upstream. [field] Set `kernel` to the node kernel (for example `6.8.0-124-generic`) after the user confirms it:

```bash
# USER-TERMINAL  (connected host; the user runs it. Writes nvidia-driver-images.txt and nvidia-driver.tar)
kernel=''; : "${kernel:?set the GPU node kernel}"
echo "nvcr.io/nvidia/driver:580-$kernel-ubuntu24.04" > nvidia-driver-images.txt
nkp create bundle --images-file nvidia-driver-images.txt --output-file nvidia-driver.tar
```

Move the tar (last section). Push it with the "extra bundle" block of SKILL.md step 4.

## P7, P8. Portal files

The user downloads these from the Nutanix portal with a login: the NDK bundle, the NDK CLI bundle, the KB-16326 support script (skill `nkp-ndk`), and the Flow CNI dark-site bundle (skill `nkp-flow-cni`). Then move them (last section).

## Move files into the air gap

For each file: on the connected host, run `sha256sum <file> > <file>.sha256`. Move both files. On the operator host, run `sha256sum -c <file>.sha256` in the same folder. Done when every check prints `OK`. If one prints `FAILED`, copy that file again.
