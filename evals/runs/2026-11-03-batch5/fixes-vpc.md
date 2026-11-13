# Batch 5 fix pass: nkp-vpc (and its cross-skill rows)

Date 2026-11-03. Scope: `review.md` M2, M3, minors 1, 13, 14, 15, 16, the vpc line of minor 17, and the section 5 rows for nkp-install, `cni.md` C5, and `ingress-certs.md` I3.
Checks: `check_skills.py --self-test` and `check_skills.py` pass (16 skills, 0 errors). `bash -n` passes on all 56 command blocks of the touched files (nkp-vpc SKILL.md and layouts.md, install `nutanix.md`, networking SKILL.md, `cni.md`, `ingress-certs.md`, lifecycle `delete.md`). Line counts: vpc SKILL.md 246, layouts.md 83, `nutanix.md` 382, `cni.md` 159, `ingress-certs.md` 224, networking SKILL.md 155, `delete.md` 137, `evals/nkp-vpc.md` 103.
Lab: not used in this pass.

## review.md

- M2 fixed (skills/nkp-vpc/SKILL.md:39, :89-91; references/layouts.md L1; evals/nkp-vpc.md V1, V7, new V8). Step 2 now says: management cluster → `SUBNET` in `~/nkp-site.env`; workload cluster → `SUBNET` (and `PE_CLUSTER`, `STORAGE_CONTAINER` when they differ) in its cluster env file, with the reason (the cluster file sources the site file first, so its line wins only for this cluster). The variable line at :39 no longer says "site file". L1 has one line for all multi-subnet layouts. V7 expects the cluster env file and FAILs a site-file append. V1 says why the site file is right there (management cluster). New V8: a second workload cluster in another VPC (own env file, own floating IPs, site file and team-x file unchanged).
- M3 fixed (SKILL.md:114-134). The read-only block reads `daemon.json` with `sudo -n` and prints only the `mtu` key, and lists the running containers (`running: …`). The text says: if a name shows, stop and ask the user; the block needs `jq` and `sudo` without a password. The CHANGES block checks `sudo -n true`, reads the file with `sudo`, makes `daemon.json.bak` (`cp -p`), writes with `sudo tee` (owner and mode stay), and restarts Docker only if `jq` gave a non-empty file. A `trap` removes the temp file. One line after the block: invalid JSON changes nothing.
  - Test on temp files (no real `/etc` change; `sudo`, `systemctl`, and the NIC MTU stubbed, `/tmp/b5vpc/block.sh`):
    - a mode-640 file with `data-root`, `registry-mirrors`, `mtu 1500` → all keys kept, `mtu 1442`, mode 640 kept, `.bak` = old file, restart called;
    - a file that is not JSON → `jq` parse error, rc 5, file unchanged, no restart;
    - no file → `{"mtu":1442}`, restart called;
    - the read-only line on a file with `proxies.http-proxy` holding a password → prints only `daemon.json mtu: none`.
- minor 1 fixed (SKILL.md:84). `FIP_API` → `CP_VIP` keeps `[pdf p.720-721]`. `FIP_UI` → first LB IP is now `[portal][live 2.19.0]`.
- minor 13 fixed (SKILL.md:121). `cat /etc/docker/daemon.json` is replaced by the `jq` line that prints only `mtu` (see M3).
- minor 14 fixed. The CIDR block (SKILL.md:96-97) now sources `~/nkp-site.env`: it uses no cluster variable. The blank lines before `## Step 2`, `## Step 3`, `## Step 4`, `## Common failures`, `## Related skills`, and before "**Another `LoadBalancer` Service…**" are back. To make room, the "Change `FIP_API`" paragraph with N-42 moved to new `layouts.md` L7. Step 6 keeps one line and a link.
- minor 15 fixed.
  - SKILL.md:47 no longer says what `--extra-sans` does. It points to networking step 3, row "API server certificate SANs". The VPC live fact stays (the external endpoint is in the SANs, `CP_VIP` is not).
  - SKILL.md:48 no longer names the NKPCluster ingress field. It points to `ingress-certs.md` I1.
  - Step 6 (SKILL.md:191) no longer has its own dry-run and patch blocks (−13 lines). It says: append `UI_HOSTNAME` and `INGRESS_HOSTNAME` (same value), then use the new I3 hostname-only patch. The "patch the NKPCluster, not the KommanderCluster" live fact stays, because V3 tests it.
  - `ingress-certs.md` I3 has a new "Hostname only" variant: skip steps 1-2, a READ-ONLY block prints the patch body, and the steps 3-4 blocks use it. The dry-run acceptance is `[live 2.19.0]` (`vpc.txt`, dry run 2).
  - `cni.md` C5: the 1442/1392 line is now a pointer to `nkp-vpc`.
- minor 16 fixed (SKILL.md:147; OPEN-ITEMS N-40). Upstream kind makes a new `kind` network with the bridge MTU, tagged `[field: kind source]`. The re-create block stays for an old network.
- minor 17, vpc line: same as M2 (V7, V8).

## Section 5 (cross-skill)

- nkp-install `nutanix.md`:
  - N5 step 2 (:308): the same rule for any workload cluster on another subnet (`SUBNET`, and `PE_CLUSTER`, `STORAGE_CONTAINER` if they differ, go to the cluster env file).
  - N4 (:132): "Cluster in a Flow VPC: add the lines from skill `nkp-vpc`, step 4."
- nkp-networking:
  - `cni.md` C4 (:110): the N-01 lab result (DSR worked through a NAT floating IP, 6 of 6, `[live 2.19.0]`), and what is not tested.
  - C5: pointer only (minor 15).
  - `ingress-certs.md` I3: hostname-only variant (minor 15).
  - SKILL.md step 3: the SANs row points to `nkp-vpc` for the external endpoint.
- nkp-cluster-lifecycle `delete.md` D5:
  - The VPC row says to record the VPC list (skill `nkp-vpc`, step 7) before the file cleanup, and why.
  - New row: after a delete of a Flow CNI cluster, remove the user HelmChartProxy with skill `nkp-flow-cni` (N-36).

## OPEN-ITEMS

- N-01: the result is now in `cni.md` C4. Still open (Network Controller VLANs and no-NAT not tested).
- N-40: kind source evidence `[field]`. Still open (not tested with `nkp create bootstrap`).
- N-42: the skill text is now in `layouts.md` L7.
- N-02, N-04, N-05, N-41, N-43 to N-46: no change (no new evidence).
- The "Last updated" line is not changed (the parent does it).

## Not done, and changes other files need

- Run evals V1, V2, V3, V7, and V8 again (not run in this pass). V3 now goes through the networking I3 pointer.
- The rules block (rule 4) and the variable table still list `SUBNET`, `PE_CLUSTER`, `STORAGE_CONTAINER` only as site variables. The check script accepts them in a cluster env file append. Nothing breaks. ADR 0003 could say once that a cluster file may override a site value for its cluster (owner: parent).
- nkp-cluster-lifecycle `SKILL.md:212` (new node pool with `"$SUBNET"`) is correct after this fix, because its block sources the cluster env file. No change needed.
