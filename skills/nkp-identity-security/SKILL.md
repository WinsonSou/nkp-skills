---
name: nkp-identity-security
description: >
  NKP identity and security: Dex login and identity providers (LDAP, Active Directory, OIDC, SAML, GitHub),
  local users, RBAC, 403 Forbidden, workspaces, projects and their roles, tenant login URL, Gatekeeper
  policies and "validation.gatekeeper.sh denied", Pod Security Admission, encryption at rest, node users,
  FIPS, CIS, nkp-deletion-protection "Deletion denied", External Secrets Operator, apply or change a license.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-03"
  sources: "live 2.19.0, pdf 2.19"
---

# NKP identity and security

<!-- RULES:BEGIN -->
## Rules for every NKP skill

1. **Marks.** Line 1 of each command block is `# READ-ONLY`, `# CHANGES`, or `# USER-TERMINAL`. CHANGES: it changes a cluster, the infrastructure, a registry, the container engine, or a file on the operator host. USER-TERMINAL: it shows a secret on the screen, or it runs on another host (the text after the mark names the host). Give it to the user to run in their own terminal. Do not run it.
2. **Approval.** Before a CHANGES block, show the command, the target, and the result. Stop. Run it only after the user types "yes" to that plan. "Just run it" is not "yes". If the user answers with another word (for example "proceed" or "ok"), ask them to type "yes".
3. **Env files.** Run blocks with bash. `~/nkp-site.env` holds the site values and the secrets. `~/nkp-<cluster>.env` holds the values of one cluster. Its first line is `source ~/nkp-site.env 2>/dev/null`. Line 2 of a block is `source ~/nkp-<cluster>.env 2>/dev/null` when the block uses a cluster-file variable. Otherwise line 2 is `source ~/nkp-site.env 2>/dev/null`. Before you run a block, replace `<cluster>` in `~/nkp-<cluster>.env` with the cluster name. If the user has not named the cluster, keep `~/nkp-<cluster>.env` in the block and ask for the name. Do not take a name from an example or another conversation. After the cluster env file exists, use its real name (for example `~/nkp-dev-01.env`) in every block that you show. Commands use the variables as `"$VAR"`.
4. **Values.** When you know a value, append one line to its file: `echo "export VAR='value'" >> ~/nkp-site.env` (CHANGES). Write a line only after the user gives or confirms the value. Ask first, and write the line in a later reply, after the answer. If the user has not given the value, do not show the append block. Do not put an example or a guessed value in it. Never write an empty value or a placeholder such as `<ip>`. A shell value inside a block (for example `obj=''`) stays empty, with its `:?` guard, until the user gives it. Never put `<...>` text in it. To change a value, append a new line. The last line wins. Some skill files add a `| File | Site variables |` table with more variables. For a value with no variable in these tables, make an UPPER_SNAKE name and ask the user. If `~/nkp-site.env` does not exist, make it: `touch ~/nkp-site.env && chmod 600 ~/nkp-site.env` (CHANGES).
5. **Secrets.** The user types the secret lines into `~/nkp-site.env` with an editor. Do not repeat or use a secret from the chat, and do not write it into an example line. Tell the user to put it in the file and to change it. Check a secret only with `printenv VAR >/dev/null` or `[ -n "$(printenv VAR)" ]`. Never print an env file, `env`, `set`, a kubeconfig, or Secret data.
6. **Unknowns.** Use only the UNKNOWN lines in the skills: `UNKNOWN (<id>): <what>. Find out with: <command>`. Run the check or ask the user. For a fact that is not in the skills, say "not in the skills" and give a READ-ONLY check. Never make up an ID or a fact.
7. **Offline.** Use only these skills, the bundle, `--help`, and the cluster. Read versions from the cluster or from `nkp version`.
8. **Tags.** `[live 2.19.0]` live cluster · `[pdf p.N]` NKP 2.19 guide · `[portal]` Nutanix portal · `[field]` not confirmed. Trust them in this order.

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `MGMT_KUBECONFIG` `BUNDLE_DIR` `IMAGE_BUNDLES` `REGISTRY_URL` `REGISTRY_CA_FILE` `PC_ENDPOINT` `PC_CA_FILE` `PC_PROJECT` `PE_CLUSTER` `SUBNET` `STORAGE_CONTAINER` `VM_IMAGE` `SSH_PUBKEY_FILE` `NTP_SERVERS` `NKP_HTTP_PROXY` `NKP_HTTPS_PROXY` |
| `~/nkp-site.env` secrets | `NUTANIX_USER` `NUTANIX_PASSWORD` `REGISTRY_MIRROR_USERNAME` `REGISTRY_MIRROR_PASSWORD` `NUTANIX_REGISTRY_USERNAME` `NUTANIX_REGISTRY_TOKEN` |
| `~/nkp-<cluster>.env` | `CLUSTER_NAME` `CP_VIP` `LB_IP_RANGE` `WORKSPACE_NS` `CLUSTER_KUBECONFIG` `NO_PROXY_LIST` |
<!-- RULES:END -->

## The parts

All identity parts run on the management cluster. Users log in once and get access to all clusters. [pdf p.575]

| Part | What it does | Facts |
|---|---|---|
| Dex | OIDC broker. It sends the login to the external identity provider (IdP) and issues the ID token. | Image `mesosphere/dex:v2.42.0-d2iq.0`, ClusterApp `dex-2.14.5`, chart `dex@2.14.2`, namespace `kommander`. [live 2.19.0] The guide text "Dex 2.22.0" is old. |
| dex-controller | Reads the `Connector` objects (`connectors.dex.mesosphere.io`) and gives them to Dex. No Dex restart. | `mesosphere/dex-controller:v0.16.1`. A fresh install has no connector. [live 2.19.0] |
| Traefik Forward Auth (TFA) | Checks every UI request: Dex login, then Kubernetes RBAC on the URL path. | `traefik-forward-auth-mgmt` v3.3.1, `--enable-rbac`. [live 2.19.0] |
| kube-oidc-proxy | Gives the Dex identity to the Kubernetes API for `kubectl`. | Image `kube-oidc-proxy:1.0.9`. [live 2.19.0] |
| dex-k8s-authenticator | The `/token` page. It makes a kubeconfig with a Dex token. | [pdf p.249] |
| RBAC | Kubernetes RBAC plus Kommander objects (VirtualGroup, workspace and project roles) that KubeFed copies to the clusters. | [references/rbac.md](references/rbac.md) |
| Gatekeeper | Admission policy. NKP has its own constraints. | 3.23.0 in `kommander`. [live 2.19.0] [references/gatekeeper.md](references/gatekeeper.md) |
| External Secrets Operator (ESO) | Copies Secrets. NKP uses it for the registry credentials and certificates of the clusters. | v2.7.0, namespace `external-secrets`. [live 2.19.0] Section "External Secrets" |
| License | Object `licenses.kommander.mesosphere.io/nutanix-license` in `kommander`. | Section "License" |

Kubernetes, Kommander, and Dex keep no user database. The IdP holds the users. [pdf p.575]

## Job → section

| Job | Where |
|---|---|
| First login, static admin user, add LDAP or Active Directory, OIDC, SAML, GitHub; CA for the IdP; local test users; token lifetime | [references/identity.md](references/identity.md) |
| `kubectl` access for a user, the `/token` page, a login URL for one workspace (tenant) | [references/identity.md](references/identity.md), I6 |
| Dex or login fails, HTTP 500 after login | [references/identity.md](references/identity.md), I8 |
| Give a user or group access (UI or `kubectl`), `403 Forbidden` | [references/rbac.md](references/rbac.md) |
| Make or delete a workspace, make a project, project roles, role propagation | [references/rbac.md](references/rbac.md), R5 and R6 |
| `admission webhook "validation.gatekeeper.sh" denied`, own Gatekeeper policies (privileged pods, host paths) | [references/gatekeeper.md](references/gatekeeper.md) |
| Delete or label change denied by `validatingadmissionpolicy/nkp-deletion-protection` | [references/gatekeeper.md](references/gatekeeper.md), G5 |
| Pod Security Admission, encryption at rest, node OS users and SSH keys (`podSecurityAdmission`, `encryptionAtRest`, `users`), FIPS, CIS | [references/cluster-security.md](references/cluster-security.md) |
| Apply or change a license | section "License" |
| ESO status, ESO on a workload cluster | section "External Secrets" |
| Enable or configure a platform app (the AppDeployment way), project CD from Git | skill `nkp-platform-apps-gitops` |

## Step 1: Read the identity and security state

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='tier={.status.dkpLevel} valid={.status.valid} end={.status.endDate}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get appdeployments dex traefik-forward-auth-mgmt kube-oidc-proxy gatekeeper external-secrets
kubectl --kubeconfig "$MGMT_KUBECONFIG" get connectors.dex.mesosphere.io -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
kubectl --kubeconfig "$MGMT_KUBECONFIG" get projects.workspaces.kommander.mesosphere.io -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get virtualgroups
kubectl --kubeconfig "$MGMT_KUBECONFIG" get constraints
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get kommanderclusters -l kommander.d2iq.io/host=true -o jsonpath='ui=https://{.items[0].status.ingress.address}/dkp/kommander/dashboard{"\n"}'
```

- `ui=`: the UI address. Dex is at `/dex`, the token page at `/token`. [pdf p.247][live 2.19.0] The guide (p.580) says `/nkp/kommander/dashboard`. On 2.19.0 that path gives 404. [live 2.19.0]
- On a fresh install: tier `Starter` (AHV) or `Pro` (other infrastructure), no connector, no project, no VirtualGroup. [live 2.19.0][pdf p.28]

Done when: you have the tier, the connectors, and the UI address.

## License tiers for these features

| Feature | Tier [pdf p.27-28] |
|---|---|
| Single sign-on (Dex, IdPs), Kubernetes RBAC, admin role | Starter, Pro, Ultimate |
| NKP RBAC (Kommander roles in the UI), policy control with Gatekeeper, FIPS build | Pro, Ultimate |
| Workspace management, projects, multi-tenancy (IdP for each workspace) | Ultimate [pdf p.365] |

- On Starter, the UI offers only the roles `cluster-admin` and `view`. [pdf p.234]
- Gatekeeper runs on Starter too, for the NKP constraints. [live 2.19.0]

## License

Facts:
- You cannot go to a lower tier after you register a license. [pdf p.26] Say this in every plan.
- A Pro or Ultimate key is bound to the name of the management cluster. A key for another name gives `License key is not valid for this cluster`. [live 2.19.0] Before a create, skill `nkp-install` asks for the licensed name.
- A higher tier installs more platform apps. Make sure that the workers have free CPU and memory first. [pdf p.29] Pro and Ultimate apps fail on the Starter minimum of 2 workers (skill `nkp-install`). On 4 workers × 8 vCPU, Ultimate takes the CPU requests of the workers to 67–98 %: that is near the limit. [live 2.19.0]
- Only an NKP administrator can add a license. [pdf p.29] The key comes from the Nutanix Support Portal (the user gets it on a connected host). It is a secret.
- **The license webhook prints the full key when it rejects it** (`data.nutanix-license-key: Invalid value: "<key>"`). [live 2.19.0] The two `patch` blocks below send all their output through the `sed` mask. Never run them without the mask. Never put a raw webhook error in the chat or in a log.
- Two ways: the UI (the default), or `kubectl` when the UI gives an error. [pdf p.29, p.31]

**A. UI.** The user does this: Global workspace → Settings → Licensing. For a default license, select Activate License. For a Nutanix license (renewal, more cores), select Update License. Enter the key. [pdf p.29, p.32]

**B. kubectl.** The user puts the key in `~/nkp-site.env` with an editor (rule 5): `export NKP_LICENSE_KEY='<key>'`.

| File | Site variables |
|---|---|
| `~/nkp-site.env` secrets | `NKP_LICENSE_KEY` |

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
[ -n "$(printenv NKP_LICENSE_KEY)" ] && echo "set: NKP_LICENSE_KEY" || echo "MISSING: NKP_LICENSE_KEY"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='ref={.spec.nutanixLicenseRef.name}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes -l '!node-role.kubernetes.io/control-plane' -o custom-columns='NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory'
kubectl --kubeconfig "$MGMT_KUBECONFIG" describe nodes -l '!node-role.kubernetes.io/control-plane' | grep -E '^Name:|^  (cpu|memory) +[0-9]'
```

- `ref=` empty: the cluster has its default license. Continue. `ref=` has a name: the cluster has a license already (renewal, more cores). Do not replace that Secret: the License uses it. Use way A. If the UI gives an error: a kubectl renewal is not in the skills. UNKNOWN (P-56): the kubectl way to replace a key that the License already uses. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='{.spec}{"\n"}'`.
- The `cpu` lines show the requests (first %) of each worker. Requests above ~60 % before an Ultimate change: tell the user to add workers or bigger workers first (skill `nkp-cluster-lifecycle`).

The plan: the old tier, the new tier, "no way back to a lower tier", the cluster name (it must match the key), the worker list with the CPU requests. After "yes", make the Secret:

```bash
# CHANGES  (makes Secret kommander/nutanix-license-secret with the license key)
source ~/nkp-site.env 2>/dev/null
: "${NKP_LICENSE_KEY:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander create secret generic nutanix-license-secret --from-file=nutanix-license-key=<(printf %s "$(printenv NKP_LICENSE_KEY)") --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f - -o name
```

Check the License change with a server dry run. The webhook checks the key and the cluster name here. It rejects a Secret name that does not exist ("referenced secret ... could not be retrieved"). [live 2.19.0]

```bash
# READ-ONLY  (server dry run: changes nothing; the sed mask hides the key in a webhook error)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch licenses.kommander.mesosphere.io nutanix-license --type merge -p '{"spec":{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}}' --dry-run=server -o jsonpath='{.spec}{"\n"}' 2>&1 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'
```

It passes when it prints `{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}` [live 2.19.0]: run the patch. It prints `denied the request`: do not run the patch. Show the masked error. `License key is not valid for this cluster` = the key is for another cluster name. Plan the Secret delete below, then ask the user for a key for this cluster name.

```bash
# CHANGES  (points the license to the new key; NKP changes the tier and installs the apps of that tier)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch licenses.kommander.mesosphere.io nutanix-license --type merge -p '{"spec":{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}}' 2>&1 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'
```

After a denial the Secret stays and holds the bad key. [live 2.19.0] Delete it after "yes" (only when `ref=` was empty):

```bash
# CHANGES  (deletes Secret kommander/nutanix-license-secret that holds a rejected key)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander delete secret nutanix-license-secret
```

After the patch, run step 1. The tier changes in about 15 s. [live 2.19.0] With a trial key the status gets `dkpLevel` and `endDate`. `licenseId`, `customerId`, `productSKU`, `version` stay empty, `coreCapacity` and `clusterCapacity` stay `0`. [live 2.19.0] UNKNOWN (P-40): which status fields a paid Pro or Ultimate key fills. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='{.status}{"\n"}'`.

The apps of the new tier take about 11 min. Some HelmReleases come late. [live 2.19.0] Run this block now, and again 15 min later:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmreleases -A | awk 'NR==1 || $4!="True"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmreleases --no-headers | wc -l
```

Done when: `valid=true` and the new tier, and two runs at least 15 min apart show only the header line. The count in `kommander` on AHV: Starter 24, Ultimate 48. [live 2.19.0] Then the user sees `Valid` in the UI on the Licensing page. [pdf p.31]

Ultimate adds these 24 HelmReleases on an AHV management cluster [live 2.19.0]:

| Group | HelmReleases |
|---|---|
| Observability, logging (13) | `kube-prometheus-stack` `prometheus-adapter` `thanos` `centralized-grafana` `centralized-opencost` `opencost` `karma` `karma-traefik` `prometheus-thanos-traefik` `grafana-logging` `grafana-loki-v3` `logging-operator` `logging-operator-logging` |
| Object storage (4) | `rook-ceph` `rook-ceph-cluster` `cosi-driver-ceph-dkp-object-store` `object-bucket-claims` |
| Data, backup (3) | `cloudnative-pg` `cloudnative-pg-plugin-barman-cloud` `velero` |
| Other (4) | `headlamp` nkp-insights-management `kubetunnel` `cilium-hubble-relay-traefik` |

Rook Ceph runs on AHV too (on `nutanix-volume` PVCs). Loki and Velero use it. Do not delete it (skill `nkp-storage-backup`).

If `valid` is not `true`, read the licensing log. Then ask the user for a new key from the portal.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs deploy/kommander-licensing-cm --tail=50
```

**NKP Full Stack license** (Prism Central with CAPX or CAPV). It needs the Secret `prism-central-metadata` in the namespace of the management CAPI cluster (`kommander` on AHV). [pdf p.32-33][live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get secret prism-central-metadata
```

If it is not there, make it after "yes". Then apply the key with A or B.

```bash
# CHANGES  (makes the Secret prism-central-metadata from Prism Central)
source ~/nkp-site.env 2>/dev/null
: "${NUTANIX_USER:?}" "${NUTANIX_PASSWORD:?}"
nkp create metadata nutanix --endpoint "$PC_ENDPOINT" --kubeconfig "$MGMT_KUBECONFIG"
```

- AWS Marketplace licenses use `spec.externalLicenseRef.awsLicense.licenseArn` [live 2.19.0] and an IAM policy [pdf p.29]. Not in the skills.

## External Secrets

- On the management cluster ESO is always on. You cannot disable it. Do not set `createPushSecrets` or `processPushSecrets` to `false`. [pdf p.311]
- NKP uses it: PushSecrets `<cluster>-oci-creds`, `<cluster>-oci-cert`, `<cluster>-nkp-oci-proxy-ca` in the workspace namespace copy the registry credentials and certificates to the clusters. [live 2.19.0][pdf p.311] When they are not `Synced`, a cluster can lose its registry access.
- On a workload cluster ESO is optional, in namespace `external-secrets`. The user enables it in the UI (management cluster workspace → Applications → External Secrets Operator → Enable → the cluster). [pdf p.311-312] For the AppDeployment way, use skill `nkp-platform-apps-gitops`.
- A Helm-installed ESO on a workload cluster: back up the ESO objects, uninstall it, then enable the platform app and apply the backup again. Else the CRDs conflict. [pdf p.312] The backup is a CHANGES step (it writes files that hold Secret references).
- Air-gapped site: the secret store (Vault, a Kubernetes cluster) must be inside the air gap. Cloud vaults do not work.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get pushsecrets,externalsecrets,secretstores
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get externalsecrets,secretstores,clustersecretstores -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n external-secrets get pods
```

Done when: every ExternalSecret has STATUS `SecretSynced` and READY `True`, and every PushSecret `Synced`. [pdf p.313][live 2.19.0] If not, run `kubectl describe` on the object and read the events. The store name and the error text show the cause.

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `admission webhook "validation.gatekeeper.sh" denied`, `[helmrelease-must-have-sa]` or `[kustomization-must-have-sa]`, "must have a serviceAccountName set" | A Flux HelmRelease or Kustomization in a project namespace has no `spec.serviceAccountName`. [live 2.19.0] | [references/gatekeeper.md](references/gatekeeper.md), G2 |
| `validation.gatekeeper.sh denied` with another constraint name | Your own constraint | [references/gatekeeper.md](references/gatekeeper.md), G4 |
| `Deletion denied: resource is protected by nkp.nutanix.com/deletion-protection=...` | The object has the NKP deletion-protection label. [live 2.19.0] | [references/gatekeeper.md](references/gatekeeper.md), G5 |
| Login button missing, "Internal Server Error", "Login error", `/token` gives 5xx | Connector or Dex config | [references/identity.md](references/identity.md), I8 |
| Login works, then `403 Forbidden` (UI or `kubectl`) | No binding, or the wrong subject name (`oidc:` prefix) | [references/rbac.md](references/rbac.md), R7 |
| HTTP 500 after login, the user has many groups | TFA cookie is larger than 4 KB | [references/identity.md](references/identity.md), I8 |
| `License key is not valid for this cluster` (webhook denial; the raw error holds the key) | The key is for another management cluster name. [live 2.19.0] | section "License": mask the output, delete the Secret, get a key for this name |
| License not valid, apps of the tier missing | Wrong key or not enough worker resources | section "License" |
| Pods rejected with `violates PodSecurity` | Pod Security Admission level | [references/cluster-security.md](references/cluster-security.md), C1 |

For other failures, use skill `nkp-troubleshooting`.

## Related skills

Architecture and tier list: skill `nkp`. The admin password rotate block: skill `nkp-install`. NKPCluster patch method: skill `nkp-cluster-lifecycle`, step 3. FIPS and custom OS images, the Gatekeeper library files: skill `nkp-airgap`. Ingress certificate and custom domain of the UI, Gatekeeper proxy mutation: skill `nkp-networking`. Platform apps and project CD: skill `nkp-platform-apps-gitops`.
