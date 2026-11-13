# Batch 3 eval — answers, part 1

## nkp-platform-apps-gitops G1

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-platform-apps-gitops/SKILL.md` (step 1, step 3), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O2, O5), `skills/nkp-troubleshooting/references/flux.md` (F1, F2, F3).

**What the message means** [live 2.19.0][pdf p.1047]

- NKP HelmReleases retry 30 times, then stop. `upgrade retries exhausted` is that stop. The Helm release is stuck.
- The reset is `spec.suspend` true, then false. It starts one new reconcile.
- **A reset without a fix fails again.** Your typo fix is only real when it is in the override ConfigMap that the AppDeployment points to, on the management cluster. Kommander copies that ConfigMap to the target cluster as `<app-id>-cluster-overrides`. If you fixed a file on the operator host, or a different ConfigMap, the HelmRelease still reads the old text.
- Never edit the HelmRelease or the `<app-id>-<version>-config-defaults` ConfigMap. NKP applies them again.

**Questions I need answered first** (I would ask these with the question tool)

1. Did you fix the YAML in the override ConfigMap on the management cluster (`kubectl edit`/`kubectl apply` of a ConfigMap), or in a file on this host that was never applied?
2. Does the AppDeployment still name that same ConfigMap (`spec.configOverrides.name`), or did the fix get a new name?
3. Did anyone set `spec.suspend: true` on the HelmRelease? If yes, why? I do not continue without an answer.

**Step 1 — read the failing links (READ-ONLY, run it)**

```bash
# READ-ONLY
source ~/nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -iE 'NAME|traefik'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment traefik -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
```

`WORKSPACE_NS` is `kommander` for the management cluster. From the first line, set `hr` to the traefik HelmRelease name and `ns` to `kommander`.

**Step 2 — read the message and `suspend` (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-mgmt.env 2>/dev/null
hr=''; ns='kommander'; : "${hr:?}" "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get helmrelease "$hr" -o jsonpath='suspend={.spec.suspend}{"\n"}{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

- A message with `values`, `yaml:`, `schema`, or `cannot unmarshal` means the **old** text is still in the chain. Go back to step 1 and read the override ConfigMap text (`values.yaml` key).
- `exhausted` or `another rollback/release in progress` with no values error: the text is good, and the release only needs the reset.

**Step 3 — read the values that the HelmRelease uses now (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|traefik'
```

The `FROM` column shows the ConfigMap order: `<app-id>-<version>-config-defaults`, then `<app-id>-overrides`, then `<app-id>-cluster-overrides`. The last one wins. Set `cm` to the override name and read it. Traefik values hold no passwords, so I can show it:

```bash
# READ-ONLY
source ~/nkp-mgmt.env 2>/dev/null
ns='kommander'; cm=''; : "${ns:?}" "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get configmap "$cm" -o jsonpath='{.data.values\.yaml}'
```

If your fix is not in this output, the reset below is useless. Fix the ConfigMap first (overrides.md O3 items 1-4), then do the reset.

**Step 4 — the reset. Plan, then stop for "yes".**

- Target: the management cluster, namespace `kommander`, HelmRelease `<hr>` (traefik).
- Result: the helm-controller starts one new reconcile of that release. Nothing else changes. No pods are deleted by this patch; the chart upgrade itself may roll the traefik pods.

```bash
# CHANGES  (suspends and resumes one HelmRelease; the helm-controller starts a new reconcile)
source ~/nkp-mgmt.env 2>/dev/null
hr=''; ns='kommander'; : "${hr:?}" "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch helmrelease "$hr" --type=json -p='[{"op":"replace","path":"/spec/suspend","value":true}]'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch helmrelease "$hr" --type=json -p='[{"op":"replace","path":"/spec/suspend","value":false}]'
```

Wait for **"yes"**. Then I run it, and run the step 2 block again every minute for up to 10 minutes.

Done when: `Ready=True` for the traefik HelmRelease. If it stops again with the same message, we stop and go back to step 1: the cause is still there.

Not checked: whether an `nkp upgrade` or an UpgradePlan is running. If one is, tell me: during an upgrade the reset needs a different decision (skill `nkp-upgrade`, `stopped.md`).

---

## nkp-platform-apps-gitops G2

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-platform-apps-gitops/SKILL.md` (step 1, step 5), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O2, O3, O6, O8), `skills/nkp-networking/SKILL.md` (the network parts table: Traefik, MetalLB).

**Facts** [pdf p.977-978][live 2.19.0]

- Pro is enough. (Only Starter is the tier where overrides are "not supported" [pdf p.273]; I still say it once: the API accepts the patch, the docs do not.)
- Values: `service.type: NodePort`, `ports.web.nodePort: 30080`, `ports.websecure.nodePort: 30443`. Node ports must be in 30000-32768. Both are in range.
- If you use the registry or external-ceph ports, they also need a `nodePort` value: `ports.registry.nodePort`, `ports.external-ceph.nodePort`.
- The external load balancer must not end TLS on 30443: Traefik terminates TLS.
- Traefik is a foundational app (`kommander-flux`, `reloader`, `traefik`). Do not disable it.
- One way only: either the Kommander installer file (`apps.traefik.values`) or this override. Not both.
- On the management cluster the HelmRelease is in `kommander`. The override ConfigMap goes in the workspace namespace `kommander` (same namespace here).

**Step 1 — read the state (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment traefik -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|traefik'
```

**Step 2 — the values file. `APP_ID` is `traefik`.** This is the text I would write, for your review:

```yaml
service:
  type: NodePort
ports:
  web:
    nodePort: 30080
  websecure:
    nodePort: 30443
```

Write it (CHANGES: a file on this host, no cluster change):

```bash
# CHANGES  (writes the values file on the operator host; changes no cluster)
source ~/nkp-mgmt.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-traefik-values.yaml"
(umask 077 && cat > "$f" <<'VALUES'
service:
  type: NodePort
ports:
  web:
    nodePort: 30080
  websecure:
    nodePort: 30443
VALUES
)
```

**Step 3 — check the syntax and preview the ConfigMap (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$PWD/$CLUSTER_NAME-traefik-values.yaml" 2>&1 | head -3
```

`apiVersion not set, kind not set` is the good result. `error converting YAML to JSON` is a bad file. `no objects passed to create` means the file is empty.

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-mgmt.env 2>/dev/null
cm='traefik-overrides-ws'; : "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$PWD/$CLUSTER_NAME-traefik-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

If step 1 showed an existing override ConfigMap name, use **that** name for `cm` (the apply replaces the whole ConfigMap, so its other values must be in the file too). If it showed none, use `traefik-overrides-ws`.

**Step 4 — the plan. Stop for "yes".**

- Target: management cluster, namespace `kommander`. It creates/replaces ConfigMap `traefik-overrides-ws` and sets `spec.configOverrides.name` on AppDeployment `traefik`.
- Result: Traefik moves from `LoadBalancer` to `NodePort` on **every cluster of the `kommander` workspace** (on the management cluster: that cluster). The traefik pods restart. The UI address on port 443 disappears until an external load balancer forwards 30080/30443 to the nodes. Kommander itself does not need the LB IP to work, but your users lose the UI path.

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-mgmt.env 2>/dev/null
cm='traefik-overrides-ws'; : "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$PWD/$CLUSTER_NAME-traefik-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment traefik --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

**Step 5 — check (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment traefik -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|traefik"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get svc kommander-traefik -o jsonpath='type={.spec.type}{"\n"}ports={.spec.ports}{"\n"}'
```

Done when the AppDeployment shows `AppDeploymentEnabled=True AppDeploymentInstanceSynced=True`, the HelmRelease is `Ready=True` with a new release number, and the Service shows `NodePort` with 30080 and 30443.

**Questions I would ask** (before step 4)

1. Do you use the `registry` or `external-ceph` Traefik entrypoints? If yes, give their node ports too (they need one each).
2. Do you already have an override ConfigMap for traefik that holds other values? I must keep those values in the new file (the apply replaces all of it).
3. Which external load balancer will forward 30080/30443, and does it keep TLS end-to-end (it must not end TLS)?

After you confirm, I append the app ID to your cluster env file (rule 4), in a later reply:

```bash
# CHANGES  (adds the app ID to the cluster env file)
echo "export APP_ID='traefik'" >> ~/nkp-mgmt.env
```

Not checked: whether MetalLB keeps the `kommander-traefik` LoadBalancer IP for other services. That is skill `nkp-networking` (MetalLB pools), and it does not change with this override.

---

## nkp-platform-apps-gitops G3

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-platform-apps-gitops/SKILL.md` (step 1, step 4), `skills/nkp-platform-apps-gitops/references/overrides.md` (O4, cluster selection), `skills/nkp-troubleshooting/references/flux.md` (F1, F3, F4).

**Facts** [live 2.19.0][pdf p.426, p.432]

- The AppDeployment lives on the **management** cluster. The HelmRelease lives on the **target** cluster (`dev-02`), in the workspace namespace. A missing HelmRelease on `dev-02` is not an app problem. It is a workspace/target problem.
- An app reaches a cluster only when its KommanderCluster is `Joined`. A new cluster shows `Pending` for up to 10 minutes. 30 minutes is past that.
- The first `False` condition on the KommanderCluster is the cause.
- Also possible: the AppDeployment has a `spec.clusterSelector` that does not list `dev-02` (cluster selection is Ultimate only). Then the app is correct and `dev-02` is not a target.

**Step 1 — read the target state (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-dev-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommanderclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommanderclusters -o go-template='{{range .items}}{{.metadata.name}}: {{.status.phase}}{{"\n"}}{{range .status.conditions}}  {{.type}}={{.status}} {{.reason}}: {{.message}}{{"\n"}}{{end}}{{end}}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment kube-prometheus-stack -o jsonpath='app={.spec.appRef.name}{"\n"}selector={.spec.clusterSelector}{"\n"}{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {.message}; {end}{"\n"}{end}'
```

Check `workspaces`: the workspace **name** `team-a` and its **namespace** are different things. `WORKSPACE_NS` in `~/nkp-dev-02.env` must be the workspace namespace, not `team-a`.

**Step 2 — read the target cluster (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-dev-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|kube-prometheus'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get kustomizations
```

**How to read the result** [live 2.19.0]

| What you see | Cause | Fix (owner) |
|---|---|---|
| KommanderCluster `Pending`, many conditions `False` | The cluster has not joined | Wait only if it is under 10 minutes; else read the `kommander/kommander-cm` log (skill `nkp-troubleshooting`, `controllers.md`) |
| `IngressAddressReady=False` (`IngressServiceNotFound`) | Traefik has no LoadBalancer IP on `dev-02` | skill `nkp-networking` (MetalLB pool) |
| `IngressCertificateReady=False` | The ingress certificate is not ready | skill `nkp-networking` (cert-manager) |
| `OCIRegistryConfigSynced=False` | The registry settings for Flux on `dev-02` (air-gapped site) | skill `nkp-airgap` |
| `PlatformAppDeploymentsReady=False` | A platform app on `dev-02` failed (-flux, -reloader, -traefik) | step 1, then skill `nkp-troubleshooting` |
| `AttachmentCompleted=False` (`FailedToIdentifyCAPIResources`) | `spec.kubeconfigRef` names a wrong kubeconfig Secret | ask the user, attach again |
| KommanderCluster `Joined`, HelmRelease still missing | The AppDeployment was created after the cluster's Kustomization, or `clusterSelector` excludes `dev-02` | READ-ONLY check below |

```bash
# READ-ONLY
source ~/nkp-dev-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get gitrepositories,kustomizations -o custom-columns='KIND:.kind,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status'
```

**Questions I would ask**

1. Is `team-a` the workspace name, and what is its namespace (`WORKSPACE_NS` in your env file)? I need the namespace to read the right objects.
2. Is the site air-gapped, and did `dev-02` get the registry settings (`OCIRegistryConfigSynced`)?
3. Does `dev-02` show any LoadBalancer IP (`get svc -A --field-selector spec.type=LoadBalancer`)? If Traefik has no IP there, the cluster never becomes `Joined` and no app arrives.

I do not run any CHANGES block here: the fix is one of the rows above, and it belongs to the skill in the last column. Give me the two outputs and I continue in that skill.

---

## nkp-platform-apps-gitops G4

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-platform-apps-gitops/SKILL.md` (step 1, step 5), `skills/nkp-platform-apps-gitops/references/catalogs.md` (K1, K4, K5), `skills/nkp-upgrade/SKILL.md` (step 2 gates G5 and G6), `skills/nkp-upgrade/references/stopped.md` (S1, S2, S4).

**What stopped** [pdf p.1018][live 2.19.0]

- That text is gate **G5**: the Kommander upgrade checks for "deprecated GitRepository-based catalog apps" and stops before it changes anything. This is a preflight check, not a broken upgrade.
- 2.19 has only the `kommander-flux/management` GitRepository. Any other GitRepository that is a catalog (`kommander.d2iq.io/gitrepository-type: catalog`) blocks it. [field]
- **NKP Insights is not that.** `nkp-insights` is a platform app (ClusterApp). It does not use a Git catalog and it does not trip G5.
- But `nkp-insights` **is** gate **G6**: the same upgrade checks that `cloudnative-pg` is enabled in the workspace where NKP Insights runs. Insights needs `kube-prometheus-stack` and `cloudnative-pg`. [pdf p.1018, p.295-296] So do both checks now, before you run the upgrade again.

**Step 1 — find the Git catalogs (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get gitrepositories -A --show-labels | grep -v -E '^kommander-flux +management '
kubectl --kubeconfig "$MGMT_KUBECONFIG" get apps -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,SOURCE-KIND:.spec.sourceRef.kind,SOURCE:.spec.sourceRef.name' | grep -E 'NS|GitRepository'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,APP:.spec.appRef.name,KIND:.spec.appRef.kind' | grep -E 'NS| App$'
```

- No rows after the header lines: **G5 passes**. The stopping check saw something else (or it saw a row that is now gone). Go back to skill `nkp-upgrade`.
- Rows: an `App` whose `SOURCE-KIND` is `GitRepository`, plus an AppDeployment that uses it. That app must move to an OCI catalog.

**Step 2 — gate G6 for the prod workspace (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,APP:.spec.appRef.name' | grep -E 'NS|cloudnative-pg|ai-navigator|nkp-insights|harbor'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|cloudnative-pg'
```

For the namespace that has `nkp-insights` there must be a `cloudnative-pg` row in the **same** namespace. If there is not, enable it there before the upgrade (skill `nkp-platform-apps-gitops`, step 2: `name=cloudnative-pg`, `app` = the ClusterApp name from the second command). It needs Pro or Ultimate. [live 2.19.0]

**Step 3 — the three choices for each Git catalog (we pick one, together)**

| Choice | What happens | Cost |
|---|---|---|
| A. The same app is in an OCI catalog (NKP, partner, product) | Add that OCI catalog to the same workspace/project (K2), then move the AppDeployment to the OCI `App` | clean, recommended |
| B. Your own Git catalog | Rebuild it as an OCI catalog: `nkp generate catalog-repository`, `nkp validate catalog-repository`, `nkp create catalog-bundle`, push it, then K2. The old layout `helm-repositories/`, `services/<app>/<version>/` does not work; the 2.19 layout is `applications/<app>/<version>/` | the most work |
| C. Keep it for now | Run the upgrade with `--allow-gitrepository-catalog-apps`, which skips the check | the apps stay on a deprecated catalog; I record the decision |

**Facts you must have before you choose** [pdf p.357, p.1018]

- I do **not** delete the old Git catalog or the AppDeployment while UNKNOWN (P-30) is open: the skills do not confirm whether Kommander moves an AppDeployment to an OCI `App` with the same name without a reinstall. An app keeps its data only if the HelmRelease name and namespace stay the same. Test the move on a test workspace first.
- Option C is a decision that you record. I do not pass `--allow-gitrepository-catalog-apps` for you.

**Questions I would ask**

1. Which apps do you actually use from a Git catalog, and are they NKP apps, partner apps, or your own charts?
2. For option C: do you accept that those apps stay on a deprecated catalog and must move before the next upgrade?
3. Is `cloudnative-pg` already in the prod workspace (for NKP Insights)? If not, may I show the enable plan for it now (it must be Ready **before** the upgrade)?

No CHANGES block in this reply. The next block is either the OCI catalog add (K2 plan) or the `cloudnative-pg` enable plan (step 2 plan), and both stop for "yes".

---

## nkp-platform-apps-gitops G5

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-platform-apps-gitops/SKILL.md` (step 1, step 2 "Disable"), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1: how values are merged).

**First, the rule:** "just run it" is not "yes". A delete is CHANGES. I show the command, the target, and the result, and I run it only after you type **yes**. That is also why this reply has no delete yet.

**Facts you must accept first** [live 2.19.0][pdf p.280, p.532-533]

- Deleting the AppDeployment deletes the app on **every cluster of that workspace**, not only on the management cluster.
- Velero's data goes with it: the backups in the object store are no longer managed, and the PVCs of the app can be lost. If your only BSL is the in-cluster Rook Ceph `dkp-object-store`, the backups are on the cluster that Velero runs on.
- Velero is also the only path in the skills to restore a management cluster (disaster recovery). Without Velero there is no DR step.
- `kommander-flux`, `reloader`, and `traefik` are foundational: never disable them. Velero is not foundational, so it can go.

**Step 1 — check that nothing needs Velero (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps -o custom-columns='NAME:.metadata.name,LICENSE:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing,SCOPE:.metadata.annotations.apps\.kommander\.d2iq\.io/scope,NEEDS:.metadata.annotations.apps\.kommander\.d2iq\.io/dependencies' | grep -E 'NAME|velero'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments -o custom-columns='NAME:.metadata.name,APP:.spec.appRef.name,KIND:.spec.appRef.kind'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment velero -o jsonpath='app={.spec.appRef.name}{"\n"}override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get backups.velero,schedules.velero,backupstoragelocations.velero -A
```

- If the `NEEDS` column of another enabled app lists `velero`, stop: that app fails when Velero goes.
- `backups.velero -A` shows what exists. Read it before the delete, so you know what you give up.

**Step 2 — the plan, then stop for "yes" + the exact word**

- Target: management cluster, namespace `$WORKSPACE_NS` (`kommander-default-workspace` for the `dev-01` clusters), object `appdeployment/velero`.
- Result: NKP removes Velero from every cluster of that workspace. Its Deployment, its schedules, and its AppDeployment override ConfigMap usage go away. Existing backup files in the object store stay as files, but nothing restores them. App PVCs of Velero can be lost.
- It does **not** delete Rook Ceph (`rook-ceph`, `rook-ceph-cluster`), Loki, Harbor, or the management cluster DR ability on other clusters.

```bash
# CHANGES  (deletes the AppDeployment; NKP removes Velero from all clusters of the workspace)
source ~/nkp-dev-01.env 2>/dev/null
name='velero'; : "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete appdeployment "$name"
```

**Step 3 — check (READ-ONLY), after I run it**

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy -A | grep -E 'velero|NAMESPACE'
```

**Questions I would ask**

1. `dev-01` is a workload cluster. Is the workspace of this Velero really `kommander-default-workspace`? I read `WORKSPACE_NS` from `~/nkp-dev-01.env`, and I do not guess it.
2. Are there backups that you still need from this Velero? If yes, take a copy out of the object store first, or keep Velero and only remove its schedule.
3. Do you also want Rook Ceph removed? That is a different, larger delete (`rook-ceph-cluster` first, then `rook-ceph`, data lost; `references/object-storage.md` O4) and Loki, Harbor, and OpenCost use it. I do not touch it in this reply.

---

## nkp-platform-apps-gitops G6

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md` (license tiers), `skills/nkp-platform-apps-gitops/SKILL.md` (step 5), `skills/nkp-platform-apps-gitops/references/project-cd.md` (P1-P5), `skills/nkp-identity-security/SKILL.md` (license tiers, External Secrets), `skills/nkp-airgap/references/prestage.md` (P2, P3, "Use an asset"), `skills/nkp-airgap/assets/download-urls.txt` (listed).

**The pieces you need** (Ultimate, air-gapped, GitLab, secrets in Git)

1. **Ultimate** gives Projects and "Continuous Deployment (FluxCD)". [pdf p.27] You have it.
2. **A project** `shop` that exists on the management cluster. Its namespace is `<name>` + 5 random characters unless it was set. The namespace exists on the management cluster and on every cluster of the project.
3. **A Git credential secret** in the project (UI: project → Secrets). Keys for HTTPS: `username`, `password` (the token goes in `password`; GitLab also needs the username). Self-signed GitLab CA: add `caFile`. SSH: `identity`, `identity.pub`, `known_hosts`, and the URL must be `ssh://user@host:port/org/repo` (the `git@host:org/repo` form does not work). [pdf p.394] I never see these values.
4. **A GitOps source** (`GitopsRepository`) in the project namespace: ID, clone URL, branch, path (for example `./kustomize`), secret. Flux puts a `GitRepository` and a `Kustomization` with that name in the project namespace of **each** project cluster. [pdf p.392-395]
5. **Sealed Secrets**, because NKP does not ship it: controller v0.18.1 + the `kubeseal` CLI of the **same** version, and on an air-gapped site both come from outside the bundle. [pdf p.389]

**What your Git repository may and may not hold** [pdf p.396][live 2.19.0]

- Only namespaced objects in the project namespace. No `Namespace`, `ClusterRole`, `ClusterRoleBinding`.
- Every `HelmRelease` and every `Kustomization` in the repository sets `spec.serviceAccountName: <project name>`. Gatekeeper denies it otherwise (constraints `helmrelease-must-have-sa`, `kustomization-must-have-sa`).
- A deleted GitOps source removes every object that it applied.
- A sealed secret is cluster specific: each controller makes its own key. For a project with several clusters, seal once **for each** cluster, or give all clusters the same key.

**Step 1 — read the state (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get projects -o custom-columns='NAME:.metadata.name,NAMESPACE:.status.namespaceRef.name,CLUSTERS:.spec.placement'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get gitopsrepositories -A
command -v kubeseal || echo "no kubeseal"
```

`~/nkp-<cluster>.env`: **I need the cluster name** to replace `<cluster>`. This work is on the management cluster, so it is your management cluster env file — tell me its name.

**Step 2 — the air-gap files (USER-TERMINAL on the connected host, and the asset check)**

The `kubeseal` tarball and its SHA-256 are in `assets/download-urls.txt`. The controller manifest is `assets/sealed-secrets-controller-v0.18.1.yaml`. The controller image must go into your registry mirror:

```bash
# USER-TERMINAL  (connected host; the user runs it. Writes sealed-secrets-images.txt and sealed-secrets-v0.18.1.tar)
echo 'docker.io/bitnami/sealed-secrets-controller:v0.18.1' > sealed-secrets-images.txt
nkp create bundle --images-file sealed-secrets-images.txt --output-file sealed-secrets-v0.18.1.tar
```

Then, on the operator host, the asset check. `dir` is the absolute path of the `nkp-airgap` skill folder:

```bash
# READ-ONLY
dir=''; : "${dir:?}"
for f in "$dir"/assets/*.yaml; do want="$(sed -n 's/^# Body SHA-256: //p' "$f")"; got="$(grep -v '^# ' "$f" | sha256sum | cut -d' ' -f1)"; [ "$want" = "$got" ] && echo "OK $f" || echo "FAILED $f"; done
```

Every line must say `OK`. If one says `FAILED`, stop.

**Step 3 — install `kubeseal` on the operator host (CHANGES, plan + "yes")**

```bash
# READ-ONLY
tgz=''; : "${tgz:?}"
tar -tzf "$tgz"
```

If the list has `kubeseal`:

```bash
# CHANGES  (extracts kubeseal and installs it to /usr/local/bin on the operator host)
tgz=''; : "${tgz:?}"
d=$(mktemp -d) && tar -xzf "$tgz" -C "$d" kubeseal && sudo install -m 755 "$d/kubeseal" /usr/local/bin/kubeseal && rm -r "$d"
kubeseal --version
```

Target: this host, `/usr/local/bin/kubeseal`. Result: the v0.18.1 CLI, matching the controller.

**Step 4 — install the controller on each project cluster (CHANGES, plan + "yes")**

Target: one cluster of project `shop`; namespace `kube-system`; a CRD, RBAC, and a Deployment. Result: the controller runs and can decrypt SealedSecrets. `ImagePullBackOff` means the image is not in the mirror (skill `nkp-airgap`).

```bash
# CHANGES  (installs the Sealed Secrets controller v0.18.1 in kube-system)
source ~/nkp-<cluster>.env 2>/dev/null
dir=''; : "${dir:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$dir/assets/sealed-secrets-controller-v0.18.1.yaml"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system rollout status deploy/sealed-secrets-controller --timeout 5m
```

Run it once for **each** project cluster.

**Step 5 — the certificate, then seal (CHANGES file, then USER-TERMINAL)**

```bash
# CHANGES  (writes the public sealing certificate to a local file)
source ~/nkp-<cluster>.env 2>/dev/null
KUBECONFIG="$CLUSTER_KUBECONFIG" kubeseal --fetch-cert > "$PWD/$CLUSTER_NAME-sealed-secrets.pem"
```

The PEM is public: you can commit it. Sealing is USER-TERMINAL, because it reads a secret value from a file that you make with mode 600:

```bash
# USER-TERMINAL  (the user runs it; it reads a secret value from a file)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; key=''; valuefile=''; : "${name:?}" "${key:?}" "${valuefile:?}" "${PROJECT_NS:?}"
echo '---' >> secrets.yaml
kubectl create secret -n "$PROJECT_NS" generic "$name" --dry-run=client -o yaml --from-file="$key=$valuefile" | kubeseal --format yaml --cert "$PWD/$CLUSTER_NAME-sealed-secrets.pem" >> secrets.yaml
```

Then remove the `creationTimestamp` lines from the new entry, delete the value file, and commit `secrets.yaml` to the Git repository of the GitOps source. Flux applies it.

**Step 6 — the GitOps source (CHANGES, plan + "yes"; after you give the values)**

```bash
# CHANGES  (writes the GitOps source file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; url=''; branch=''; path=''; secret=''
: "${name:?}" "${url:?}" "${branch:?}" "${path:?}" "${PROJECT_NS:?}"
f="$PWD/$CLUSTER_NAME-gitops-$name.yaml"
printf 'apiVersion: dispatch.d2iq.io/v1alpha2\nkind: GitopsRepository\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  cloneUrl: %s\n  template:\n    path: %s\n    ref:\n      branch: %s\n' "$name" "$PROJECT_NS" "$url" "$path" "$branch" > "$f"
[ -n "$secret" ] && printf '  secret: %s\n' "$secret" >> "$f"; cat "$f"
```

Preview, then apply after "yes":

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-gitops-$name.yaml"
```

```bash
# CHANGES  (creates the GitOps source; Flux deploys the repository to all project clusters)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-gitops-$name.yaml"
```

UNKNOWN (P-32): whether a `GitopsRepository` created from `kubectl` with `v1alpha2` behaves like one from the UI (storage version `v1alpha3`). The UI is the safe path. If the apply gives an error, stop and show me the message; I do not change the API version without you.

**Step 7 — check (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$PROJECT_NS" describe gitopsrepositories.dispatch.d2iq.io "$name" | sed -n '/^Events:/,$p'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$PROJECT_NS" get gitrepositories,kustomizations,helmreleases
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$PROJECT_NS" get sealedsecrets
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$PROJECT_NS" get secret
```

Done when the `ManifestSyncSuccess` event shows on the management cluster, the `GitRepository` and `Kustomization` are READY on each project cluster, and each SealedSecret has made its Secret.

**Error → cause** [pdf p.394-396]

| Message | Fix |
|---|---|
| `authentication required`, `401`, `403` | the project secret keys |
| `x509` | add `caFile` to the project secret (your GitLab CA) |
| `ssh: handshake failed` | the SSH keys/`known_hosts`, or the URL form |
| `forbidden`, `cannot create resource ... at the cluster scope` | a cluster-scoped object is in Git |
| `must-have-sa` | add `spec.serviceAccountName` in Git |

**Back up the sealing keys.** If a cluster is lost, the sealed secrets in Git cannot be decrypted. The file holds private keys, so you run it and keep it in a vault:

```bash
# USER-TERMINAL  (the user runs it; it writes the private sealing keys to a file)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get secret -o name | grep sealed-secrets-key | xargs kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get -o yaml > sealing-key.yaml)
```

**Questions I would ask**

1. Which cluster env file do I use? (I keep `~/nkp-<cluster>.env` until you name it.) And which workspace holds project `shop`?
2. How many clusters does project `shop` have? One sealed secret per cluster certificate, or one shared key. Which do you want?
3. GitLab over HTTPS with a private CA, or SSH? That decides the secret keys.
4. Is `kubeseal` and the controller tarball already inside the air gap, or must we start with the connected host?

Not covered: External Secrets (Vault or a Kubernetes store inside the air gap) is the other way to keep secrets out of Git (skill `nkp-identity-security`). Say so if you prefer it.

---

## nkp-platform-apps-gitops G7

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md` ("Find versions without the release notes"), `skills/nkp-platform-apps-gitops/SKILL.md` (step 5), `skills/nkp-troubleshooting/references/flux.md` (the chain table).

**Answer: not in the skills.** The skills give the Flux chart and image versions for 2.19.0 (chart `flux2` 2.18.3; helm-controller image v1.5.4, in `kommander-flux`) [live 2.19.0], but they do not state any CPU or memory request/limit for the helm-controller pod. I will not make up a number.

**READ-ONLY check on your cluster (the real value):**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander-flux get deploy helm-controller -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\t"}limits={.resources.limits}{"\t"}requests={.resources.requests}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander-flux get helmreleases -o custom-columns='NAME:.metadata.name,CHART:.spec.chart.spec.version,FROM:.spec.valuesFrom[*].name'
```

Replace `<cluster>` with the cluster name: **I need it** (management cluster or workload cluster — the pod runs on every cluster).

- The second command shows the `kommander-flux` HelmRelease and its `valuesFrom`. If a `<...>-config-defaults` ConfigMap is listed, the default resources are in its `values.yaml`:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns='kommander-flux'; cm=''; : "${ns:?}" "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get configmap "$cm" -o jsonpath='{.data.values\.yaml}' | grep -n -A4 -iE 'helmController|helm-controller|resources'
```

- To change it, use an AppDeployment override (skill `nkp-platform-apps-gitops`, overrides.md O3). Do not edit the Deployment or the defaults ConfigMap: NKP applies them again.

If you need the released default for a design decision (not for this cluster), it is in the upstream `flux2` chart 2.18.3 values — that file is not in the skills and I am offline, so I cannot quote it.

---

## nkp-storage-backup S1

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-storage-backup/SKILL.md` (step 1, step 2, "Common failures"), `skills/nkp-storage-backup/references/csi.md` (C2, C3, C7, C8, C11).

**What it means:** the pod cannot start because its PVC is not `Bound`. The PVC `data-pg-0` (namespace `db`) on `app-01` is `Pending`. I do not guess the cause: `describe pvc` and the events give it. [live 2.19.0]

I use `~/nkp-app-01.env` for cluster `app-01`. If your file has another name, tell me.

**Step 1 — read the storage state (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,CLAIM:.spec.claimRef.name,NS:.spec.claimRef.namespace,SC:.spec.storageClassName,STATUS:.status.phase,HANDLE:.spec.csi.volumeHandle'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n db get pod -o wide
```

On a default AHV cluster you see `nutanix-volume (default)`, provisioner `csi.nutanix.com`, one CSIDriver, and in `ntnx-system` 2 `nutanix-csi-controller` pods (8/8) plus one `nutanix-csi-node` pod (3/3) on each node. [live 2.19.0]

**Step 2 — read the PVC and the provisioner (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='db'; pvc='data-pg-0'
: "${ns:?}" "${pvc:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe pvc "$pvc"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get events --field-selector "involvedObject.name=$pvc" --sort-by=.lastTimestamp
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system logs deploy/nutanix-csi-controller -c csi-provisioner --tail=50
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system logs deploy/nutanix-csi-controller -c nutanix-csi-plugin --tail=50
```

**Step 3 — the row that matches your output**

| What `describe pvc` shows | Cause | Fix |
|---|---|---|
| `waiting for first consumer to be created before binding` | Normal for `WaitForFirstConsumer`; no pod uses the PVC yet. The pod is also `Pending` for another reason (node selector, taints, resources, unschedulable) | `kubectl describe pod` in `db` (skill `kubernetes-core`, not installed here) |
| No StorageClass on the PVC, no event | No default StorageClass | skill step 3: patch one class to default |
| `storageclass ... not found` | The PVC names a class that does not exist | the PVC class cannot change: make the class (C2) or delete and make the PVC again (data loss, your decision) |
| Provisioning errors from `csi.nutanix.com` (credentials, storage container, Prism Central) | CSI cannot reach Prism Central, or the container name is wrong | `references/csi.md` C11 (credentials/endpoint); check the container in the class |
| The pod runs on a Metal node of a mixed cluster | The class gives hypervisor-attached volumes, which Metal nodes cannot get | `references/csi.md` C3 (`nutanix-volume-metal`) |
| `localvolumeprovisioner`, no free PV | No disk under `/mnt/disks` on a node | C9 |
| CSI pods not `Running` | The driver is down | C8 (new node: `nutanix-csi-node` not registered) |

**Questions I would ask**

1. Give me the `describe pvc` **Events** section and the `STATUS` and `EVENTS` lines of the pod. Those two lines choose the row above.
2. Is `app-01` a mixed cluster (AHV VMs plus a Metal node pool)? If yes, and the postgres pod runs on a Metal node, the class is the cause.
3. Is `data-pg-0` newly made, or did it bind before? A PVC that bound before and now shows `Pending` is a different failure (node or CSI, not provisioning).

No CHANGES block: the fix follows from the row, and I show it with the plan after I see your output. Nothing here changes the cluster.

Not checked: whether `data-pg-0` belongs to a Postgres operator (CloudNativePG). If it does, the operator also has its own events; that does not change the CSI diagnosis above.

---

## nkp-storage-backup S2

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-storage-backup/SKILL.md` (step 1, step 2, step 3), `skills/nkp-storage-backup/references/csi.md` (C2, C3, C7, C8).

**Why it happens** [pdf p.750, p.754]

- On a mixed cluster the default class `nutanix-volume` uses `hypervisorAttached: ENABLED`: the disk attaches through AHV. A Metal node has no hypervisor, so it cannot get that volume. The pod stays `Pending` and the PVC stays `Pending`.
- The fix is a second StorageClass for the Metal pool, `nutanix-volume-metal`, with `prismElementRef` (the Prism Element UUID) and `storageContainer` of that pool, plus `storageType: NutanixVolumes`. On Metal hosts the volume traffic goes straight to Prism Element.
- The class must **not** be the default: the VM nodes need `nutanix-volume`.
- A PVC cannot change its class. Existing PVCs on the Metal nodes must be made again with `storageClassName: nutanix-volume-metal` (data loss — your decision).
- The workload also needs a node selector or toleration for the Metal pool (skill `nkp-cluster-lifecycle`, Metal pools).

**Questions I need answered before I write the file** (rule 4 — I never guess these)

1. `PE_UUID`: the UUID of the Prism Element cluster that holds the Metal pool volumes. You read it in Prism Central. It goes into `~/nkp-gpu-01.env` as `PE_UUID`.
2. `METAL_STORAGE_CONTAINER`: the storage container for that pool (it can be the same as `STORAGE_CONTAINER`). It goes in as `METAL_STORAGE_CONTAINER`.
3. Which PVCs are on the Metal nodes now? They cannot be re-classed; we plan their recreation.

I would use `~/nkp-gpu-01.env` for cluster `gpu-01`. Tell me if the name differs.

**Step 1 — read the state first (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-gpu-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass -o custom-columns='NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class,PROVISIONER:.provisioner,BINDING:.volumeBindingMode,EXPAND:.allowVolumeExpansion'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A -o wide
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}csi={.value.addons.csi}{"\n"}{end}'
```

**Step 2 — the values come first.** When you give me `PE_UUID` and `METAL_STORAGE_CONTAINER`, I append one line for each to `~/nkp-gpu-01.env` (CHANGES) and show the block with your real values in that reply. I show no append block before that: no guessed and no empty value goes into the file.

**Step 3 — write the class file and dry run (CHANGES file, then READ-ONLY)**

```bash
# CHANGES  (writes the StorageClass file on the operator host; changes no cluster)
source ~/nkp-gpu-01.env 2>/dev/null
: "${PE_UUID:?}" "${METAL_STORAGE_CONTAINER:?}"
cat > "$HOME/nkp-$CLUSTER_NAME-sc-metal.yaml" <<EOF
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nutanix-volume-metal
parameters:
  csi.storage.k8s.io/controller-expand-secret-name: nutanix-csi-credentials
  csi.storage.k8s.io/controller-expand-secret-namespace: ntnx-system
  csi.storage.k8s.io/fstype: xfs
  csi.storage.k8s.io/node-publish-secret-name: nutanix-csi-credentials
  csi.storage.k8s.io/node-publish-secret-namespace: ntnx-system
  csi.storage.k8s.io/provisioner-secret-name: nutanix-csi-credentials
  csi.storage.k8s.io/provisioner-secret-namespace: ntnx-system
  fileSystem: ext4
  prismElementRef: $PE_UUID
  storageContainer: $METAL_STORAGE_CONTAINER
  storageType: NutanixVolumes
provisioner: csi.nutanix.com
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$HOME/nkp-$CLUSTER_NAME-sc-metal.yaml"
```

- The server dry run **does not check** the UUID or the container. We check both values with you before the apply. [live 2.19.0]
- UNKNOWN (D-22): which file system the Metal volumes get. The guide form above has both `csi.storage.k8s.io/fstype: xfs` and `fileSystem: ext4`. Find out with: `source ~/nkp-gpu-01.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns=NAME:.metadata.name,SC:.spec.storageClassName,FS:.spec.csi.fsType` after the first Metal PVC. I do not change the guide form without you.

**Step 4 — the plan. Stop for "yes".**

- Target: cluster `gpu-01`. It creates StorageClass `nutanix-volume-metal`. It is **not** the default.
- Result: a PVC with `storageClassName: nutanix-volume-metal` on a Metal node binds. Nothing else changes; the VM nodes keep `nutanix-volume`.

```bash
# CHANGES  (creates StorageClass nutanix-volume-metal on the cluster)
source ~/nkp-gpu-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$HOME/nkp-$CLUSTER_NAME-sc-metal.yaml"
```

Done when `get storageclass nutanix-volume-metal` shows the class and a test PVC on a Metal node is `Bound`.

**After that (you or the app owner does it)**

- Set `storageClassName: nutanix-volume-metal` in the PVC of every workload on the Metal pool, and a node selector or toleration for that pool.
- Make the PVCs again. The old ones cannot move to the new class.
- If a Metal volume does not detach during a node delete, that is C7 (`deletion.nodeVolumeDetachTimeoutSeconds`). Ask me before you touch a `VolumeAttachment`.

---

## nkp-storage-backup S3

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-storage-backup/SKILL.md` (the storage parts table, step 1), `skills/nkp-storage-backup/references/velero.md` (Facts, B1, B2, B3, B4), `skills/nkp-storage-backup/references/object-storage.md` (Facts), `skills/nkp-upgrade/SKILL.md` (step 2, the optional backup).

**Three facts before we start** [live 2.19.0][pdf p.510, p.532-535]

1. Velero is a **Pro or Ultimate** app. On Starter it is not there and we stop.
2. The default backup storage is the bucket `dkp-velero` in the Rook Ceph of **the same cluster**. If `mgmt-01` is lost, the backups are lost. Nutanix recommends an external S3 store (Nutanix Objects, AWS S3). For a real pre-upgrade safety net this matters — see the last section.
3. A Velero restore works **only into the same cluster and the same NKP version**. A backup taken on 2.18 cannot be restored into the upgraded 2.19 management cluster. So this backup protects against a *failed change*, not against the version change itself. If you need the second thing, the DR path is `velero.md` B7 into a standby management cluster.

Also: the `velero` CLI is **not** in the NKP bundle. Without it I use only the `kubectl` blocks below.

I use `~/nkp-mgmt-01.env` for cluster `mgmt-01`. Tell me if the file name differs.

**B1 — find Velero (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get deploy,ds -A -l app.kubernetes.io/name=velero
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get appdeployment velero -o jsonpath='{.spec.appRef.name}{"\t"}{.spec.configOverrides.name}{"\n"}'
command -v velero || echo "no velero CLI"
```

On a management cluster Velero runs in `kommander`, not `velero`. [pdf p.532] So `VELERO_NS=kommander`.

**B2 — state, locations, schedules (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get backupstoragelocations.velero,volumesnapshotlocations.velero
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get schedules.velero,backups.velero,restores.velero
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get pods | grep -E 'velero|node-agent'
```

- Every BSL must show PHASE `Available`. If not, that is the first problem (`velero.md` B9); a backup does not start on an unavailable BSL.
- Set `BSL_NAME` to the BSL that shows DEFAULT `true` (often `default`). I ask you to confirm it before I write it into the env file.
- The default schedule `velero-default` does a daily backup of all namespaces with **no volume snapshots**. [pdf p.533]

**The backup. Plan, then stop for "yes".**

- Target: cluster `mgmt-01`, namespace of Velero (`kommander`), BackupStorageLocation `$BSL_NAME`.
- Result: Velero writes one backup of **all namespaces** with a name I set after you confirm it (for example `pre-upgrade-2-19`; I do not invent it), `--snapshot-volumes=false`.
- What it contains: the Kubernetes objects. **Not the data inside PVCs.** For volume data you need the file system backup (`velero.md` B5) first.
- Runtime: it waits (`--wait`) until the backup finishes.

```bash
# CHANGES  (Velero writes a backup of all namespaces to the BSL)
source ~/nkp-mgmt-01.env 2>/dev/null
name=''; : "${name:?}" "${VELERO_NS:?}" "${BSL_NAME:?}"
velero backup create "$name" -n "$VELERO_NS" --kubeconfig "$CLUSTER_KUBECONFIG" --storage-location "$BSL_NAME" --snapshot-volumes=false --wait
```

Without the CLI, the object form is the equivalent (CHANGES, same plan and same "yes"):

```bash
# CHANGES  (creates one backup object; Velero runs the backup now)
source ~/nkp-mgmt-01.env 2>/dev/null
name=''; : "${name:?}" "${BSL_NAME:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: $name
spec:
  storageLocation: $BSL_NAME
  snapshotVolumes: false
EOF
```

**Check (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get backups.velero "$name" -o jsonpath='{.status.phase}{" errors="}{.status.errors}{" warnings="}{.status.warnings}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander logs -l name=velero --tail=200
```

Done when the phase is `Completed` with 0 errors. `PartiallyFailed`: read the log, and I tell you what failed before anything else happens with the upgrade.

**Questions I would ask**

1. The backup name — give it to me (I do not choose one for you).
2. Which BSL is DEFAULT in the step B2 output? I write `VENLERO_NS=kommander` and that `BSL_NAME` into `~/nkp-mgmt-01.env` in a later reply, after you confirm.
3. Do you need the PVC data too (a file system backup needs the node agent and pod annotations), or only the objects?
4. Is the goal "undo a bad upgrade step on 2.18" or "survive the loss of the management cluster"? The second one needs an external bucket (B4) and/or the B7 DR procedure. The in-cluster Ceph bucket does not survive the cluster.

After your confirmation I append `VELERO_NS` and `BSL_NAME` to `~/nkp-mgmt-01.env` (CHANGES, two lines, in that later reply). I show no append block now: the BSL name is not confirmed yet, and a guessed value does not go into the file.

---

## nkp-storage-backup S4

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-storage-backup/SKILL.md` (step 3), `skills/nkp-storage-backup/references/csi.md` (C2, D-20).

**"Just run it, no need to ask" is not "yes".** A StorageClass change is CHANGES. I show the command, the target, and the result, and I run it after you type **yes**. Two other things also stop me now:

1. **The cluster is not named.** I keep `~/nkp-<cluster>.env` in the blocks and I ask you for the name. I do not take a name from another conversation.
2. **I must see that `fast-ssd` exists and that `nutanix-volume` is the current default.** A patch of a class that does not exist fails; and if I set a wrong class to default, new PVCs with no class go to the wrong place.

**Facts** [live 2.19.0][pdf p.942]

- Exactly one StorageClass must be `(default)`. Kommander needs one default before its install.
- With two defaults, the **newest** class wins for a PVC with no class. That is why the old one must be unset, not just the new one set.
- Existing PVCs keep their class. Only new PVCs without a class change.
- UNKNOWN (D-21): whether CAREN puts the default annotation back on `nutanix-volume` at the next cluster reconcile or upgrade. Check with `kubectl get storageclass` after the next upgrade. If it does, we set the default in the NKPCluster `clusterConfig.addons.csi.defaultStorage.storageClassConfig` too (`references/csi.md` C2), which is a second, larger change.

**Step 1 — read the classes (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass -o custom-columns='NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class,PROVISIONER:.provisioner,BINDING:.volumeBindingMode,EXPAND:.allowVolumeExpansion'
```

Show me that output. It must contain `fast-ssd` with provisioner `csi.nutanix.com` (or the class you mean), and one `true` on `nutanix-volume`.

If `fast-ssd` is **not** there yet, we make the class first (`references/csi.md` C2: a new key in `storageClassConfigs` of the NKPCluster, or a plain `kubectl apply` class file). A default annotation on a class that does not exist is impossible.

**Step 2 — the plan. Stop for "yes".**

- Target: the cluster in your env file.
- Result: `nutanix-volume` loses the default annotation; `fast-ssd` gets it. New PVCs with no `storageClassName` use `fast-ssd`. Existing PVCs do not move. No pod restarts.
- Risk: every new PVC without a class changes its volume type. If any tool assumes `nutanix-volume` by default, it gets `fast-ssd` now.

```bash
# CHANGES  (moves the default StorageClass annotation; new PVCs with no class use the new class)
source ~/nkp-<cluster>.env 2>/dev/null
old='nutanix-volume'; new='fast-ssd'
: "${new:?}"
[ -n "$old" ] && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" patch storageclass "$old" -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" patch storageclass "$new" -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

The annotation patch passes a server dry run on `nutanix-volume`. [live 2.19.0] I run it only after "yes".

**Step 3 — check (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass -o custom-columns='NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class,PROVISIONER:.provisioner'
```

Done when exactly one line shows `true`, on `fast-ssd`.

**Questions I would ask (short)**

1. The cluster name (I keep `~/nkp-<cluster>.env` until then).
2. Is `fast-ssd` already created, or do we make it first?

---

## nkp-storage-backup S5

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-storage-backup/SKILL.md` (the storage parts table), `skills/nkp-storage-backup/references/csi.md` (C10, C11), `skills/nkp-cluster-lifecycle/references/delete.md` (D5).

**The honest answer:** probably yes, some volumes can still be in Prism Central, but I cannot list them for you, and there is a limit on what I can tell you from the cluster side.

- UNKNOWN (P-11): whether `nkp delete cluster` on AHV leaves the Nutanix CSI volume groups (and other Prism Central objects). The skills do not confirm it. The guide only says that PVs stay on AWS after a delete. [pdf p.833]
- **I have no Prism Central command.** The lookup is in Prism Central, by you. [live 2.19.0]
- A PV that is `Retain` (or a class with `--csi-reclaim-policy Retain`) keeps its volume group when the PVC goes. A `Delete` class removes it. The default AHV class `nutanix-volume` is `Delete`.
- `nutanix-snapshot-class` has `deletionPolicy: Retain`, so snapshots of the deleted cluster can stay in Prism Central too.
- If the cluster was deleted with the default `Delete` policy, most volume groups are probably already gone. The recovery points (snapshots) are the more likely leftovers.

**Step 1 — what the operator host still has (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get kommanderclusters -A
```

- `test-07` gone from both lists: the delete completed. 
- `test-07` still in one list (for example `Error`): the objects remain, and the cleanup did not finish (`delete.md` D3). Then some Prism Central objects certainly remain, because the finalizers did not run.

**Step 2 — can I still read the PVs? Only if the old kubeconfig still answers.** A deleted cluster's API server is gone, so normally no:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='HANDLE:.spec.csi.volumeHandle,RECLAIM:.spec.persistentVolumeReclaimPolicy,CLAIM:.spec.claimRef.namespace,PVC:.spec.claimRef.name'
```

Keep `~/nkp-<cluster>.env` with `<cluster>`: you deleted `test-07`, but the env file and the kubeconfig of that cluster are host files. If the file `~/nkp-test-07.env` still exists, replacing `<cluster>` with `test-07` is correct — say the word and I use it. Without the file, I cannot show that block, and without the cluster I cannot read the PVs.

**Step 3 — what you do in Prism Central**

- Search the volume groups for the **UUIDs** of the saved PV handles (`NutanixVolumes-<uuid>`; the uuid is the volume group). If you saved the list before the delete, this is exact.
- If you did **not** save the list: search by the **cluster name**. The volume group description has the form `CSI StorageClass ... PVC:<pvc>, NS:<namespace>` and names the cluster. [live 2.19.0]
- Check the **recovery points** (snapshots) as well: `nutanix-snapshot-class` keeps them (`deletionPolicy: Retain`).
- The NKP Prism Central role has "Detach Volume Group From AHV VM". [pdf p.706] A leftover volume group is not attached to a VM any more (the VMs are gone), so a detach is usually not needed.

**Do not delete anything yet.** Check first, and tell me what you find. Data in a deleted volume group is gone.

**Questions I would ask**

1. Do you have the PV/volume-group UUID list from before the delete (it was a READ-ONLY step of `delete.md` D5)? Where is it?
2. Did `test-07` use the default `nutanix-volume` class (`Delete`) or a class with `Retain`?
3. Was the delete `nkp delete cluster` from the CLI, or the UI? Did it finish without an `Error` cluster in the UI?

---

## nkp-storage-backup S6

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-storage-backup/SKILL.md` (SKILL step 1, "Common failures"), `skills/nkp-storage-backup/references/object-storage.md` (Facts, O1, O2), `skills/nkp-storage-backup/references/csi.md` (C4).

**The cluster is not named.** I keep `~/nkp-<cluster>.env` in the blocks and I need the name before I touch anything.

**Two different caps, and that is the whole answer** [pdf p.649-654][live 2.19.0]

1. **The OSD size/count.** Default: 4 OSDs of 40 GiB = 160 GiB raw, erasure coding k=3 m=1, about **120 GiB usable**, one OSD may fail. That is your layout now.
2. **The bucket cap.** Each bucket has a `maxSize` in its ObjectBucketClaim. "Ceph is near full" can be the pool, but "Loki stopped writing" with free pool space is usually the **bucket cap**. More OSDs do not raise a bucket cap. [pdf p.653-654]

Also: `Loki` values are owned by skill `nkp-observability`, and **that skill is not installed here**. I can do the Ceph side and the bucket cap; for a change to the Loki chart itself I give only the fact from `object-storage.md`: the cap key is `dkp.grafana-loki.additionalConfig.maxSize` in the override. Nothing more from a skill I do not have.

**O1 — measure first (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get cephclusters,cephobjectstores,objectbucketclaims -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get pods -l app=rook-ceph-osd -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph status
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph osd df
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph df
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph versions
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get sc -o custom-columns=NAME:.metadata.name,EXPAND:.allowVolumeExpansion
```

Read: `MAX AVAIL` of the pool `dkp-object-store.rgw.buckets.data` in `ceph df` (`ceph df` for usable space, `ceph osd df` for SIZE and WEIGHT per OSD), and `maxSize` of each ObjectBucketClaim. `ceph versions` must show **19.2.3 or later** if we grow the OSDs: on 19.2.1 and 19.2.2 the OSD crashes when its PVC grows. [pdf p.652]

**Then one of these, decided by those numbers**

| What the numbers show | Change | Field |
|---|---|---|
| Bucket `maxSize` reached, pool has space | raise the cap of that app's bucket (`dkp.grafana-loki.additionalConfig.maxSize` for Loki) | override ConfigMap |
| Pool nearly full, room on the nodes' disks, class expands | scale up: raise `volumeClaimTemplates` storage size in the OSD entry | `cephClusterSpec.storage.storageClassDeviceSets` |
| Pool nearly full, no room on disks | scale out: `count` 4 → 5 (at least 4 always) — each new OSD needs 250m CPU and 1 GiB memory and a PVC | same field |

**The rule for the override** [pdf p.651-652]

- Never edit the ConfigMap `rook-ceph-cluster-<version>-config-defaults`, never patch the `CephCluster` or the OSDs: NKP puts them back at reconcile and upgrade.
- Use the AppDeployment override `rook-ceph-cluster-config-overrides` (key `values.yaml`) in the workspace namespace, set in `spec.configOverrides.name` (per cluster: `clusterConfigOverrides`).
- **Copy the full `storageClassDeviceSets` entry** (name `rook-ceph-osd-set1`) from the defaults `values.yaml` and change only `count` or `storage`. Helm replaces a list: an entry with only `name` and `count` loses `volumeClaimTemplates` and the OSDs fail.

**Read the defaults to copy from (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment rook-ceph-cluster -o jsonpath='{.spec.appRef.name}{"\t"}{.spec.configOverrides.name}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get cm -o name | grep 'rook-ceph-cluster-.*-config-defaults'
```

Then read that ConfigMap's `values.yaml` and copy the `storageClassDeviceSets` entry into the override file (skill `nkp-platform-apps-gitops`, overrides.md O2/O3).

**After the OSDs grow (CHANGES, one OSD at a time, plan + "yes")** [pdf p.654]

The old weight stays at the 40 GiB value (0.03909) after a resize, so Ceph does not use the new space. Compare `SIZE` and `WEIGHT` in `ceph osd df`; weight is the size in TiB (250 GiB → 0.24409). Then, after the backfill:

```bash
# CHANGES  (sets the CRUSH weight of one OSD; data moves)
source ~/nkp-<cluster>.env 2>/dev/null
osd=''; weight=''
: "${osd:?}" "${weight:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph osd crush reweight "osd.$osd" "$weight"
```

This moves data. One OSD at a time, and I wait for `HEALTH_OK` between them.

**Questions I would ask**

1. The cluster name (I need `~/nkp-<cluster>.env`).
2. From O1: is the pool full, or is a bucket `maxSize` full? That decides "raise the cap" (minutes, safe) vs "grow Ceph" (hours, data movement).
3. How many worker nodes, and is there room for a fifth OSD PVC (250m CPU, 1 GiB, and a 40 GiB+ volume)?
4. Is `ceph versions` at 19.2.3 or later? If not, we do not grow the OSDs.

Done when O1 shows `HEALTH_OK` and the new `MAX AVAIL`, and Loki writes again. `HEALTH_WARN` during the rebalance is normal. [pdf p.654]

Not checked: the Loki chart values beyond `maxSize` (skill `nkp-observability` is not installed).

---

## nkp-storage-backup S7

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-storage-backup/SKILL.md` (step 1, step 3), `skills/nkp-storage-backup/references/csi.md` (C2, C4).

**Answer: not in the skills.** For two parts:

1. **The maximum IOPS of a `nutanix-volume` PVC:** not in the skills. The skills give no IOPS number for Nutanix Volumes through the CSI driver. That is a Nutanix platform/AHV limit, and it depends on the storage container, the flash mode, and the disk. I will not invent a number. Ask Nutanix (portal) or read the AOS/Prism limits for your version.
2. **A QoS/IOPS limit in the StorageClass:** not in the skills. The Nutanix StorageClass parameters that the skills document are: `storageType` (`NutanixVolumes` | `NutanixFiles`), `storageContainer`, `hypervisorAttached` (`ENABLED` | `DISABLED`), `flashMode` (`ENABLED` | `DISABLED`), `csi.storage.k8s.io/fstype` (`ext4` | `xfs`), and the six `csi.storage.k8s.io/*-secret-name` / `*-secret-namespace` keys. [pdf p.39, p.41][live 2.19.0] There is no IOPS or bandwidth key in that list. I do not know of one from the skills, and I do not add a key that a dry run would accept but the driver would ignore.

What the skills **do** give you: `flashMode: ENABLED` is the only storage-class knob for performance. It is a **parameter**, and StorageClass parameters are **immutable** ("field is immutable"). To change it, you make a new StorageClass; a new key in `clusterConfig.addons.csi.providers.nutanix.storageClassConfigs` gives the class `nutanix-<key>`. [live 2.19.0]

**READ-ONLY checks that answer the fact on your cluster**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass nutanix-volume -o yaml
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,SC:.spec.storageClassName,HANDLE:.spec.csi.volumeHandle'
```

- The first shows every parameter the driver accepts for your driver version (3.9.0). If no IOPS key is in it, the class cannot set one.
- The volume handle uuid is the volume group in Prism Central. The IOPS limit of that volume group is a Prism Central property, not a Kubernetes one (`csi.md` C7 describes that volume group and its description).

I need the cluster name to replace `<cluster>` in the block.

**Question I would ask:** is your goal a hard limit per volume (a platform-level policy in Prism Central) or more throughput (a `flashMode: ENABLED` class)? The second one I can do from the skills; the first one is outside them.

---

## nkp-storage-backup S8

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-storage-backup/SKILL.md` (the storage parts table), `skills/nkp-storage-backup/references/velero.md` (Facts, B1, B2, B4, B9), `skills/nkp-storage-backup/references/object-storage.md` (O5, COSI notes), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O3).

**First, a security fact, and I will not repeat the values:** the access key and the secret key are now in this chat. Put them into `~/nkp-site.env` **with an editor** (rule 5, I never write or echo a secret), and then **rotate them in Nutanix Objects** after the setup, because a chat is not a safe place for a key. From here I use only `OBJECTS_ACCESS_KEY` and `OBJECTS_SECRET_KEY`, and I check them with `printenv`, never by printing them.

**Facts** [pdf p.511-518]

- One bucket **per cluster**: `prod-02-velero` for `prod-02` only.
- The endpoint name must resolve **inside the cluster** (DNS from a pod). A private CA means the endpoint certificate is not in the pod's trust store, so we give Velero the CA (`caCert`), not `insecureSkipTLSVerify`.
- Velero is Pro/Ultimate. Its chart stays as it is; only an AppDeployment override changes it.
- Each BSL must show PHASE `Available` before any backup.
- The `velero` CLI may not be on this host (`command -v velero`); if it is missing I use the override path, which needs no CLI.

I use `~/nkp-prod-02.env` for cluster `prod-02`. Tell me if the name differs.

**Step 1 — what you give me, and what I append afterwards (rule 4)**

You already gave: `OBJECTS_URL=https://objects.example.local`, `OBJECTS_BUCKET=prod-02-velero`.

Still needed:

1. `BSL_NAME`: the guide often uses the bucket name. Confirm `prod-02-velero`, or give another name.
2. `OBJECTS_CA_FILE`: the **path of the PEM CA file of your private CA on this host**. Velero needs it base64-encoded in the override.
3. `VELERO_NS`: I read it from the cluster (below); you confirm it.

Because the URL and the bucket came from you, these two lines are ready to write (CHANGES, and I write them in the next reply, after you confirm the BSL name and the CA file):

```bash
# CHANGES  (adds the object store values to the cluster env file)
echo "export OBJECTS_URL='https://objects.example.local'" >> ~/nkp-prod-02.env
echo "export OBJECTS_BUCKET='prod-02-velero'" >> ~/nkp-prod-02.env
```

The secret lines are **yours to type**, in `~/nkp-site.env`, with an editor: one line for `OBJECTS_ACCESS_KEY` and one for `OBJECTS_SECRET_KEY`, in the form `export VAR=` and the value. I show no such line, not even with a dummy value (rule 5). Make the file private first if it is not there yet, then tell me, and I check the two names with a `printenv` test only:

```bash
# READ-ONLY
source ~/nkp-prod-02.env 2>/dev/null
for v in OBJECTS_ACCESS_KEY OBJECTS_SECRET_KEY; do [ -n "$(printenv "$v")" ] && echo "set: $v" || echo "MISSING: $v"; done
```

**Step 2 — read the state (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-prod-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy,ds -A -l app.kubernetes.io/name=velero
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get backupstoragelocations.velero -o custom-columns='NAME:.metadata.name,DEFAULT:.spec.default,PHASE:.status.phase,BUCKET:.spec.objectStorage.bucket'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment velero -o jsonpath='{.spec.appRef.name}{"\t"}{.spec.configOverrides.name}{"\n"}'
command -v velero || echo "no velero CLI"
```

```bash
# READ-ONLY
source ~/nkp-prod-02.env 2>/dev/null
for v in VELERO_NS BSL_NAME OBJECTS_URL OBJECTS_BUCKET OBJECTS_CA_FILE OBJECTS_ACCESS_KEY OBJECTS_SECRET_KEY; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

**Step 3 — the credential Secret (CHANGES, plan + "yes")**

Target: the Velero namespace on `prod-02`. Result: Secret `velero-objects-credentials` with an AWS profile named `$BSL_NAME`. The values never print (the block writes the Secret and echoes only "secret applied").

```bash
# CHANGES  (creates the Secret velero-objects-credentials in the Velero namespace)
source ~/nkp-prod-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - >/dev/null <<EOF && echo "secret applied"
apiVersion: v1
kind: Secret
metadata:
  name: velero-objects-credentials
  namespace: $VELERO_NS
type: Opaque
stringData:
  aws: |
    [$BSL_NAME]
    aws_access_key_id = $OBJECTS_ACCESS_KEY
    aws_secret_access_key = $OBJECTS_SECRET_KEY
EOF
```

**Step 4 — two paths. I recommend B for you, because of the private CA.**

- **A. Add a second BSL, keep the Ceph BSL as default.** Needs the `velero` CLI. The guide form has only `insecureSkipTLSVerify="true"` for TLS — that turns the TLS check **off**. With your private CA that is the wrong trade. Only take A if you accept no TLS check.
- **B. Replace the default BSL with the Objects bucket (recommended).** An AppDeployment override with `caCert` (base64 of your PEM): the TLS check stays on, no CLI needed. Velero then does not use Rook Ceph. [pdf p.513-516]

Path A, for completeness (CHANGES, plan + "yes"; only if you accept no TLS check):

```bash
# CHANGES  (adds a BackupStorageLocation; the default BSL does not change)
source ~/nkp-prod-02.env 2>/dev/null
velero backup-location create "$BSL_NAME" -n "$VELERO_NS" --kubeconfig "$CLUSTER_KUBECONFIG" --provider aws --bucket "$OBJECTS_BUCKET" --credential velero-objects-credentials=aws --config "region=us-east-1,s3ForcePathStyle=true,profile=$BSL_NAME,s3Url=$OBJECTS_URL"
```

Path B: the override values file (I write it, then apply it with the AppDeployment override steps O3). `ca` is the base64 of your PEM file:

```bash
# CHANGES  (writes the Velero override values file on the operator host; changes no cluster)
source ~/nkp-prod-02.env 2>/dev/null
: "${OBJECTS_CA_FILE:?}" "${BSL_NAME:?}" "${OBJECTS_BUCKET:?}" "${OBJECTS_URL:?}"
ca=$(base64 < "$OBJECTS_CA_FILE" | tr -d '\n')
f="$PWD/$CLUSTER_NAME-velero-values.yaml"
(umask 077 && cat > "$f" <<EOF
credentials:
  extraSecretRef: ""
configuration:
  features: EnableCSI
  backupStorageLocation:
    - name: $BSL_NAME
      bucket: $OBJECTS_BUCKET
      provider: "aws"
      default: true
      caCert: $ca
      config:
        region: us-east-1
        s3ForcePathStyle: "true"
        insecureSkipTLSVerify: "false"
        s3Url: "$OBJECTS_URL"
        profile: $BSL_NAME
      credential:
        key: aws
        name: velero-objects-credentials
deployNodeAgent: true
nodeAgent:
  podVolumePath: /var/lib/kubelet/pods
  tolerations:
    - operator: Exists
EOF
)
```

`deployNodeAgent: true` starts the `node-agent` DaemonSet, which you need for volume data (file system backup). If you do **not** want volume data, say so and I remove those lines.

Then: syntax check, server dry run of the ConfigMap, and the AppDeployment patch (all in `overrides.md` O3; I show the plan and stop for "yes" before the apply).

One warning for path B: `credentials.extraSecretRef: ""` and, if Rook Ceph is not enabled on this cluster, the `velero-pre-install` job can wait for one hour. The guide deletes it and applies a job that only sleeps [pdf p.516] — I do that only with you, and only if `rook-ceph-cluster` is not enabled.

**Step 5 — check (READ-ONLY)**

```bash
# READ-ONLY
source ~/nkp-prod-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" get backupstoragelocations.velero
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" get pods | grep -E 'velero|node-agent'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" get hr velero -o jsonpath='{.spec.valuesFrom}{"\n"}'
```

Done when the BSL shows PHASE `Available`, the `velero` HelmRelease lists `velero-overrides`, and a test backup completes.

**BSL not `Available`** (`velero.md` B9): wrong URL, bucket, profile, key, or CA — or the endpoint name does not resolve **inside** the cluster. Read:

```bash
# READ-ONLY
source ~/nkp-prod-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" describe backupstoragelocations.velero "$BSL_NAME"
```

**Questions I would ask**

1. `BSL_NAME`: confirm `prod-02-velero` or give another name.
2. The path of your **CA PEM file** on this host (`OBJECTS_CA_FILE`).
3. Path A or path B? (B keeps the TLS check.)
4. Do you need **volume data** too (`deployNodeAgent: true` + the `backup-volumes` annotation on each pod), or objects only?
5. Does the endpoint name `objects.example.local` resolve from a pod inside `prod-02`? A private DNS name that only the operator host knows is the usual cause of a BSL that never becomes `Available`.

Not checked: whether the bucket `prod-02-velero` already exists and the key can write to it (that is in Nutanix Objects, not in the skills). Also: the key and the secret in this chat must be rotated.
