# Batch 4 review: kubernetes-core, nkp-observability, nkp-gpu-ai

Reviewer: Opus, fresh read-only session, 2026-11-03. Scope: `git diff f03913d..8169518` and commit 96729af (check script domains). I changed no repo file except this one. Scratch files are in `/tmp/rvb4`.

What I did:
- `python3 scripts/check_skills.py --self-test && python3 scripts/check_skills.py`: both pass (`13 skills checked, 0 errors`).
- `bash -n` on all 82 command blocks in scope: no syntax errors. Every block has a mark on line 1. Every block that uses a site or cluster variable has the correct `source … 2>/dev/null` on line 2 (`/tmp/rvb4/b2.py`).
- Rule 4: every shell value in a block is `''` with a `:?` guard, except `repo='nvidia/driver'` (`nvidia.md:69`), which is a constant and not a proposed value. No append block shows a guessed value. No `<...>` text is in a block value.
- Secrets: no block prints a secret. All Secret objects are made with `--from-file=…<(printf %s "$(printenv VAR)")` or from a file path. The vGPU token file and `~/alertmanager.yaml` are never printed. There is one small deviation from rule 5 (minor 8).
- `nkp` flags: all of them are in `nkp-help*.txt` (`--gpu-profile-name`, `--vgpu-runfile` in `nkp-help-airgap.txt:36,47`; `--nvidia-runfile` `:72`; `--gpu-count`, `--gpu-name` in `nkp-help-lifecycle.txt:40-42`). `--gpu-name` is hidden in `--help` and is logged in `gpu-ai.txt`.
- `kubectl` flags: all of them are in `kubernetes-core.txt` except `api-resources --api-group`. I checked that flag live (`kubectl api-resources --help`); it exists (minor 11). `--docker-password` is only named as the guide way that the skill does not use.
- `[pdf p.N]` tags: I compared each tag with the page text (`/tmp/rvb4/tags.py`, then I read each flagged tag). Almost all are correct. The exceptions are in minor 1 and minor 15.
- The upstream app tree: `ghcr.io/mesosphere/kommander-applications:v2.19.0` has digest `sha256:ec2a35cc94a0…041e`. That is the lab OCIRepository digest (`gpu-ai.txt:4`). I also read these charts: `gpu-operator` v26.3.3, `dra-driver-nvidia-gpu` 0.4.1, `kueue` 0.18.0, `kube-prometheus-stack` 87.16.0, and the AI catalog `kueue:0.18.0` app.
- Lab, read-only: `get`, `explain`, `--help`, and `tar -t` on the bundle. I did no dry run, so I did not need the webhook check. I read no Secret value. The checks:
  - the `nkp-deletion-protection` VAP and its binding;
  - the API server flags;
  - the ClusterApps;
  - the NFD config;
  - the PriorityClasses, the IngressClass, CoreDNS, and the ResourceQuotas;
  - the bundle tags for the NVIDIA driver, cuda-sample, busybox, curl, Kueue, and NDK;
  - the CAPI label sync arguments.

**Verdict: go-with-changes.** 0 BLOCKER, 5 MAJOR, 15 MINOR.

The three skills are careful and well gated, and they use live evidence well. Examples of good work:
- The GPU app tree analysis is correct in every point I checked: the DRA default, the `nvidia-dra-driver` HelmRelease, the exact name `nvidia-gpu-operator-config-overrides`, the pre-install job, and "no common top-level value names".
- The DRA claim test was dry-run on the lab.
- The kubernetes-core blocks keep every value empty with a guard. They use `diff` and server dry runs before a change.
- The secret handling in observability is clean: the Slack URL and the Splunk and Elasticsearch passwords go through `printenv`, and the user writes `~/alertmanager.yaml`.
- The eval run already passed 24/24 (`grading.md`).

The main defects:
- The NFD label that gpu-ai checks is never set on NKP nodes (M1).
- One Loki step can overwrite the Rook bucket Secret (M2).
- The project Loki bucket cap uses a key and a ConfigMap path that do not reach the bucket chart on 2.19.0 (M3).
- The GPU pool taint advice in gpu-ai and in nkp-cluster-lifecycle is opposite (M4).
- Alertmanager way A is undone silently by the next Helm upgrade of the app, also by an override change that this skill makes (M5).

## 1. BLOCKER

None.

## 2. MAJOR

**M1. gpu-ai checks the NFD label `feature.node.kubernetes.io/pci-10de.present`. NKP's NFD never sets it.**
- Files: `skills/nkp-gpu-ai/SKILL.md:43, 84, 93, 193`; `evals/nkp-gpu-ai.md:13, 62`.
- Evidence [live 2.19.0]:
  - The NFD worker ConfigMap `node-feature-discovery/node-feature-discovery-worker-conf` has `sources.pci.deviceLabelFields: [class, vendor]`. NFD therefore writes `pci-<class>_<vendor>.present` labels, never `pci-<vendor>.present`.
  - The lab nodes show only `feature.node.kubernetes.io/pci-0300_1234.present` (5 nodes).
  - An NVIDIA GPU gets `pci-0302_10de.present` (3D controller) or `pci-0300_10de.present` (VGA). Those are the labels that the guide's own fix sets (pdf p.621). The DRA kubelet plugin affinity also accepts them (chart `dra-driver-nvidia-gpu` 0.4.1, `values.yaml:288-305`).
- Effect: step 1 shows an empty `PCI-10DE.PRESENT` column on a healthy GPU cluster. "How to read it" and the Common failures row then tell the agent that NFD failed. The agent proposes a manual `kubectl label node` (CHANGES) on every GPU node. Eval G5 found the mismatch, but graded it minor.
- Fix:
  - `SKILL.md:84`: change the `-L` list to `feature.node.kubernetes.io/pci-0302_10de.present,feature.node.kubernetes.io/pci-0300_10de.present,nvidia.com/gpu.product,nvidia.com/vgpu.present,nvidia.com/mig.config.state`.
  - `:43` and `:93`: "NKP's NFD labels by PCI class and vendor (`deviceLabelFields: [class, vendor]`) [live 2.19.0]. An NVIDIA node has `pci-0302_10de.present` (3D controller) or `pci-0300_10de.present` (VGA) `true`."
  - `:193`: in the symptom, use "no `pci-0302_10de.present` and no `pci-0300_10de.present` label".
  - Update evals G1 and G5 the same way.

**M2. Loki on S3 (L4 items 2-4) can overwrite the Rook bucket Secret `dkp-loki`.**
- File: `skills/nkp-observability/references/logging.md:109, 121, 131-162`.
- Evidence (the 2.19.0 app tree, digest-matched): `grafana-loki-v3/3.6.7/helmrelease/cm.yaml` uses `dkp-loki` in all places:
  - `extraEnvFrom.secretRef.name: dkp-loki` in each component;
  - `loki.annotations.secret.reloader.stakater.com/reload: dkp-loki`;
  - `bucketNames: dkp-loki`.

  `dkp-loki` is the Secret that Rook makes for the ObjectBucketClaim `dkp-loki` (`rook-ceph-cluster/1.19.5/objectbucketclaims/ceph-object-bucket-claim-config-defaults.yaml`: `bucketName: dkp-loki`). The guide name `nkp-loki` (p.660-661) belongs to the BYOS Ceph example and is not the default.
- Effect: item 2 reads `dkp-loki` from the defaults. Item 3 then says "Use the name from item 2 if the defaults name one". So the agent runs `create secret … dkp-loki | apply`. That replaces the keys of a Secret that the bucket provisioner owns. The provisioner can write them back, and the Ceph bucket loses its credentials.
- Fix:
  - Item 2: "The defaults use the Secret `dkp-loki`, the Rook bucket Secret [live 2.19.0]. Never write to `dkp-loki`."
  - Item 3: always make a new Secret, for example `loki-s3-creds` (ask the user for the name; rule 4). Set `secret=''` with its guard, as now.
  - Item 4: use the new name in the six `extraEnvFrom` entries, and add `loki.annotations.secret.reloader.stakater.com/reload: <the new name>`. The default annotation points to `dkp-loki`.
  - D-05 in OPEN-ITEMS: remove "the default Secret name (`nkp-loki` guide vs `dkp-loki` field)". The answer is `dkp-loki` (app tree).

**M3. Project Loki bucket cap (L10 item 3): the key and the ConfigMap path do not reach the bucket chart on 2.19.0.**
- File: `skills/nkp-observability/references/logging.md:378`.
- Evidence (app tree `project-grafana-loki-v3/3.6.7`):
  - The cap is `dkp.project-grafana-loki-v3.additionalConfig.maxSize` (default `"5G"`, `helmrelease/cm.yaml:13-24`), not the guide key `nkp.project-grafana-loki.maxSize` (p.554).
  - The bucket HelmRelease `project-loki-v3-object-bucket-claims` reads only `…-config-defaults` and `project-grafana-loki-v3-overrides` (by that exact name, `optional: true`; `object-bucket-claims.yaml:38-43`). The Loki HelmRelease `project-grafana-loki-v3` reads only the defaults, plus the Kommander cluster-overrides patch.
- Effect: L10 tells the agent to use a new ConfigMap name and `configOverrides`. The retention then reaches Loki, but the cap probably never reaches the bucket chart. The project bucket stays at 5G, and project logs stop when it is full.
- Fix:
  - Use the key `dkp.project-grafana-loki-v3.additionalConfig.maxSize` [live 2.19.0, app tree]. Keep the guide key only as "the guide writes `nkp.project-grafana-loki.maxSize` (p.554); 2.19.0 uses …".
  - Add an UNKNOWN in the observability range (for example D-34): "whether the bucket cap of project Loki must be in a ConfigMap named exactly `project-grafana-loki-v3-overrides` in the project namespace on the target cluster. Find out with: `… get helmreleases -n <project ns> -o custom-columns='NAME:.metadata.name,FROM:.spec.valuesFrom[*].name'`."
  - Until D-34 is closed, tell the user that the cap path is not confirmed.

**M4. The GPU pool taint advice in the two skills is opposite.**
- Files: `skills/nkp-cluster-lifecycle/references/variables.md:127` ("Add a taint … for example key `dedicated`, value `gpu` … The GPU operator setup must tolerate it"); `skills/nkp-gpu-ai/SKILL.md` step 2 item 5.
- Evidence: the gpu-ai skill is correct. `gpu-operator` v26.3.3 `daemonsets.tolerations` and `dra-driver-nvidia-gpu` 0.4.1 `kubeletPlugin.tolerations` tolerate only `nvidia.com/gpu:NoSchedule` (chart `values.yaml`).
- Effect: an agent that makes the pool with lifecycle V6 gets a pool where no operator or DRA pod starts. It then needs the gpu-ai N4 toleration override.
- Fix (owner nkp-cluster-lifecycle; the authors asked for this change, and it is right): `variables.md:127`: "Add the taint key `nvidia.com/gpu`, effect `NoSchedule` (the GPU operator and DRA driver tolerate only this key; skill `nkp-gpu-ai`, step 2)". The generic example at `:68` can stay.

**M5. Alertmanager way A (replace the Secret) is undone by the next Helm upgrade of `kube-prometheus-stack`, also by an override change that this skill makes.**
- File: `skills/nkp-observability/references/monitoring.md:169-202` (way A and D-31).
- Evidence:
  - Chart 87.16.0 `templates/alertmanager/secret.yaml` renders `alertmanager-<name>` from `alertmanager.config` unless `alertmanager.alertmanagerSpec.useExistingSecret: true`.
  - The NKP defaults set `alertmanager.config` (route to `'null'`; `kube-prometheus-stack/87.16.0/helmrelease/cm.yaml:462-475`).
  - The HelmRelease has `upgrade.serverSideApply: enabled`. Helm owns the Secret.
- Effect: each Helm upgrade writes the NKP default config again. A Helm upgrade comes with a platform upgrade, and also with each override change in M1, M2, M5, or M6 of the same file. The receivers stop silently. D-31 is effectively answered.
- Fix:
  - At way A: "Helm owns this Secret [field: chart 87.16.0 template]. Each change of the app values (M1, M2, M5, M6, an upgrade) puts the NKP default back. After each such change, do way A again, or use way B."
  - Change D-31 to the open part only: whether `alertmanager.alertmanagerSpec.useExistingSecret: true` in the M-override keeps a user Secret on NKP 2.19.
  - Add an eval step to B2: an M1 change after way A must warn about the receivers.

## 3. MINOR

1. **Wrong tags in Kueue A3** (`ai-apps.md:43, 86`).
   - "Kueue 0.18 serves `kueue.x-k8s.io/v1beta2` [live 2.19.0][pdf p.625]": p.625 has no API version, and the lab has no Kueue. The fact is true: upstream chart 0.18.0 CRDs serve `v1beta2` and store it. Tag it `[field]`, or log the chart read in `gpu-ai.txt`.
   - The `controllerManagerConfigYaml` and `kueue-system-kueue-manager-config` facts have the same problem. They are also true: the catalog app HelmRelease `kueue` has `targetNamespace: kueue-system`, and Flux names the release `kueue-system-kueue`.
   - Partly close D-43: Kueue → `kueue-system` (catalog app `kueue:0.18.0`, `helmrelease/helmrelease.yaml`).
2. **"Slot-2 name" is wrong for these apps.**
   - `monitoring.md:14`: the `kube-prometheus-stack` HelmRelease does not read `kube-prometheus-stack-overrides`. Its direct read is `kube-prometheus-stack-mgmt-overrides` (optional) [app tree].
   - `insights.md:17`: the `nkp-insights` HelmRelease reads only its defaults.
   - Fix: "The guide name is not read directly by this HelmRelease (O2 shows `valuesFrom`). Use the O3 name rule."
   - The same fact partly closes D-30. The HelmRelease reads `kube-prometheus-stack-mgmt-overrides` by name, after the defaults. A new `configOverrides` adds `kube-prometheus-stack-cluster-overrides` after it, so a user `prometheus.additionalServiceMonitors` there replaces the NKP list. The current text already warns about this.
   - Cross-skill (owner gitops): `overrides.md` O1 slot 2 says `<app-id>-overrides` as if every app read it. Write "for apps whose HelmRelease lists it (check with O2)".
3. **D-32 can be answered.**
   - The HelmRelease `logging-operator-logging` reads `logging-operator-logging-overrides` by name, `optional: true` (`logging-operator/6.7.0/logging-operator-logging/logging-operator-logging.yaml`). The `logging-operator` HelmRelease reads only its defaults.
   - So the direct ConfigMap on the target cluster, in the HelmRelease namespace, is the way. The p.560 way works on the management cluster only because the namespace is `kommander` there.
   - Close D-32 with this evidence, and in L2 keep only the first branch. The READ-ONLY check can stay.
4. **gitops does not list the GPU name exception** (cross-skill, owner gitops).
   - `overrides.md` O1/O3 lists `velero-overrides` as the only name exception. Add `nvidia-gpu-operator-config-overrides`: the `nvidia-dra-driver` HelmRelease reads it by name.
   - On the management cluster, that name is in `kommander`, which is also the HelmRelease namespace. So O5 item 5 (remove `configOverrides`) does not remove the DRA values. Only a delete of the ConfigMap does.
   - gpu-ai `SKILL.md:119` can say this in one line.
5. **`nkp-deletion-protection` is incomplete in kubernetes-core** (`SKILL.md:214`). The lab VAP (6 validations, `Deny`+`Audit`, `failurePolicy=Fail`) also has these rules:
   - a `strict` object can never change its label value, and so it can never be deleted;
   - a `standard` label cannot be removed;
   - only a user whose name does not start with `system:` can change `standard` to `revoked`.

   The lab has no object with the label: I checked 360 listable resource types and found 0. Move the fact to the owner (identity; see section 5), keep a one-line pointer here, and add "no object had the label on 2.19.0 [live]".
6. **The DenyServiceExternalIPs fact is copied** (ADR 0001). `networking.md:29` repeats the admission plugin fact. Identity `cluster-security.md:112` already lists the API server plugins. Keep the symptom → fix line ("`externalIPs` is rejected; use a `LoadBalancer` Service"), and point to identity for the flag list.
7. **`GrafanaLokiV2NotDeployed` is normal: the evidence is too narrow.** The evidence is a Starter cluster with no logging apps (`observability-skill.txt`). `logging.md:37` says "On a healthy 2.19.0 cluster". Write "seen on 2.19.0 when no Loki v2 was ever installed". The same applies to `SKILL.md:162`. The claim is plausible (the message text), but it is not tested with Loki v3 running.
8. **Rule 5 deviation in the NAI pull Secret block** (`ai-apps.md:131`). The guard `: "${NUTANIX_REGISTRY_USERNAME:?…}" "${NUTANIX_REGISTRY_TOKEN:?…}"` expands the secret. It prints nothing, but rule 5 says to check secrets only with `printenv`. Use the form of the other skills: `k=$(printenv NUTANIX_REGISTRY_USERNAME >/dev/null && printenv NUTANIX_REGISTRY_TOKEN >/dev/null && echo ok); : "${k:?…}"`.
9. **D-41 note.** On 2026-11-03 I checked that `nvcr.io/nvidia/driver:580-6.8.0-124-generic-ubuntu24.04` exists upstream (`crane manifest`). The bundle has only `580-6.8.0-111`, `580-5.15.0-176`, and `595-6.8.0-134` [live, `tar -t`]. Keep `[field]` in `nvidia.md:59`. This is the image for the airgap row (section 5).
10. **A lifecycle fact is copied.** `nvidia.md:168` restates the CAPI label sync (`nvidia.com/` prefix). Lifecycle `variables.md:66` owns it (lab: `--additional-sync-machine-labels=^nvidia\.com/.*,…`). Keep only the pointer.
11. **Missing evidence line.** `kubectl api-resources --api-group` (`SKILL.md` step 2 of kubernetes-core) is not in `kubernetes-core.txt`. It exists [live, checked]. Add the help line to the live file.
12. **The Trivy example tag looks real.** `insights.md:113` has the tag `0.64.1-20261101T000000Z`, and the eval model copied it (grading item 1). I agree with the grader. Replace it with the bundle tag and the comment "change the date part to the new tag".
13. **`APP_ID` has no guard** (grading item 3, owner gitops). The O2 and O3 blocks use `$APP_ID` with no `: "${APP_ID:?}"`. I agree with the grader.
14. **Two ways are kept for the precompiled driver** (`nvidia.md:47-73`). `nvidiaDriverRoot: /run/nvidia/driver` is correct only in mode B, and the text says so. The sentence "A GPU image of the Nutanix Ubuntu image is not needed for driver mode B" (`:28`) is good. No change is needed, except this: when the user chooses mode A after a failed mode B, they must remove `nvidiaDriverRoot`. Add one line.
15. **Inference with a pdf tag.** `ai-apps.md:157`: "single NAI pods can block the node drain [pdf p.336]". p.336-337 only say to add replicas before a Kubernetes upgrade. Write "The guide adds replicas before the upgrade [pdf p.336-337]", and tag the drain reason `[field]`.

## 4. Commands, flags, and facts checked

| Claim | Result | Evidence |
|---|---|---|
| DRA is on by default in 2.19 | correct | pdf p.610; app defaults `devicePlugin.enabled: false`, DRA chart on; lab feature gates (`gpu-ai.txt`) |
| `nvidia-gpu-operator-config-overrides` is the only name the DRA driver reads | correct | `dra-driver/dra-driver.yaml` valuesFrom `${releaseName}-config-overrides` (comment: "the text input in the NKP UI") |
| Toleration key `nvidia.com/gpu` only | correct | chart values: gpu-operator `daemonsets.tolerations`, DRA `kubeletPlugin.tolerations` |
| No common top-level value names | correct | `comm` of the top-level keys of both charts: empty |
| Kernel mismatch D-41 | correct | bundle tags (lab `tar -t`); pdf p.14 lists Ubuntu 24.04 `6.8.0-124-generic`; p.13 lists 22.04 `5.15.0-185` |
| AMD and NAI are not in the 2.19.0 bundle | correct | bundle tags: AI catalog bundle has no `amd*`; product bundle has only `ndk` 2.3.0. The public `collection:2.19` now lists `amd-kmm-operator` 1.0.0 and `amd-gpu-operator` 1.5.1 |
| "Multiple ClusterPolicies found" job failure | correct | `preserve-existing-deviceplugin-configuration.sh:108` |
| cuda-sample and busybox in the bundle | correct | lab `tar -t` |
| Guide app versions are not ClusterApps on 2.19.0 | correct | lab `get clusterapps`: `logging-operator-6.7.0`, `rook-ceph-cluster-1.19.5`, `kube-prometheus-stack-87.16.0` only; pdf p.558 shows `6.4.0`, `1.19.6` |
| `GrafanaLokiV2NotDeployed` is normal | plausible, evidence narrow | minor 7 |
| `nkp-deletion-protection` VAP | correct, incomplete | minor 5 |
| `DenyServiceExternalIPs` | correct | lab kube-apiserver `--enable-admission-plugins=DenyServiceExternalIPs,…` |
| No `--event-ttl` (1 h default) | correct | lab kube-apiserver command |
| PriorityClasses, IngressClass `kommander-traefik` (default), CoreDNS v1.14.2 ×2, NKP quotas | correct | lab |
| Kueue ConfigMap `kueue-system-kueue-manager-config`, `v1beta2` | correct (tag wrong) | minor 1 |
| `trivy-bundles:0.64.1-20260929T031542Z`, `imageFull` | correct | `nkp-insights/1.9.7/helmrelease/cm.yaml:701`; bundle |

`bash -n`: 82/82 pass. Scrub: I found no IP, host name, cluster name, UUID, user, or token in the diff (the only IPs are documentation ranges). The live files use `<mgmt-cluster>`, `<ip>`, and `<node>`.

**Commit 96729af (`nvidia.com`, `nvcr.io` in `ALLOWED_DOMAIN_SUFFIXES`): right.** Both are public vendor domains in resource names (`nvidia.com/gpu`), labels, and image references. They are not site data. Air-gapped skills need them as text. No URL to them is in the skills, so the "no web" rule is kept. The only risk is a private host under these domains, and that is not realistic.

## 5. Cross-skill changes that the authors asked for

| Request | Right? | Note |
|---|---|---|
| nkp-cluster-lifecycle V6: GPU pool taint key `nvidia.com/gpu` | **Yes, and it is needed** (M4) | `variables.md:127` |
| nkp-airgap rows (GPU driver image for the node kernel; AMD and NAI not in the bundle) | Yes | Add a C3 or prestage example for `nvcr.io/nvidia/driver:580-<kernel>-ubuntu24.04` (`580-6.8.0-124-generic-ubuntu24.04` exists upstream). For AMD and NAI, add only pointers to D-44 and D-45 in gpu-ai. Do not copy the gpu facts. |
| nkp-identity-security owns `nkp-deletion-protection` | Yes | It is an NKP admission policy, and identity owns admission (Gatekeeper, PSA). Use the full rule set of minor 5. Also add a row in nkp-troubleshooting `deletes.md`: "delete denied by ValidatingAdmissionPolicy `nkp-deletion-protection`" → identity. |
| nkp-networking pointer to DenyServiceExternalIPs | Optional, low value | The flag fact already has an owner: identity `cluster-security.md:112`. A one-line pointer in the networking LoadBalancer section ("`externalIPs` is rejected → use MetalLB") is enough. |
| nkp-storage-backup O2 back-pointer to observability | Yes | O2 keeps the `rook-ceph-cluster` override for the workspace Loki cap (`dkp.grafana-loki.additionalConfig.maxSize`: a rook-ceph-cluster value, read by the OBC HelmRelease). Add "Loki retention and store: skill `nkp-observability` (`logging.md` L3-L4)". The project Loki cap belongs to observability (M3). |

More requests from this review: gitops O1/O3 (minor 2, 4, 13), and closing D-30, D-32, and part of D-05 and D-43 in OPEN-ITEMS (M2, minor 1-3).

## 6. Top fixes, in order

1. M1: the NFD label (all GPU node checks are wrong now).
2. M2: never write `dkp-loki`; use a new Secret name and the reloader annotation.
3. M4: lifecycle V6 taint key.
4. M5: the way A warning and D-31.
5. M3: the project Loki cap key, and D-34.
6. Then the minor items, in this order: 8 (secret check), 4, 2, 3 (override paths), 5, 6 (ownership), then the rest.

Then run the check script, and run evals G1, G5, B2, B3 again, plus a new eval for Loki on S3 (L4).

Not checked:
- I did not run the evals again.
- The lab is Starter with no GPU and no logging apps. So M3, M5, D-40, and D-42 depend on the app tree and the chart templates, not on a running app.
- I did not check that the NKP UI makes `nvidia-gpu-operator-config-overrides`. Only the comment in the app tree says so.
