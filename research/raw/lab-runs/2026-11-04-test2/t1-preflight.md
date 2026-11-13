# T1 — preflight (read-only)

Executor `lt2-test-1`. Date 2026-11-04. Task `t1-preflight`. NKP 2.19.0.
Scope: read-only. No CHANGES block ran on a cluster, Prism Central, or the registry. The only write: the local repo file `research/raw/live/2.19/nkp-help-ops.txt` (appended, as the task allows).

Skills used, in order: router `skills/nkp/SKILL.md` → `nkp-install` (step "Check the operator host", `references/nutanix.md` N2, N3) → `nkp-airgap` (step 2, `references/nodes.md` "Check that the site mirror has an image", A-30, A-31) → `nkp-flow-cni` (step 1, step 2, `references/install.md` I2). Companion: `nutanix-api` (client), `nutanix-nkp` ("Site preflight", "Leftover audit for a cluster"), `nutanix-networking` ("Free IP check for a VIP or an LB range", "VPCs"), `nutanix-vm` ("Images: check before a create"), `nutanix-iam` not needed.

Facts from the site file (values scrubbed): `SUBNET=PRIMARY-IPAM`, `PE_CLUSTER` = the AHV cluster, `STORAGE_CONTAINER=SelfServiceContainer`, `VM_IMAGE=nkp-ubuntu-24.04-release-cis-1.36.2-20261014170313`, `REGISTRY_URL` = `<registry-host>/nutanix`, `NTP_SERVERS` = 1 server, no `PC_PROJECT`, no proxy.
Node subnet (`SUBNET`): VLAN, `<net>.0/25`, pool `<net>.81`–`<net>.120`, gateway `<net>.1`. So `<net>` = the /24 of the node subnet. All test IPs are inside the /25 and outside the pool.

## Blocks and key output

All blocks are in `blocks/t1-preflight/` (scrubbed). Each one is a read-only block; the ssh form has `timeout` and the keepalive flags. No block ran a CHANGES step.

### 01 — `01-bastion-tools.sh` (tools, self-check of nkp-install "Check the operator host")

Result: every tool the two skill sets need for this job is present. `podman` is absent, but `docker` is there (the skill needs one of the two).

```
Ubuntu 24.04.5 LTS, x86_64, cgroup2fs
nkp /usr/bin/nkp              kubectl /usr/local/bin/kubectl     docker /usr/bin/docker
tmux 3.4                      yq mikefarah v4.54.1                jq-1.7
curl openssl tar ping ip awk sed grep seq stat df nproc free sha256sum python3 scp ssh
MISSING: podman
nkp: v2.19.0   (catalog v0.11.1, diagnose v0.14.0, imagebuilder/kommander/konvoy/konvoybundlepusher v2.19.0, mindthegap v1.26.1)
Client Version: v1.37.2   Kustomize v5.8.1
docker 29.9.2
nproc 16, 31 GB RAM, 848 GB free on /
```

- `nkp` v2.19.0 matches the target. kubectl v1.37.2 is the bundle version; the bundle's Kubernetes is 1.36.2, so the client is one minor ahead — inside the skew policy the skill names.
- `yq` is mikefarah **v4.54.1** — the exact need of `nkp-flow-cni/references/install.md` I2.
- **No missing tool for the management create, the Flow CNI path A, or the delete path.**
- No cluster env file in `~` (as the task said); `~` holds `flow-cni-1.1.0.tar`, `nkp-bundle_v2.19.0_linux_amd64.tar.gz`, `nkp-site.env`, `nkp-v2.19.0/`.

### 23 — `23-tools-extra.sh` (the remaining tools that the blocks call)

`base64 tr sort uniq head tee mktemp cut xargs find` — all found. `base64` matters: N4C builds `--additional-trust-bundle` from it.

### 02 — `02-site-env.sh` (env file, nkp-install N2)

```
set: syntax
4C list: PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE NTP_SERVERS  -> all set
MISSING: IMAGE_BUNDLES
optional: PC_CA_FILE MISSING, PC_PROJECT MISSING, NKP_HTTP_PROXY MISSING, NKP_HTTPS_PROXY MISSING, MGMT_KUBECONFIG set (dangling: expected, no management cluster)
secrets: NUTANIX_USER set, NUTANIX_PASSWORD set, REGISTRY_MIRROR_USERNAME set, REGISTRY_MIRROR_PASSWORD set,
         NUTANIX_REGISTRY_USERNAME MISSING, NUTANIX_REGISTRY_TOKEN MISSING, NKP_LICENSE_KEY set
files: BUNDLE_DIR ok, REGISTRY_CA_FILE ok, SSH_PUBKEY_FILE ok
```

- Everything the management create on a site mirror (N4C) reads is present: the URL, the CA, the mirror credentials, the bootstrap image, the NTP list, the image, the container, the SSH key, the PC endpoint and the license key.
- `NUTANIX_REGISTRY_*` is missing and **not needed**: that pair is only for case 4A (connected, no mirror).
- `IMAGE_BUNDLES` is missing. It is only for `nkp push bundle` (nkp-airgap step 4); a seeded mirror does not need it. Consequence for T3: the Flow CNI bundle push needs `REGISTRY_PUSH_USERNAME`/`REGISTRY_PUSH_PASSWORD` and `EXTRA_BUNDLE`, and all three are **MISSING** (block 20).
- `FLOW_CNI_PULL_USERNAME`/`FLOW_CNI_PULL_TOKEN` missing — correct for a dark site (`install.md` I4 adds no pull secret).

### 03 — `03-pc-preflight.py` (ntnx "Site preflight")

```
PE_CLUSTER <ahv-cluster>, NTP 1 server, DNS 1 server, cluster VIP <net>.37, data services IP <net>.38
SUBNETS: PRIMARY-IPAM VLAN <net>.0/25 pool <net>.81-<net>.120 gw <net>.1
         SECONDARY-IPAM-VPC-EXT VLAN external <net>.128/25 (VPC external)
         <lab-vpc>-sn1 OVERLAY <overlay-net>.0/24
CONTAINERS: 3 user containers + NutanixManagementShare (internal)
IMAGES: 1 image (the site image), DISK_IMAGE, 30.0 GiB, copy on the AHV cluster
VPCs: <lab-vpc> (REGULAR, 1 external subnet) — pre-existing, not mine
```

### 04 + 05 + 06 + 07 — free IP check (ntnx `nutanix-networking` "Free IP check")

The recipe cannot run as one block: the client runs on the laptop, the ARP probe must run on the L2 host (the bastion). Split in two, then corrected (see Learnings L-01).

```
04 (API sources, laptop): 18 addresses, holder=null, inPool=false for every one
05 (recipe arp(), bastion): PRESENT for all 18   <-- false
06 [exploration] ip neigh raw: `<net>.50 dev ens3 INCOMPLETE` (no lladdr); live hosts show lladdr (STALE/REACHABLE)
07 [exploration] corrected: FREE (INCOMPLETE) for all 18
08 (N3 ping, bastion): no reply for all three VIPs and all 15 LB IPs
```

Result: **all 18 IPs are free** — no API holder, outside the pool, nothing answers ARP, nothing answers ICMP.

### 08 — `08-n3-infra.sh` (nkp-install N3, PC and certificate)

```
nkp: v2.19.0
pc: 302            pc login: 200
subject=C=US, ST=CA, L=San Jose, O=Nutanix Inc., OU=Manageability, CN=<pc-cn>
No extensions in certificate
ssh key file found
```

- PC login is **200** with `NUTANIX_USER`/`NUTANIX_PASSWORD` from the site file.
- The PC certificate has **no SAN** (`CN=<pc-cn>`, no extensions). So `PC_CA_FILE` cannot validate the IP endpoint: the create needs `--insecure` (`nkp create cluster nutanix --help` has it). See Learnings L-03.
- The block as written reads `CP_VIP`/`LB_IP_RANGE` from `~/nkp-<cluster>.env`; no cluster file exists at preflight time, so the IPs were set in the block (Learnings L-02).

### 09 — `09-n3-mirror.sh` (N3 registry blocks)

```
mirror: 401        mirror login: 200
{"errors":[{"code":"UNAUTHORIZED",...}]}   (the 401 body, no credentials)
CA file: subject CN=<ca-cn>, issuer CN=<ca-root>, notAfter 2035
```

- `mirror:` 401 is the value the skill accepts ("a `401` without credentials also proves that the registry answers"). `mirror login:` **200** with the pull account.
- The CA file is an intermediate CA of the site, not a self-signed leaf — the site passed `REGISTRY_CA_FILE` correctly.

### 10 + 11 + 13 — A-30 and A-31 (nkp-airgap `nodes.md`)

```
10 repo='registry.k8s.io/pause'  -> url /v2/nutanix/registry.k8s.io/pause/tags/list  -> 404 repository not found
11 repo='pause'                  -> url /v2/nutanix/pause/tags/list                  -> 200 {"name":"nutanix/pause","tags":["3.10","3.10.1"]}
13 /v2/_catalog                  -> http=200, 416 repositories,
                                    0 of them keep a registry host in the path (no dotted first path part)
                                    'nutanix/pause' present; no flow/ovn image yet
```

**A-30 answered:** the mirror holds an image from another registry **without** the registry host in the path. `registry.k8s.io/pause` → `<project>/pause`. The `_catalog` confirms it for all 416 repositories.
**A-31 answered:** the pull account **can** list all repositories (`/v2/_catalog` = 200).

### 14 — `14-leftover-audit.py` (ntnx "Leftover audit for a cluster", baseline)

```
nkp-mgmt-01 -> VMs 0, volume_groups 0, floating_ips 0, ip_reservations 0, categories 1
               {key: KubernetesClusterName, value: nkp-mgmt-01, inUse: false}
skilltest   -> VMs 0, volume_groups 0, floating_ips 0, ip_reservations 0, categories 1
               {key: KubernetesClusterName, value: skilltest-mgmt-01, inUse: false}
```

- Nothing blocking: no VM, volume group, FIP or IP reservation of these names. Two leftovers of an earlier test: the categories `KubernetesClusterName=nkp-mgmt-01` and `KubernetesClusterName=skilltest-mgmt-01`, both `inUse: false`. They are not deleted (a PC delete needs a new "yes"; the create sets the same key/value again).

### 15 + 16 — the node image (nkp-airgap step 2; ntnx nutanix-vm "Images")

```
bundle: kubernetes-os-ubuntu-24.04-nkp-v2.19.0-v1.36.2_linux_amd64.tar, konvoy-bootstrap-image-v2.19.0.tar, cli/nkp v2.19.0
image:  nkp-ubuntu-24.04-release-cis-1.36.2-20261014170313, DISK_IMAGE, 30.0 GiB,
        clusterLocationExtIds = [the AHV cluster], isSharedWithAllProjects true
```

- The image exists, is a `DISK_IMAGE`, has a copy on `PE_CLUSTER`, and is 30 GiB (the default node disk is 80 GiB).
- It **fits NKP 2.19.0**: the bundle ships Kubernetes **1.36.2** (`kubernetes-os-...-v1.36.2_...`), and the image name has `1.36.2` and `ubuntu-24.04`. CIS level 1, no FIPS; the create must not pass `--fips`.

### 17 + 18 — the Flow CNI dark-site bundle (nkp-flow-cni step 2, N-30)

`tar -tf` only, no extract. 914 MB, 685 entries, layout `docker/registry/v2`, `images.yaml`, `charts.yaml`.

```
chart:  charts/nutanix-flow-cni:1.1.0
docker.io: nats:2.10-alpine
           natsio/nats-box:0.14.1
           natsio/nats-server-config-reloader:0.13.0
           nutanix/flow-cni:1.1.0
           nutanix/flow-container-security:1.1.0
           nutanix/flow-ovn-kubernetes:1.1.1
ghcr.io:   k8snetworkplumbingwg/multus-cni:v4.1.3
```

- **N-30 answered.** 6 images on `docker.io`, 1 on `ghcr.io`, 1 chart.
- The chart is `charts/nutanix-flow-cni:1.1.0` — the same version as the chart on the management cluster (`nutanix-flow-cni` 1.1.0), which is the step 1 requirement.
- Note the version skew inside the bundle: chart `1.1.0`, but the OVN image is `nutanix/flow-ovn-kubernetes:1.1.1`.
- `images.yaml` gives the registry per image. That is the missing half of A-30 for this bundle: with the host dropped (block 11), `ghcr.io/k8snetworkplumbingwg/multus-cni` must land at `<project>/k8snetworkplumbingwg/multus-cni`, and `docker.io/nats` at `<project>/nats`.

### 19 — `19-help-ops.sh` → `research/raw/live/2.19/nkp-help-ops.txt`

Appended two entries in the same `########## <command> ##########` form (lines 170 and 188). No IP, no secret. Checked: the file has no IP literal.

- `nkp create workspace WORKSPACE_NAME`: flags `--display-name`, `--dry-run`, `-o`, `-n/--namespace`, `--kubeconfig`, `--request-timeout`, `--context`; the default display name is the workspace name.
- `nkp delete` subcommands: `bootstrap`, `capi-components`, `cluster`, `nodepool` — **there is no `delete workspace`**. So the R5 delete has only the UI path (as `nkp-identity-security` assumes).

### 20 — `20-env-extra.sh` (variables of the Flow CNI and push path, host leftovers)

```
MISSING: REGISTRY_PUSH_USERNAME, REGISTRY_PUSH_PASSWORD, EXTRA_BUNDLE, IMAGE_BUNDLES,
         FLOW_CNI_PULL_USERNAME, FLOW_CNI_PULL_TOKEN
docker ps -a: the site Harbor stack (goharbor v2.14.6) only — no kind bootstrap container
no bootstrap.conf, no nkp-mgmt-01 or skilltest file in ~      848 GB free
```

- The registry is the site Harbor on the operator host (read-only observation; not touched).
- **Blocker for T3:** the `nkp-airgap` 4A "extra bundle" push needs `REGISTRY_PUSH_USERNAME` and `REGISTRY_PUSH_PASSWORD`; the site file has neither, and `EXTRA_BUNDLE` is not set either. T3 must ask the user for a push account first, or the push fails on an empty flag.
- Operator host clean: no bootstrap cluster, no old cluster files.

### 21 — `21-vpc-baseline.py` (VPC list, read-only)

`<lab-vpc>` (REGULAR, 1 external subnet) exists — pre-existing, not from an NKP cluster, not mine to touch. No Flow-created VPC.

### 22 — `22-create-help-insecure.sh` (`nkp create cluster nutanix --help`, read-only)

`--insecure` exists ("If true, the Prism Central server certificate will not be validated"). Also `--additional-trust-bundle`, `--registry-mirror-cacert`, `--registry-mirror-url`, `--onboard-to-prism-central` (default true), `--fips`, `--kubernetes-pod-network-cidr`, `--kubernetes-service-cidr`, `--timeout`, `--wait`. No CNI flag exists (confirms `nkp-flow-cni`).

## The 9 checks

| # | Check | Result | Key fact |
|---|---|---|---|
| 1 | Operator host tools (incl. Flow CNI path) | **pass** | All present; `yq` mikefarah v4.54.1, docker 29.9.2, tmux 3.4, nkp/kubectl 2.19.0/v1.37.2, cgroup2fs. Only `podman` absent (docker is enough). |
| 2 | Site env file for a management create on a site mirror | **pass** | All N4C values + the 4 secrets present. `IMAGE_BUNDLES`, `NUTANIX_REGISTRY_*`, `FLOW_CNI_PULL_*`, `REGISTRY_PUSH_*`, `EXTRA_BUNDLE` missing (see T3 note). |
| 3 | PC login, PC certificate, mirror, pull account | **pass** | `pc login: 200`; the PC certificate has **no SAN** → create needs `--insecure`; `mirror: 401` bare, `mirror login: 200`. |
| 4 | 18 IPs free (`<net>.50`, `.51-.55`, `.60`, `.61-.65`, `.70`, `.71-.75`) | **pass** | No holder in PC, outside the pool, no ARP reply, no ICMP reply. |
| 5 | Leftover audit `nkp-mgmt-01`, `skilltest-*` | **pass with note** | 0 VMs/VGs/FIPs/reservations; 2 unattached categories (`KubernetesClusterName=nkp-mgmt-01`, `=skilltest-mgmt-01`), `inUse:false`. |
| 6 | Node image exists and fits 2.19.0 | **pass** | `nkp-ubuntu-24.04-release-cis-1.36.2-…`, DISK_IMAGE, 30 GiB, on the AHV cluster; bundle ships Kubernetes 1.36.2. |
| 7a | Mirror path of a `registry.k8s.io` image | **pass (A-30 answered)** | **Without** the registry host: `registry.k8s.io/pause` → `<project>/pause`, tags `3.10`, `3.10.1`; with the host → 404. |
| 7b | Pull account can list all repositories | **pass (A-31 answered)** | `/v2/_catalog` = 200, 416 repositories, none keeps a registry host in its path. |
| 8 | Flow CNI dark-site bundle file list | **pass (N-30 answered)** | chart `nutanix-flow-cni:1.1.0`; `nutanix/flow-cni:1.1.0`, `nutanix/flow-container-security:1.1.0`, `nutanix/flow-ovn-kubernetes:1.1.1`, `nats:2.10-alpine`, `natsio/nats-box:0.14.1`, `natsio/nats-server-config-reloader:0.13.0` (docker.io), `k8snetworkplumbingwg/multus-cni:v4.1.3` (ghcr.io). |
| 9 | Help text saved | **pass** | Two entries appended to `research/raw/live/2.19/nkp-help-ops.txt`; `nkp delete` has no `workspace` subcommand. |

## The node OS decision

The user decided **Ubuntu 24.04 for all nodes, also for the two Flow CNI clusters**. The skill states the need, and the preflight check of it **fails on this site**:

- `[nkp-skill nkp-flow-cni/SKILL.md step 1]` prerequisites table: "Node OS | **Rocky Linux** on all nodes. NKP 2.19 has a pre-built Rocky Linux 9.8 image".
- The step 1 check-block Done-when: "The image name has `rocky`. If not, ask the user for a Rocky image name in Prism Central". `VM_IMAGE` = `nkp-ubuntu-24.04-release-cis-1.36.2-…`, so this Done-when **fails**.
- The same section says: "If one item fails, stop. Tell the user which item fails."
- Prism Central holds **one** image only (block 03), the Ubuntu 24.04 one; there is no Rocky image on the site for a fallback.

Recorded as the brief asks: the skill names the Rocky need; the run goes on with Ubuntu on the user's decision, tagged `[live 2.19.0, unsupported OS]`. Every later result on `skilltest-flow-a`/`-b` is on an OS that Flow CNI does not support.

## Learnings

### L-01 `[ntnx-skill nutanix-networking]` "Free IP check for a VIP or an LB range" — the `arp()` classification is wrong on Linux (blocks 05, 06, 07)

The recipe's `arp()` returns `PRESENT` for a **free** address on Linux:

```python
line = line.strip()
return 'FAILED' if 'FAILED' in line else 'FREE?' if ('no entry' in line or not line) else 'PRESENT'
```

Right after a failed probe, iproute2 shows `<net>.55 dev ens3 INCOMPLETE`: no `lladdr`, no `FAILED`, no `no entry`. The function therefore takes its last branch and returns `PRESENT`. The first run reported **PRESENT for all 18 free addresses**, which reads as "the whole test range is taken". The `no entry` string it looks for is the macOS `arp -n` text; on the Linux operator host the format is different.

Proposed fix, in the recipe:

```python
return 'PRESENT' if 'lladdr' in line else 'FREE?' if ('no entry' in line or not line) else 'FAILED'
```

i.e. classify by the presence of `lladdr` (the only field that proves an answer), and add the settle note: read `ip neigh` at least ~1 s after the `ping`, because the entry is transiently `INCOMPLETE`. Evidence for both directions in block 06: live hosts `.37`/`.38`/`.39` show `lladdr` (`STALE`/`REACHABLE`); the candidates show `INCOMPLETE`. Also update the "How to read the result" row: on Linux a free address is `FAILED`/`INCOMPLETE`, never `no entry`.

### L-02 `[ntnx-skill nutanix-networking]` + `[fact]` — the free-IP recipe cannot be run as one block under this repo's rules (block 04 + 05)

The recipe is one python block that does the four API sources **and** `subprocess` `ping`/`ip neigh`. `[fact]` the lab rule is that the `ntnx.py` client runs on the laptop, while the ARP probe must run on the bastion (same L2). One block cannot do both, so the executor must split a skill block in two — which the BRIEF forbids ("follow the skills exactly") and which risks a mis-read (the API part alone says only "no holder"). I split it and marked the second half. Proposed fix: make `free_ip_check(..., arp=None)` skip the probe, and add a second small block "the ARP half, run on the L2 host" in the recipe, so the split is a documented part of the skill.

### L-03 `[nkp-skill nkp-install/references/nutanix.md N1, N4C]` — no `--insecure` line, and the PC certificate has no SAN (blocks 08, 22)

`N1` says `PC_CA_FILE` "optional | only when the PC certificate has a SAN with the host or IP of `PC_ENDPOINT`". It does not say what to do when the certificate has **no SAN** — which is this site (`CN=<pc-cn>`, "No extensions in certificate") and, per the `nutanix-nkp` recipe note, the PC default. The N4C create script has only `${PC_CA_FILE:+--additional-trust-bundle ...}` and no `--insecure`, and the flag exists (block 22). Result: the create as written in the skill fails with a certificate error, or the executor invents a flag. Proposed fix: in N4C add
`${PC_CA_FILE:-} ... ` plus a note and a line: when `PC_CA_FILE` is unset, add `--insecure` (and say that the guide warns about it). Also add the fact to N1's `PC_CA_FILE` row: "no SAN on the PC default certificate → `--insecure`".

### L-04 `[nkp-skill nkp-install/references/nutanix.md N3]` — N3 cannot run before the cluster env file exists (block 08)

N3's block starts `source ~/nkp-<cluster>.env` and pings `"$CP_VIP"` and `$LB_IP_RANGE`. At preflight time no cluster env file exists yet (the skill's own order creates it in "Prepare the env files", which is *after* "Check the operator host"), so `CP_VIP` is empty and the block pings the empty string. The skill says "Done when: ... `ping` of `CP_VIP` gets no reply" without saying where the values come from at that point. I set the three VIPs and three ranges in the block. Proposed fix: split N3 into "the site half" (PC, certificate, mirror — site variables only) and "the cluster half" (VIP and LB ping, cluster file needed), and state that the cluster half runs after "Prepare the env files".

### L-05 `[nkp-skill nkp-flow-cni/references/install.md N-30]` — the bundle has `images.yaml`, which the find command does not read (blocks 17, 18)

The skill gives one discovery command: `tar -tf "$EXTRA_BUNDLE" | grep '/_manifests/tags/[^/]*/$'`. It works (7 images + 1 chart), but the bundle also carries `images.yaml` and `charts.yaml` at the top level, and `images.yaml` is the only place that says **which registry** each image comes from (`docker.io` vs `ghcr.io`). That is exactly the fact A-30 needs and the one that decides whether the mirror rewrite finds `ghcr.io/k8snetworkplumbingwg/multus-cni`. Proposed fix: add to step 2
`tar -xOf "$EXTRA_BUNDLE" images.yaml` (read-only, to stdout) and record N-30's answer in the skill.

### L-06 `[nkp-skill nkp-airgap/references/nodes.md A-30]` — answered; write the rule into the file (blocks 10, 11, 13)

A-30 asks "with or without the registry host". Answer: **without**. `repo='registry.k8s.io/pause'` → `404 repository nutanix/registry.k8s.io/pause not found`; `repo='pause'` → `200 {"name":"nutanix/pause","tags":["3.10","3.10.1"]}`. The `_catalog` corroborates it: 0 of 416 repositories carry a registry host in the path (`nutanix/alpine/curl`, `nutanix/capi-operator/cluster-api-operator`, …). Proposed fix: replace the UNKNOWN line with the rule "the mirror path is the registry path **without** the registry host: `<repo-path>`" and one example per registry (`registry.k8s.io/pause` → `pause`, `ghcr.io/<org>/<img>` → `<org>/<img>`). Keep the two-repo check as the verification.

### L-07 `[nkp-skill nkp-airgap/references/nodes.md A-31]` — answered: the pull account can list (block 13)

`GET /v2/_catalog` with the pull account → **200**, 416 repositories. The UNKNOWN says "`http=401` or `403` means that this account cannot list". Proposed fix: record "Harbor site mirror: the pull account can list the whole catalog (200); a `401` here means a read-only robot account scoped to repositories". Keep the check.

### L-08 `[nkp-skill nkp-flow-cni/SKILL.md step 1]` — the step cannot pass on Ubuntu, and the stop rule has no override path (see "The node OS decision")

The skill's Done-when requires `rocky` in the image name and then says "If one item fails, stop". The brief's standing decision is Ubuntu 24.04. Nothing in the skill tells the executor how to record a user override, so the executor must break either the skill's stop rule or the brief. Proposed fix: add one line to step 1: "If the user overrides the OS (Ubuntu or another), continue, and tag every result `[unsupported OS]`. Flow CNI has no support statement for it." That turns a contradiction into a decision.

### L-09 `[nkp-skill nkp-airgap/SKILL.md step 4A]` — the push account is checked only at the push block (block 20)

`REGISTRY_PUSH_USERNAME`, `REGISTRY_PUSH_PASSWORD` and `EXTRA_BUNDLE` are all absent from the site file. Step 4A has a check block for the push account, but it sits *after* the "Get the CA file" step and just prints `MISSING` — nothing in the file says "stop and ask for the push account" before the CHANGES push. For T3 the consequence is direct: the Flow CNI bundle push cannot run until the user adds the two lines, and the push block would run with an empty `--to-registry-username`. Proposed fix: make the push-account check the **first** block of 4A with a Done-when ("both print `set:`"), and note that a pull-only robot account is not enough.

### L-10 `[nkp-skill nkp-install SKILL.md "Check the operator host"]` — the tool list omits `yq` and `jq` (block 01)

The block checks nkp, docker, kubectl, cgroup, tmux, nproc/free/df. `yq` (mikefarah v4) is a hard need of `nkp-flow-cni/references/install.md` I2 and `nkp-upgrade` gitops.md, and `jq` is used by `nkp-networking` proxy, `nkp-identity-security` cluster-security and `nkp-upgrade`. No single block checks the union, so an executor that starts from `nkp-install` finds the missing tool only in the middle of a Flow CNI run. Proposed fix: add `command -v yq && yq --version` and `command -v jq` to the operator-host block, with the note "the bundle has no `yq`" (already in install.md).

### L-11 `[fact]` — preflight facts worth keeping

- The site Harbor is on the operator host (`docker ps -a`: goharbor v2.14.6 stack) — so "the registry" and "the bastion" are the same machine, which is why the `mirror login` check passes locally.
- `REGISTRY_CA_FILE` holds an **intermediate** CA (`<ca-cn>` issued by `<ca-root>`), not a self-signed leaf. The skill's "only if there is none" CA-fetch block writes the leaf, so a site that follows it gets a different file than this site has. Worth one line in 4A step 3.
- Two unattached `KubernetesClusterName` categories from an earlier test (`nkp-mgmt-01`, `skilltest-mgmt-01`). Harmless for the create; the final audit (T8) must not read them as a leftover of *this* test.
- The Flow CNI bundle has chart `1.1.0` and OVN image `1.1.1`. The skill's "the bundle version must be the same as the chart version of step 1" holds for the chart, not for the image tag — do not compare image tags to the chart version in step 2.

## Status

`done`. Every one of the 9 checks passed; no CHANGES block ran outside the one local repo file write; nothing was installed.
