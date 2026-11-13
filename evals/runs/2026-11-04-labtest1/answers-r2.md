# Answers (run r2)

## nkp-install E18

Skill files read: `nkp/SKILL.md`, `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`, `nkp-identity-security/SKILL.md` (section "License").

One thing in your message decides the cluster name. An Ultimate key (trial or paid) is bound to the name of the management cluster. A key for another name fails at the license step with `License key is not valid for this cluster`. You cannot rename a cluster. The only fix is delete the cluster and create it again. So I must know the name that is in the key **before** the create. The skills give no trial exception, so I treat the trial key as name-bound.

Applying the license after the install is correct. On AHV the management cluster installs Kommander as Starter, and the license goes on afterwards. Note two facts: you cannot go to a lower tier after you register a license, and a trial key adds `dkpLevel` and `endDate` to the license status.

I answer the five install questions first. Then I load the provider file and start the steps.

**My answers from your message**
1. Infrastructure: Nutanix AHV with Prism Central.
2. First cluster, so a management cluster (`--self-managed`).

**Questions I need**
1. Which cluster name is in the trial key? If the key does not say `skilltest-mgmt-01`, do we use the licensed name as `CLUSTER_NAME`, or do you get a new key for `skilltest-mgmt-01`?
2. Is this site connected or air-gapped? Does the site have its own registry mirror (Harbor, Nexus, Artifactory)? This selects one of three create cases: connected (N4A), air-gapped with the bundle only (N4B), site registry mirror (N4C).
3. Is the Ultimate trial key already in your hand, and which end date does it show? (No block now. You put the key in `~/nkp-site.env` at the license step, not before.)

**One warning for Ultimate, before the create**
The CLI defaults fit Pro and Ultimate: 3 control-plane nodes with 4 vCPU and 16 GiB, 4 workers with 8 vCPU and 32 GiB. But Ultimate installs much more. On 4 workers × 8 vCPU, Ultimate takes the CPU requests of the workers to 67–98 %. That is near the limit. If you want room for your own workloads, plan more or bigger workers at create time (`--worker-replicas`, `--worker-vcpus`) now, because a later change is a second step.

Stop here: no env-file block and no create in this reply (rule 4). Answer the questions and I continue with `nutanix.md` N1: the value list for `~/nkp-site.env` and `~/nkp-skilltest-mgmt-01.env` (or the licensed name), the values that you confirm one line at a time, then the operator host check, the Prism Central preflight, the dry run, and the create with your "yes".

While you answer, I run only this READ-ONLY check on the operator host. It starts no step and it changes nothing:

```bash
# READ-ONLY
nkp version
docker version --format '{{.Server.Version}}'
kubectl version --client
stat -fc %T /sys/fs/cgroup
tmux -V
nproc; free -g; df -h "${TMPDIR:-/tmp}"
```

I expect: the `nkp` line shows 2.19.x (same version as the install), Docker 27.4.0 or later, `cgroup2fs` on Linux, tmux present, and at least 4 CPU and 4 GB memory free for the kind bootstrap cluster. If the `nkp` line is another version, I use `cli/nkp` from the bundle instead.

## nkp-airgap A9

Skill files read: `nkp/SKILL.md`, `nkp-airgap/SKILL.md`, `nkp-airgap/references/nodes.md`, `nkp-airgap/references/catalogs.md`, `nkp-install/references/nutanix.md` (N6, default StorageClass), `kubernetes-core/references/workloads.md` (W5, PVC basics).

**The image:** `docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine`

Do not use `nginx:latest`, and do not use `docker.io/library/nginx`. The NKP bundle has no `library/nginx` image, so the mirror answers 404 for it. The images that a pushed bundle does have include `docker.io/library/busybox:1` and `docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine` [live 2.19.0]. The second one is nginx, it runs as a non-root user, and it listens on **8080**, not 80.

**How you write the image.** Write `docker.io/<path>:<tag>`. Do not write `REGISTRY_URL` in front of it. Each node has `/etc/containerd/certs.d/_default/hosts.toml` with `override_path = true`, so a `docker.io` pull goes to the mirror. The kubelet credential file on the node holds the pull account. So the pod needs no `imagePullSecret`.

**Check the path before you write the file.** I run:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
repo='nginxinc/nginx-unprivileged'; : "${repo:?set repo, for example library/busybox}"
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"; p="${h#"$host"}"; p="${p#/}"; p="${p:+$p/}"
url="https://$host/v2/$p$repo/tags/list"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file /dev/stdin -w '\nhttp=%{http_code}\n' "$url" <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD"
```

I expect `http=200` and a tag list that has `1.29.5-alpine`. `404` means the mirror does not have the image. `401` means a wrong pull account. `x509` means a wrong `REGISTRY_CA_FILE`. Then I use one of the tags that the list shows.

**The manifest.** Write the file, then apply. The apply is a CHANGES step: I show it and stop for "yes".

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: nutanix-volume
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-test
spec:
  containers:
  - name: nginx
    image: docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: nginx-data
```

`nutanix-volume` is the default StorageClass on AHV [live 2.19.0]. I check it first, because a wrong class leaves the PVC `Pending` and the pod `Pending` with it:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'ImagePullBackOff|ErrImagePull' || echo "no image pull errors"
```

Tell me the cluster name: your message says "the new cluster", and I do not take a name from an example. Until you give it, the block keeps `~/nkp-<cluster>.env`. The first `source` line has no name yet.

**If you really want upstream `nginx` (port 80, root user):** the image is not on the mirror and nothing offline can copy it. Then: on a connected host, `nkp create bundle` with `--images-file` that lists `docker.io/library/nginx:<tag>` (USER-TERMINAL, your host), move the tar to this host, append its path as `EXTRA_BUNDLE`, and push it with `nkp push bundle --bundle "$EXTRA_BUNDLE" --to-registry ...` (CHANGES, I show the plan and stop for "yes"). Then the manifest uses `docker.io/library/nginx:<tag>`. That is more work than the smoke test needs.

## nkp-vpc V1

Skill files read: `nkp/SKILL.md`, `nkp-vpc/SKILL.md`, `nkp-vpc/references/layouts.md`, `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`, `ntnx-skills/nutanix-networking/RECIPES.md` (Floating IPs, Subnets, VPCs, Free IP check), `ntnx-skills/nutanix-nkp/RECIPES.md` (Site preflight).

Your case is the **exposed** layout: a management cluster, users outside the VPC, NAT external subnet. PC 7.5 meets the requirement (AOS and PC 7.5 or later, Network Controller 7.0.0 or later, NKP 2.17 or later).

**Floating IPs: 2.**

| Floating IP | Private IP it maps to | Variable | Why |
|---|---|---|---|
| `FIP_API` | `CP_VIP` (kube-vip, overlay) | `FIP_API`, `API_EXTERNAL_ENDPOINT` | The corp LAN runs kubectl against `API_EXTERNAL_ENDPOINT`; the nodes also join the API through it. |
| `FIP_UI` | first IP of `LB_IP_RANGE` (Traefik) | `FIP_UI`, `UI_HOSTNAME` | The NKP UI for the corp LAN. |

The guide asks for a third floating IP for `--extra-sans`. You do not need it. `--control-plane-external-endpoint` already puts the external endpoint into the API certificate, and `CP_VIP` is not in the certificate names. Use `https://API_EXTERNAL_ENDPOINT:6443` for kubectl, not `https://CP_VIP:6443`.

Add one more floating IP only in these two cases:
- `+1` if people on the corp LAN SSH to the bastion. The bastion is in the VPC, so its overlay IP is private.
- `+1` for each more `LoadBalancer` Service that the corp LAN must reach. No NKP object makes these. Add them with step 6 of the skill.

A NAT external subnet cannot route the overlay out, so the floating IPs are the only path. If the network team routes the overlay range through a no-NAT subnet later, the floating IPs are not needed.

**What I add to the create.** Two lines, in the `nkp-install` create script for this cluster, before `"$@"`:

```text
  --control-plane-external-endpoint "$API_EXTERNAL_ENDPOINT" \
  --cluster-hostname "$UI_HOSTNAME" \
```

- `--cluster-hostname` works on a **management** cluster only. It gives the UI certificate `kommander-traefik-tls` the `UI_HOSTNAME` name. Without it, Traefik sends the login `/_oauth_kommander` to the **private** LB IP with a 307 redirect, and a browser on the corp LAN cannot follow it.
- Traefik keeps its overlay IP from `LB_IP_RANGE`. The external endpoint replaces the VIP in the CAPI `Cluster`, in kubeadm, in `cluster-info`, in the Cilium `KUBERNETES_SERVICE_HOST`, and in the kubeconfig.
- No other flag changes for the VPC. The CNI stays Cilium.
- The registry, bundle, and NTP flags do not change (N4B or N4C).

**Order: the two floating IPs go in Prism Central before the create.** The nodes join through `FIP_API`. Both are "Virtual IP" associations: no VM NIC owns `CP_VIP` or the LB IP. So each one is a `PrivateIpAssociation` in one POST. Do it as a plan and stop for "yes" (CHANGES, in Prism Central). Done when each one shows `associationStatus` `ASSOCIATED_TO_PRIVATE_IP` (not `ASSOCIATED_TO_VNIC`). Record the address and the extId of each one; the delete later needs them.

**Warning for this exact layout.** The bastion is in the VPC, so the create makes its kind bootstrap cluster on a NIC with MTU 1442, and Docker uses 1500. Then TLS to Prism Central fails during the bootstrap. I run this before the dry run:

```bash
# READ-ONLY  (needs jq)
source ~/nkp-site.env 2>/dev/null
dev=$(ip route show default | awk '{print $5; exit}'); echo "nic $dev mtu $(cat "/sys/class/net/$dev/mtu")"
docker network inspect bridge --format 'bridge mtu {{index .Options "com.docker.network.driver.mtu"}}'
docker network inspect kind --format 'kind mtu {{index .Options "com.docker.network.driver.mtu"}} containers {{len .Containers}}' 2>/dev/null || echo "no kind network"
curl -sk -o /dev/null -m 10 -w 'pc %{http_code}\n' "$PC_ENDPOINT"
```

If the bridge or kind MTU is not the NIC MTU, I fix Docker (layouts.md L8, it restarts Docker) after your "yes", and only then start the dry run. `pc` must not be `000` (`302` is normal).

**Values I need before I write any block** (I append each one only after you give or confirm it): `VPC_NAME` (`tenant-a`), the overlay subnet `tenant-a-nodes` as `SUBNET` (it goes in `~/nkp-site.env`, because this is a management cluster), `CP_VIP`, a new `LB_IP_RANGE`, `FIP_API`, `FIP_API_ID`, `API_EXTERNAL_ENDPOINT`, `FIP_UI`, `FIP_UI_ID`, `UI_HOSTNAME` (to the cluster env file). Also N1: `PE_CLUSTER`, `STORAGE_CONTAINER`, `VM_IMAGE`, `SSH_PUBKEY_FILE`, `PC_ENDPOINT`, and `NTP_SERVERS` if the site is air-gapped. A DNS name needs an A record first; without DNS, the values are the floating IP addresses.

Two more checks before the create:
- `CP_VIP` and `LB_IP_RANGE` are in the overlay subnet, outside its IPAM pool, and free. The free-IP recipe proves this from a host in the VPC: the bastion. Good, it is in the same VPC.
- The pod CIDR (`192.168.0.0/16`) and the service CIDR (`10.96.0.0/12`) do not overlap any VPC range that the nodes route to. I run that check with `vpc_cidrs` set to your list.

Done when the cluster answers `api 200` from the corp LAN on `API_EXTERNAL_ENDPOINT`, the `ui=` value is `UI_HOSTNAME`, and `ui 302`.

## nkp-vpc V4

Skill files read: `nkp/SKILL.md`, `nkp-vpc/SKILL.md` (step 6 and step 7), `nkp-cluster-lifecycle/references/delete.md`, `ntnx-skills/nutanix-nkp/RECIPES.md` (Leftover audit for a cluster), `ntnx-skills/nutanix-storage/RECIPES.md` ("What an NKP cluster leaves behind", "Delete a volume group"), `ntnx-skills/nutanix-networking/RECIPES.md` (Floating IPs, Subnets, VPCs, Subnet IP reservations).

`nkp delete cluster` deletes the node VMs and their disks. It does **not** delete the floating IPs, the overlay subnet, or the VPC. It also keeps one Nutanix volume group for each PVC that the cluster had. So "nothing left in Prism Central" is these steps, in this order.

The blocks use `~/nkp-tenant-b-dev.env`. Tell me the workspace namespace (`WORKSPACE_NS`) and the VPC name (`VPC_NAME`) if the env file is not there.

**1. Record first. I run (READ-ONLY).** Do this before the delete: the floating IP delete needs the extIds, and after the delete the association still shows.

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
echo "cluster=$CLUSTER_NAME vpc=$VPC_NAME subnet=$SUBNET vip=$CP_VIP lb=$LB_IP_RANGE"
echo "fip_api=$FIP_API id=$FIP_API_ID fip_ui=$FIP_UI id=$FIP_UI_ID"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,IP:.status.loadBalancer.ingress[0].ip
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o name
```

**2. Safety gate. I run (READ-ONLY).** From the folder of the create.

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,SIZE:.spec.capacity.storage,HANDLE:.spec.csi.volumeHandle'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nkpclusters -A
```

- I expect `error: the server doesn't have a resource type "nkpclusters"` or `No resources found`: the cluster manages no other cluster. A list here: stop, delete those first.
- Each PV is one volume group in Prism Central. `HANDLE` is `NutanixVolumes-<uuid>`, and `<uuid>` is the extId of the group. I keep this list for step 5.
- If a PVC holds data that you need, I stop and ask for the backup first.

The plan I show you, then I stop. It says: all nodes and VMs go, all pods go, all `LoadBalancer` Services go, all PVC data in the cluster becomes unreachable; the floating IPs, the subnet, the VPC, the volume groups, and the mirror Secrets stay until the steps below. Approval needs `yes` **and** the exact cluster name `tenant-b-dev`.

**3. Delete (CHANGES, after "yes" and the name).**

```bash
# CHANGES  (deletes the workload cluster: its VMs, nodes, and data; cannot be undone)
source ~/nkp-tenant-b-dev.env 2>/dev/null
nkp delete cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m
```

I expect three `•`/`✓` steps, then `INF Deleted <namespace>/tenant-b-dev cluster`, then `RC` 0. About 1 min. The nodes, and any VMs with the name prefix, must be gone.

**4. Check. I run (READ-ONLY), after RC 0.**

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters,clusters.cluster.x-k8s.io,machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME"
curl -sk -o /dev/null -w 'api %{http_code}\n' --max-time 5 "https://${API_EXTERNAL_ENDPOINT:-$CP_VIP}:6443/version"
```

I expect `No resources found` and `NotFound`, and `api 000`. A floating IP that still points to a private IP that no VM holds answers `000`. That is normal until step 5.

**5. Leftover audit in Prism Central. I run (READ-ONLY).** This composes the `nutanix-*` recipes; it reads only.

```bash
# READ-ONLY  (needs python3; the client reads PC_ENDPOINT, NUTANIX_USER, NUTANIX_PASSWORD from ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import sys; sys.path.insert(0, '/tmp/nkp-eval-lt1/ntnx-skills/nutanix-api/scripts'); from ntnx import *
N = '/networking/v4.4/config'; G = '/volumes/v4.3/config/volume-groups'; V = '/vmm/v4.1/ahv/config/vms'
CAT = '/prism/v4.0/config/categories'
ipv = lambda o: ((o or {}).get('ipv4') or {}).get('value') if isinstance(o, dict) else None

def vg_row(g):
    d = g.get('description') or ''
    if 'K8sClusterID' not in d or ' for ' not in d:
        return None
    f = lambda k: next((p.split(':', 1)[1] for p in d.split(', ') if p.startswith(k + ':')), None)
    return d.split(' for ', 1)[1].split(',', 1)[0], f('PVC'), f('NS')

cluster = 'tenant-b-dev'
out = {'VMs': [{'name': v['name'], 'extId': v['extId'], 'power': v.get('powerState')}
               for v in list_all(V, filter=f"startswith(name,'{cluster}')")],
       'volume_groups': [], 'floating_ips': [], 'floating_ips_unnamed': [],
       'ip_reservations': [], 'categories': []}
for g in list_all(G):
    e = vg_row(g)
    if (not g.get('isHidden') and g.get('usageType') != 'INTERNAL' and e and e[0] == cluster
            and not (req(f'{G}/{g["extId"]}/vm-attachments')[2].get('data') or [])):
        out['volume_groups'].append({'name': g['name'], 'extId': g['extId'], 'pvc': e[1], 'ns': e[2]})
for f in list_all(f'{N}/floating-ips'):
    row = {'address': ((f['floatingIp'] or {}).get('ipv4') or {}).get('value'), 'name': f['name'],
           'extId': f['extId'], 'status': f.get('associationStatus'),
           'private': ipv(((f.get('association') or {}).get('privateIp') or {}))}
    if cluster in (f.get('name') or ''):
        out['floating_ips'].append(row)
    elif row['private']:
        out['floating_ips_unnamed'].append(row)
for s in list_all(f'{N}/subnets'):
    for r in (req(f'{N}/subnets/{s["extId"]}/reserved-ips')[2].get('data') or []):
        if cluster in (r.get('clientContext') or ''):
            out['ip_reservations'].append({'ip': r.get('ipv4Address'), 'subnet': s['name'], 'context': r.get('clientContext')})
used = {c.get('extId') for v in list_all(V) for c in v.get('categories') or []}
for c in list_all(CAT):
    if cluster in (c.get('key') or '') or cluster in (c.get('value') or ''):
        out['categories'].append({'key': c['key'], 'value': c['value'], 'extId': c['extId'], 'inUse': c['extId'] in used})
out['counts'] = {k: len(v) for k, v in out.items() if isinstance(v, list)}
print(out['counts'])
[print(k, r) for k, v in out.items() if isinstance(v, list) for r in v]
PY
```

This is the `nutanix-nkp` RECIPES.md recipe "Leftover audit for a cluster", with the cluster name set. I report the counts first, then the rows: `VMs` (expect 0), `volume_groups` (normal after a delete, one per PVC), `floating_ips` (normal: NKP never deletes them), `floating_ips_unnamed` (bulk `fip-dummy-name` floating IPs: candidates only, I confirm that each private IP is `CP_VIP` or the first LB IP of the cluster before a delete), `ip_reservations`, `categories` (`inUse` false means nothing holds it). The name is a prefix match: a row named `tenant-b-dev-02` belongs to another cluster, I say so and do not touch it.

**6. Floating IPs (CHANGES, plan then "yes").** One per row: `FIP_API`, plus one for each `LoadBalancer` Service of step 1, unless another cluster uses it. For each one: read it by extId, check the address, disassociate (PUT without the association), then delete with a fresh ETag. Never delete an associated floating IP directly. Done when a read by extId gives 404. About 6 s each.

**7. Volume groups (CHANGES, plan then "yes"). Only if the step 2 PV list was not empty.** First the READ-ONLY "What an NKP cluster leaves behind": it keeps only a group whose description has `for tenant-b-dev,` and `K8sClusterID`, with `vm-attachments` empty, and never a Prism Central internal group. I compare that list with the PV list (`<uuid>` = extId), then show the count, and for each group the name, extId, PVC, and namespace. The delete destroys the PVC data. After the delete, run the list again: no group.

**8. Mirror Secrets (CHANGES, plan then "yes").**

```bash
# READ-ONLY
source ~/nkp-tenant-b-dev.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get secret "$CLUSTER_NAME-oci-cert" "$CLUSTER_NAME-oci-creds"
```

`NotFound` for both: the cluster had no mirror flags, skip. Otherwise delete the two Secrets. Use the workload cluster `WORKSPACE_NS`, never `kommander`.

**9. Overlay subnet and VPC. I ask you, and I do not delete them by default.** A cluster delete never means a subnet or VPC delete: the next cluster in this VPC, or the bastion, can use them. I delete the overlay subnet of this cluster and its VPC only when you say the site does not need them. Then: the overlay subnet first, then the VPC (its route table goes with it). **Keep the external subnet**: other VPCs use it. `CP_VIP` and `LB_IP_RANGE` are free again in the overlay.

**10. Operator host files (CHANGES, plan then "yes"). Last**, because the list holds the cluster env file: the create script, the patch and node pool files, the dry-run `.yaml` (it holds Secrets), the create log, the kubeconfig, and `~/nkp-tenant-b-dev.env`.

**11. Audit again. I run (READ-ONLY).** Done when the counts are 0 for every kind, except the subnet and VPC that you chose to keep. Tell me that choice, and I report it as the one known remainder. Prism Central images stay: other clusters use them.
