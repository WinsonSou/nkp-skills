# Lab test 1 — NKP 2.19.0 management cluster from scratch (scrubbed log)

Operator host `<bastion>`; agent runs on a laptop and sends each block over `ssh <bastion> 'bash -s'`.
Cluster `skilltest-mgmt-01`. Case N4C (site Harbor mirror), Pro/Ultimate trial, Ubuntu 24.04 image, 3 CP + 4 workers (CLI defaults).

## 1. Env files (CHANGES, approved 2026-11-03)

- `~/nkp-site.env` (600): PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NTP_SERVERS BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE
- `~/nkp-skilltest-mgmt-01.env` (600): CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS
- `bash -n` on both: `set: syntax`.

## 2. N2 + N3 (READ-ONLY)

- N2: `set:` for all 19 names (incl. mirror credentials and `NKP_LICENSE_KEY`).
- N3: `nkp: v2.19.0`; PC `curl` → `302`; `CP_VIP` no ping reply; `.51–.55` no reply; key file and CA file found; bootstrap image tar found.
- Extra (not in skill): Harbor API with mirror credentials + CA → `200`; PC v4 API with NUTANIX_USER → `200`.
- `nkp create cluster nutanix --help`: `--timeout` default `30m0s`; `--insecure` exists. [live 2.19.0]

## 3. Create script + dry run (CHANGES, approved)

- Script `~/nkp-skilltest-mgmt-01-create.sh` = N4C template + `--insecure` + `--timeout 60m`.
- Dry run `--dry-run --output yaml` → rc 0 in ~3 min. stderr shows it **creates a kind bootstrap cluster, installs CAPI, runs preflight checks (passed), then deletes the bootstrap cluster**. [live 2.19.0] No bootstrap container left after it.
- Output 11951 bytes, 7 Secrets (`*-pc-credentials`, `-for-ccm`, `-for-csi`, `-for-konnector-agent`, `-image-registry-mirror-credentials`, `global-nutanix-credentials`, `prism-central-metadata`), NKPCluster `skilltest-mgmt-01` (ns `kommander`, annotation `kommander.d2iq.io/host: "true"`), ConfigMap `kommander-bootstrap-configuration`.
- Values seen: CP replicas 3, CP 4 sockets/16Gi/80Gi, md-0 8 sockets/32Gi/80Gi with autoscaler min=max=4, subnet PRIMARY-IPAM, image ubuntu-24.04 1.36.2, CNI Cilium, MetalLB <net>.51–.55, KubeVIP host <net>.50:6443, `ntp.servers: [<ntp>]`, mirror url `https://<registry-host>/nutanix` with `ca.crt` in the mirror Secret, PC `insecure: true`, `additionalTrustBundle: ""` in the PC credentials Secret.
- P-07: not answered (no PC_CA_FILE set). The key `additionalTrustBundle` lives in the PC credentials Secret data.

## 4. Create (CHANGES, approved) — RC=0

- Started 13:28:26 in tmux, log `~/skilltest-mgmt-01-create.log` (600). Finished 13:52:25 (**24 min**).
- Timeline: bootstrap image load 12 s → kind up → CAPI → preflight → create; machines ready ≈ 13:34 (kubeconfig file written 13:34); move (pivot) 13:36:46; Kommander core 13:37–13:52 (`14 core applications`, last ones `kubefed`, `traefik-forward-auth-mgmt`).
- **A-05 answered:** the create prints `Cluster kommander/skilltest-mgmt-01 kubeconfig was written to to the filesystem` and the file is `$PWD/<cluster>.conf` (here `~/skilltest-mgmt-01.conf`, mode 600). [live 2.19.0]
- Final line: `Cluster was created successfully! Get the dashboard details with: nkp get dashboard --kubeconfig=...`

## 5. Verify (READ-ONLY, MGMT_KUBECONFIG set inline, not yet in env files)

- `nkp describe cluster`: 3 CP + 4 worker Machines READY True; Cluster/ControlPlane rows empty READY (as skill says).
- NKPCluster `Reconciled`, v2.19.0, k8s v1.36.2.
- HelmRelease wait: 24 condition met. Nodes 7 Ready, Ubuntu, IPs from pool .81–.120.
- Non-running pods: none. Pod wait: 145 condition met.
- N6: `nutanix-volume (default)`; IPAddressPool `metallb` `<net>.51-<net>.55`; ntnx-system and Cilium pods all Running/ready; `kommander-traefik` EXTERNAL-IP `<net>.51` (= first LB IP).
- License `nutanix-license tier=Starter valid=true` (before the trial key).

## 6. Session autonomy (user, 2026-11-03 evening)

User approved blocks C and D, then granted **standing approval for the rest of this session** (user offline). Orchestrator: Opus; executors: DeepSeek-V4.1-Flash subagents. Scope granted:
- Try the license on `skilltest-mgmt-01` (expected to fail: the key is bound to cluster name `nkp-mgmt-01`), then delete it and recreate the management cluster as **`nkp-mgmt-01`** (same IPs .50 / .51–.55), then license it.
- Workload clusters: wl1 `CP_VIP .60`, LB `.61–.65`; wl2 `.70`, `.71–.75`; spare `.40`, `.41–.45`.
- PC: may use `<vpc>` for a VPC test, may create `skilltest-*` subnets/VPCs, may delete the old `<old-mgmt-cluster>` leftovers (2 FIPs, 3 volume groups).
- End state: delete all clusters; log everything in LEARNINGS.md.

## 7. Blocks C + D (CHANGES, approved)

- C: `MGMT_KUBECONFIG` → site file, `CLUSTER_KUBECONFIG` → cluster file.
- D1: `set: NKP_LICENSE_KEY`; 4 workers 8 CPU / ~31 GiB allocatable. Status before: `{"clusterCapacity":0,"coreCapacity":0,"customerId":"","dkpLevel":"Starter","licenseId":"","productName":"NKP","productSKU":"","valid":true,"version":""}`, spec `{}`.
- D2: `secret/nutanix-license-secret` created.
- D3: webhook `kommander-licensing-validating` sideEffects `None`. Server dry run of the patch → `NotAcceptable: admission webhook "webhook.licensing.kommander.mesosphere.io" denied the request: data.nutanix-license-key: Invalid value: "<REDACTED KEY>": error decrypting license key: License key is not valid for this cluster`. **The webhook echoes the full license key in the error.**
- D4: real patch → same denial; status unchanged (Starter, valid). Expected: the key is bound to cluster name `nkp-mgmt-01`.
- Licensing log only shows `LicenseClusterCount` "self-attached … ignored" lines; nothing about the key.
