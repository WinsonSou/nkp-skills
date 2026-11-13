# Identity: Dex, identity providers, login, kubectl access

Use this file from skill `nkp-identity-security`. All objects are on the management cluster.

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `IDP_LDAP_HOST` `IDP_LDAP_BIND_DN` `IDP_LDAP_USER_BASE_DN` `IDP_LDAP_GROUP_BASE_DN` `IDP_OIDC_ISSUER` `IDP_OIDC_CLIENT_ID` `IDP_SAML_SSO_URL` `IDP_CA_FILE` |
| `~/nkp-site.env` secrets | `IDP_LDAP_BIND_PASSWORD` `IDP_OIDC_CLIENT_SECRET` `DEX_USER_HASH` |

- `IDP_LDAP_HOST`: `host:port` of the LDAP or Active Directory server (LDAPS is port 636).
- `IDP_LDAP_BIND_DN` and `IDP_LDAP_BIND_PASSWORD`: the service account that searches the directory.
- `IDP_LDAP_USER_BASE_DN`, `IDP_LDAP_GROUP_BASE_DN`: where the users and the groups are.
- `IDP_OIDC_ISSUER`, `IDP_OIDC_CLIENT_ID`, `IDP_OIDC_CLIENT_SECRET`: from the OIDC client that the IdP admin makes.
- `IDP_SAML_SSO_URL`: the SAML single sign-on URL of the IdP.
- `IDP_CA_FILE`: PEM file of the CA that signed the IdP server certificate (LDAP) or the SAML signing certificate.
- The `IDP_*` values are for one connector. A second connector of the same type replaces the values of the first (the last line wins). Do one connector at a time. Append the new values before each connector.

## I1. Static admin user

- The install makes one static admin user. Use it only to set up an identity provider. Keep it as a backup login. [pdf p.575, p.729]
- The user gets the password with `nkp get dashboard` (USER-TERMINAL). To rotate it, use skill `nkp-install`, step "Give the user the UI access". [pdf p.252]
- The admin user is bound to `cluster-admin`. [pdf p.233][live 2.19.0]

## I2. Choose the scope and the type

| Scope | Connector namespace | Tier |
|---|---|---|
| All workspaces (global) | `kommander` | all tiers |
| One workspace (tenant) | the workspace namespace (`kubectl get workspaces`, column WORKSPACE NAMESPACE) | Ultimate [pdf p.365] |

- A connector for one workspace shows only on the login URL of that workspace (I6). The group and user names get the workspace prefix ([rbac.md](rbac.md), R1). [pdf p.229, p.368]
- You can have many connectors. The login page shows one button for each. `spec.displayName` is the button text. [pdf p.241, p.246]
- Connector types in the CRD: `ldap`, `oidc`, `saml`, `github`. [live 2.19.0] Air-gapped site: the IdP must be inside the air gap. GitHub and public OIDC providers do not work there.
- GitHub (connected sites only): use the UI. Callback URL `https://<host>/dex/callback`, then the GitHub client ID and secret, and "Load All Groups" for groups. [pdf p.242-243]
- The UI way: Global workspace → Administration → Identity Providers → Add Identity Provider. [pdf p.242] The CLI way below makes the same `Connector` object (`dex.mesosphere.io/v1alpha1`). The dex-controller gives it to Dex. Dex does not restart. [pdf p.239][live 2.19.0]

Before you start, ask the user for: the scope, the type, the values in the table above, the connector name (`a-z`, `0-9`, `-`), and the button text. The user adds the secret lines with an editor (rule 5).

Ask first, then append in the next reply (rule 4). Show no append block in the reply that asks. A base DN is a full DN. If the user gives a short value (for example `OU=Staff`), write the full DN that you think is correct (for example `OU=Staff,DC=corp,DC=example,DC=com`) and ask the user to confirm it. Append it only after the user confirms. Do the same for the connector name and the button text: no example value in a block before the user gives it.

Get `host` for the blocks below: the host part of `ui=` in SKILL.md step 1. If the UI has a custom domain, use that name (skill `nkp-networking`).

## I3. LDAP or Active Directory

Typical attribute values. Ask the user to confirm each value for their directory. [pdf p.239, p.246][field]

| Value | OpenLDAP | Active Directory |
|---|---|---|
| `user_filter` | `(objectClass=inetOrgPerson)` | `(objectClass=person)` |
| `user_attr` (login name) | `uid` | `sAMAccountName` |
| `id_attr` | `uid` | `DN` |
| `email_attr` | `mail` | `userPrincipalName` |
| `name_attr` | `cn` | `cn` |
| `group_filter` | `(objectClass=groupOfUniqueNames)` or `(objectClass=posixGroup)` | `(objectClass=group)` |
| `member_user_attr`, `member_group_attr` | `DN`, `uniqueMember` (or `uid`, `memberUid`) | `DN`, `member` |
| `group_name_attr` | `cn` | `cn` |

1. Check the values and the secrets:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
for v in IDP_LDAP_HOST IDP_LDAP_BIND_DN IDP_LDAP_USER_BASE_DN IDP_LDAP_GROUP_BASE_DN IDP_CA_FILE IDP_LDAP_BIND_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
openssl x509 -in "$IDP_CA_FILE" -noout -subject -enddate
```

2. After "yes", make the two Secrets. Dex reads the bind password from the key `password` and the CA from the key `tls.crt`. [live 2.19.0] The block gives the secret through `--from-file=<(...)`, so it is not in the process list.

```bash
# CHANGES  (makes the bind password Secret and the CA Secret in the connector namespace)
source ~/nkp-site.env 2>/dev/null
ns=''; name=''
: "${ns:?}" "${name:?}" "${IDP_LDAP_BIND_PASSWORD:?}" "${IDP_CA_FILE:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" create secret generic "$name-bind" --from-file=password=<(printf %s "$(printenv IDP_LDAP_BIND_PASSWORD)") -o name
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" create secret generic "$name-ca" --from-file=tls.crt="$IDP_CA_FILE" -o name
```

3. Write the connector file. Set the empty values from the table (after the user confirms them).

```bash
# CHANGES  (writes the connector file on the operator host; changes no cluster)
source ~/nkp-site.env 2>/dev/null
ns=''; name=''; display=''; user_filter=''; user_attr=''; id_attr=''; email_attr=''; name_attr=''; group_filter=''; member_user_attr=''; member_group_attr=''; group_name_attr=''
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

- Without `rootCASecretRef`, Dex uses the CA list of its image. [live 2.19.0] Use `insecureNoSSL: true` (port 389, no TLS) or `insecureSkipVerify: true` only for a test, and only after the user agrees. [pdf p.245]
- `startTLS: true` for port 389 with StartTLS. [live 2.19.0]

4. Do I5 (dry run, apply, test).

## I4. OIDC or SAML

**OIDC.** The IdP admin makes a client with the redirect URI `https://<host>/dex/callback`. [pdf p.243, p.577] Dex reads the keys `client-id` and `client-secret` from one Secret. [live 2.19.0] After "yes":

```bash
# CHANGES  (makes the OIDC client Secret in the connector namespace)
source ~/nkp-site.env 2>/dev/null
ns=''; name=''
: "${ns:?}" "${name:?}" "${IDP_OIDC_CLIENT_ID:?}" "${IDP_OIDC_CLIENT_SECRET:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" create secret generic "$name-client" --from-literal=client-id="$IDP_OIDC_CLIENT_ID" --from-file=client-secret=<(printf %s "$(printenv IDP_OIDC_CLIENT_SECRET)") -o name
```

```bash
# CHANGES  (writes the connector file on the operator host; changes no cluster)
source ~/nkp-site.env 2>/dev/null
ns=''; name=''; display=''; host=''
: "${ns:?}" "${name:?}" "${display:?}" "${host:?}" "${IDP_OIDC_ISSUER:?}"
(umask 077 && cat > "$HOME/nkp-idp-$name.yaml" <<EOF
apiVersion: dex.mesosphere.io/v1alpha1
kind: Connector
metadata:
  name: $name
  namespace: $ns
spec:
  enabled: true
  type: oidc
  displayName: "$display"
  oidc:
    issuer: "$IDP_OIDC_ISSUER"
    redirectURI: "https://$host/dex/callback"
    clientSecretRef:
      name: $name-client
    scopes: [openid, profile, email, groups]
    insecureEnableGroups: true
    userIDKey: email
    userNameKey: email
EOF
)
```

- The groups claim needs `insecureEnableGroups: true` and a scope that the IdP knows (often `groups`). Ask the user. [pdf p.577]
- `insecureSkipEmailVerified: true` does not help `kubectl`: the API server library still needs `email_verified: true` in the token. Fix it in the IdP. [pdf p.575]
- Other fields: `claimMapping` (`email`, `groups`, `preferred_username`), `getUserInfo`, `promptType`. [live 2.19.0]

**SAML.** Give the IdP admin the entity ID `https://<host>/dex` and the ACS (callback) URL `https://<host>/dex/callback`. [pdf p.579] Dex checks the signature of the SAML response with the CA in the key `tls.crt`. [live 2.19.0] After "yes":

```bash
# CHANGES  (makes the CA Secret, then writes the connector file on the operator host)
source ~/nkp-site.env 2>/dev/null
ns=''; name=''; display=''; host=''; user_attr=''; email_attr=''; groups_attr=''
: "${ns:?}" "${name:?}" "${display:?}" "${host:?}" "${user_attr:?}" "${email_attr:?}" "${groups_attr:?}" "${IDP_SAML_SSO_URL:?}" "${IDP_CA_FILE:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" create secret generic "$name-ca" --from-file=tls.crt="$IDP_CA_FILE" -o name
(umask 077 && cat > "$HOME/nkp-idp-$name.yaml" <<EOF
apiVersion: dex.mesosphere.io/v1alpha1
kind: Connector
metadata:
  name: $name
  namespace: $ns
spec:
  enabled: true
  type: saml
  displayName: "$display"
  saml:
    ssoURL: "$IDP_SAML_SSO_URL"
    redirectURI: "https://$host/dex/callback"
    entityIssuer: "https://$host/dex"
    caSecretRef:
      name: $name-ca
    usernameAttr: $user_attr
    emailAttr: $email_attr
    groupsAttr: $groups_attr
EOF
)
```

- `user_attr`, `email_attr`, `groups_attr`: the attribute names in the SAML response. Ask the IdP admin. [pdf p.580] SAML has no refresh tokens. [pdf p.576]
- The guide also adds each user email to the TFA whitelist (`traefikForwardAuth.whitelist` of the app `traefik-forward-auth-mgmt`). [pdf p.580] In 2.19.0 the default whitelist is empty and TFA checks RBAC (`enableRBAC: true`). [live 2.19.0]
- UNKNOWN (P-41): whether an IdP user can pass TFA with the empty default whitelist (and only RBAC). Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs deploy/traefik-forward-auth-mgmt --tail=50` after the first login of a user that has a binding ([rbac.md](rbac.md)).

Then do I5.

## I5. Dry run, apply, test

```bash
# READ-ONLY  (server dry run: the webhooks check the connector and change nothing)
source ~/nkp-site.env 2>/dev/null
name=''
: "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f "$HOME/nkp-idp-$name.yaml"
```

The dry run prints `created (server dry run)`. It does not check that the Secrets exist. [live 2.19.0] Show the file as the plan. After "yes":

```bash
# CHANGES  (adds the connector; the login page gets a new button)
source ~/nkp-site.env 2>/dev/null
name=''
: "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f "$HOME/nkp-idp-$name.yaml"
```

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get connectors.dex.mesosphere.io -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs deploy/dex-dex-controller -c manager --tail=20
```

Then the user opens `https://<host>/token` (global) or the workspace URL (I6) and selects "Log in with <button text>". [pdf p.247] Read the Dex log during the login (I7).

Done when: the Dex log shows `login successful: connector "<name>"` with the email and the groups of the user. [pdf p.249] Then a new user has no access yet. Give access with [rbac.md](rbac.md). [pdf p.231]

To turn a connector off, patch `spec.enabled` to `false` (CHANGES). [live 2.19.0]

## I6. kubectl access and the login URL of a workspace

- A user gets a kubeconfig from `https://<host>/token`: log in, select the cluster, follow the page. The token is valid for 24 hours. [pdf p.249-250]
- Or the Konvoy credentials plugin (the link "Credentials plugin instructions" on the same page) gets new tokens automatically. With one kubeconfig file for each cluster, use a different profile name for each cluster. Else all clusters use the same token. [pdf p.250-251]
- Each cluster needs its own token. [pdf p.251]
- A workspace IdP (tenant) has its own login URL: `https://<host>/token/landing/<workspace-name>`. It shows the global IdPs and the IdPs of that workspace. [pdf p.368] The workspace name is the NAME column of `kubectl get workspaces`.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ws=''
: "${ws:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspace "$ws" -o name && echo "https://$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get kommanderclusters -l kommander.d2iq.io/host=true -o jsonpath='{.items[0].status.ingress.address}')/token/landing/$ws"
```

## I7. Dex values: token lifetime, local users, CA

Dex reads extra Helm values from the ConfigMap `dex-overrides` in `kommander`. The guide also names it in `spec.configOverrides` of the Dex AppDeployment. [pdf p.577-578, p.587] Facts [live 2.19.0]:
- The Dex HelmRelease reads `dex-overrides` directly (slot 2, `optional: true`), also without `configOverrides`. A fresh install has no such ConfigMap. This is the model of skill `nkp-platform-apps-gitops`, file `overrides.md`, O1.
- Slot 3 is `dex-cluster-overrides`. Kommander makes it, and it holds `config.issuer`. Without the issuer, every login and `kube-oidc-proxy` stop.
- With `configOverrides`, Kommander can also copy `dex-overrides` into `dex-cluster-overrides`. UNKNOWN (P-33): how Kommander merges a workspace override with the cluster override. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmrelease dex -o jsonpath='{range .spec.valuesFrom[*]}{.name}{"\n"}{end}'` and the issuer check at the end of this section.

Keep all Dex values in this one ConfigMap. Read it first, and keep the old keys. For the general override rules, use skill `nkp-platform-apps-gitops`.

The order: file, dry run, plan without the hash, "yes", apply, issuer check, Ready check.

Value keys:
- Token lifetime: `config.expiry.idTokens` (default `24h`). [pdf p.577]
- Local users (tests only; Nutanix does not recommend them in production): `config.staticPasswords` with `email` and `hash` (bcrypt). [pdf p.585-587] The default values have no `staticPasswords`. [live 2.19.0] A new local user has no access until you bind it ([rbac.md](rbac.md), R3 with kind `User`). [pdf p.588]
- CA for an OIDC IdP: the `oidc` connector has no CA field. [live 2.19.0] A field note mounts a CA Secret into Dex with `extraVolumes`, `extraVolumeMounts`, and `env` `SSL_CERT_FILE`. [field]
- UNKNOWN (P-42): whether the Dex chart 2.14.2 takes `extraVolumes`, `extraVolumeMounts`, and `env` from `dex-overrides`. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get deploy dex -o jsonpath='{.spec.template.spec.volumes[*].name}{"\n"}'` after the change.

Local user hash. The user runs this in their own terminal, then puts the output in `~/nkp-site.env` as `export DEX_USER_HASH='...'` (rule 5):

```bash
# USER-TERMINAL  (htpasswd asks for the password two times; the output is the bcrypt hash)
htpasswd -nBC 10 "" | tr -d ':\n'; echo
```

Write the ConfigMap file. This example sets the token lifetime and one local user. Remove the parts that the user does not want. The heredoc puts the hash in single quotes: a `$` in an unquoted hash breaks Dex. [pdf p.587]

```bash
# CHANGES  (writes the dex-overrides file on the operator host; changes no cluster)
source ~/nkp-site.env 2>/dev/null
lifetime=''; email=''
: "${lifetime:?}" "${email:?}" "${DEX_USER_HASH:?}"
(umask 077 && cat > "$HOME/nkp-dex-overrides.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: dex-overrides
  namespace: kommander
data:
  values.yaml: |
    config:
      expiry:
        idTokens: "$lifetime"
      staticPasswords:
      - email: "$email"
        hash: '$DEX_USER_HASH'
EOF
)
```

Dry run both changes:

```bash
# READ-ONLY  (server dry runs: change nothing)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f "$HOME/nkp-dex-overrides.yaml"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch appdeployment dex --type merge -p '{"spec":{"configOverrides":{"name":"dex-overrides"}}}' --dry-run=server -o jsonpath='{.spec.configOverrides}{"\n"}'
```

The plan: the file without the hash, and "Dex restarts; logins stop for a short time". Never show the hash (rule 5). Show the file with:

```bash
# READ-ONLY  (prints the file; the hash line shows (hidden))
sed -E 's/(hash: ).*/\1(hidden)/' "$HOME/nkp-dex-overrides.yaml"
```

After "yes":

```bash
# CHANGES  (applies dex-overrides and points the Dex AppDeployment to it; the Dex HelmRelease runs again)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f "$HOME/nkp-dex-overrides.yaml"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch appdeployment dex --type merge -p '{"spec":{"configOverrides":{"name":"dex-overrides"}}}'
```

Issuer check. Wait 1 minute after the apply. The block prints the number of `issuer:` lines only, no values:

```bash
# READ-ONLY  (prints a count; must be 1)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get cm dex-cluster-overrides -o go-template='{{index .data "values.yaml"}}' | grep -c '^ *issuer:'
```

- `1`: go on. [live 2.19.0: `1` before any change]
- `0`: stop. The issuer is gone. Make a plan to remove `spec.configOverrides` from the Dex AppDeployment (skill `nkp-platform-apps-gitops`, file `overrides.md`, O5 item 5). The HelmRelease still reads `dex-overrides` in slot 2. Tell the user, and note the result on P-33.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander wait helmrelease dex --for=condition=Ready --timeout=10m
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander rollout status deploy/dex --timeout=5m
```

Done when: the issuer check prints `1`, and both commands end without error. Then the user tests the admin login and the new value.

## I8. Login failures

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get pods | grep -E 'dex|traefik-forward-auth|kube-oidc-proxy'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs deploy/dex --tail=100
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs deploy/dex-dex-controller -c manager --tail=30
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmreleases dex traefik-forward-auth-mgmt kube-oidc-proxy
```

| Text or symptom | Cause | Fix |
|---|---|---|
| Dex pod restarts; `error parse config file` | Bad Dex values (for example a bad base64 value, or a bcrypt hash broken by `$`). [pdf p.248, p.587] | Fix `dex-overrides` (I7). |
| `/token` gives HTTP 5xx after a timeout | Dex does not run. [pdf p.248] | Read the Dex pod events and log. |
| UI shows "Internal Server Error" and "Login error" | Most connector errors show here. [pdf p.248] | Read the Dex log at the login time. |
| `LDAP Result Code 200 "Network Error"`, `no such host` | DNS name or port of the LDAP server. [pdf p.248] | Fix `IDP_LDAP_HOST`, check DNS from the cluster. |
| `x509: certificate signed by unknown authority` | Wrong or missing IdP CA. | LDAP and SAML: replace the `<name>-ca` Secret (I3, I4). OIDC: I7. |
| `filter returned multiple (2) results` | The user search finds more than one entry. [pdf p.249] | Make `user_filter` or the base DN narrower. |
| Login works, then `403 Forbidden` | No RBAC binding, or the wrong subject name. | [rbac.md](rbac.md), R7 |
| `kubectl` with the Dex token fails for an OIDC user | `email_verified` is not `true` in the token. [pdf p.575] | Fix the IdP claim. |
| HTTP 500 after login for a user with many groups | The TFA cookie is larger than 4 KB. [pdf p.585] | Fewer groups for the user. Last choice: TFA value `clusterStorage.enabled: true`, `clusterStorage.namespace: kommander` on the app `traefik-forward-auth-mgmt` (slower). [pdf p.585] For the app override, use skill `nkp-platform-apps-gitops`. |

Done when: the Dex log shows `login successful` for the user.
