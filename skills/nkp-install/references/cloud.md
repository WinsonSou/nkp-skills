# Install NKP on AWS, EKS, Azure, AKS, GCP, or vSphere

Use this file from skill `nkp-install`. The live 2.19.0 files have no `--help` for these providers, so every flag here has a `[pdf p.N]` tag. Sections have C-labels so that they do not mix with the steps in `SKILL.md`.

Site variables of this file (rule 4; same use as the rules table):

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `AWS_REGION` `AWS_PROFILE` `AWS_VPC_ID` `AWS_SUBNET_IDS` `AWS_SECURITY_GROUP_IDS` `AWS_AMI_ID` `AZURE_SUBSCRIPTION_ID` `AZURE_TENANT_ID` `AZURE_CLIENT_ID` `AZURE_IMAGE_ID` `GCP_PROJECT` `GCP_IMAGE` `GOOGLE_APPLICATION_CREDENTIALS` `VSPHERE_SERVER` `VSPHERE_DATACENTER` `VSPHERE_RESOURCE_POOL` `VSPHERE_DATASTORE` `VSPHERE_FOLDER` `VSPHERE_NETWORK` `VSPHERE_TEMPLATE` |
| `~/nkp-site.env` secrets | `AWS_ACCESS_KEY_ID` `AWS_SECRET_ACCESS_KEY` `AWS_SESSION_TOKEN` `AZURE_CLIENT_SECRET` `VSPHERE_USERNAME` `VSPHERE_PASSWORD` |
| `~/nkp-<cluster>.env` | `K8S_VERSION` |

## C1. Before you start

| Provider | License | Management cluster | Workload cluster | Section |
|---|---|---|---|---|
| AWS (EC2) | Pro, Ultimate [pdf p.27] | yes | yes | C3 |
| EKS | Ultimate [pdf p.28] | **no** (cannot be self-managed) [pdf p.856] | yes, Kubernetes 1.34 or later [pdf p.856] | C4 |
| Azure (VMs) | Pro, Ultimate [pdf p.27] | yes | yes | C5 |
| AKS | Ultimate [pdf p.27] | **no** [pdf p.901] | yes | C6 |
| GCP | Pro, Ultimate [pdf p.28] | yes | yes | C7 |
| vSphere | Pro, Ultimate [pdf p.28] | yes | yes | C8 |

- EKS and AKS need an existing management cluster with Kommander. [pdf p.901]
- A management cluster and a workload cluster on different infrastructures need Ultimate (Multi-Cloud). [pdf p.28]
- AWS, Azure, GCP, and vSphere nodes need a machine image that you build with NIB (`nkp create image <provider>`). Use skill `nkp-airgap` for the image. EKS uses the Amazon EKS optimized AMI. [pdf p.828, p.855, p.922]
- The operator host needs the cloud CLI (`aws`, `az`, `gcloud`) to make the IAM roles or the service principal. The user does that part in their cloud account. [pdf p.820, p.195, p.911]
- UNKNOWN (P-06): which providers make ClusterClass clusters in 2.19. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters -A -o custom-columns=NAME:.metadata.name,CLASS:.spec.topology.classRef.name`.

Check the provider flags in the CLI first. The guide pages and the CLI can differ:

```bash
# READ-ONLY  (replace aws with the provider name)
nkp create cluster aws --help
```

Done when: every flag of the script that you plan to write is in the `--help` output. If a flag is not there, stop and tell the user. Look for these flags by name, because the guide does not show them for every provider [field]:
- `--namespace` and `--kubeconfig` (AWS, vSphere, EKS, AKS workload cluster)
- `--dry-run` and `--output` (EKS, AKS)
- with a proxy: `--control-plane-http-proxy` and `--worker-http-proxy` (not on EKS; AKS has only `--worker-http-proxy`)

## C2. Values, secrets, and the registry

Append each known value to the file in the "File" column (rule 4). Make a cluster env file first (`SKILL.md` step "Prepare the env files"). For a workload cluster, append its workspace namespace as `WORKSPACE_NS`. For a management cluster, append `WORKSPACE_NS='kommander'`.

| Provider | Site values (`~/nkp-site.env`) | Secrets (user adds them with an editor) | Cluster values |
|---|---|---|---|
| AWS | `AWS_REGION` `AWS_PROFILE` `AWS_VPC_ID` `AWS_SUBNET_IDS` `AWS_SECURITY_GROUP_IDS` `AWS_AMI_ID` | `AWS_ACCESS_KEY_ID` `AWS_SECRET_ACCESS_KEY` `AWS_SESSION_TOKEN` (only when the user has no profile) | `CLUSTER_NAME` |
| EKS | `AWS_REGION` `AWS_PROFILE` `MGMT_KUBECONFIG` | as AWS | `CLUSTER_NAME` `WORKSPACE_NS` |
| Azure | `AZURE_SUBSCRIPTION_ID` `AZURE_TENANT_ID` `AZURE_CLIENT_ID` `AZURE_IMAGE_ID` | `AZURE_CLIENT_SECRET` | `CLUSTER_NAME` |
| AKS | as Azure, without `AZURE_IMAGE_ID`; `MGMT_KUBECONFIG` | `AZURE_CLIENT_SECRET` | `CLUSTER_NAME` `WORKSPACE_NS` `K8S_VERSION` |
| GCP | `GCP_PROJECT` `GCP_IMAGE` `GOOGLE_APPLICATION_CREDENTIALS` (the path of the key file) | the key file itself (never print it) | `CLUSTER_NAME` |
| vSphere | `VSPHERE_SERVER` `VSPHERE_DATACENTER` `VSPHERE_RESOURCE_POOL` `VSPHERE_DATASTORE` `VSPHERE_FOLDER` `VSPHERE_NETWORK` `VSPHERE_TEMPLATE` `SSH_PUBKEY_FILE` | `VSPHERE_USERNAME` `VSPHERE_PASSWORD` | `CLUSTER_NAME` `CP_VIP` |

- AWS: the cluster name must be unique in the AWS account. [pdf p.829]
- Registry mirror (air-gapped, or for speed): append `REGISTRY_URL` and `REGISTRY_CA_FILE`, and the user adds `REGISTRY_MIRROR_USERNAME` and `REGISTRY_MIRROR_PASSWORD`. Every script adds the mirror flags only when `REGISTRY_URL` has a value. [pdf p.829-830, p.842] To seed the mirror, use skill `nkp-airgap`.
- Air-gapped site, management cluster: load the bootstrap image first. [pdf p.828] Use `podman` instead of `docker` on a Podman host.

```bash
# CHANGES  (loads the bootstrap image into the local container engine)
source ~/nkp-site.env 2>/dev/null
docker load -i "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)"
```

- Connected site without a mirror: the cluster pulls NKP images with the Nutanix Docker Hub token. [pdf p.675] If `--help` shows `--nutanix-registry-username`, add `--nutanix-registry-username "$NUTANIX_REGISTRY_USERNAME" --nutanix-registry-password "$NUTANIX_REGISTRY_TOKEN"` as a line before `"$@"`.
- The CLI takes the mirror password and the token only as flags. Other users on the host can see them in the process list. Tell the user this.
- Proxy: add the lines from skill `nkp-networking`, its file `proxy.md`, sections X2 and X3. The three flags `--http-proxy`, `--https-proxy`, and `--no-proxy` alone do not set the nodes on these providers.

Check the names. Keep only the `for v in` line of the provider. Add `REGISTRY_URL` and the mirror names when you use a mirror. The AWS line has no key names, because a profile is also possible:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for v in CLUSTER_NAME AWS_REGION AWS_VPC_ID AWS_SUBNET_IDS AWS_AMI_ID; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in CLUSTER_NAME WORKSPACE_NS AWS_REGION MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in CLUSTER_NAME AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_IMAGE_ID; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in CLUSTER_NAME WORKSPACE_NS K8S_VERSION MGMT_KUBECONFIG AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in CLUSTER_NAME GCP_PROJECT GCP_IMAGE GOOGLE_APPLICATION_CREDENTIALS; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in CLUSTER_NAME CP_VIP SSH_PUBKEY_FILE VSPHERE_SERVER VSPHERE_DATACENTER VSPHERE_RESOURCE_POOL VSPHERE_DATASTORE VSPHERE_FOLDER VSPHERE_NETWORK VSPHERE_TEMPLATE VSPHERE_USERNAME VSPHERE_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

The lines are, in order: AWS, EKS, Azure, AKS, GCP, vSphere.

Done when: each name prints `set:`.

## C3. AWS (EC2)

Prerequisites (the user does them): the IAM CloudFormation stacks for the bootstrapper and for the cluster roles, and a NIB AMI in the region. Air-gapped: the VPC has the endpoints `ec2`, `elasticloadbalancing`, `secretsmanager`, `autoscaling`, `ecr.api`, `ecr.dkr`, and the subnets are private, one per Availability Zone. [pdf p.822-829] Defaults: 3 control-plane nodes `m5.xlarge`, 4 workers `m5.2xlarge`, 80 GiB root volume. [pdf p.821]

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster aws \
  --self-managed \
  --cluster-name "$CLUSTER_NAME" \
  --with-aws-bootstrap-credentials=true \
  --vpc-id "$AWS_VPC_ID" \
  --subnet-ids "$AWS_SUBNET_IDS" \
  --ami "$AWS_AMI_ID" \
  ${AWS_SECURITY_GROUP_IDS:+--additional-security-group-ids "$AWS_SECURITY_GROUP_IDS"} \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_CA_FILE:+--registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  "$@"
EOF
)
```

- All flags: [pdf p.830]. `--internal-load-balancer=true` keeps the API load balancer private (air-gapped). `--os-hint flatcar` is for Flatcar images. Add them before `"$@"` when the user asks. [pdf p.830]
- Workload cluster: replace `--self-managed` with `--kubeconfig "$MGMT_KUBECONFIG" --namespace "$WORKSPACE_NS"`. The guide shows these two flags for Azure and GCP, not for AWS. [field] C1 checks them.
- FIPS: the guide adds `--kubernetes-version`, `--etcd-version`, `--kubernetes-image-repository`, `--etcd-image-repository` with `+fips.0` versions and a FIPS AMI. [pdf p.829] Use skill `nkp-airgap` for the FIPS image.

Done when: the script exists. Then do C9.

## C4. EKS (workload cluster only)

Prerequisites: the EKS IAM stack and the EBS CSI policy on the node role (the user does them). [pdf p.848-855] Kubernetes before 1.34 needs `nkp legacy create cluster eks`, which is deprecated. [pdf p.856]

UNKNOWN (P-05): the CNI on an EKS cluster. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'cilium|calico'`.

1. Only with access keys (not with a role on the bastion): refresh the bootstrap credentials in the management cluster. [pdf p.855]

```bash
# CHANGES  (updates the AWS credentials that the management cluster uses)
source ~/nkp-site.env 2>/dev/null
KUBECONFIG="$MGMT_KUBECONFIG" nkp update bootstrap credentials aws
```

2. Write the script. With ECR as the mirror, the guide uses `REGISTRY_MIRROR_USERNAME='AWS'` and the output of `aws ecr get-login-password` as the password. [pdf p.855] The user puts that password into `~/nkp-site.env` with an editor.

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster eks \
  --kubeconfig "$MGMT_KUBECONFIG" \
  --namespace "$WORKSPACE_NS" \
  --cluster-name "$CLUSTER_NAME" \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  "$@"
EOF
)
```

- `--cluster-name` and `--kubeconfig`: [pdf p.855]. `--namespace` is not shown for EKS. [field] C1 checks it.
- The NKP version that creates an EKS cluster must also delete it. [pdf p.856]

Done when: the script exists. Then do C9.

## C5. Azure (VMs)

Prerequisites: a service principal with the `contributor` role (`az ad sp create-for-rbac`, the user does it), and a NIB image in an Azure Compute Gallery. [pdf p.195, p.885] The CLI reads Base64 copies of the four Azure values, so the script makes them. [pdf p.196-197]

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
b64() { tr -d '\n' | base64 | tr -d '\n'; }
export AZURE_SUBSCRIPTION_ID_B64="$(b64 <<<"$AZURE_SUBSCRIPTION_ID")" AZURE_TENANT_ID_B64="$(b64 <<<"$AZURE_TENANT_ID")"
export AZURE_CLIENT_ID_B64="$(b64 <<<"$AZURE_CLIENT_ID")" AZURE_CLIENT_SECRET_B64="$(b64 <<<"$AZURE_CLIENT_SECRET")"
nkp create cluster azure \
  --self-managed \
  --cluster-name "$CLUSTER_NAME" \
  --compute-gallery-id "$AZURE_IMAGE_ID" \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_CA_FILE:+--registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  "$@"
EOF
)
```

- `--self-managed`, `--cluster-name`: [pdf p.197]. `--compute-gallery-id` format: `/subscriptions/<id>/resourceGroups/<group>/providers/Microsoft.Compute/galleries/<gallery>/images/<definition>/versions/<version>`. [pdf p.885]
- Image from an Azure Marketplace base image: also add `--plan-offer`, `--plan-publisher`, `--plan-sku`. [pdf p.880-881, p.885]
- Workload cluster: replace `--self-managed` with `--kubeconfig "$MGMT_KUBECONFIG" --namespace "$WORKSPACE_NS"`. [pdf p.202]
- Default storage is the Azure CSI driver. Default VM: `Standard_D4s_v3`. [pdf p.194, p.872]

Done when: the script exists. Then do C9.

## C6. AKS (workload cluster only)

Credentials: the same service principal and Base64 values as C5. [pdf p.204-206] Ask the user to choose an AKS Kubernetes version from `az aks get-versions -o table --location <region>` and append it as `K8S_VERSION` to the cluster env file. [pdf p.902]

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
b64() { tr -d '\n' | base64 | tr -d '\n'; }
export AZURE_SUBSCRIPTION_ID_B64="$(b64 <<<"$AZURE_SUBSCRIPTION_ID")" AZURE_TENANT_ID_B64="$(b64 <<<"$AZURE_TENANT_ID")"
export AZURE_CLIENT_ID_B64="$(b64 <<<"$AZURE_CLIENT_ID")" AZURE_CLIENT_SECRET_B64="$(b64 <<<"$AZURE_CLIENT_SECRET")"
KUBECONFIG="$MGMT_KUBECONFIG" nkp create cluster aks \
  --namespace "$WORKSPACE_NS" \
  --cluster-name "$CLUSTER_NAME" \
  --kubernetes-version "$K8S_VERSION" \
  "$@"
EOF
)
```

- `--cluster-name`, `--kubernetes-version`, and the management kubeconfig in `KUBECONFIG`: [pdf p.901-902]. `--namespace` is not shown for AKS. [field] C1 checks it.

Done when: the script exists. Then do C9.

## C7. GCP

Prerequisites: a service account with the Editor role plus `compute.disks.setIamPolicy` and `compute.instances.setIamPolicy`, and its key file (the user does them). Google publishes no NKP image: build one with NIB. [pdf p.911-912, p.922] `GCP_IMAGE` has the form `projects/<project>/global/images/<image>`. [pdf p.224] The script makes the Base64 credentials from the key file. [pdf p.913]

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
export GCP_B64ENCODED_CREDENTIALS="$(base64 < "$GOOGLE_APPLICATION_CREDENTIALS" | tr -d '\n')"
nkp create cluster gcp \
  --self-managed \
  --cluster-name "$CLUSTER_NAME" \
  --with-gcp-bootstrap-credentials=true \
  --project "$GCP_PROJECT" \
  --image "$GCP_IMAGE" \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_CA_FILE:+--registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  "$@"
EOF
)
```

- Flags: [pdf p.218, p.923]. The VPC network `default` is used unless you add `--network <name>`. [pdf p.218, p.922]
- Workload cluster: replace `--self-managed` with `--kubeconfig "$MGMT_KUBECONFIG" --namespace "$WORKSPACE_NS"`. [pdf p.224]
- Control-plane nodes go to 3 zones; workers to one zone. Default region `us-west1`. [pdf p.922]

Done when: the script exists. Then do C9.

## C8. vSphere

Prerequisites: vSphere Client 7.0.3 or later on the operator host, CNS (vSphere 7.0.3 or later) for persistent volumes, the NKP vSphere roles, a DHCP network, shared storage, and a NIB VM template that matches the Kubernetes version. [pdf p.835-841] `CP_VIP` is a static IP for the API endpoint, outside the DHCP range. [pdf p.842][field] The CLI reads `VSPHERE_SERVER`, `VSPHERE_USERNAME`, and `VSPHERE_PASSWORD` from the environment. [pdf p.842]

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster vsphere \
  --self-managed \
  --cluster-name "$CLUSTER_NAME" \
  --server "$VSPHERE_SERVER" \
  --data-center "$VSPHERE_DATACENTER" \
  --resource-pool "$VSPHERE_RESOURCE_POOL" \
  --data-store "$VSPHERE_DATASTORE" \
  --folder "$VSPHERE_FOLDER" \
  --network "$VSPHERE_NETWORK" \
  --control-plane-endpoint-host "$CP_VIP" \
  --vm-template "$VSPHERE_TEMPLATE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_CA_FILE:+--registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  "$@"
EOF
)
```

- Flags: [pdf p.842]. `--registry-mirror-cacert`: [pdf p.681] (all providers).
- Workload cluster: replace `--self-managed` with `--kubeconfig "$MGMT_KUBECONFIG" --namespace "$WORKSPACE_NS"`. The guide does not show these two flags for vSphere. [field] C1 checks them.
- The service `LoadBalancer` setup on vSphere is not in the skills. After the create, check:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools
```

Done when: the script exists. Then do C9.

## C9. Dry run, then create

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|^  name:|^  namespace:|^ +(image|ami|amiID|id|region|instanceType|vmSize|url):' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

The file holds Secrets. Never print it. `--dry-run` and `--output yaml`: [pdf p.830, p.880, p.919, p.923]. The guide does not show them for EKS and AKS. [field] C1 checks them. Done when: the dry run ends without an error, and the user agrees with the shown lines. Then create:

```bash
# CHANGES  (creates the cluster in the cloud or vSphere account: machines, load balancers, and with --self-managed the bootstrap cluster and the pivot)
source ~/nkp-<cluster>.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

Done when: the command ends without an error. Then go to the `SKILL.md` step "Set the kubeconfig variables", and then "Check or install Kommander" (management cluster). Status: `nkp describe cluster` shows each Machine READY `True`. [pdf p.856]

## C10. Common failures

| Symptom | Cause | Fix |
|---|---|---|
| A flag is unknown | The guide and the CLI differ. | Use the flag name from `nkp create cluster <provider> --help`. |
| AWS: access denied | The IAM stacks or the instance profiles are missing. [pdf p.822-826] | Ask the user to apply the CloudFormation stacks. |
| AWS air-gapped: nodes do not join | VPC endpoints are missing, or the subnets cannot reach the mirror. [pdf p.829] | Ask the user to add the endpoints and routes. |
| EKS: create refused | Kubernetes before 1.34, or `--self-managed` used. [pdf p.856] | Use 1.34 or later. Create it from the management cluster. |
| Azure: image not found | Wrong `--compute-gallery-id`, or the plan flags are missing for a Marketplace base. [pdf p.885] | Correct `AZURE_IMAGE_ID`. Add the plan flags. |
| GCP: no image | Google publishes no NKP image. [pdf p.922] | Build it with NIB (skill `nkp-airgap`). |
| vSphere: template error | The template does not match the Kubernetes version. [field] | Build a new template with NIB (skill `nkp-airgap`). |

For other failures, use skill `nkp-troubleshooting`. For node pools and deleting a cluster, use skill `nkp-cluster-lifecycle`.
