# Batch 3 eval — answers (part 2)

Operator host: air-gapped site. Login shell: zsh. No live cluster connected now.
Every command block below is bash. Marks: `# READ-ONLY`, `# CHANGES`, `# USER-TERMINAL`.
No CHANGES block runs before the user types "yes" to its plan.

---

## nkp-identity-security S1

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-identity-security/SKILL.md`, `skills/nkp-identity-security/references/gatekeeper.md` (G1, G2, G4).

### Reply

**No. Do not delete that constraint.**

Facts:

- `helmrelease-must-have-sa` is one of NKP's own constraints (ConstraintTemplate `requiredserviceaccountname`, from the Flux Kustomization `kommander/gatekeeper-constraint-templates`). It is a `deny` constraint on Flux `HelmRelease` objects in every namespace with the label `kommander.d2iq.io/managed-by-kind=Project`. [live 2.19.0]
- Gatekeeper is on by default and NKP ships these constraints to keep projects apart. Do not disable it and do not weaken the constraint. [pdf p.581]
- What the constraint protects: project Flux objects must run as the project service account (`spec.serviceAccountName`), not as the Flux controller account, which is `cluster-admin`. [live 2.19.0][pdf p.388] If you delete the constraint, every tenant that can write a HelmRelease in a project namespace gets cluster-admin through Flux. That is the hole the constraint closes.
- Same constraint, same fix, for `[kustomization-must-have-sa]`.

The fix is one line in the source (Git), not a change to Gatekeeper:

```yaml
spec:
  serviceAccountName: <project-service-account>
```

The service account already exists: project CD makes one with the name of the project. [pdf p.388]

### Questions I ask you now (one `ask_user_question` round)

1. Which cluster runs this project namespace? (I need the name for `~/nkp-<cluster>.env`.)
2. Which project namespace does Flux fail in? (I need the name for `ns` below.)

### Step 1 — read the state (READ-ONLY, I run it)

`<cluster>` below becomes the name you give me.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}" "${CLUSTER_KUBECONFIG:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get requiredserviceaccountname -o custom-columns='NAME:.metadata.name,ACTION:.spec.enforcementAction,KINDS:.spec.match.kinds[*].kinds,NSLABEL:.spec.match.namespaceSelector.matchLabels'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns -l kommander.d2iq.io/managed-by-kind=Project
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get serviceaccounts
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get rolebindings -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get helmreleases,kustomizations -o custom-columns='KIND:.kind,NAME:.metadata.name,SA:.spec.serviceAccountName'
```

What each line tells us:

- Line 1: that the constraint is `deny`, on `HelmRelease` (and `Kustomization`), and which namespaces it matches. This is NKP's own policy, so there is no policy owner to ask.
- Line 3: the service account names in the namespace. Use the one with the project name.
- Line 5: the Flux objects whose SA column is empty. Those are the ones that get denied.

### Step 2 — fix in Git

Add `spec.serviceAccountName: <that project service account>` to every object with an empty SA column, in the Git repository or the file that Flux reads. That service account must have rights for every object the release makes, **in that namespace only**. If the chart makes cluster-scoped objects (CRDs, ClusterRoles), it cannot run from a project namespace at all: deploy it as a workspace app instead (skill `nkp-platform-apps-gitops`). [pdf p.388]

No cluster access is needed for this step, so it is not a block I run. If you want me to write the patched YAML for review, give me the file or the chart values and I will show the diff before anything is committed.

### Step 3 — done check (READ-ONLY, I run it after the Flux reconcile)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,SA:.spec.serviceAccountName'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get requiredserviceaccountname helmrelease-must-have-sa -o jsonpath='action={.spec.enforcementAction} violations={.status.totalViolations}{"\n"}'
```

Done when: the HelmRelease is `Ready=True` and `violations=0`. A stuck HelmRelease after this: skill `nkp-troubleshooting`.

If you still believe the constraint is wrong for your case, that is a policy change, not a delete: `enforcementAction: warn` on that constraint, with a plan, your security owner's agreement, and a "yes". I will not delete a constraint on a bare request.

---

## nkp-identity-security S2

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-identity-security/SKILL.md` (I2, I3, I5), `skills/nkp-identity-security/references/identity.md` (I1–I5, table of site variables), `skills/nkp-identity-security/references/rbac.md` (R1, R2, R3).

### Reply

Facts first:

- All workspaces (global) means one `Connector` object in namespace `kommander`. That is available on every tier. A connector for one workspace only needs Ultimate. [pdf p.365]
- Type is `ldap`; Active Directory uses the same type. Port 636 is LDAPS, so we do **not** use `insecureNoSSL` or `insecureSkipVerify`. [pdf p.245]
- Three objects: the bind-password Secret (key `password`), the CA Secret (key `tls.crt`), and the `Connector` (`dex.mesosphere.io/v1alpha1`). Dex reads the password from the key `password` and the CA from the key `tls.crt`. [live 2.19.0]
- New connector → the dex-controller gives it to Dex. **Dex does not restart.** [live 2.19.0]
- Users get no access until you bind them. RBAC is additive; a fresh IdP user sees an empty UI. [pdf p.231-232]

**One security item before we start:** the bind password is now in this chat. I will not repeat it and I will not copy it out of the chat. You type it into `~/nkp-site.env` with an editor yourself, and you rotate the `svc-nkp` password in AD after we finish.

### Questions I ask you now (one `ask_user_question` round)

1. Connector name (`a-z`, `0-9`, `-`) and the button text (`spec.displayName`)? e.g. name `corp-ad`, button `Corp AD`.
2. Confirm the AD attribute mapping. I propose the standard AD set and need your yes on each value: `user_filter=(objectClass=person)`, `user_attr=sAMAccountName`, `id_attr=DN`, `email_attr=userPrincipalName`, `name_attr=cn`, `group_filter=(objectClass=group)`, `member_user_attr=DN`, `member_group_attr=member`, `group_name_attr=cn`. [pdf p.239, p.246][field]
3. Is `/home/ops/corp-ca.pem` on this operator host (the machine I run on), and does it hold the full chain that signs the LDAPS certificate of `dc01.corp.example.com`?
4. Do `OU=Staff` and `OU=Groups` hold the users and groups directly? If the groups are nested, say so — a nested group search is not in the skills, and I will tell you what we can and cannot do.

### Step 1 — values (CHANGES, plan; I run it after you type "yes")

Command: 5 appended lines. Target: `~/nkp-site.env` on the operator host. Result: the site variables exist for the blocks below; nothing on any cluster changes.

I write these now because you gave me the values. `~/nkp-site.env` must exist first (`touch ~/nkp-site.env && chmod 600 ~/nkp-site.env`, CHANGES, only if it is missing).

```bash
# CHANGES  (appends 5 site values to ~/nkp-site.env on the operator host)
source ~/nkp-site.env 2>/dev/null
echo "export IDP_LDAP_HOST='dc01.corp.example.com:636'" >> ~/nkp-site.env
echo "export IDP_LDAP_BIND_DN='CN=svc-nkp,OU=Service,DC=corp,DC=example,DC=com'" >> ~/nkp-site.env
echo "export IDP_LDAP_USER_BASE_DN='OU=Staff,DC=corp,DC=example,DC=com'" >> ~/nkp-site.env
echo "export IDP_LDAP_GROUP_BASE_DN='OU=Groups,DC=corp,DC=example,DC=com'" >> ~/nkp-site.env
echo "export IDP_CA_FILE='/home/ops/corp-ca.pem'" >> ~/nkp-site.env
```

**You** add the secret line, with an editor, not on the command line (no shell history, no screen):

- open `~/nkp-site.env`
- add a line that sets `IDP_LDAP_BIND_PASSWORD`, in single quotes
- save; then rotate the AD password afterwards, because it was posted in chat

I check it only as present or missing (never printed).

### Step 2 — check (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
for v in IDP_LDAP_HOST IDP_LDAP_BIND_DN IDP_LDAP_USER_BASE_DN IDP_LDAP_GROUP_BASE_DN IDP_CA_FILE IDP_LDAP_BIND_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
openssl x509 -in "$IDP_CA_FILE" -noout -subject -enddate
```

Done when: six `set:` lines, and the certificate is the CA you expect, not expired. A `MISSING:` line stops us there.

### Step 3 — the two Secrets (CHANGES, plan; after "yes")

Command: two `create secret`. Target: namespace `kommander` on the management cluster. Result: `corp-ad-bind` (key `password`) and `corp-ad-ca` (key `tls.crt`), which Dex reads. The password never goes on screen or into shell history.

`name` is the connector name from your answer ("corp-ad" in this example).

```bash
# CHANGES  (makes the bind password Secret and the CA Secret in namespace kommander)
source ~/nkp-site.env 2>/dev/null
ns='kommander'; name='corp-ad'
: "${ns:?}" "${name:?}" "${IDP_LDAP_BIND_PASSWORD:?}" "${IDP_CA_FILE:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" create secret generic "$name-bind" --from-literal=password="$IDP_LDAP_BIND_PASSWORD" -o name
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" create secret generic "$name-ca" --from-file=tls.crt="$IDP_CA_FILE" -o name
```

### Step 4 — the connector file (CHANGES on the operator host only, plan; after "yes")

Command: writes `~/nkp-idp-corp-ad.yaml`. Target: this host's home directory. Result: one file for review; no cluster object yet.

```bash
# CHANGES  (writes the connector file on the operator host; changes no cluster)
source ~/nkp-site.env 2>/dev/null
ns='kommander'; name='corp-ad'; display=''; user_filter='(objectClass=person)'; user_attr='sAMAccountName'; id_attr='DN'; email_attr='userPrincipalName'; name_attr='cn'; group_filter='(objectClass=group)'; member_user_attr='DN'; member_group_attr='member'; group_name_attr='cn'
: "${ns:?}" "${name:?}" "${display:?}" "${user_filter:?}" "${user_attr:?}" "${id_attr:?}" "${email_attr:?}" "${name_attr:?}" "${group_filter:?}" "${member_user_attr:?}" "${member_group_attr:?}" "${group_name_attr:?}"
(umask 077 && cat > "$HOME/nkp-idp-$name.yaml" <<EOF
apiVersion: dex.mesosphere.io/v1alpha1
kind: Connector
metadata:
  name: $name
  namespace: $ns
spec:
  enabled: true
  type: ldap
  displayName: "$display"
  ldap:
    host: "$IDP_LDAP_HOST"
    rootCASecretRef:
      name: $name-ca
    bindDN: "$IDP_LDAP_BIND_DN"
    bindSecretRef:
      name: $name-bind
    userSearch:
      baseDN: "$IDP_LDAP_USER_BASE_DN"
      filter: "$user_filter"
      username: $user_attr
      idAttr: $id_attr
      emailAttr: $email_attr
      nameAttr: $name_attr
    groupSearch:
      baseDN: "$IDP_LDAP_GROUP_BASE_DN"
      filter: "$group_filter"
      userMatchers:
      - userAttr: $member_user_attr
        groupAttr: $member_group_attr
      nameAttr: $group_name_attr
EOF
)
```

`display` and the attribute values stay empty until you answer question 1 and 2. The `:?` guards stop the block before it writes a file with an empty value.

### Step 5 — dry run (READ-ONLY, I run it; I show you the file)

```bash
# READ-ONLY  (server dry run: the webhooks check the connector and change nothing)
source ~/nkp-site.env 2>/dev/null
name='corp-ad'
: "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f "$HOME/nkp-idp-$name.yaml"
```

`created (server dry run)` = the object passes the schema and the webhooks. The dry run does not check that the Secrets exist. [live 2.19.0] So I also check them:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ns='kommander'
: "${ns:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" get secret corp-ad-bind corp-ad-ca
```

### Step 6 — apply (CHANGES, plan; after "yes")

Command: `apply -f ~/nkp-idp-corp-ad.yaml`. Target: the `Connector` in namespace `kommander` on the management cluster. Result: a new login button "Corp AD" on the NKP login page (`https://<ui>/dex`), for every workspace.

```bash
# CHANGES  (adds the connector; the login page gets a new button)
source ~/nkp-site.env 2>/dev/null
name='corp-ad'
: "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f "$HOME/nkp-idp-$name.yaml"
```

### Step 7 — test (READ-ONLY, I run it while you log in)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get connectors.dex.mesosphere.io -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs deploy/dex-dex-controller -c manager --tail=20
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get kommanderclusters -l kommander.d2iq.io/host=true -o jsonpath='ui=https://{.items[0].status.ingress.address}/{"\n"}'
```

You open the UI address, press "Corp AD", and log in with your AD account (`sAMAccountName` + AD password). I read the Dex log at that moment:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs deploy/dex --tail=100 | grep -F 'login successful'
```

Done when the log shows `login successful: connector "corp-ad"` with your email **and your groups**. Write down the exact group strings: Kubernetes sees them as `oidc:<group>`. [pdf p.229, p.249]

Login errors and their causes (all in `identity.md`, I8): `LDAP Result Code 200 "Network Error"` → `IDP_LDAP_HOST` or DNS; `x509: certificate signed by unknown authority` → wrong or missing CA (replace the `corp-ad-ca` Secret); `filter returned multiple (2) results` → narrow `user_filter` or the base DN; UI "Internal Server Error" → read the Dex log at login time.

### Step 8 — next, access

Your users can log in and see nothing yet. That is correct. The next step is RBAC for the AD groups (file `rbac.md`, R3), with the subject names `oidc:<group>` taken from the Dex log line above. Tell me the group and the level (`view`, `edit`, `admin`) and I write that plan.

---

## nkp-identity-security S3

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-identity-security/SKILL.md` (Common failures, tiers), `skills/nkp-identity-security/references/rbac.md` (R1, R2, R3, R7), `skills/nkp-identity-security/references/identity.md` (I5, I8).

### Reply

Login works, so the identity part is done. `403 Forbidden` is RBAC. With a ClusterRoleBinding to `cluster-admin` on group `nkp-admins`, there are two likely causes, and I expect both:

1. **The subject name is wrong.** Kubernetes never sees a group called `nkp-admins`. After a global Dex login it sees `oidc:nkp-admins`. [pdf p.229, p.233] A binding whose subject is the bare name `nkp-admins` matches no authenticated group, so it grants nothing → 403.
2. **`cluster-admin` does not open the NKP UI.** The UI paths (`/dkp/*`, `/dp/...`) are checked by Traefik Forward Auth against the Kommander ClusterRoles. UI access needs **both** `dkp-kommander-<level>` (the dashboard) and `dkp-<level>` (all `/dkp/*` paths). [pdf p.228-229, p.236] `cluster-admin` is plain Kubernetes RBAC and does not give the Kommander role names.

Keep `cluster-admin` for `kubectl`; add the two `dkp-*` bindings for the UI.

### Step 1 — read the state (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
user=''; group='oidc:nkp-admins'
: "${user:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" auth can-i get /dkp/kommander/dashboard --as "$user" ${group:+--as-group "$group"}
kubectl --kubeconfig "$MGMT_KUBECONFIG" auth can-i list pods -A --as "$user" ${group:+--as-group "$group"}
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterrolebindings,rolebindings -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name' | grep -F -e "$user" -e "$group"
kubectl --kubeconfig "$MGMT_KUBECONFIG" get virtualgroups -o custom-columns='NAME:.metadata.name,SUBJECTS:.spec.subjects[*].name'
```

`user` is the AD login exactly as the Dex token shows it (for LDAP, the `sAMAccountName` value of `email_attr`); give it to me and I fill the variable. `auth can-i --as` asks the API server and changes nothing. Two `no` answers with the corrected group name confirm cause 1 and 2.

### Step 2 — confirm the group string (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs deploy/dex --tail=200 | grep -F 'login successful'
```

I need the group exactly as the Dex token shows it (`groups=[...]`). AD often sends the display name, not `nkp-admins`. If the log has no groups for your user, the connector is not sending groups at all (LDAP `groupSearch`), and RBAC on a group cannot work until that is fixed (file `identity.md`). That would be the real cause, not the binding.

### Questions I ask you now (one `ask_user_question` round)

1. Which level do you want for these admins: `admin`, `edit`, or `view`? (`admin` for a team that manages the platform.)
2. Is the exact group value in the Dex log `nkp-admins`, or something else?

### Step 3 — the bindings (CHANGES, plan; I run it after "yes")

I write this file with `subject='oidc:nkp-admins'`, `level='admin'`, `k8srole='cluster-admin'` once you confirm question 1 and 2.

Command: writes `~/nkp-rbac-nkpadmins.yaml`. Target: this host (step 3a) and then the management cluster (step 3c). Result: group `oidc:nkp-admins` gets the NKP UI dashboard and `/dkp/*` rights on the management cluster, and `cluster-admin` on all clusters through the VirtualGroup.

```bash
# CHANGES  (writes the binding file on the operator host; changes no cluster)
name='nkpadmins'; kind='Group'; subject=''; level=''; k8srole=''
: "${name:?}" "${kind:?}" "${subject:?}" "${level:?}" "${k8srole:?}"
(umask 077 && cat > "$HOME/nkp-rbac-$name.yaml" <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $name-dkp-kommander
  labels:
    workspaces.kommander.mesosphere.io/rbac: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dkp-kommander-$level
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: $kind
  name: "$subject"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $name-dkp
  labels:
    workspaces.kommander.mesosphere.io/rbac: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dkp-$level
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: $kind
  name: "$subject"
---
apiVersion: kommander.mesosphere.io/v1beta1
kind: VirtualGroup
metadata:
  name: $name
spec:
  subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: $kind
    name: "$subject"
---
apiVersion: kommander.mesosphere.io/v1beta1
kind: VirtualGroupClusterRoleBinding
metadata:
  name: $name-$k8srole
spec:
  clusterRoleRef:
    name: $k8srole
  virtualGroupRef:
    name: $name
EOF
)
```

`subject` is filled with `oidc:nkp-admins` — with the prefix. That prefix is the whole point of this change.

The UI way, if you prefer it: Administration → Identity Providers → Groups tab, then Access Control → Cluster Role Bindings. [pdf p.243-244]

### Step 4 — dry run (READ-ONLY, I run it)

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-site.env 2>/dev/null
name='nkpadmins'
: "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f "$HOME/nkp-rbac-$name.yaml"
```

### Step 5 — apply (CHANGES, plan; after "yes")

Command: `apply -f ~/nkp-rbac-nkpadmins.yaml`. Target: the management cluster (4 objects; KubeFed copies the VirtualGroup binding to the clusters). Result: the group gets UI and Kubernetes access.

```bash
# CHANGES  (adds the bindings and the VirtualGroup; the group gets access)
source ~/nkp-site.env 2>/dev/null
name='nkpadmins'
: "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f "$HOME/nkp-rbac-$name.yaml"
```

### Step 6 — check (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
user=''; group='oidc:nkp-admins'
: "${user:?}" "${group:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" auth can-i get /dkp/kommander/dashboard --as "$user" --as-group "$group"
kubectl --kubeconfig "$MGMT_KUBECONFIG" auth can-i list pods -A --as "$user" --as-group "$group"
```

`user` is the same AD login as in step 1. Done when both print `yes`.

**Then log out and log in again in the UI.** The Traefik Forward Auth cookie holds the old group list. [pdf p.584] Without the new login, the 403 stays and people think the fix failed.

Last item: your old ClusterRoleBinding on the bare name `nkp-admins` now does nothing. Delete it **after** the new bindings work, with its own plan and a "yes" — not in the same step.

---

## nkp-identity-security S4

**Skill files read:** `skills/nkp/SKILL.md` (license tiers), `skills/_shared/RULES.md`, `skills/nkp-identity-security/SKILL.md` (License, Step 1), `skills/nkp-identity-security/references/identity.md` (I8, for the log path).

### Reply

I will do it with `kubectl`, because the UI gave an error. But I do not run a licence change on "just apply it": a licence change installs a new set of platform apps and it is one-way. Two facts you must have before I touch it:

1. **There is no way back to a lower tier after you register a licence.** [pdf p.26]
2. **Ultimate installs more apps than Pro.** If the workers have no free CPU and memory, the new apps stay Pending. [pdf p.29] Pro and Ultimate apps fail on the Starter minimum of 2 workers.

Also: only an NKP administrator can add a licence. [pdf p.29] The key is a secret; it stays in `~/nkp-site.env` and I never print it.

### Step 1 — read the state (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
[ -n "$(printenv NKP_LICENSE_KEY)" ] && echo "set: NKP_LICENSE_KEY" || echo "MISSING: NKP_LICENSE_KEY"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='tier={.status.dkpLevel} valid={.status.valid}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes -l '!node-role.kubernetes.io/control-plane' -o custom-columns='NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory'
```

Line 1 is the only check I make on the secret: present or missing. If it says `MISSING:`, the key is in another file or not exported, and I stop and ask you — I will not write a key.

### Step 2 — why the UI failed (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs deploy/kommander-licensing-cm --tail=50
```

Read this before the change. If it names a bad key, the `kubectl` way fails the same way and we need a new key from the portal. If it names a missing Secret, the fix is below.

One conditional: if your key is a **Full Stack** licence (Prism Central with CAPX or CAPV), it needs the Secret `prism-central-metadata` in the management namespace, else the licence stays invalid. [pdf p.32-33] I check it with `kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get secret prism-central-metadata` (READ-ONLY) and tell you before step 3.

### Step 3 — the plan (I stop here for "yes")

| Item | Value |
|---|---|
| Target | Secret `kommander/nutanix-license-secret` on the management cluster |
| Command | `create secret --dry-run=client ... \| apply -f -` then one `patch` of `licenses.kommander.mesosphere.io/nutanix-license` |
| Current tier | from step 1 (Pro or Starter) |
| New tier | Ultimate |
| Result | NKP registers the key, changes the tier, and installs the Ultimate platform apps on the clusters |
| Not reversible | no lower tier after registration [pdf p.26] |
| Risk | the workers must have free CPU and memory (step 1, line 3) |

### Step 3a — make the Secret (CHANGES; runs only after you type "yes")

```bash
# CHANGES  (makes or replaces Secret kommander/nutanix-license-secret with the license key)
source ~/nkp-site.env 2>/dev/null
: "${NKP_LICENSE_KEY:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander create secret generic nutanix-license-secret --from-literal=nutanix-license-key="$NKP_LICENSE_KEY" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f - -o name
```

### Step 3b — check the licence change (READ-ONLY, I run it)

A server dry run changes nothing. The licence webhook rejects a Secret name that does not exist ("referenced secret ... could not be retrieved"). [live 2.19.0] So this proves step 3a worked.

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch licenses.kommander.mesosphere.io nutanix-license --type merge -p '{"spec":{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}}' --dry-run=server -o jsonpath='{.spec}{"\n"}'
```

### Step 3c — point the licence at the key (CHANGES; second "yes")

Command: `patch licenses.kommander.mesosphere.io nutanix-license`. Target: management cluster, namespace `kommander`. Result: NKP changes the tier to Ultimate and installs the Ultimate apps on the workers.

```bash
# CHANGES  (points the license to the new key; NKP changes the tier and installs the apps of that tier)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch licenses.kommander.mesosphere.io nutanix-license --type merge -p '{"spec":{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}}'
```

### Step 4 — verify (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='tier={.status.dkpLevel} valid={.status.valid}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pods -A | grep -vE 'Running|Completed' | head -30
```

Done when: `valid=true` and `tier=Ultimate`, and no app pod is Pending. The Licensing page in the UI then shows `Valid`. [pdf p.31]

If `valid` is not `true`, I read `kommander-licensing-cm` again (step 2) and ask you for a new key from the portal. Which status fields a Pro or Ultimate key fills is UNKNOWN (P-40) in the lab — we read them from your cluster, we do not guess.

---

## nkp-identity-security S5

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-identity-security/SKILL.md` (Job → section, Common failures), `skills/nkp-identity-security/references/cluster-security.md` (C1, read block), `skills/nkp-cluster-lifecycle/SKILL.md` (step 1, step 2, step 3), `skills/nkp-cluster-lifecycle/references/variables.md` (pointer only).

### Reply

Pushback first, because it changes the plan: **`enforce: restricted` as the cluster default is not safe on NKP.**

Facts [live 2.19.0]:

- `podSecurityAdmission` has `enforce`, `audit`, `warn` (default `privileged`) and `exemptions.namespaces` (default `["kube-system"]`). The API accepts only `privileged`, `baseline`, `restricted` — the schema does not validate the word, so a typo is accepted and does nothing useful.
- NKP labels `kommander`, `metallb-system`, `node-feature-discovery`, `ntnx-system` with `pod-security.kubernetes.io/enforce=privileged`, so those keep working. `kube-system` is exempt by default.
- A `restricted` label on any other namespace produces Pod Security warnings in **11 NKP namespaces** on 2.19.0: the CAPI providers, `caren-system`, `kommander-flux`, `git-operator-system`, `kube-federation-system`, `container-object-storage-system`, and the workspace namespaces. Their pods would be rejected under `enforce=restricted`, and you would break fleet management on dev-01, not just workloads.
- `enforce: baseline` is safe for those namespaces.

So the recommended shape is: cluster default `enforce=baseline` with `warn=restricted` and `audit=restricted` (every workload gets restricted warnings and audit records), plus an `enforce=restricted` **label on the namespaces that hold your workloads** on dev-01. Labels are plain Kubernetes, take effect at once, and replace no node.

If the security team insists on a cluster-wide `enforce=restricted`, it is possible, but only with an `exemptions.namespaces` list built from the test in step 3 — and the change replaces control-plane nodes. I will show that as plan B, and I want your acceptance in writing for the exemption list.

### Questions I ask you now (one `ask_user_question` round)

1. Does the security team accept plan A (default `baseline` + `restricted` labels on the workload namespaces of dev-01), or do they demand a cluster-wide `restricted`?
2. Which namespaces on dev-01 hold the workloads that must be restricted? (For plan A I need the list; for plan B they are the opposite list.)

### Step 1 — select the cluster (READ-ONLY, I run it)

`dev-01` is a workload cluster, so its NKPCluster is in a workspace namespace, not in `kommander`.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CAPI:.status.capiClusterRef.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

From the `dev-01` row I take `NAMESPACE` (its workspace namespace) and `NAME`. Then I append both values to the cluster env file (rule 4, CHANGES, one line each: `CLUSTER_NAME='dev-01'` and the `WORKSPACE_NS` value from that row), after you confirm the row is the cluster you mean.

If `CLASS` is empty for that row, the cluster has no ClusterClass and this skill has no steps for it: I stop and tell you.

Then:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-dev-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when the block prints four `set:` lines. `CLUSTER_KUBECONFIG` comes from skill `nkp-install`, step "Set the kubeconfig variables".

### Step 2 — read the current value (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o json | jq -c '.spec.capiCluster.topology | {version, vars: [.variables[] | select(.name=="clusterConfig") | .value | {encryptionAtRest, podSecurityAdmission}]}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o go-template='{{range $i, $v := .spec.capiCluster.topology.variables}}variable {{$i}}: {{$v.name}}{{"\n"}}{{end}}'
```

Line 1: is Pod Security set today? Line 2: the index of `clusterConfig` (`v`) for the patch in step 4. I need that index; I do not guess it.

### Step 3 — test the level on the namespaces (READ-ONLY, I run it)

A server dry run of a namespace label shows the pods that the level would reject, and changes nothing.

```bash
# READ-ONLY  (server dry runs of a namespace label: change nothing)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-dev-01.env 2>/dev/null
level='baseline'
: "${level:?}"
for ns in $(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns -o json | jq -r '.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | .metadata.name'); do [ "$ns" = kube-system ] && continue; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" label --dry-run=server --overwrite ns "$ns" pod-security.kubernetes.io/enforce="$level" 2>&1 | grep -i '^warning' | sed "s|^|$ns: |"; done
```

- No output at `level='baseline'`: the planned default is safe on dev-01. This is the test that matters.
- Run the same block once more with `level='restricted'` if you want the evidence for the security team. Each line it prints is a namespace that needs a `privileged` label or an exemption under a `restricted` default. No line output does **not** prove anything for plan A, because `warn=restricted` does not reject pods.

### Step 4 — plan A (recommended)

**Plan A, part 1.** Command: one JSON patch of the NKPCluster `dev-01`. Target: the `clusterConfig` variable of the topology on the management cluster. Result: the API server admission configuration changes to `enforce=baseline`, `warn=restricted`, `audit=restricted`; every workload gets restricted warnings and audit entries. Effect: the control-plane nodes are replaced, one by one. Whether workers are replaced too is UNKNOWN (P-44); I check the machines 10 minutes after the change.

I write the patch file first (CHANGES on this host only):

```bash
# CHANGES  (writes the patch file on the operator host; changes no cluster)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-dev-01.env 2>/dev/null
v=''; field='podSecurityAdmission'; value='{"enforce":"baseline","warn":"restricted","audit":"restricted"}'
: "${v:?}" "${field:?}" "${value:?}"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-patch.json" <<EOF
[{"op":"test","path":"/spec/capiCluster/topology/variables/$v/name","value":"clusterConfig"},
 {"op":"add","path":"/spec/capiCluster/topology/variables/$v/value/$field","value":$value}]
EOF
)
```

`v` is the index from step 2, line 2. The `test` op stops the patch if that index is not `clusterConfig`.

Then the dry run (READ-ONLY). I show you the diff as the plan:

```bash
# READ-ONLY  (server dry run: the API server checks the patch and changes nothing)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-dev-01.env 2>/dev/null
new=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type json --patch-file "$HOME/nkp-$CLUSTER_NAME-patch.json" --dry-run=server -o yaml) && diff <(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o yaml) - <<< "$new"
```

Then, after you type "yes":

```bash
# CHANGES  (applies the patch file to the NKPCluster; NKP changes the cluster)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type json --patch-file "$HOME/nkp-$CLUSTER_NAME-patch.json"
```

**Plan A, part 2.** After the cluster is Reconciled: `enforce=restricted` on your workload namespaces. One namespace per run:

```bash
# CHANGES  (sets Pod Security enforce=restricted on one namespace of dev-01)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-dev-01.env 2>/dev/null
ns=''
: "${ns:?}" "${CLUSTER_KUBECONFIG:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" label --overwrite ns "$ns" pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/audit=restricted pod-security.kubernetes.io/warn=restricted
```

Do not label the NKP namespaces (`kommander`, `metallb-system`, `node-feature-discovery`, `ntnx-system`, `kube-system`, `caren-system`, `kommander-flux`, `git-operator-system`, `kube-federation-system`, `container-object-storage-system`, workspace namespaces).

**Plan B, if the security team demands cluster-wide `restricted`.** Same patch, different value, and the exemption list from step 3 comes in full with `kube-system`:

```text
value='{"enforce":"restricted","warn":"restricted","audit":"restricted","exemptions":{"namespaces":["kube-system","ntnx-system","node-feature-discovery","kommander","metallb-system"]}}'
```

The list must hold every namespace that step 3 named, and `kube-system` must be in it (a value without `exemptions` gets the default `["kube-system"]` added by the dry run). [live 2.19.0] Each exemption list is at most 64 namespaces. I will not run plan B until step 3 shows the exact list and you accept it.

### Step 5 — watch (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-dev-01.env 2>/dev/null
capi=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.status.capiClusterRef.name}'); sleep 60
for c in RollingOut=False ScalingUp=False ScalingDown=False Remediating=False Available; do kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" wait "clusters.cluster.x-k8s.io/$capi" --for=condition="$c" --timeout=60m; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" wait "nkpclusters.clusters.nkp.nutanix.com/$CLUSTER_NAME" --for=jsonpath='{.status.phase}'=Reconciled --timeout=30m
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
```

Done when each wait prints "condition met" and all nodes are `Ready`.

### Step 6 — verify the admission (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns -o custom-columns='NS:.metadata.name,ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
```

Line 1: which namespaces enforce what. Line 2: a new AGE means a new machine (that is the P-44 check). Done when your workload namespaces show `restricted`, the NKP namespaces show `privileged`, and a test pod in a new namespace gets the restricted warnings.

---

## nkp-identity-security S6

**Skill files read:** `skills/nkp/SKILL.md` (Pro tier), `skills/_shared/RULES.md`, `skills/nkp-identity-security/SKILL.md` (tier table, Gatekeeper row), `skills/nkp-identity-security/references/gatekeeper.md` (G1, G3, G4), `skills/nkp-airgap/SKILL.md` (pre-stage pointer), `skills/nkp-airgap/references/prestage.md` (P1, "Use an asset").

### Reply

Pro is enough: your own Gatekeeper policies ("policy control using Gatekeeper") are a Pro and Ultimate feature. [pdf p.28] Gatekeeper 3.23.0 already runs in `kommander` on the cluster; we do not install it and we do not disable it.

The guide takes the policy files from GitHub. **That does not work on an air-gapped site.** The pinned files are in the assets of skill `nkp-airgap`, and I check their SHA-256 before I apply anything.

Two things that decide the plan, so I check them before I write any policy:

- On 2.19.0, `kube-system` and `ntnx-system` run privileged pods, and `kube-system`, `ntnx-system`, `node-feature-discovery` use hostPath volumes. [live 2.19.0]
- The library constraint excludes only `kube-system`. A `deny` constraint would stop new CSI driver pods in `ntnx-system` and new NFD pods. So the first apply is `enforcementAction: dryrun` (audit only), with the extra namespaces excluded, and `deny` comes later, after you see the audit.

### Questions I ask you now (one `ask_user_question` round)

1. Which cluster? (I need the name for `~/nkp-<cluster>.env`.)
2. Are the skill files on this operator host at `/tmp/nkp-eval-b3/skills/nkp-airgap` — the folder I read them from, with `assets/` under it? If you keep another copy, give the path.
3. Do you accept `dryrun` first and `deny` after the audit? (Recommended. `deny` first is possible and the plan says so, but it blocks the CSI and NFD pods of `ntnx-system` unless we exempt them.)

### Step 1 — check the assets (READ-ONLY, I run it)

`dir` is the skill folder: the one that holds `assets/` and `references/`. It is the only value I edit in this block.

```bash
# READ-ONLY
dir='/tmp/nkp-eval-b3/skills/nkp-airgap'; : "${dir:?}"
for f in "$dir"/assets/*.yaml; do want="$(sed -n 's/^# Body SHA-256: //p' "$f")"; got="$(grep -v '^# ' "$f" | sha256sum | cut -d' ' -f1)"; [ "$want" = "$got" ] && echo "OK $f" || echo "FAILED $f"; done
```

Every line must start with `OK`. A `FAILED` line means the file changed or was damaged: stop, do not apply it. The three Gatekeeper files have the upstream URL, the gatekeeper-library commit `a8d4799...,` and their SHA-256 in the header. [live 2.19.0]

### Step 2 — find what the policy would block (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o json | jq -r '.items[] | select(any(.spec.containers[]; .securityContext.privileged == true)) | .metadata.namespace' | sort | uniq -c
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o json | jq -r '.items[] | select(any(.spec.volumes[]?; .hostPath != null)) | .metadata.namespace' | sort | uniq -c
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get constraints
```

The counts name the namespaces to exclude. On 2.19.0 I expect `kube-system` and `ntnx-system` in the first list.

### Step 3 — dry run the template (READ-ONLY, I run it)

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
dir='/tmp/nkp-eval-b3/skills/nkp-airgap'
: "${dir:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$dir/assets/gatekeeper-privileged-containers-template.yaml"
```

### Step 4 — plan: the ConstraintTemplate (CHANGES; I stop here for "yes")

Command: `apply -f gatekeeper-privileged-containers-template.yaml`, then wait for the CRD. Target: the cluster. Result: ConstraintTemplate `k8spspprivilegedcontainer` and the new constraint kind `K8sPSPPrivilegedContainer`; Gatekeeper then audits existing pods. No pod is blocked by this step.

```bash
# CHANGES  (adds the ConstraintTemplate; Gatekeeper makes its constraint CRD)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
dir='/tmp/nkp-eval-b3/skills/nkp-airgap'
: "${dir:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$dir/assets/gatekeeper-privileged-containers-template.yaml"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" wait constrainttemplate k8spspprivilegedcontainer --for=jsonpath='{.status.created}'=true --timeout=2m
```

After this step a constraint dry run works. Before it, it fails with `no matches for kind "K8sPSPPrivilegedContainer"`; that error is normal. [live 2.19.0]

### Step 5 — write your constraint copy (CHANGES on this host only; plan, after "yes")

I do not edit the asset. I write a local copy with the action and the excluded namespaces from steps 1–2: `dryrun` now, plus the namespaces step 2 found.

```bash
# CHANGES  (writes the constraint file on the operator host; changes no cluster)
dir='/tmp/nkp-eval-b3/skills/nkp-airgap'; action='dryrun'
: "${dir:?}" "${action:?}"
(umask 077 && awk -v a="$action" '{print} /^spec:$/{print "  enforcementAction: " a}' "$dir/assets/gatekeeper-privileged-containers-constraint.yaml" | sed 's/excludedNamespaces: \["kube-system"\]/excludedNamespaces: ["kube-system","ntnx-system","node-feature-discovery"]/' > "$HOME/nkp-gk-privileged.yaml")
grep -nE '^ +(enforcementAction|excludedNamespaces):' "$HOME/nkp-gk-privileged.yaml"
```

The `grep` must show both lines with the new values. The `exemptImages` entry in the asset (`safeimages.com/*`) is an upstream example; it exempts no image of your site.

Then the constraint dry run (READ-ONLY):

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$HOME/nkp-gk-privileged.yaml"
```

### Step 6 — plan: the constraint (CHANGES; second "yes")

Command: `apply -f ~/nkp-gk-privileged.yaml`. Target: the cluster. Result: constraint `psp-privileged-container`, kind `K8sPSPPrivilegedContainer`, on Pods in all namespaces except the excluded ones, action `dryrun`: violations are recorded, nothing is rejected.

```bash
# CHANGES  (adds the constraint; audit only while the action is dryrun)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$HOME/nkp-gk-privileged.yaml"
```

### Step 7 — read the audit (READ-ONLY, I run it)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get k8spspprivilegedcontainer psp-privileged-container -o jsonpath='action={.spec.enforcementAction} violations={.status.totalViolations}{"\n"}{range .status.violations[*]}{.namespace}/{.name}: {.message}{"\n"}{end}'
```

Done when the audit shows only violations you accept.

### Step 8 — then `deny`

After the audit is clean, I write a new plan: the same block as step 5 with `action='deny'`, the same excluded namespaces, the dry run, and then the apply — with a fresh "yes". A `deny` constraint rejects API requests from that moment, so any remaining privileged workload that restarts gets blocked.

Host paths (`K8sPSPHostFilesystem`) are the other library policy you asked about in the guide: the template asset exists (`gatekeeper-host-filesystem-template.yaml`), but there is **no** constraint asset for it. The constraint `psp-host-filesystem` with `parameters.allowedHostPaths` (`pathPrefix`, `readOnly`) is a short YAML file that I write with **your** paths. Give me the paths and I add it as its own plan, again as `dryrun` first. [pdf p.582]

Other library policies: the user downloads them on a connected host from the same repository and commit (`gatekeeper-library-repo` in `assets/download-urls.txt`).

---

## nkp-identity-security S7

**Skill files read:** `skills/nkp/SKILL.md` (tiers), `skills/_shared/RULES.md`, `skills/nkp-identity-security/SKILL.md` (Job → section, Related skills), `skills/nkp-identity-security/references/cluster-security.md` (C4), `skills/nkp-airgap/references/os-images.md` (O1, O2, O3), `skills/nkp-airgap/SKILL.md` (bundle contents, FIPS artifacts).

### Reply

**No. You cannot enable FIPS on the existing management cluster.** FIPS mode is set only at create time; you cannot turn it on or off later. You make a new cluster. [pdf p.988]

That is the answer for the audit too: an audit next month needs a FIPS cluster that was created as FIPS, not a flag flipped on the current one.

Facts you need for the new cluster:

- FIPS needs **Pro or Ultimate**. [pdf p.28]
- The node OS image must be a **FIPS image**. The Nutanix pre-built images (Rocky Linux 9.8, Ubuntu 24.04) are **not** FIPS. [pdf p.55-56] Build one with NIB (`nkp create package-bundle ... --fips`, then `nkp create image nutanix ... --fips`). The package bundle must be FIPS too. [pdf p.60][references/os-images.md, O1 and O3]
- AHV create flag: `nkp create cluster nutanix --fips` — "The OS images used by the cluster must be prepared with FIPS mode enabled". [live 2.19.0]
- Air-gapped: the 2.19.0 bundle **has** the FIPS parts: `kubernetes-images-1.36.2-d2iq.1-fips.tar`, `containerd-*_fips.tar.gz` for RHEL and Oracle Linux, `mesosphere/kube-proxy:v1.36.2_fips.0`, `mesosphere/kfips:v0.6.2`. [live 2.19.0] It does **not** have the OS distribution packages (that is `nkp create package-bundle`) and does not have a FIPS base OS image.
- A cluster is FIPS when its Kubernetes version has `+fips.0`. [pdf p.988]
- Validation for the audit: `nkp check cluster fips` compares file signatures on the nodes with the signature files in the `nkp` binary. [pdf p.989]
- Do not plan a FIPS upgrade of the current cluster in place: `version` and `+fips.0` are part of the topology, and the guide treats FIPS as a create-time property. A cluster that was not created FIPS stays not FIPS.

### Step 1 — confirm the current state (READ-ONLY, I run it)

This is the management cluster, so its NKPCluster is in `kommander`; no cluster env file is needed.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -l kommander.d2iq.io/host=true -o custom-columns='NAME:.metadata.name,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='tier={.status.dkpLevel} valid={.status.valid}{"\n"}'
printf '%s\n' "$VM_IMAGE"
```

Line 1: `K8S` with no `+fips.0` confirms the cluster is not FIPS. Line 2: the licence tier (FIPS needs Pro or Ultimate). Line 3: the node image in use — a Nutanix pre-built Rocky or Ubuntu name means there is no FIPS image at the site yet.

### Step 2 — what we must build before the audit

| Item | Where | Skill |
|---|---|---|
| FIPS OS package bundle (`--fips`) on a connected host, moved in | operator host, `"$BUNDLE_DIR"/image-artifacts` | `nkp-airgap`, `os-images.md`, O1 |
| FIPS base OS image (RHEL) imported into Prism Central | Prism Central | `nkp-airgap`, `os-images.md`, O2 |
| FIPS image build (`nkp create image nutanix ... --fips`) | operator host + Prism Central | `nkp-airgap`, `os-images.md`, O3 |
| New cluster create with `--fips` and the new image | operator host | `nkp-install`, metal or nutanix file |
| `nkp check cluster fips` for the audit evidence | new cluster | `cluster-security.md`, C4 |

### Questions I ask you now (one `ask_user_question` round)

1. Which infrastructure is the management cluster on — Prism Central with AHV? (Nutanix path needs `--fips` plus a NIB-built image; AWS or vSphere use the `+fips.0` version flags instead. [pdf p.988-989])
2. Do you have a RHEL base cloud image (qcow2/img) available offline for NIB? Without `--source-image`, NIB tries to download upstream, and that fails offline. [live 2.19.0]
3. Is there time and capacity to create the new FIPS cluster before the audit, or does the audit need a written statement that FIPS is not possible on this cluster?

### Step 3 — the validation run (CHANGES; only on the new cluster, after "yes")

Not for the current cluster: it is not FIPS, so the check only fails. On the new cluster it makes check objects and a result ConfigMap in namespace `default`.

```bash
# CHANGES  (runs the FIPS check on the cluster; it makes check objects and a result ConfigMap in namespace default)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
nkp check cluster fips --kubeconfig "$CLUSTER_KUBECONFIG"
```

The objects it creates, its output and its exit code are UNKNOWN (P-46) in the skills; we read them from the new cluster after the run:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n default get pods,jobs,configmaps
```

The create steps for the new cluster are skill `nkp-install` (Nutanix or Metal file), with `--fips` added as a line in the create script, and skill `nkp-airgap` for the image build. Tell me which one you want and I write that plan; it is a separate, longer change.

---

## nkp-identity-security S8

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-identity-security/SKILL.md` (the parts table, Step 1), `skills/nkp-identity-security/references/identity.md` (I2, I3, I4, I7).

### Reply

Two answers, and both are honest about the limit of these skills.

**1. The maximum number of LDAP connectors Dex supports in NKP: not in the skills.** I have no documented cap, and I will not invent one. What the skills do say:

- You can have many connectors; the login page shows one button for each, with `spec.displayName` as the text. [pdf p.241, p.246]
- Every connector is one `Connector` object (`connectors.dex.mesosphere.io`), and the dex-controller feeds them to Dex without a restart. [live 2.19.0]
- Scope matters more than count in practice: one connector in namespace `kommander` serves all workspaces; a connector in a workspace namespace serves only that workspace's login URL and needs Ultimate. [pdf p.365]

So the practical limit at your site is the number of `Connector` objects you keep, not a number in the docs. For a hard, supported limit, ask Nutanix support — that is a vendor question, not a command.

**2. Okta group sync over SCIM: also not in the skills.** What the skills do state is that the connector types in the CRD are `ldap`, `oidc`, `saml`, and `github`. [live 2.19.0] There is no SCIM connector type, and no SCIM section anywhere in these skills. So there is no documented SCIM group sync, and I will not claim Okta SCIM works in NKP.

What NKP does support for Okta groups is the OIDC groups claim:

- Okta as an `oidc` connector, with `insecureEnableGroups: true` and a scope the IdP knows (often `groups`). [pdf p.577]
- Then Dex puts the groups in the token, Kubernetes sees `oidc:<group>`, and RBAC binds on that name. [pdf p.229]
- `insecureSkipEmailVerified: true` does not help `kubectl`: the API server library still needs `email_verified: true` in the token. Fix that in Okta. [pdf p.575]

Group sync in the other connector types, if you prefer them: LDAP `groupSearch`, SAML `groupsAttr`. [pdf p.239, p.580]

### Checks I run (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get connectors.dex.mesosphere.io -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get crd connectors.dex.mesosphere.io -o json | jq -r '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties | keys[]'
```

Line 1: how many connectors exist now, and in which namespaces (that also shows the scope of each one). Line 2: the connector types that the installed CRD accepts — that list is the proof for the SCIM answer on **your** version, instead of my word. If the list contains something other than `ldap`, `oidc`, `saml`, `github` (plus fields like `displayName`, `enabled`), tell me and I re-read it with you.

### Questions I ask you now (one `ask_user_question` round)

1. How many LDAP connectors do you plan to add, and are they global (namespace `kommander`) or per workspace? (Per workspace needs Ultimate. [pdf p.365])
2. Is Okta your IdP, and do you need group sync only, or also SCIM-driven user provisioning from Okta into something in NKP?

If the answer to 2 is "SCIM provisioning into NKP", the skills give no supported path. I would say plainly: NKP keeps no user database — the IdP holds the users [pdf p.575] — so there is nothing in NKP for Okta SCIM to write to, and group sync happens through the OIDC/LDAP/SAML token. Confirm the requirement with Nutanix support before you design around SCIM.
