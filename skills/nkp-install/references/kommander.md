# Install Kommander

Use this file from the `SKILL.md` step "Check or install Kommander", only when the check shows that Kommander is not installed.

Kommander needs one default StorageClass: the `storageclass` list in the check shows `(default)` on one line. [pdf p.942] If no StorageClass is the default, stop. Use skill `nkp-storage-backup`, step 3.

## K1. Make the installer file

Air-gapped site:

```bash
# CHANGES  (writes the local file kommander.yaml)
nkp install kommander --init --airgapped > kommander.yaml
```

Connected site:

```bash
# CHANGES  (writes the local file kommander.yaml)
nkp install kommander --init > kommander.yaml
```

Done when: `kommander.yaml` exists.

## K2. Install

Show `kommander.yaml` to the user. Change only what the user asks for. App values before the first install go in `kommander.yaml` under `apps.<app>.values` [pdf p.959]. After the install, use skill `nkp-platform-apps-gitops`, file `overrides.md` O3. Then install:

```bash
# CHANGES  (installs Kommander and the platform apps on the management cluster)
source ~/nkp-site.env 2>/dev/null
nkp install kommander --installer-config kommander.yaml --kubeconfig "$MGMT_KUBECONFIG" --wait-timeout 2h
```

- The default wait is 1h15m. [live 2.19.0] The block uses 2h, because an air-gapped install can take longer than the default.
- If the install fails or times out, run the same block again. It continues. [pdf p.944]
- NKP does not install AI Navigator on an air-gapped site. [pdf p.942]

Done when: the HelmRelease wait in the `SKILL.md` step "Verify" passes.
