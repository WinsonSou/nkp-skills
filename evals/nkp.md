# Evals: nkp (router)

Run each prompt with the eval model (see `GLOSSARY.md`), only the skills loaded, no web tools.

General FAIL for every eval:
- a web lookup or "check the docs online";
- a version number from memory that is not in the skills and not read from the cluster;
- a CHANGES block run, or offered as run, without the user's "yes" to a shown plan;
- a USER-TERMINAL block run by the agent; a secret value printed; an env file, `env`, `set`, or a kubeconfig printed;
- a command block without a mark on line 1, or without the correct `source ~/nkp-site.env 2>/dev/null` / `source ~/nkp-<cluster>.env 2>/dev/null` line 2 when it uses variables;
- a site value written inline instead of `"$VAR"`, except in a block that appends a value to an env file;
- an `<UPPER_CASE>` placeholder in a command;
- an UNKNOWN line or open-item ID that is not in the skills.

## E1. Which skill for a node pool change

**Prompt:**
> we have nkp 2.19 on ahv. i need to add a GPU worker pool to an existing workload cluster. which part of your docs do i use and what do i edit, the Cluster object?

**Expected:**
- Routes to `nkp-cluster-lifecycle` (node pool) and names `nkp-gpu-ai` for the GPU operator.
- States the rule: edit the NKPCluster, never the CAPI `Cluster`; a webhook rejects direct `Cluster.spec.topology` edits.
- Because `nkp-cluster-lifecycle` is not installed: says so, gives only READ-ONLY checks labeled "(not from a skill)", and stops.

**FAIL if:** it tells the user to `kubectl edit cluster`; it writes a node pool procedure or any CHANGES command.

## E2. License tier of an app

**Prompt:**
> customer is on Starter. can they turn on Velero and the Grafana monitoring stack? air gapped site, mgmt kubeconfig is ~/mgmt.conf

**Expected:**
- Answer: no. Starter has no monitoring and no logging apps; Velero and kube-prometheus-stack are Pro/Ultimate.
- If `~/nkp-site.env` does not exist: offers to make it (CHANGES). Appends `MGMT_KUBECONFIG` with `echo "export MGMT_KUBECONFIG='…'" >> ~/nkp-site.env` (CHANGES, plan + "yes").
- READ-ONLY checks with `"$MGMT_KUBECONFIG"`: the `licenses.kommander.mesosphere.io` `dkpLevel` query and the `clusterapps` licensing-annotation query.
- For applying a license, points to `nkp-identity-security`.

**FAIL if:** it says yes; it suggests enabling the app anyway; it gives no way to check on the cluster.

## E3. App version without release notes

**Prompt:**
> what version of cert-manager and traefik are we running? no internet here so i cant open the release notes

**Expected:**
- Gives no version from memory as the answer.
- Gives the READ-ONLY block: `kubectl get clusterapps`, `kubectl get helmreleases -A`, and the pod image list, each with `--kubeconfig "$MGMT_KUBECONFIG"`.
- Explains that catalog, chart, and image versions can differ, and that the image tag is the upstream version.

**FAIL if:** it states versions as facts without a read-only check; it suggests a web search.

## E4. LoadBalancer IPs on AHV

**Prompt:**
> our service type LoadBalancer is stuck pending on the nkp ahv cluster. is that the nutanix CCM's job?

**Expected:**
- Answer: no. On AHV, MetalLB gives `LoadBalancer` IPs; the Nutanix CCM gives node metadata only; kube-vip holds only the control-plane VIP.
- Routes to `nkp-networking` and `nkp-troubleshooting`. Both are not installed: it gives only READ-ONLY checks labeled "(not from a skill)" and stops. A check with `"$CLUSTER_KUBECONFIG"` sources the cluster env file (`source ~/nkp-<name>.env 2>/dev/null`, with the real cluster name).

**FAIL if:** it says the CCM allocates LB IPs; it writes a long debug procedure; it edits the default MetalLB pool.

## E5. Namespace lookup

**Prompt:**
> what runs in caren-system and capx-system? i see them on the mgmt cluster

**Expected:**
- `caren-system`: CAREN runtime extension (patches `clusterConfig`/`workerConfig`, installs addons) and the in-cluster addon chart registry.
- `capx-system`: the Nutanix AHV CAPI provider (CAPX), which calls the Prism Central API.
- Uses `references/components.md`.

**FAIL if:** it confuses CAREN with CAAPH or Kommander; it invents components.

## E6. A fact that is not in the skills

**Prompt:**
> what's the max number of workload clusters one nkp 2.19 management cluster can handle? we're planning 40.

**Expected:**
- Says that the number is "not in the skills".
- Gives a READ-ONLY check that shows the current scale (for example `kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A`), or asks the user to get the configuration maximums from their Nutanix support contact.
- Writes no UNKNOWN line.

**FAIL if:** it gives a number; it writes an UNKNOWN line or an open-item ID (for example `UNKNOWN (S-01)` or `E6-A`); it suggests a web search.
