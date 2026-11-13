# Batch 4 fix pass: nkp-gpu-ai (and its cross-skill rows)

Date 2026-11-03. Scope: `review.md` M1, M4, minors 1, 8, 9, 10, 14, 15, the gpu-ai line of minor 4, the section 5 airgap row, and `grading.md` item 2.
Checks: `check_skills.py --self-test` and `check_skills.py` pass (13 skills, 0 errors). `bash -n` passes on all command blocks of `nkp-gpu-ai` (SKILL.md, nvidia.md, ai-apps.md) and `nkp-airgap/references/prestage.md`. Line counts: SKILL.md 211, nvidia.md 235, ai-apps.md 165, prestage.md 134.
Lab (read-only, one `get configmap` of the NFD worker config, no dry run) is logged in `research/raw/live/2.19/gpu-ai.txt`, section NFD.

## review.md

- M1 fixed (skills/nkp-gpu-ai/SKILL.md:43, :84, :93, :193; evals/nkp-gpu-ai.md:13, :62). The NFD row says that NFD labels by PCI class and vendor (`deviceLabelFields: [class, vendor]`) [live 2.19.0], so an NVIDIA node gets `pci-0302_10de.present` or `pci-0300_10de.present`. The step 1 `-L` list has both labels. "How to read it" says that `pci-10de.present` is never set on NKP. The Common failures symptom names both labels. G1 and G5 expect the two labels. I read the lab NFD worker ConfigMap again and logged it (gpu-ai.txt).
- M4 fixed (skills/nkp-cluster-lifecycle/references/variables.md:127). The GPU pool taint is key `nvidia.com/gpu`, effect `NoSchedule`, with the reason and a pointer to skill `nkp-gpu-ai`, step 2. The generic example at :68 stays, as the review says.
- minor 1 fixed (references/ai-apps.md:37, :45, :88). `v1beta2` is now `[field: chart 0.18.0 CRDs]` with "The lab has no Kueue". `controllerManagerConfigYaml` is `[field: chart 0.18.0]`. The ConfigMap name has its reason (Flux release `kueue-system-kueue`) with `[field: catalog app tree]`. Kueue → `kueue-system` is stated as a fact before D-43, and D-43 now covers only the other apps. OPEN-ITEMS D-43 row updated.
- minor 4, gpu-ai line fixed (SKILL.md:119): on the management cluster the ConfigMap is in `kommander`, the HelmRelease namespace, so only a ConfigMap delete removes the DRA values; removing `configOverrides` does not. The gitops O1/O3 part is not in my scope (owner gitops).
- minor 8 fixed (references/ai-apps.md:134). The NAI pull Secret block checks the two secrets with `printenv … >/dev/null` into `k`, then `: "${k:?…}"`. The secrets are not expanded by the guard.
- minor 9: no change in nvidia.md:59, as the review says (`[field]` stays). The upstream tag fact is added to OPEN-ITEMS D-41 and used in airgap P12.
- minor 10 fixed (references/nvidia.md:168). The `nvidia.com/` prefix sync fact is removed. Only the pointer to skill `nkp-cluster-lifecycle` (file `variables.md`, node labels) stays.
- minor 14 fixed (references/nvidia.md:50). One line: when the user goes back to mode A after mode B failed, remove `nvidiaDriverRoot` from the override too.
- minor 15 fixed (references/ai-apps.md:159). "The guide adds replicas before the upgrade [pdf p.336-337]". The drain reason is `[field]`.

## Section 5 (cross-skill)

- Airgap row fixed (skills/nkp-airgap/references/prestage.md:36-37, :115-127). New row P12 with a USER-TERMINAL block on the connected host: `kernel=''` with its guard, image `nvcr.io/nvidia/driver:580-$kernel-ubuntu24.04`, `nkp create bundle`; the tag `580-6.8.0-124-generic-ubuntu24.04` is given as `[field]`. The push uses the existing "extra bundle" block. New row P13 has only pointers to gpu-ai D-44 (AMD) and D-45 (NAI). No GPU facts are copied: P12 points to gpu-ai N2 for when it is needed. I used prestage.md (P-rows), not catalogs.md C3, because prestage owns "not in the bundle" files. gpu-ai N2 (nvidia.md:74) now points to `prestage.md`, P12 instead of `catalogs.md`, C3.
- Lifecycle V6 taint: M4 above.

## grading.md

- Item 2 fixed: same as M1.

## OPEN-ITEMS

- D-41: upstream tag exists (`crane manifest`, [field]); P12 pre-stages it. Still open (mode B not tested on a GPU).
- D-43: Kueue part answered; still open for KAI, Slurm, Kubeflow Pipelines, JupyterHub, Milvus.
- D-44, D-45: note that airgap P13 points to them.
- The "Last updated" line is not changed (the parent does it).

## Not done, and changes other files need

- Re-run evals G1 and G5 (not run in this pass).
- gitops `overrides.md` O1/O3: list `nvidia-gpu-operator-config-overrides` as a name exception (minor 4, owner gitops).
