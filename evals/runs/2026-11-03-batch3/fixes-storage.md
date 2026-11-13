# Batch 3 fix pass: nkp-storage-backup

Date 2026-11-03. Base cfc4589. Scope: `review.md` M4 and minors 2, 3, 9, 11 (`caCert`), 15 (velero.md), 16; `grading.md` finding 1 (S3 FAIL); the lifecycle `deletion` note.
Checks: `check_skills.py --self-test` and `check_skills.py` pass. `bash -n` passes on all 17 command blocks of velero.md. Shell fixes tested in `/tmp/b3fixS`: the restore block with a stub `velero` (empty and non-empty `sel` array give the right argv), the `:?` guards (empty value stops the block), and the `caCert` base64 line (round trip gives the PEM back). Lab: no new commands. The live file notes why B3 has no `kubectl` Backup form (`research/raw/live/2.19/storage-skill.txt`, last section).
Line counts: SKILL.md 176, csi.md 252, object-storage.md 141, velero.md 323.

## review.md

- M4 fixed (skills/nkp-storage-backup/SKILL.md:168; references/velero.md:53). The BSL pointer is B9 (failures), not B8 (restore).
- minor 2 fixed (references/velero.md:104, :126). Guards on `VELERO_NS`, `BSL_NAME`, `OBJECTS_ACCESS_KEY`, `OBJECTS_SECRET_KEY` (Secret block) and `VELERO_NS`, `BSL_NAME`, `OBJECTS_BUCKET`, `OBJECTS_URL` (`backup-location create`). Tested.
- minor 3 fixed (references/velero.md:22). No pointer to nkp-airgap. Text: "How to get it is not in the skills"; the user gets the v1.18 CLI on a connected host and checks the SHA-256 against the release page. The same line names the sections that need the CLI (B3, B4 item 3, B6, B7, B8): stop and tell the user.
- minor 9 fixed (references/object-storage.md:22, :117; references/velero.md:182, :189). Plain `ceph.rook.io/DeviceSet`, `<ceph-namespace>.ceph.rook.io/bucket`, `backup.velero.io/backup-volumes`. The `printf` and quote tricks are gone.
- minor 11 (`caCert`) fixed (references/velero.md:132, :144, :160-168). The values text says which site variables fill `<bsl-name>`, `<bucket>`, `<objects-url>`. A READ-ONLY block prints the one-line Base64 of `OBJECTS_CA_FILE` (a CA is not a secret). No CA file: remove the `caCert` line. Tested. The `gatekeeper.md` part of minor 11 is not mine.
- minor 15 (velero.md part) fixed (references/velero.md:218, :223, :243-263). `kc=''` with a `:?` guard; the text gives the two values. The B7 restore is one parameterized block (`row`, `res`, `sel` array) and the table has one row of values for each restore. Tested with a stub. The `rbac.md` and `IDP_*` parts are not mine.
- minor 16 fixed (evals/nkp-storage-backup.md:104, S9). B7 eval: one plan for pause, backup, check, resume; resume also after a failure; no B8 steps; no PV data.

## grading.md

- Finding 1 (S3 FAIL) fixed.
  - B3 (references/velero.md:59): no CLI → stop and tell the user. No `kubectl apply` of a `velero.io/v1` `Backup`: the form is not in the guide (it gives only the CLI for backups), and the Starter lab has no Velero CRD, so `kubectl explain` cannot confirm a schema [live 2.19.0].
  - B1 (references/velero.md:35) and Facts (:18): `VELERO_NS` comes only from the B1 output, not from the guide page (p.532) or an example.
  - Eval S3 (evals/nkp-storage-backup.md:42-44): expects the stop without the CLI; FAIL for a namespace from the guide page or a `kubectl apply` Backup.
- S8 minor (append block in the same reply): not fixed. Model behavior; rule 4 is clear and the batch 3 grading routes the point-of-use text to identity and gitops.

## Lifecycle note

- Checked (references/csi.md:201). nkp-cluster-lifecycle SKILL.md:136 lists `workers/machineDeployments/<i>/deletion` in the step 3 topology block, so the pointer lands. Added the `value` form for `nodeVolumeDetachTimeoutSeconds` and a warning: `add` replaces all of `deletion`, so keep its other keys (for example `nodeDrainTimeoutSeconds`). The lifecycle example names only the drain timeout; no lifecycle change is needed.

## OPEN-ITEMS

- No change to D-20..D-29. No new UNKNOWN.

## For other files

- nkp-airgap: optional P-row for the velero v1.18 CLI tarball with its SHA-256 (prestage, `download-urls.txt`). If it is added, velero.md:22 can point to it again.
