# Answers: group a

## nkp-install E2

Skill files read: `nkp/SKILL.md`, `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`, `nkp-identity-security/SKILL.md` (license tiers).

Short answers first:

**1. Smallest management cluster.** The CLI defaults (3 control planes 4 vCPU/16 GiB/80 GiB, 4 workers 8 vCPU/32 GiB/80 GiB) are the Pro and Ultimate minimums, not the Starter one. The Starter minimum for a management cluster is these extra flags:

```text
--control-plane-vcpus 2 --control-plane-memory 8 --worker-replicas 2 --worker-vcpus 4 --worker-memory 8
```

**2. Ubuntu 24.04 image.** Two facts you must have:
- The 2.19 guide says Starter supports only the Nutanix **Rocky Linux** image [pdf p.715]. That is a support statement, not a technical block.
- A Starter create with the **Ubuntu 24.04** image does work and runs [live 2.19.0].

So: it works, but it is outside support on Starter. The decision is yours; I continue with the image you name. What Starter does *not* allow at all is a **custom image built with NIB** [pdf p.57].

**3. One control plane node.** `--control-plane-replicas 1` works, but the cluster is lost when that node fails. That is acceptable only for a test cluster [pdf p.696]. For a lab where you can rebuild in 25 min, fine; say so and I add the flag.

**One warning before you pick 2 workers:** with 2 workers the Pro and Ultimate platform apps fail after a license upgrade [pdf p.695]. If this lab may get Pro or Ultimate later, stay at 4 workers now.

Starter also has no monitoring apps and no logging apps [pdf p.26-28]. Nothing in this answer changes that.

### What I need from you before anything is written

`nkp-site.env` and `~/nkp-<cluster>.env` are not made yet, and I write no value I do not have. Please give me:

1. Cluster name (only `a-z`, `0-9`, `.`, `-`) [pdf p.718]. Starter has no name-bound license, so any free name is correct.
2. Is the site connected or air-gapped; does it have its own registry mirror (Harbor/Nexus/Artifactory)?
3. Prism Central endpoint, the Prism Element cluster, the node subnet (IPAM/DHCP on), the storage container.
4. The exact name of the Ubuntu 24.04 image in Prism Central (it must contain the Kubernetes version, e.g. `1.36.2`) [pdf p.726], and the path of the SSH public key file.
5. A free `CP_VIP` and a free `LB_IP_RANGE` (`first-last`) in the node subnet, **outside** the IPAM pool. On a basic VLAN subnet Prism Central cannot see a VIP or a MetalLB address at all, so we prove them free with the ARP probe of skill `nutanix-networking` before the create. I need the full addresses for that.
6. NTP servers (mandatory on an air-gapped site).
7. Then you add `NUTANIX_USER` and `NUTANIX_PASSWORD` to `~/nkp-site.env` yourself with an editor; on a connected site also `NUTANIX_REGISTRY_USERNAME` and `NUTANIX_REGISTRY_TOKEN`.

Also: is this the first NKP cluster on this site? If an old cluster was deleted here, we run the leftover audit (skill `nutanix-nkp`) before the create, because old volume groups and floating IPs can hold the new addresses.

### What happens next, in order

1. Operator host check (`nkp version`, container engine, `cgroup2fs`, 4 CPU / 4 GB free, `tmux`) — READ-ONLY.
2. Make the two env files and write the values you give me (CHANGES, I stop for "yes").
3. Check the env files, Prism Central reachability and login, and the free-IP result — READ-ONLY.
4. I write `~/nkp-<cluster>-create.sh` with the Starter size flags plus `--self-managed --timeout 60m` (CHANGES, the script only), then the dry run (CHANGES, writes `~/<cluster>-dryrun.yaml`, creates no VMs; it is also the preflight test, about 3 min, and it makes and deletes a kind bootstrap cluster). You look at the shown lines and type "yes".
5. The create in tmux (CHANGES). Management create takes 22–24 min; on AHV `--self-managed` also installs Kommander.

Nothing above runs until you answer 1–7.

## nkp-install E5

Skill files read: `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`, `nkp-install/references/kommander.md`, `nkp/SKILL.md`.

**No.** On Nutanix AHV, `nkp create cluster nutanix --self-managed` installs Kommander as part of the create [pdf p.47]. `nkp install kommander` is for the case where the create ran without it, or where a check shows that it is not there.

Always check first. I run (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get ns kommander-flux
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmreleases
kubectl --kubeconfig "$MGMT_KUBECONFIG" get storageclass
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander wait --for condition=Ready helmreleases --all --timeout 15m
```

What I expect, and what each answer means:
- The namespace `kommander-flux` exists → Kommander is installed. Kommander is not installed when the namespace is missing **or** when there are no HelmReleases in `kommander`.
- `storageclass` shows `(default)` on one line (on AHV that is `nutanix-volume`). Kommander needs one default StorageClass [pdf p.942].
- The last line prints `condition met` per object. That is the "Kommander is done" condition. If it times out, one HelmRelease is not Ready; that is a different job, skill `nkp-troubleshooting`.

If the check shows Kommander **is** installed: you are done, nothing else to run. Then verify the cluster with the "Verify" step, and if your tier is Pro or Ultimate, apply the license (Kommander installs as Starter) with skill `nkp-identity-security`, section "License".

If the check shows it is **not** installed, the fix is two steps, and I stop for "yes" before each:

1. `nkp install kommander --init > kommander.yaml` (CHANGES, writes a local file; add `--airgapped` on an air-gapped site).
2. `nkp install kommander --installer-config kommander.yaml --kubeconfig "$MGMT_KUBECONFIG" --wait-timeout 2h` (CHANGES, installs Kommander and the platform apps on the management cluster; the default wait of 1h15m is raised to 2h because an air-gapped install can be slower). A failed or timed-out run of the same block continues.

Tell me the cluster name and I show the verify block with your env file (`~/nkp-<cluster>.env`). I keep `<cluster>` in the path until you name it.

## nkp-install E16

Skill files read: `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`.

**It did not fail.** For a workload cluster, `✓ Waiting for machines to be ready` is the normal last line and it is a success [live 2.19.0]. Two things are normal and both look odd:

- A workload create writes **no** kubeconfig file and prints **no** success line. The `.conf` file is expected to be missing.
- So the "Set the kubeconfig variables" step is mandatory for a workload cluster, not optional.

Use the cluster env file `~/nkp-dev-01.env` (I use the name you gave me; if that file does not exist yet, we make it first with the same CHANGES/“yes” rule and append `CLUSTER_NAME`, `CP_VIP`, `LB_IP_RANGE`, `WORKSPACE_NS`).

### Step 1 — get the kubeconfig (CHANGES, needs "yes")

Command:

```bash
# CHANGES  (writes a local kubeconfig file and appends its path to the cluster env file)
source ~/nkp-dev-01.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-dev-01.env
```

- Target: the files `$PWD/dev-01.conf` (mode 600) on this operator host and one appended line in `~/nkp-dev-01.env`.
- Result: a new kubeconfig for `dev-01`, valid from now on; the last `CLUSTER_KUBECONFIG` line wins. It changes no cluster object. The `nkp` help says it can touch the local kubeconfig, so I treat it as CHANGES.
- `WORKSPACE_NS` must be the **workspace namespace** of the workspace that holds `dev-01` (for example `kommander-default-workspace`), never the workspace name.

Type "yes" and I run it. Tell me if you do not know `WORKSPACE_NS`; then I read it first (READ-ONLY): `kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -A`, and `WORKSPACE_NS` is the WORKSPACE NAMESPACE column.

### Step 2 — is it healthy (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
test -f "$MGMT_KUBECONFIG" && echo "mgmt kubeconfig ok"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommanderclusters "$CLUSTER_NAME"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" wait --for=condition=Ready helmreleases -A --all --timeout 30m
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A --no-headers | wc -l
```

Healthy looks like this:
- `mgmt kubeconfig ok`, and every node `Ready`.
- The `--field-selector` pod list prints **nothing** (the "No resources found" line goes to stderr). Any line here is a bad pod.
- In `nkp describe cluster`, every `Machine/` row shows READY `True`. The `Cluster/` and `ControlPlane` rows can have an empty READY column [live 2.19.0].
- The NKPCluster PHASE is `Reconciling Platform Applications` at first, then `Reconciled`. `Reconciled` can come **30–40 min after** the create ended; that is normal [live 2.19.0].
- The KommanderCluster STATUS is `Joined`.
- The HelmRelease wait prints `condition met` for each object, and the count does not change in two reads 15 min apart. Never take the first count as final: apps arrive late. (On a full Ultimate lab the live numbers were 19 HelmReleases in the workspace namespace, 16 AppDeployments, about 122 pods [live 2.19.0]; Starter is smaller.)

If a pod is bad: `kubectl describe pod` and the events, then skill `kubernetes-core` step 1, or `ImagePullBackOff` → skill `nkp-airgap` step 5.

## nkp-install E17

Skill files read: `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md` (N1 "IP plan", N3), `nkp-airgap` not needed, companion `nutanix-networking/SKILL.md` + `RECIPES.md` ("Free IP check for a VIP or an LB range"), `nutanix-nkp/SKILL.md` (Site preflight), `nutanix-api/SKILL.md`.

Yes, I can prove it, but not with a `ping` and not from a routed host. The proof has five sources in this order: the IPAM pool, the IP reservations, the VM NIC IPs, the platform IPs (PC, cluster VIP, data services IP, hosts, CVMs, floating IPs, VPC gateways), and last the **ARP probe from a host on the same Layer 2** — this operator host.

Your case is exactly the hard one: on a basic VLAN subnet Prism Central does **not** show a kube-vip or MetalLB address, so the ARP probe is the only proof for `.50` and `.51-.55` [live 2.19.0]. And a ping that fails means "no ICMP", not "free" — ARP is what counts.

I need the full addresses. Give me the /24 prefix (or the full `CP_VIP` and `LB_IP_RANGE`) and the subnet name of `SUBNET`. Then I run (READ-ONLY: Prism Central GETs and ARP probes, nothing is written):

```bash
# READ-ONLY  (Prism Central reads and ARP probes from this bastion; changes nothing)
source ~/nkp-site.env 2>/dev/null
prefix=''; : "${prefix:?set prefix, for example 192.0.2}"
python3 - "$prefix" <<'PY'
import os, sys
sys.path.insert(0, '<nutanix-api skill dir>/scripts'); from ntnx import *
# recipe: nutanix-networking RECIPES.md "Free IP check for a VIP or an LB range"
# (ipv, subnet_id, pool, reserved, nic_ips, fip_ips, vpc_gateway_ips, platform_ips, arp, free_ip_check)
p = sys.argv[1]
for row in free_ip_check(os.environ['SUBNET'], [f'{p}.{i}' for i in (50, 51, 52, 53, 54, 55)]):
    print(row)
PY
```

I copy the recipe functions verbatim from `nutanix-networking/RECIPES.md` into that script; nothing is edited except the final call.

Expected output shape, and how I read it for each of the six addresses:

| Result | Meaning | What I do |
|---|---|---|
| `holder` set (a platform IP, a VM, a reservation, a floating IP, a VPC gateway) | the address belongs to something that Prism Central can see | report the exact holder and object name, take the next address |
| `holder` empty, `inPool` **true** | it is **inside the IPAM pool** — Prism Central may hand it to a new VM at any time | this is a real risk on your subnet. Either move the VIP/range outside the pool, or reserve all six addresses first (skill `nutanix-networking`, "IP reservations"; that is CHANGES, separate "yes") |
| `holder` empty, `inPool` false, `arp` `FAILED` | nothing on that L2 answers — **free** | good for `CP_VIP` and the range |
| `arp` `PRESENT` | a host answers for it | taken; the network team is wrong |
| `arp` `FREE?` / no entry (macOS `arp -n`) | same as `FAILED` in practice | treat as free |

Two things that make the result invalid, so I check them first:
- The probe must run **on this bastion**, on that VLAN. From a host that reaches Prism Central over a tunnel or a router every address looks free. Verified 2026-11-04: the recipe returned `FAILED` for a live data-services IP when it ran from a routed laptop, while its API sources named that IP correctly [live 2.19.0].
- `ping -W` is seconds on Linux, milliseconds on macOS; the recipe default `1` is correct for this Linux host.

Then, before the create, I also run the composite "Site preflight" of skill `nutanix-nkp` (also READ-ONLY): it reports the PC certificate, the AHV cluster, the subnet and its pool, the storage container and its free space, the image and its placement on the PE cluster, the NTP list, and the same free check of `CP_VIP` and `LB_IP_RANGE`. The credential check is part of it.

I run nothing until you give me the prefix and the subnet name. When the six addresses pass, they go into `~/nkp-site.env` / the cluster env file as `CP_VIP` and `LB_IP_RANGE` (CHANGES, one more "yes"), and then we do the dry run.

## nkp-install E18

Skill files read: `nkp-install/SKILL.md` (step "Choose the provider file", question 5), `nkp-install/references/nutanix.md`, `nkp-identity-security/SKILL.md` (section "License", "License tiers for these features"), `nkp/SKILL.md`.

### One blocking question before anything else

An Ultimate key is **bound to the name of the management cluster**. A key issued for another name makes the license step fail with `License key is not valid for this cluster`, and the only fix is: delete the cluster, create it again with the licensed name [live 2.19.0].

So: **does the trial key from the portal name `skilltest-mgmt-01`?** Check the portal key page (or the mail that came with the key). If the key names something else, tell me that name and I use it as `CLUSTER_NAME` — the cluster name must be the licensed name, not a name we like.

I do not create anything until you confirm this.

### Then I need the rest of the values

Is this the first cluster on the site (yes, management)? Connected or air-gapped; is there a registry mirror? Prism Central endpoint, Prism Element cluster, node subnet, storage container, the Ubuntu 24.04 or Rocky 9.8 image name in Prism Central, the SSH public key file, a free `CP_VIP`, a free `LB_IP_RANGE` outside the IPAM pool (I prove both free first, skill `nutanix-networking`), NTP servers on an air-gapped site. And you add `NUTANIX_USER` / `NUTANIX_PASSWORD`, plus `NUTANIX_REGISTRY_USERNAME` / `NUTANIX_REGISTRY_TOKEN` on a connected site, to `~/nkp-site.env` with an editor.

On your confirmation I make the files and write the values I have (CHANGES, "yes" first), for example:

```bash
# CHANGES  (appends the cluster name you confirmed to the new cluster env file)
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
test -e ~/nkp-skilltest-mgmt-01.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-skilltest-mgmt-01.env); }
echo "export CLUSTER_NAME='skilltest-mgmt-01'" >> ~/nkp-skilltest-mgmt-01.env
echo "export WORKSPACE_NS='kommander'" >> ~/nkp-skilltest-mgmt-01.env
```

### What Ultimate changes in the plan

1. **Node sizes.** Do **not** add the Starter minimum flags. 4 vCPU/16 GiB control planes and 4 workers × 8 vCPU/32 GiB are the Pro/Ultimate minimums, and Ultimate on 4 workers takes the worker CPU requests to 67–98 %, which is near the limit [live 2.19.0]. If the lab is small, tell me and we size with the worker CPU requests in front of us; do not go down to 2 workers, because the Ultimate apps fail on the Starter minimum of 2 workers [pdf p.695].
2. **Kommander installs as Starter, then the license.** That is the supported order and it is what you planned: create `--self-managed` (22–24 min, with `--timeout 60m`), verify, then apply the key with skill `nkp-identity-security`, section "License".
3. **No way back.** You cannot go to a lower tier after you register a license [pdf p.26]. An Ultimate trial that expires takes its apps with it — plan the workers so the paid tier fits later.
4. **A higher tier installs many more apps.** The measured Ultimate management cluster has 48 HelmReleases in `kommander` (Starter: 24) [live 2.19.0]. Budget about 11 min for the new tier's apps after the license patch.
5. **The key is a secret.** Put it in `~/nkp-site.env` with an editor (`export NKP_LICENSE_KEY='...'`), never in the chat. Note that the license webhook prints the full key when it rejects one; both `patch` blocks in the license procedure mask it, and I never show a raw webhook error.

Sequence after your confirmation: env files → operator host check → env/infra checks → free-IP proof → create script + dry run (CHANGES, preflight test) → create in tmux → verify → license (CHANGES, separate plan and "yes"). Each CHANGES block stops for the word "yes".

## kubernetes-core K9

Skill files read: `kubernetes-core/SKILL.md` (step 3, step 4), `kubernetes-core/references/workloads.md` (rollout), `nkp-install` not needed, env file layout from `_shared/RULES.md`.

**Your file is very probably right.** This is a known behaviour, not a YAML error:

- `kubectl apply --dry-run=server` and `kubectl diff` check each object against the cluster **as it is now**. The `Namespace demo` that sits in the same file is not created by a dry run, so the API server (and the admission webhooks) reject the `PersistentVolumeClaim` and the `Deployment` with `namespaces "demo" not found` [live 2.19.0].

So: make the namespace first, then the dry run and the diff of the same file again. Nothing else in the file changes.

One thing to check in your file: if the `Namespace` object has labels or annotations (for example Pod Security labels), we do **not** use `kubectl create namespace` — that would drop them. Then we put the Namespace in its own file and apply that file first.

### Plan

1. Create the namespace `demo` on cluster `app-01`. Target: one empty Namespace object. Result: the PVC and the Deployment pass their server-side checks afterwards. No workload is created yet.
2. Dry run and diff of `~/demo.yaml` (READ-ONLY). Expected: no `NotFound`, `diff_rc=0` (nothing exists yet) or `1` (differences), and no Gatekeeper `denied`.
3. `kubectl apply -f ~/demo.yaml` after your "yes". Expected: `namespace/demo created` (if the Namespace is still in the file — then the create in step 1 is redundant, tell me and we skip it), `persistentvolumeclaim/... created`, `deployment.apps/... created`.

Step 1 is CHANGES. Type "yes" and I run:

```bash
# CHANGES  (creates one empty namespace)
source ~/nkp-app-01.env 2>/dev/null
ns='demo'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" create namespace "$ns"
```

Then I run (READ-ONLY — changes nothing):

```bash
# READ-ONLY  (server dry run and diff: change nothing)
source ~/nkp-app-01.env 2>/dev/null
f="$HOME/demo.yaml"
: "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" diff -f "$f"; echo "diff_rc=$?"
```

Read: `diff_rc=0` = nothing to change, `1` = there are differences (normal for new objects), anything above 1 = an error — then send me the error line and I do not continue. I read `$?` directly after `diff`, never through a pipe. The diff is shown to you in the plan; Secret data stays hidden (`--show-secrets=false` is the default and I never add `--show-secrets`).

Then, after your "yes" for the apply:

```bash
# CHANGES  (applies the file to the cluster)
source ~/nkp-app-01.env 2>/dev/null
f="$HOME/demo.yaml"
: "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$f"
```

And after that, to prove it runs (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='demo'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pvc,deploy,pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status deploy --all --timeout 5m
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get events --types=Warning
```

A PVC stays `Pending` until a pod uses it (that is normal for this kind of file), and on NKP the default StorageClass is `nutanix-volume`. If the PVC is `Pending` **with a pod attached**, the events name the reason (scheduling or storage) and I go to step 1 of the skill.

If `~/nkp-app-01.env` does not exist yet on this host, tell me and I make it first (CHANGES, one more "yes").

## kubernetes-core K10

Skill files read: `kubernetes-core/SKILL.md` (step 4, the `diff` exit-code rule), `_shared/RULES.md`.

**No — the `rc=0` you saw is not the exit code of `diff`.** In `kubectl diff -f web.yaml | head -50; echo rc=$?` the `$?` belongs to the **last command in the pipe**, which is `head`. `head` almost always exits 0. So the `rc=0` tells you nothing about the diff [live 2.19.0].

And there **was** an error: that error line is real. With a pipe you cannot see the diff exit code at all, so you cannot tell "no change" (0) from "changes" (1) from "the API server refused / an object was not found" (more than 1).

Re-run it without the pipe (READ-ONLY — `diff` changes nothing):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
f="$HOME/web.yaml"
: "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" diff -f "$f"; echo "diff_rc=$?"
```

If the output is long, keep the exit code by writing to files instead of a pipe:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
f="$HOME/web.yaml"
: "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" diff -f "$f" >/tmp/web.diff 2>/tmp/web.err; echo "diff_rc=$?"
wc -l /tmp/web.diff; sed -n 1,20p /tmp/web.err
```

How to read `diff_rc`:
- `0` = no difference, nothing to apply.
- `1` = there are differences; the diff body shows them. Nothing is wrong.
- `>1` (usually 1 only, but the API server errors give a higher code) = the diff itself failed. That is your error line, and it is the important one.

Please paste that error line (the stderr text). The most common cases:
- `Error from server (NotFound): ... namespaces "<ns>" not found` — the file has a new Namespace in it; that is not a bug in the file, and the fix is: make the namespace first, then dry run and diff again (skill `kubernetes-core` step 4).
- `Error from server (Forbidden)` / `denied by Gatekeeper` — a permission or policy problem, not a syntax problem; the message names the object.

Never add `--show-secrets` to see more; Secret data stays hidden by default and I keep it that way.

If the cluster env file `~/nkp-app-01.env` is not there yet, tell me and I make it first (CHANGES, "yes" first).

## nkp-airgap A8

Skill files read: `nkp-airgap/SKILL.md` (steps 1–4), `nkp-airgap/references/os-images.md` (O1–O3), `nkp-airgap/references/prestage.md` (move with a SHA-256 check), `nkp-install/references/nutanix.md` (N1 "Node OS image").

### Stop first: this is not supported on Starter

Custom node images are **not** supported on the Starter license [pdf p.57]. The guide says Starter supports only the Nutanix Rocky Linux image [pdf p.715]. The rule is: **do not build a custom image for Starter.**

Your options, in order of effort:
1. **Use a Nutanix pre-built image** — Rocky Linux 9.8 or Ubuntu 24.04, CIS Level 1, no FIPS [pdf p.55-56]. Keep the portal image name. No NIB, no build, works on Starter.
2. **Upgrade the site to Pro or Ultimate first**, then build the RHEL 9.8 image. Custom images are a Pro/Ultimate job.

Also: "hardened" is not a NIB option in these skills. NIB has `--fips` and the GPU variants, and CIS Level 1 comes from the pre-built images, not from a hardening flag. What "hardened" must mean for you (FIPS? CIS? an internal benchmark?) is not in the skills — tell me which one, and I give only the steps that exist.

If you still want the build (because the site will be Pro/Ultimate), here is the whole offline path. I mark where I stop.

### O1 — make the OS package bundle on a **connected** host

The 2.19 bundle has the Kubernetes packages and the containerd tarball, but **not** the RHEL distribution packages [pdf p.73]. `nkp create package-bundle` fetches them from Red Hat, so it cannot run on this air-gapped host.

1. On the connected host: extract the same bundle (or copy only its `image-artifacts/` folder) and put the same `nkp` CLI on the path.
2. RHEL needs a Red Hat subscription. You add the secret lines to `~/nkp-site.env` **on the connected host** with an editor: `RHSM_USER` and `RHSM_PASS`, or `RHSM_ORG_ID` and `RHSM_ACTIVATION_KEY` [pdf p.75, p.711].
3. You run, in the extracted bundle folder (this is your terminal, not mine):

```bash
# USER-TERMINAL  (connected host; you run it. Adds the RHEL 9.8 packages to image-artifacts)
source ~/nkp-site.env 2>/dev/null
ls image-artifacts > /tmp/before.txt
nkp create package-bundle rhel-9.8 --artifacts-directory image-artifacts/
ls image-artifacts | diff /tmp/before.txt - ; du -sh image-artifacts
```

Add `--fips` only if the image must be FIPS (then the package bundle must be FIPS too). Keep `--kubernetes-version` at the CLI default (1.36.2 for 2.19.0). The `diff` output lists the new files.

4. Pack and move: `tar -czf image-artifacts.tar.gz image-artifacts`, plus a `sha256sum` file, then to this host (USB or file share). Do not copy a bundle tar without a SHA-256 check.

Done when, on this host, `ls "$BUNDLE_DIR"/image-artifacts` shows the new files from that `diff`. I check that and extract the tar into `"$BUNDLE_DIR"` (CHANGES, "yes" first).

### O2 — the base OS image

NIB starts from a base image in Prism Central: qcow2 or img, UEFI boot, cloud-init and an SSH server installed, Python 3, a user with sudo, 20 GB free on the root file system, no Kubernetes parts. **Do not** use a Nutanix pre-built image and **do not** use an image that NIB made before [pdf p.58].

On an air-gapped site the upstream download fails, so you must import the RHEL cloud image into Prism Central yourself and give me its name. Without `--source-image` NIB tries to download and fails offline [live 2.19.0]. (`rhel-8.10` always needs `--source-image`; give it for `rhel-9.8` too.)

### O3 — build the image

1. Load the NIB container image into the local engine. CHANGES, I stop for "yes":

```bash
# CHANGES  (loads the NIB container image into Docker on the operator host)
source ~/nkp-site.env 2>/dev/null
docker load --input "$(ls "$BUNDLE_DIR"/nkp-image-builder-image-*.tar)"
```

2. Values I need first: `NODE_OS='rhel-9.8'`, `BASE_IMAGE=<the name of your imported RHEL cloud image>`, `PC_ENDPOINT`, `PE_CLUSTER`, `SUBNET`, and the Nutanix credentials in `~/nkp-site.env`. I append `NODE_OS` and `BASE_IMAGE` to the site env file after you confirm them (CHANGES, separate "yes"). Then a READ-ONLY check that only prints `set: <name>` / `MISSING: <name>`.

3. The build. CHANGES — it makes a temporary VM in Prism Central on `SUBNET` in `PE_CLUSTER` and saves the result as a new image. I stop for "yes":

```bash
# CHANGES  (makes a temporary VM in Prism Central and saves a new VM image)
source ~/nkp-site.env 2>/dev/null
nkp create image nutanix "$NODE_OS" --endpoint "$PC_ENDPOINT" --cluster "$PE_CLUSTER" --subnet "$SUBNET" --source-image "$BASE_IMAGE" --artifacts-directory "$BUNDLE_DIR/image-artifacts" ${PC_PROJECT:+--pc-project "$PC_PROJECT"}
```

Optional lines before running it, only if your case needs them: `--bundle "$(ls "$BUNDLE_DIR"/container-images/konvoy-image-bundle-*.tar)"` when the cluster uses the internal registry mirror; `--fips`; `--extra-build-name <text>`; the bastion flags when this host cannot reach `SUBNET` directly; `--insecure` only if you ask for it.

Done when: the command ends without an error and Prism Central shows the new image. Keep the image name that NIB prints, and make sure the image placement policy allows it on `PE_CLUSTER` [pdf p.713] — else the create preflight fails with `Check: NutanixVMImage`.

4. Then the image goes into the cluster create as `VM_IMAGE` (skill `nkp-install`). Note the guide requires the VM image name to contain the Kubernetes version [pdf p.726].

Tell me: Starter stays, or Pro/Ultimate? And what "hardened" means for you. Then I do the steps that apply, one CHANGES block at a time.

## nkp-airgap A9

Skill files read: `nkp-airgap/SKILL.md` (step 2, step 3), `nkp-airgap/references/nodes.md` (last section "Check that the site mirror has an image"), `nkp-airgap/references/catalogs.md` (C3), `kubernetes-core/SKILL.md` (step 4).

**Do not guess the path, and never pull from the internet.** The image that most people write first is not in your mirror:

- `docker.io/library/nginx` → **404** in a mirror seeded from the NKP bundle [live 2.19.0].
- Two images from the bundle **are** there: `docker.io/nginxinc/nginx-unprivileged` (tag `1.29.5-alpine`) and `docker.io/library/busybox` (tag `1`) [live 2.19.0].

So use `nginxinc/nginx-unprivileged:1.29.5-alpine`.

The mirror path rule: the first path part of `REGISTRY_URL` is the Harbor project, and an image `docker.io/<path>:<tag>` sits at `<project>/<path>` in the mirror [live 2.19.0]. Your `REGISTRY_URL` therefore gives the full image name: `<registry-host>/<project>/nginxinc/nginx-unprivileged:1.29.5-alpine`, where `<project>` is the path part of `REGISTRY_URL`.

### Step 1 — prove it, before it goes into a manifest

I run (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
repo='nginxinc/nginx-unprivileged'; : "${repo:?set repo}"
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"; p="${h#"$host"}"; p="${p#/}"; p="${p:+$p/}"
url="https://$host/v2/$p$repo/tags/list"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file /dev/stdin -w '\nhttp=%{http_code}\n' "$url" <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD"
```

- `http=200` with `{"name":...,"tags":[...]}` → the mirror has it; use a tag from that list.
- `http=404` → not there. Then either pick `library/busybox:1`, or add the image with `nkp create bundle` on a connected host and push it as an extra bundle (C3) — that is a separate job with its own approvals.
- `http=401` → the pull account is wrong. `x509` → `REGISTRY_CA_FILE` is wrong.

The password goes in through a here-string, so it does not appear in the process list.

### Step 2 — the manifest

Put the resolved name in the YAML. `image:` must be the mirror path, not `docker.io/...`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-smoke
  namespace: smoke
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-smoke
  namespace: smoke
spec:
  replicas: 1
  selector:
    matchLabels: {app: nginx-smoke}
  template:
    metadata:
      labels: {app: nginx-smoke}
    spec:
      containers:
        - name: nginx
          image: <registry-host>/<project>/nginxinc/nginx-unprivileged:1.29.5-alpine
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: nginx-smoke
```

Replace `<registry-host>/<project>/...` with the string you get from `REGISTRY_URL` — one value, no guessing, and it is the same string the `tags/list` call proved. On NKP the default StorageClass is `nutanix-volume`, so I leave `storageClassName` out and check it first:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
```

Then the normal path of skill `kubernetes-core`, step 4: the namespace first if it does not exist (CHANGES, "yes"), then `apply --dry-run=server` and `diff` (READ-ONLY), then `apply` after "yes".

Tell me the cluster name and I put its env file in the blocks; and say which tag the `tags/list` answer shows, in case it is newer than `1.29.5-alpine`.

## nkp-airgap A10

Skill files read: `nkp-airgap/SKILL.md` (steps 2 and 4), `nkp-airgap/references/nodes.md` (last section, UNKNOWN A-31), `nkp-airgap/references/catalogs.md` (C1/C3), `nutanix-api/SKILL.md` (read-only client).

**I cannot promise a full listing — that is not in the skills.** What exists is a per-image check (`tags/list`) and an unverified "list all repositories" call. In that order:

### 1. Check whether your pull account may list all repositories (UNKNOWN A-31)

Not confirmed anywhere in the skills, so this is a check, not an answer:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file /dev/stdin -w '\nhttp=%{http_code}\n' "https://$host/v2/_catalog" <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD"
```

- `http=200` with `{"repositories":[...]}` → that is your list (then filter to the project: the first path part of `REGISTRY_URL`). Tell me and I page through it and summarise by project and image count.
- `http=401` or `403` → this account may not list. That is the usual case for a pull-only robot account. Then way 2 or 3.
- `x509` → `REGISTRY_CA_FILE` is wrong.

The path is `/v2/_catalog` (plain registry API). The Harbor UI API (`/api/v2.0/...`) needs `%252F` in a repository name and is a different interface [live 2.19.0].

### 2. Read it per image (`tags/list`) — the reliable way

For a named image, the path rule is: the first part of `REGISTRY_URL` is the project, and `docker.io/<path>` sits at `<project>/<path>` [live 2.19.0]. Set `repo` to the path below `docker.io/`:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
repo=''; : "${repo:?set repo, for example library/busybox}"
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"; p="${h#"$host"}"; p="${p#/}"; p="${p:+$p/}"
url="https://$host/v2/$p$repo/tags/list"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file /dev/stdin -w '\nhttp=%{http_code}\n' "$url" <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD"
```

`200` lists the tags, `404` means the mirror does not have that image.

### 3. What the mirror *should* hold — list the bundle instead

This is the honest, offline answer to "everything that is in our mirror", because the mirror was seeded from these files. READ-ONLY, on this host:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls -l "$BUNDLE_DIR"/container-images/
tar -tf "$(ls "$BUNDLE_DIR"/container-images/konvoy-image-bundle-*.tar)" | sed -n 's#^docker/registry/v2/repositories/\(.*\)/_manifests/tags/\([^/]*\)/current/link$#\1:\2#p' | sort -u
```

Do the same for `kommander-image-bundle-*.tar`, `nkp-release-specs-*.tar`, and each `*catalog*.tar` (C1 has the one-line loop for the catalogs). The three "always needed" bundles hold 122 + 273 + the release specs images in 2.19.0 [live 2.19.0], so the list is long. The answer is: what is in the bundle, plus whatever extra bundles were pushed (an `EXTRA_BUNDLE` per push), plus whatever the registry already held before NKP.

### 4. Also valid

The Harbor UI shows every repository of a project to an account that may read it. That is a user action in your browser, and it is the quickest "everything" answer when the pull robot account cannot list.

Tell me which way you want: the `_catalog` check first (I run it), or the bundle listing (I run it and summarise). I do not claim a complete inventory from anything I have not read.
