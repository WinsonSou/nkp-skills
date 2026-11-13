# OS package bundles and custom node images (NIB)

Use this file from skill `nkp-airgap`. NIB (Nutanix Image Builder) builds node OS images. The `nkp` CLI runs NIB in a container on the operator host. NIB makes a temporary VM on the infrastructure and saves it as an image. [pdf p.57-61]

Site variables of this file (rule 4; same use as the rules table):

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `NODE_OS` `BASE_IMAGE` |

## When you need this

- The Nutanix pre-built images (Rocky Linux 9.8, Ubuntu 24.04, CIS Level 1, no FIPS) do not need NIB. [pdf p.55-56] Keep the portal image name. [pdf p.57]
- Custom images are **not** supported on the Starter license. [pdf p.57] The guide says that Starter supports only the Nutanix Rocky Linux image. [pdf p.715] This is a support statement, not a block: a Starter cluster on the Nutanix Ubuntu 24.04 image creates and runs, and the license shows `tier=Starter valid=true`. [live 2.19.0] Tell the user that Ubuntu on Starter is not supported, then do what the user chooses. Do not build a custom image for Starter.
- You need NIB for: a FIPS image, GPU on a Rocky image (the Ubuntu pre-built image supports NVIDIA passthrough and vGPU; the Rocky one does not) [pdf p.56], pre-installed GPU drivers, another OS, or images on other infrastructure (AWS, Azure, GCP, vSphere). On pre-provisioned hosts, `nkp upload image-artifacts` uses the same artifacts (section O4). [pdf p.71-74]

OS names (2.19.0 help) [live 2.19.0]:

| Command | OS names |
|---|---|
| `nkp create package-bundle` | `oracle-8.9` `oracle-9.4` `rhel-8.10` `rhel-9.6` `rhel-9.8` `rocky-9.8` `ubuntu-22.04` `ubuntu-24.04` |
| `nkp create image nutanix` | `rhel-8.10` `rhel-9.6` `rhel-9.8` `rocky-9.8` `ubuntu-22.04` `ubuntu-24.04` |

Ask the user for the OS. Append it as `NODE_OS` to `~/nkp-site.env` (rule 4).

## O1. Make the OS package bundle (connected host)

The air-gapped bundle has the NKP Kubernetes packages, the Python packages, and the containerd tarball, but **not** the OS distribution packages. [pdf p.73] `nkp create package-bundle` gets them from the OS vendor repositories, so it runs on a connected host. [pdf p.59-60]

1. The user extracts the same NKP bundle on the connected host (or copies only its `image-artifacts` folder) and puts the same `nkp` CLI on the path.
2. RHEL only: the user adds the Red Hat Subscription Manager lines to `~/nkp-site.env` on the connected host with an editor (rule 5): `RHSM_USER` and `RHSM_PASS`, or `RHSM_ORG_ID` and `RHSM_ACTIVATION_KEY`. [pdf p.75, p.711]
3. The user runs, in the extracted bundle folder:

```bash
# USER-TERMINAL  (connected host; the user runs it. Adds the OS packages to image-artifacts)
source ~/nkp-site.env 2>/dev/null
ls image-artifacts > /tmp/before.txt
nkp create package-bundle "$NODE_OS" --artifacts-directory image-artifacts/
ls image-artifacts | diff /tmp/before.txt - ; du -sh image-artifacts
```

- For a FIPS image, add `--fips`. [pdf p.60]
- `--kubernetes-version` defaults to the version of the CLI (1.36.2 for 2.19.0). [live 2.19.0] Keep the default.
- `--output-directory` writes the build scripts for review. `--from-directory` builds from changed scripts. These two flags cannot be used together. [live 2.19.0]
- The vendor repositories must be reachable from the connected host. The OS vendor documents the URLs. [pdf p.60]

4. The `diff` output shows the new files. The user packs the folder (`tar -czf image-artifacts.tar.gz image-artifacts`), moves the file with a SHA-256 check (references/prestage.md, last section), and extracts it into `"$BUNDLE_DIR"` on the operator host.

Done when: on the operator host, `ls "$BUNDLE_DIR"/image-artifacts` shows the new files from the `diff`.

## O2. Get the base OS image

NIB starts from a base OS image in Prism Central. [pdf p.57-58]
- Format qcow2 or img, UEFI boot, cloud-init and an SSH server installed, Python 3, a user with sudo, 20 GB free on the root file system, no Kubernetes parts. [pdf p.57]
- Do not use a Nutanix pre-built image or an image that NIB made before. [pdf p.58]
- On an air-gapped site, the user downloads the vendor cloud image on a connected host and imports it into Prism Central. Without `--source-image`, NIB downloads the upstream image, which fails offline. [live 2.19.0] `rhel-8.10` always needs `--source-image`. [pdf p.59]

Ask the user for the image name in Prism Central. Append it as `BASE_IMAGE` (rule 4).

## O3. Build the image (Nutanix AHV)

1. Load the NIB container image (air-gapped only). [pdf p.58, p.712]

```bash
# CHANGES  (loads the NIB container image into Docker on the operator host)
source ~/nkp-site.env 2>/dev/null
docker load --input "$(ls "$BUNDLE_DIR"/nkp-image-builder-image-*.tar)"
```

2. Check the values. `NUTANIX_USER` and `NUTANIX_PASSWORD` come from the env file. [pdf p.58-59]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
for v in NODE_OS BASE_IMAGE PC_ENDPOINT PE_CLUSTER SUBNET BUNDLE_DIR NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
docker images | grep -i image-builder
```

3. Build. The temporary VM uses `SUBNET` in `PE_CLUSTER`. [pdf p.59]

```bash
# CHANGES  (makes a temporary VM in Prism Central and saves a new VM image)
source ~/nkp-site.env 2>/dev/null
nkp create image nutanix "$NODE_OS" --endpoint "$PC_ENDPOINT" --cluster "$PE_CLUSTER" --subnet "$SUBNET" --source-image "$BASE_IMAGE" --artifacts-directory "$BUNDLE_DIR/image-artifacts" ${PC_PROJECT:+--pc-project "$PC_PROJECT"}
```

Optional flags. Add them before you run the block: [live 2.19.0][pdf p.59-61]
- `--fips`: a FIPS image. The package bundle must also be FIPS (O1).
- `--bundle "$(ls "$BUNDLE_DIR"/container-images/konvoy-image-bundle-*.tar)"`: loads the cluster images into the OS image. Use it when the cluster uses the internal registry mirror. [pdf p.712] Only `.tar` files.
- `--extra-build-name <text>`: adds text to the image name.
- `--gpu-profile-name`, `--vgpu-runfile`: GPU images. For the GPU values, use skill `nkp-gpu-ai`.
- `--bastion-host`, `--bastion-username`, `--bastion-private-key-file`, `--bastion-port`: NIB reaches the temporary VM through a jump host. [pdf p.60]
- `--insecure`: Prism Central with an untrusted certificate. Only when the user asks for it.
- `--overrides <files>`: Nutanix support gives these files. [pdf p.62] The air-gapped procedure in the guide does not use them. [pdf p.59-61]
- `--debug`: stops after each step for a person at the terminal. Do not use it in the agent shell.

4. Read the image name in the last lines of the output. The image placement policy must allow the image on `PE_CLUSTER`. [pdf p.713] For a cluster create, the user appends the name as `VM_IMAGE` (skill `nkp-install`). The name must contain the Kubernetes version. [pdf p.726]

Done when: the command ends without an error and Prism Central shows the new image.

## O4. Pre-provisioned hosts

`nkp upload image-artifacts` copies the packages, the containerd tarball, and the images to existing hosts over SSH (Ansible). [pdf p.71-74] Main flags: `--ssh-host` (comma-separated list), `--ssh-username`, `--ssh-private-key-file`, `--ssh-port`, `--artifacts-directory "$BUNDLE_DIR/image-artifacts"`, `--bundle`, `--fips`, `--nvidia-runfile`, `--provider`, and the bastion flags. [live 2.19.0] The files go to `/opt/dkp/packages/`, `/opt/dkp/containerd/`, and other folders on the host. [pdf p.74] Older field scripts use `--os-packages-bundle`, `--containerd-bundle`, `--pip-packages-bundle`. 2.19.0 does not have these flags. [live 2.19.0] For the upload block of the pre-provisioned install, use skill `nkp-install`, pre-provisioned hosts, section P3.

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| Package download fails in O1 | The connected host cannot reach the vendor repositories, or RHEL has no subscription. [pdf p.60, p.75] | Fix the access or the RHSM values. |
| NIB fails to pull its container | The NIB image is not loaded. [pdf p.712] | O3 step 1. |
| The build cannot reach the temporary VM | No route from the operator host to `SUBNET`. | Use the bastion flags. [pdf p.60] |
| Build fails at the package install offline | `--artifacts-directory` is missing or has no packages for this OS. | Do O1 for this `NODE_OS`, then build again. |
| Base image download fails | No `--source-image` on an air-gapped site. | O2. |
| `NutanixVMImage` preflight fails in the create | The image name was changed, or the placement policy blocks it. [pdf p.713, p.726] | Keep the NIB image name. Fix the policy. |
