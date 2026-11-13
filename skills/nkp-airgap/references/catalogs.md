# Offline catalogs and extra images

Use this file from skill `nkp-airgap`. In 2.19, catalogs are OCI artifacts in a registry. Flux reads them as `OCIRepository` objects. [live 2.19.0] For catalog apps after the catalog exists (enable, configure, upgrade), use skill `nkp-platform-apps-gitops`.

## C1. Catalogs that are in the bundle

The bundle has two catalog bundles. Each has the catalog artifact, the charts, and the images. [live 2.19.0]

| Bundle (pattern) | Catalog repositories in the 2.19.0 bundle | Use |
|---|---|---|
| `container-images/*product-catalog*.tar` | `nutanix-cloud-native/nkp-nutanix-product-catalog/collection:2.19`, `nutanix-cloud-native/nkp-nutanix-product-catalog/ndk:2.3.0` | NDK only, Nutanix infrastructure only. [pdf p.946] A connected site uses the same repository and tag `2.19` on `ghcr.io` [field] (skill `nkp-ndk`, step 3). |
| `container-images/*ai-applications-catalog*.tar` | `nutanix-cloud-native/nkp-ai-applications-catalog/collection:2.19` and one repository for each app | AI apps (skill `nkp-gpu-ai`) |

1. List the catalog repositories of the bundle:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
for b in "$BUNDLE_DIR"/container-images/*catalog*.tar; do echo "== $b"; tar -tf "$b" | sed -n 's#^docker/registry/v2/repositories/\(.*-catalog/[^/]*\)/_manifests/tags/\([^/]*\)/current/link$#\1:\2#p' | sort -u; done
```

2. Push the bundle with the "extra bundle" block of SKILL.md step 4 (4A site registry, or 4B internal mirror).
3. Create the catalog in the workspace `kommander-workspace`. A catalog there goes to all workspaces and projects. [pdf p.340, p.357] Use `--project` with `--workspace` for one project only. [live 2.19.0]

UNKNOWN (A-07): the OCI URL of a catalog after `nkp push bundle` into a registry, and the URL with the internal registry mirror. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get ocirepositories`.

With the internal registry mirror, stop here and tell the user that the catalog URL is not known (A-07). With a site registry, the block below assumes that the push keeps the repository path under `REGISTRY_URL`. [field] Change `repo` and `tag` to a line from step 1 before you run it.

```bash
# CHANGES  (creates an OCIRepository catalog in the kommander-workspace; it goes to all workspaces)
source ~/nkp-site.env 2>/dev/null
repo='nutanix-cloud-native/nkp-ai-applications-catalog/collection'; tag='2.19'; : "${REGISTRY_URL:?REGISTRY_URL is empty, see A-07}"
nkp create catalog-app --url "oci://${REGISTRY_URL#*://}/$repo" --tag "$tag" --workspace kommander-workspace --kubeconfig "$MGMT_KUBECONFIG"
```

- NKP adds the registry credentials of the CAPI cluster to the `OCIRepository`. `--skip-oci-registry-patches` stops this. `--secret-ref`, `--service-account`, and `--cert-ref` give other credentials. [live 2.19.0]
- `--insecure` is for a plain-HTTP registry only. [live 2.19.0]

4. Check:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get ocirepositories
```

Done when: the new `OCIRepository` shows READY `True`. If it shows an error, read its STATUS. A "not found" error means a wrong URL (A-07).

## C2. Your own catalog (connected host)

`nkp create catalog-bundle` packs catalog apps from a catalog repository folder. `--airgapped` adds the images and OCI artifacts. It is required for an air-gapped site. [pdf p.357][live 2.19.0] It pulls the images, so it runs on a connected host. NDK images need a `docker login` with the Nutanix Docker Hub token. [pdf p.340]

```bash
# USER-TERMINAL  (connected host; the user runs it in the catalog repository folder. Writes a catalog bundle tar)
nkp create catalog-bundle --airgapped --apps my-app=1.0.0 --output-file my-catalog.tar
```

- `--apps name=version` selects apps. It can repeat. Without `--apps`, it packs all app versions in the folder. [pdf p.357]
- `--collection-tag` is required for more than one app. [live 2.19.0]
- `--constraint nkpVersion=2.19` selects apps for one NKP version. `--repo-dir` sets the folder. `--platform` defaults to `linux/amd64`. [live 2.19.0]
- The output shows the `nkp create catalog-application` command with the URL. Keep that command. [pdf p.340]

Then: move the tar with a SHA-256 check (references/prestage.md, last section), push it with the "extra bundle" block of SKILL.md step 4, and create the catalog with the URL from the output (C1 step 3).

- The guide shows `nkp push bundle --to-registry-mirror-url`. That flag does not exist. Use `--to-registry`. [pdf p.340][live 2.19.0]
- The 2.19 upgrade checks for "deprecated GitRepository-based catalog apps". [pdf p.1018] Use OCI catalogs only (skill `nkp-platform-apps-gitops`).

## C3. Extra images and charts (connected host)

For images or Helm charts that no bundle has (your apps, an extra tool), make a bundle on a connected host with `nkp create bundle`. [live 2.19.0]

```bash
# USER-TERMINAL  (connected host; the user runs it. Writes my-images.tar)
printf '%s\n' 'docker.io/library/nginx:1.29.5' > my-images.txt
nkp create bundle --images-file my-images.txt --output-file my-images.tar
```

- `--images-file`: a simple list of images (one for each line) or a YAML file. `--helm-charts-file`: a YAML file with charts. `--oci-artifacts-file`: OCI artifacts. [live 2.19.0] The YAML formats are not in the skills. Run `nkp create bundle --help`.
- `--merge` adds images to an existing bundle file. `--overwrite` replaces the file. `--platform` defaults to `linux/amd64`. `--image-pull-concurrency` defaults to 1. [live 2.19.0]
- Move the tar with a SHA-256 check. Push it with the "extra bundle" block of SKILL.md step 4.

Other bundle commands in 2.19.0: `nkp serve` (serves a bundle as a registry), `nkp import` (loads images from a bundle into containerd), `nkp push image-archive`. [live 2.19.0] Their flags are not in the skills. Run `--help` on each.
