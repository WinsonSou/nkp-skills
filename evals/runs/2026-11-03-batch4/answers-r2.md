# Batch 4 re-run — replies

Common for all sections: I read the router `skills/nkp/SKILL.md` and `skills/_shared/RULES.md` first, then the owner skill and its reference files. I run every block with bash from the operator host (zsh login shell). I do not run a `# CHANGES` block before the user types "yes" to the plan. I do not run a `# USER-TERMINAL` block.

---

## nkp-gpu-ai G1

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (step 1, step 2, step 3, step 4), `skills/nkp-gpu-ai/references/nvidia.md` (N1-N4), `skills/nkp-platform-apps-gitops/SKILL.md` (step 2), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O2, O3).

**Plan from your message.** Your prompt answers step 2 items 1-5 of the skill:

1. Driver mode **A**: the driver is in the node image (NIB, passthrough). The operator driver stays off. `driver.enabled: false` is the app default.
2. GPU access: **DRA** (the 2.19 default).
3. Sharing: **none** (no time-slicing, no MIG).
4. vGPU: **no**, so the vGPU token operator is not in this job.
5. Pool taint: I must read it. The operator DaemonSets and the DRA plugin tolerate only the key `nvidia.com/gpu`.

So there are **no values**. Step 3 item 1 says: "Driver mode A, DRA, no sharing: no values. Go to item 3, without `--config-overrides`." I make **no** override ConfigMap. Two consequences:

- The guide name `nvidia-gpu-operator-overrides` does not apply here, and an override is not needed.
- `nvidia-dra-driver` reads only `nvidia-gpu-operator-config-overrides`. With no override, UNKNOWN D-40 has no effect on this job.

**Questions.** No blocking question. I would ask these with the question tool:
1. "Do you want the step 4 GPU test pod after the enable?" (yes / no).
2. "Is the GPU image the Ubuntu or the RHEL image?" — I also read the OS in the block below. Rocky Linux 9.8 has no GPU support at all. [pdf p.13]

**Step 1 — read the state.** The cluster is named, so the cluster env file is `~/nkp-ai-01.env`. The workspace is `ml`. I take the workspace namespace from the cluster, not from the name.

```bash
# READ-ONLY
source ~/nkp-ai-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
```

If the file is missing, or a name is `MISSING`, I make the file with skill `nkp-install`, "Prepare the env files", item 2 (CHANGES, plan and "yes"), then append the confirmed values with rule 4. I do not guess `WORKSPACE_NS`.

Then the skill step 1 block:

```bash
# READ-ONLY
source ~/nkp-ai-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,KERNEL:.status.nodeInfo.kernelVersion,OS:.status.nodeInfo.osImage,GPU:.status.allocatable.nvidia\.com/gpu,TAINTS:.spec.taints[*].key'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L feature.node.kubernetes.io/pci-0302_10de.present,feature.node.kubernetes.io/pci-0300_10de.present,nvidia.com/gpu.product,nvidia.com/vgpu.present,nvidia.com/mig.config.state
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'NAMESPACE|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deviceclasses,resourceslices
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterpolicies.nvidia.com -o jsonpath='{range .items[*]}{.metadata.name} devicePlugin={.spec.devicePlugin.enabled} driver={.spec.driver.enabled} state={.status.state}{"\n"}{end}'
```

What I look for, in this order:

1. Tier is `Pro` (you said Pro; I confirm it, I do not trust the chat).
2. The ClusterApp name for the enable is exactly what this output shows. On 2.19.0 it is `nvidia-gpu-operator-26.3.3`. [live 2.19.0]
3. Every GPU node has `PCI-0302_10DE.PRESENT` or `PCI-0300_10DE.PRESENT` `true`. No such label: NFD did not label the node, or the VM has no GPU. I stop and check NFD first (`node-feature-discovery` namespace), because the DRA plugin runs only on nodes with an NVIDIA PCI label.
4. The pool taint key is `nvidia.com/gpu`. Another key: the operator pods stay off the GPU nodes. Then I choose with you: change the taint on the pool (skill `nkp-cluster-lifecycle`, V6; that replaces the nodes) or add the full `daemonsets.tolerations` and `kubeletPlugin.tolerations` lists (N4, one override ConfigMap). Not "plain" any more, so I ask.
5. `clusterpolicies` gives "the server doesn't have a resource type": the operator is not installed yet. This is the expected state.
6. `OS` is not Rocky Linux 9.8.

**Step 2 — preview.** No override ConfigMap, so `--config-overrides` is not in the command. `--dry-run` prints the AppDeployment and creates nothing.

```bash
# CHANGES  (client dry run only: prints the AppDeployment; creates nothing)
source ~/nkp-ai-01.env 2>/dev/null
name='nvidia-gpu-operator'; app='nvidia-gpu-operator-26.3.3'
ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG" --dry-run
```

I set `app` to the exact name that step 1 prints. `ws` is the workspace **name** that belongs to `$WORKSPACE_NS` (`ml` is the name you gave; the namespace can differ).

**The plan, before any change.** Target: the management cluster `kommander` namespace gets the AppDeployment `nvidia-gpu-operator`; NKP installs the app on the cluster `ai-01` in workspace `ml`. Result: the apps `nvidia-gpu-operator` and `nvidia-dra-driver` run in the workspace namespace of `ai-01`, the driver stays off (your image has it), GPUs are served through DRA, nothing is shared, no values are changed. **I stop here.**

One scope note: a platform app goes to **every** cluster of the workspace. `--clusters` (some clusters only) is Ultimate, and your license is Pro. So if workspace `ml` holds more clusters than `ai-01`, they all get the operator. `get workspaces` and `nkp get clusters -A` in step 1 show that. Say so now if that is not what you want.

("Just do it" or "plain, no sharing" is not "yes". I need your "yes" to this plan.)

**Step 3 — enable.** Same block, no `--dry-run` (CHANGES, plan above, "yes" first):

```bash
# CHANGES  (creates the AppDeployment; NKP installs the app on ai-01)
source ~/nkp-ai-01.env 2>/dev/null
name='nvidia-gpu-operator'; app='nvidia-gpu-operator-26.3.3'
ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG"
```

**Step 4 — check.** Step 1 again. Done when the `nvidia-gpu-operator` and `nvidia-dra-driver` HelmReleases are READY `True`, the operator pods run on the GPU nodes, the validator pods are `Completed`, `deviceclasses` shows `gpu.nvidia.com` (and `mig.nvidia.com`, `vfio.gpu.nvidia.com`), and `resourceslices` shows the GPUs of each GPU node. A first install with mode A is quick; a mode B driver install takes 10 minutes or more. Not Ready after 15 minutes: skill `nkp-troubleshooting`, file `flux.md`.

**Step 5 — optional test.** If you said yes to the test pod, the step 4 block of `nkp-gpu-ai` (CHANGES, plan and "yes"). It creates a ResourceClaimTemplate `single-gpu` and a pod `gpu-test` in namespace `default` on `ai-01`. The pod is `Pending` in DRA mode only if it asks with `limits` instead of a claim (D-42) — the skill block uses a claim, so it is correct.

**Next.** I run step 1, report the taint key, the NFD labels and the tier, and stop for "yes" on the preview.

---

## nkp-gpu-ai G5

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (step 1, step 2 item 5, step 4, "Common failures"), `skills/nkp-gpu-ai/references/nvidia.md` (N3, N4), `skills/nkp-cluster-lifecycle/references/variables.md` (V6, taints).

You have two different symptoms, and they can have two different causes. I diagnose both from one read.

- "Pods asking for a gpu stay Pending" → in DRA mode a pod that asks with `limits: nvidia.com/gpu: 1` gets no device (UNKNOWN D-42; the known failure row is "Pod `Pending` with `Insufficient nvidia.com/gpu`"). The second cause is the pool taint.
- "nvidia pods only run on some nodes" → the nodes without them have no NVIDIA PCI label (NFD did not label them), or the pool taint key is not `nvidia.com/gpu`, or only some nodes are in the GPU pool.

**Questions.** I would ask these with the question tool:
1. "What is the name and namespace of one Pending pod?"
2. "Did this cluster have the GPU operator with the **device plugin** before (for example on 2.18)?" A cluster that had the device plugin keeps it, and mixing DRA with the device plugin is not allowed. [pdf p.610] The `clusterpolicies` line in the read below answers this too, so the question is a cross-check.

**Step 1 — read the state** (`~/nkp-dev-02.env`, cluster `dev-02`):

```bash
# READ-ONLY
source ~/nkp-dev-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,KERNEL:.status.nodeInfo.kernelVersion,OS:.status.nodeInfo.osImage,GPU:.status.allocatable.nvidia\.com/gpu,TAINTS:.spec.taints[*].key'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L feature.node.kubernetes.io/pci-0302_10de.present,feature.node.kubernetes.io/pci-0300_10de.present,nvidia.com/gpu.product,nvidia.com/vgpu.present,nvidia.com/mig.config.state
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'NAMESPACE|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deviceclasses,resourceslices
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterpolicies.nvidia.com -o jsonpath='{range .items[*]}{.metadata.name} devicePlugin={.spec.devicePlugin.enabled} driver={.spec.driver.enabled} state={.status.state}{"\n"}{end}'
```

Then the Pending pod, and the NFD pods:

```bash
# READ-ONLY
source ~/nkp-dev-02.env 2>/dev/null
pod=''; podns=''; : "${pod:?}" "${podns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$podns" describe pod "$pod" | tail -30
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n node-feature-discovery get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].key'
```

with `pod` and `podns` set from your answer.

**How I read it, and the fix for each branch.** I do not change anything until you pick the branch and say "yes".

| What the read shows | Cause | Fix |
|---|---|---|
| `describe pod` events: `Insufficient nvidia.com/gpu`, `deviceclasses` has `gpu.nvidia.com` (DRA mode), `clusterpolicies` shows `devicePlugin=false` | The pod asks with `limits` in DRA mode (D-42) | Tell the app owner to use a ResourceClaim (skill step 4 template). No cluster change. |
| Same, but you want the old `limits` way | You want the device plugin | N4 values (`devicePlugin.enabled: true`, `gpuResourcesEnabledOverride: false`, `resources.gpus.enabled: false`, `resources.computeDomains.enabled: false`, `webhook.enabled: false`) in one override ConfigMap `nvidia-gpu-operator-config-overrides` (O3), then check that `deviceclasses` has no `gpu.nvidia.com`. DRA and the device plugin must not both serve GPUs. |
| `describe pod` events: `untolerated taint` / no node matches | The pool taint key is not `nvidia.com/gpu`, or the pod has no toleration | Add the toleration to the workload, or add the full `daemonsets.tolerations` + `kubeletPlugin.tolerations` lists (N4) so the operator pods start there too. |
| Some nodes have no `pci-0302_10de.present` / `pci-0300_10de.present` label, and the NFD pods are not Running on them | NFD did not label the node | Fix NFD first. The hand label (`kubectl label node ... =true`) is CHANGES and does not stay — a new node loses it. Use the pool label (skill `nkp-cluster-lifecycle`) or fix NFD. |
| `nvidia-dra-driver` pods run only on nodes with the label; no `resourceslices` for the other nodes | The DRA plugin runs only on nodes with an NVIDIA PCI label | Same as above. |
| `clusterpolicies` shows `state` not `ready`, or a validator pod is not `Completed` | Operator not healthy | `nvidia-dcgm` CrashLoop: remove `toolkit.version` from the override. Driver pod `ImagePullBackOff`: N2. |

**Next.** I run step 1 and the `describe pod`, then give you the one branch that matches and its plan. Nothing changes before your "yes".

---

## nkp-observability B2

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-observability/SKILL.md` (step 1, step 2, step 3), `skills/nkp-observability/references/monitoring.md` (M0, M4), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1-O3).

Your message has one hard problem and one important warning. I answer both before any change.

**1. The webhook URL is a secret, and it is now in the chat.** I do not repeat it, and I do not put it in a file. Rule 5: you type it into `~/nkp-site.env` with an editor. Treat the value you pasted as exposed and **rotate it in Slack** (new incoming webhook), then put the new one in the file. The site variable is `ALERT_SLACK_WEBHOOK_URL` (file `references/monitoring.md`).

**2. The site is air-gapped.** `hooks.slack.com` is on the internet. Alertmanager must reach the receiver, and on an air-gapped site the skill says to use an internal receiver. [M4, done-when] If `app-01` has no proxy or relay path to Slack, the alerts never arrive and no config makes them arrive. This is a blocking question.

**Questions.** I would ask these with the question tool:
1. "Which way: A (replace the Alertmanager config Secret — all alerts of the cluster, one route tree) or B (`AlertmanagerConfig` object — an added route, survives app value changes)?" Recommended: **A**, because you want *all* alerts. Caveat in item 3 below.
2. "How do the `app-01` pods reach `hooks.slack.com` — proxy, or an internal relay?" (Recommended answer to select: "we have a proxy"; if there is no path, we stop and you choose an internal receiver.)
3. "Confirm the channel name exactly (`#ops-alerts`) and whether resolved alerts must also go to Slack."

**Step 1 — read the state** (`~/nkp-app-01.env`, cluster `app-01`):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses,alertmanagers -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'prometheus|alertmanager|grafana|loki|fluent|thanos|karma|insights' | grep -v -E 'Running|Completed'
```

`Starter` tier: no app of this skill, and I stop. The `pods` line prints only pods that are not `Running` or `Completed`; an empty result is healthy.

Then M0, for the stack namespace and the selectors:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAMESPACE|kube-prometheus-stack'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  serviceMonitorSelector={.spec.serviceMonitorSelector}{"\n"}  serviceMonitorNamespaceSelector={.spec.serviceMonitorNamespaceSelector}{"\n"}  ruleSelector={.spec.ruleSelector}{"\n"}  ruleNamespaceSelector={.spec.ruleNamespaceSelector}{"\n"}  retention={.spec.retention}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get alertmanagers -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  configSelector={.spec.alertmanagerConfigSelector}{"\n"}  configNamespaceSelector={.spec.alertmanagerConfigNamespaceSelector}{"\n"}  matcherStrategy={.spec.alertmanagerConfigMatcherStrategy}{"\n"}{end}'
```

`ns` = the namespace of the `kube-prometheus-stack` HelmRelease (a workload cluster: usually `$WORKSPACE_NS`).

**3. Warning that belongs in the plan (Way A).** Helm owns the Secret `alertmanager-kube-prometheus-stack-alertmanager`, and the NKP defaults set the route to `"null"`. [live 2.19.0, chart 87.16.0] Each change of the `kube-prometheus-stack` values (any alert rule, dashboard, or storage change) and each platform upgrade puts the NKP default back, and **the Slack receivers stop with no error**. Way B does not have this problem, but its route has the `namespace=<object namespace>` matcher limit (field) and it is an added route, not the whole route tree. UNKNOWN (D-31): `alertmanagerSpec.useExistingSecret: true` may keep a user Secret across value changes; the skill says do not set it without a lab test.

**Step 2 — you write the config file** (USER-TERMINAL, it holds the webhook). I do not run it and I do not read the result:

```bash
# USER-TERMINAL  (operator host; the user writes the Alertmanager config, it holds a secret)
umask 077
vi ~/alertmanager.yaml
```

The file must have: a `route` with a default `receiver`; a `receivers` entry with `slack_configs` (`api_url`, `channel: '#ops-alerts'`, `send_resolved: true`); and a route that sends `Watchdog` and `InfoInhibitor` to a `"null"` receiver. [pdf p.637-639] The `api_url` is the value of `ALERT_SLACK_WEBHOOK_URL`. The check on your side does not print the value:

```bash
# READ-ONLY  (prints set or MISSING; never the value)
source ~/nkp-site.env 2>/dev/null
[ -n "$(printenv ALERT_SLACK_WEBHOOK_URL)" ] && echo "set: ALERT_SLACK_WEBHOOK_URL" || echo "MISSING: ALERT_SLACK_WEBHOOK_URL"
```

**The plan, before the change.** Target: the cluster `app-01`, namespace `$WORKSPACE_NS`. The Secrets `alertmanager-kube-prometheus-stack-alertmanager` gets your `alertmanager.yaml`. Result: **all** alerts of `app-01` go to `#ops-alerts` in Slack; the `Watchdog` and `InfoInhibitor` alerts still go to `null`. Every notification of this cluster changes at once. I stop here for "yes".

**Step 3 — apply** (CHANGES, after "yes"):

```bash
# CHANGES  (replaces the Alertmanager config Secret of the cluster)
source ~/nkp-app-01.env 2>/dev/null
ns=''; : "${ns:?}"
f=$(test -s "$HOME/alertmanager.yaml" && echo ok); : "${f:?no ~/alertmanager.yaml}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic alertmanager-kube-prometheus-stack-alertmanager --from-file=alertmanager.yaml="$HOME/alertmanager.yaml" --dry-run=client --save-config -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

**Step 4 — check that Alertmanager loaded it** (READ-ONLY; the log does not hold the secret):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --since=10m | grep -iE 'config|error' | tail -5
```

A load error shows `error` with the line. Done when a test alert (or the routed `Watchdog`) reaches `#ops-alerts`. A network error in the log means item 2 above (no path to Slack), not a config problem.

**Next.** I run step 1 and M0, give you `ns`, and stop on the plan. After your "yes" I apply and check the log. I also give you the one-line reminder: **after any further `kube-prometheus-stack` value change or platform upgrade, tell me — Way A must be applied again.**

### Turn 2

> ok, way A is done and slack works. now also turn off the NKP alert rule group etcd.

**Skill files read for this turn:** `skills/nkp-observability/references/monitoring.md` (M1, M6 item 1, Facts, O2 read block), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O3, O6).

**Two facts before I touch the values.**

1. This change is a **`kube-prometheus-stack` value change**, so it puts the NKP default Alertmanager config back, and your Slack receivers (Way A) **stop, with no error**. The plan therefore has two steps, in this order: apply the rule override, then apply `~/alertmanager.yaml` again. The skill says to tell you this before way A; I say it again now.
2. The rule group name must be a real key under `defaultRules.rules`. The value names come from the defaults ConfigMap (M1: "the rule group names are keys under `defaultRules.rules` in the defaults ConfigMap"). I read it first; I do not guess that the key is named `etcd`.

**Step 1 — read the current values** (`ns` = stack namespace from the first reply):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
APP_ID='kube-prometheus-stack'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E "NS|$APP_ID"
```

Then the defaults, with the values keys only (no secret):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns=''; : "${ns:?}"
cm=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get cm -o name | grep 'kube-prometheus-stack-.*-config-defaults'); : "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$cm" -o jsonpath='{.data.values\.yaml}' | grep -n -A 30 -E '^ *defaultRules:'
```

- A key `etcd:` under `defaultRules.rules`: the value is `defaultRules.rules.etcd: false`.
- No `etcd` key: the skill gives no such group name. I tell you "not in the skill; the defaults have no `etcd` group", show the real group names from the output, and ask which one you mean. I do not invent a key.
- The existing override (O2) — if `workspace-override` is not empty, I read that ConfigMap with the O2 `awk` mask and **keep its values in the new file**: O3 item 4 replaces the whole ConfigMap.
- If the AppDeployment shows `cluster-override=kube-prometheus-stack-kommander-overrides`, I tell you before the patch (O1 slot 3).

**Step 2 — the values file** (CHANGES, operator host only). Only the values that change:

```bash
# CHANGES  (writes the values file on the operator host; changes no cluster)
source ~/nkp-app-01.env 2>/dev/null
APP_ID='kube-prometheus-stack'; : "${APP_ID:?}"
f="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml"
(umask 077 && cat > "$f" <<'VALUES'
defaultRules:
  rules:
    etcd: false
VALUES
)
```

Plus, when O2 found existing override values, those lines stay in the same file.

**Step 3 — syntax check, then a server dry run** (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
APP_ID='kube-prometheus-stack'; : "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

Good file: `apiVersion not set, kind not set`. Bad file: `error converting YAML to JSON` with the line. `no objects passed to create`: the file is empty. This check is mandatory; the API accepts a ConfigMap with bad YAML and the HelmRelease then fails. [live 2.19.0]

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-app-01.env 2>/dev/null
APP_ID='kube-prometheus-stack'; cm='kube-prometheus-stack-overrides-ws'; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

I use the existing override name from step 1, or the new name `kube-prometheus-stack-overrides-ws`. Never `kube-prometheus-stack-overrides`: on the management cluster that name lands in slot 2 as well, and removing `configOverrides` does not remove it (O1).

**The plan, before the change.** Target: management cluster, namespace `$WORKSPACE_NS`, ConfigMap `kube-prometheus-stack-overrides-ws`; the AppDeployment `kube-prometheus-stack` gets `spec.configOverrides.name` = that ConfigMap. Result: on **every** cluster of the workspace the `etcd` default rule group is off and the other groups stay on; the Prometheus and Grafana pods restart; **your Slack route stops** until I apply `~/alertmanager.yaml` again in the same maintenance step. Nothing here is irreversible: a value can be set back. I stop for "yes".

**Step 4 — apply, then restore the Slack config** (both CHANGES, one maintenance step, after "yes"):

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-app-01.env 2>/dev/null
APP_ID='kube-prometheus-stack'; cm='kube-prometheus-stack-overrides-ws'; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

```bash
# CHANGES  (puts your Alertmanager config back after the value change)
source ~/nkp-app-01.env 2>/dev/null
ns=''; : "${ns:?}"
f=$(test -s "$HOME/alertmanager.yaml" && echo ok); : "${f:?no ~/alertmanager.yaml}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic alertmanager-kube-prometheus-stack-alertmanager --from-file=alertmanager.yaml="$HOME/alertmanager.yaml" --dry-run=client --save-config -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

**Step 5 — check** (O6, then the Alertmanager log, then the rule list):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
APP_ID='kube-prometheus-stack'; : "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|$APP_ID"
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --since=10m | grep -iE 'config|error' | tail -5
```

Done when `AppDeploymentEnabled=True AppDeploymentInstanceSynced=True` on each cluster, the HelmRelease is READY `True` with a new release number, the Alertmanager log has no config error, and the Prometheus UI (Grafana Explore, or Thanos Query) no longer lists the `etcd` group. A silence is not the tool here — this turns the group off.

**Next.** I run step 1, tell you the exact key name from the defaults, and stop on the plan that includes the Slack re-apply.

---

## nkp-observability B3

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-observability/SKILL.md` (step 1, step 3), `skills/nkp-observability/references/logging.md` (Facts, L1, L3, L4 item 2, L6), `skills/nkp-storage-backup/references/object-storage.md` (O1, O2), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1-O4, O6).

The change is small: `retention_period: 720h` in the one Loki values file of `mgmt-01`. Two facts change the plan.

1. **The logs older than 7 days are already gone.** Loki retention is not a backup: the compactor deleted them. After the change you keep 30 days from now on. You cannot get the older logs back. That loss is irreversible, so you must hear it before "yes".
2. **30 days needs about 4 times the space.** The default store is a Rook Ceph bucket with its own cap (`maxSize` of the ObjectBucketClaim). A bigger `retention_period` does not raise the cap. The bucket fills, Loki stops taking logs. [L3][object-storage O2]

**Questions.** I would ask these with the question tool:
1. "Do you accept that the logs older than 7 days are gone, and that we raise the bucket cap in the same change?" (Recommended: yes, one change.)
2. "How much do the logs of one week use now?" — or I read it from Ceph (`ceph df`, O1). 30 days needs roughly 4x.

**Step 1 — read the current state** (cluster `mgmt-01`; on the management cluster `CLUSTER_KUBECONFIG` is the same file as `MGMT_KUBECONFIG`, `WORKSPACE_NS` is `kommander`):

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'prometheus|alertmanager|grafana|loki|fluent|thanos|karma|insights' | grep -v -E 'Running|Completed'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks
```

Then the existing override and the value names (O2). `APP_ID=grafana-loki-v3`:

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='grafana-loki-v3'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E "NS|$APP_ID"
```

`ns` = the namespace of the `grafana-loki-v3` HelmRelease (`kommander`). Then the defaults, with the retention and store lines only (the L4 item 2 block, with a wider pattern):

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
ns='kommander'; : "${ns:?}"
cm=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get cm -o name | grep 'grafana-loki-v3-.*-config-defaults'); : "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$cm" -o jsonpath='{.data.values\.yaml}' | grep -n -E 'retention|limits_config|maxSize|secretRef:|name: dkp-loki|reloader|s3:'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get objectbucketclaims -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph df
```

- The retention value is `loki.structuredConfig.limits_config.retention_period` in the **one** Loki values file. Default 168h, minimum 24h. 30 days = `720h`.
- If an override already exists, I read it with the O2 `awk` mask and keep its values in the new file: the apply replaces the whole ConfigMap.
- Bucket cap: the key of the workspace Loki cap that `object-storage.md` O2 gives is `dkp.grafana-loki.additionalConfig.maxSize`. The `grafana-loki-v3` chart is a different app, and the skills do not confirm the v3 key name — I take the real key from the defaults output above (`grep maxSize`). If the output has no `maxSize`, I say "not in the skills" and give the check `kubectl get objectbucketclaims -A` for the current cap, and we agree the new value. I do not invent a key.

**Step 2 — the values file** (CHANGES, operator host only, the confirmed values in place of the comment):

```bash
# CHANGES  (writes the Loki values file on the operator host; changes no cluster)
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='grafana-loki-v3'; : "${APP_ID:?}"
f="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml"
(umask 077 && cat > "$f" <<'VALUES'
loki:
  structuredConfig:
    limits_config:
      retention_period: 720h
VALUES
)
```

The cap line (from step 1) goes in the same file, under the key the defaults use.

**Step 3 — checks** (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='grafana-loki-v3'; : "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='grafana-loki-v3'; cm='grafana-loki-v3-overrides-ws'; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

The name is the existing override from step 1, or a new `grafana-loki-v3-overrides-ws`. The skill notes that the guide calls these ConfigMaps `grafana-loki-v3-overrides` and `grafana-loki-v3-custom-overrides`; on the management cluster `-overrides` also fills slot 2, so I do not use it. [O1]

**The plan, before the change.** Target: the management cluster, namespace `kommander`, ConfigMap `grafana-loki-v3-overrides-ws`; the AppDeployment `grafana-loki-v3` points at it. Result: the Loki compactor keeps logs for **30 days (720h)** instead of 7; the bucket cap is raised to the agreed size; the Loki pods restart; **the logs that are already older than 7 days do not come back**. If the agreed cap is more than the free Ceph space, the Ceph step comes first (object-storage O2) — I show that plan separately. I stop for "yes".

**Step 4 — apply** (CHANGES, after "yes"):

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='grafana-loki-v3'; cm='grafana-loki-v3-overrides-ws'; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

**Step 5 — check** (O6, then the compactor log and the cap):

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='grafana-loki-v3'; : "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|$APP_ID"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander logs -l app.kubernetes.io/name=loki,app.kubernetes.io/component=compactor --tail=30 | grep -iE 'retention|error'
```

Done when O6 passes (a new release number on the HelmRelease), the compactor log has no error, and `objectbucketclaims` shows the new `maxSize`.

**Next.** I run step 1, give you the real key names and the current cap, and stop on the plan with the two irreversible facts.

---

## nkp-observability B6

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-observability/SKILL.md` (step 1, "Common failures"), `skills/nkp-observability/references/logging.md` (L1, L9).

**Short answer: not necessarily. That condition alone does not prove that logging is broken.** The `GrafanaLokiV3Deployed` condition has two different `False` reasons, and only one is a fault:

| Reason | Meaning | Logging broken? |
|---|---|---|
| `GrafanaLokiV2NotDeployed` | No Loki v2 was ever installed, so there was nothing to move (normal on a cluster with no logging apps). Seen on 2.19.0. [live 2.19.0] | No by itself — but the skill marks the combination "reason `GrafanaLokiV2NotDeployed` **with Loki v3 running**" as not tested (field). I check the real state. |
| `Failed` | The LoggingStack controller started the v2 → v3 move and stopped on a bad override conversion. [pdf p.552] | Yes for the move: L9. |
| `True` / `Succeeded` | Move done. | No. |

**The cluster name is not in your message.** I keep `~/nkp-<cluster>.env` in the block and I ask you for the cluster name (rule 3). I do not take a name from another conversation or from an example.

**Questions.** I would ask these with the question tool:
1. "Which cluster shows the condition — one workload cluster, the management cluster, or every cluster?"
2. "Do you see new logs in the Grafana of that cluster (Explore, data source Loki)?" — that is the user-visible proof, and it separates the two reasons.

**Step 1 — read the condition and the real state** (L1):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|logging|loki|fluent|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get loggings -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}controlNamespace={.spec.controlNamespace}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterflows,clusteroutputs -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'NAME|fluentbit|fluentd|loki|logging-operator'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[*]}  {.type}={.status} {.reason}: {.message}{"\n"}{end}{end}'
```

The `message` tells the story:

- **`GrafanaLokiV2NotDeployed`** and the Loki v3 HelmReleases `grafana-loki-v3`, `grafana-logging` are `True` with running pods → logging is **not** broken. The condition only says "there was no v2 to remove". I then prove it with the last 30 lines of an ingester log and one Grafana Explore query, and I tell you this is a cosmetic condition, no change needed.
- **`GrafanaLokiV2NotDeployed`** and no Loki pod at all → logging is absent (the logging apps are not enabled on that cluster). That is a different job: step 3 of `nkp-observability` (enable `rook-ceph`, `rook-ceph-cluster`, `logging-operator`, `grafana-loki-v3`, `grafana-logging`). Not an upgrade fault.
- **`Failed`** with a message like `Failed to convert Loki v2 overrides configurations to v3 format for: workspace '...', project '...', cluster '...'` → L9. Each name in the message is one override that failed to convert.

**Step 2 — only for reason `Failed`** (L9):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get events --field-selector reason=GrafanaLokiV3Deployed
```

Then, for each failed scope, I write new **v3 Helm values** for that scope only (they are chart values, not the Loki server config file [pdf p.553]) and apply them: a workspace scope with O3, a cluster scope with O4, a project scope with L10 item 3. Every one of them is a CHANGES plan with "yes". Then I ask the controller to try again (CHANGES, plan and "yes"):

```bash
# CHANGES  (asks the LoggingStack controller to reconcile again)
source ~/nkp-<cluster>.env 2>/dev/null
ls=''; : "${ls:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" annotate loggingstack "$ls" reconcile.loggingstack.nkp.nutanix.com/requestedAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
```

`ls` = the LoggingStack name from step 1. Done when `GrafanaLokiV3Deployed=True` with reason `Succeeded` and message `Loki v3 deployment completed`. [pdf p.554]

**Next.** Tell me the cluster name. I run step 1, read the `reason`, and answer "logging is fine" or give the L9 plan. I change nothing on a condition alone.

---

## nkp-observability B9

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-observability/SKILL.md` (step 1), `skills/nkp-observability/references/logging.md` (Facts, L1, L4, L5), `skills/nkp-storage-backup/references/object-storage.md`, `skills/nkp-platform-apps-gitops/references/overrides.md` (O1-O4, O6).

I cannot do this the way you wrote it. Three points, then the way that works.

**1. I do not write to the Secret `dkp-loki`.** `dkp-loki` is the Secret that Rook makes for the ObjectBucketClaim `dkp-loki` (your Ceph bucket). The bucket provisioner owns it. If we write Objects keys into it, the Ceph bucket can lose its credentials and every Ceph-backed app on that cluster breaks. The skill is explicit: **"Never write to `dkp-loki`"** and **"Never use `dkp-loki`"** in the values. [live 2.19.0, app tree `grafana-loki-v3` 3.6.7] The guide name `nkp-loki` in the PDF is from its own-Ceph example, not this one. So: a **new** Secret, for example `loki-s3-creds`, and no Rook bucket delete.

**2. The keys stay out of the chat and out of my commands.** The access key in your message is now exposed. **Rotate it in Nutanix Objects.** Then you type both lines into `~/nkp-site.env` with your editor (rule 5); I never repeat them and never print them. The site variables are `LOKI_S3_ACCESS_KEY` and `LOKI_S3_SECRET_KEY`.

**3. Your Objects URL is a value of this cluster, and its bucket must exist.** `LOKI_S3_URL` is a cluster variable of `~/nkp-app-01.env`, form `http(s)://<host>:<port>/<bucket>`. One bucket for each cluster. I confirm the exact string and that the bucket `loki-app-01` exists in Objects before I append it (rule 4: append after your confirmation, in the next reply).

Also: **old logs stay in the old bucket.** Loki does not copy them. [L4 step 5] And UNKNOWN (D-33): `grafana-loki-v3` lists `rook-ceph-cluster` as a dependency, so I do not disable Rook Ceph without a lab test.

**Questions.** I would ask these with the question tool:
1. "Is `loki-app-01` the bucket for **this** cluster only, and does it exist in Objects?" (yes / not yet)
2. "What name for the new Secret? `loki-s3-creds` is the skill example." (Recommended: `loki-s3-creds`.)
3. "Does the certificate of `objects.site.local` chain to a CA that the Loki pods trust?" (public CA / our private CA / unknown) — a private CA needs the CA in the pods, or `http_config: {insecure_skip_verify: true}` (field; that turns the TLS check off and you decide).
4. "Is `objects.site.local` resolvable from the pods of `app-01`?" (yes / no / unknown) — it must resolve. [pdf p.511]

**Step 1 — read the defaults before anything.** L4 item 2:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns=''; : "${ns:?}"
cm=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get cm -o name | grep 'grafana-loki-v3-.*-config-defaults'); : "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$cm" -o jsonpath='{.data.values\.yaml}' | grep -n -E 'secretRef:|name: dkp-loki|reloader|s3:'
```

`ns` = the namespace of the `grafana-loki-v3` HelmRelease (usually `$WORKSPACE_NS`; find it with the step 1 block of `nkp-observability`). This output gives (a) the seven components that load the Secret and (b) the **Reloader annotation key** that I must copy into the values. I also read the existing override with the O2 `awk` mask and keep its values.

**Step 2 — the value of this cluster** (CHANGES, after your confirmation, next reply). I append, only for the URL you confirmed:

```bash
# CHANGES  (appends the Loki bucket URL of this cluster to its env file)
echo "export LOKI_S3_URL='https://objects.site.local/loki-app-01'" >> ~/nkp-app-01.env
```

**Step 3 — you write the two secret lines** (USER-TERMINAL; I do not run it):

```bash
# USER-TERMINAL  (the user adds the two Objects key lines with an editor)
vi ~/nkp-site.env
```

Check without printing (READ-ONLY): `[ -n "$(printenv LOKI_S3_ACCESS_KEY)" ] && [ -n "$(printenv LOKI_S3_SECRET_KEY)" ] && echo "set: both" || echo "MISSING: one or both"`.

**Step 4 — the new Secret** (CHANGES). The block refuses the name `dkp-loki`:

```bash
# CHANGES  (creates or updates the new S3 credentials Secret for Loki; never dkp-loki)
source ~/nkp-app-01.env 2>/dev/null
ns=''; secret='loki-s3-creds'; : "${ns:?}"
[ "$secret" = dkp-loki ] && secret=''; : "${secret:?set a new Secret name, not dkp-loki}"
k=$(printenv LOKI_S3_ACCESS_KEY >/dev/null && printenv LOKI_S3_SECRET_KEY >/dev/null && echo ok); : "${k:?LOKI_S3_ACCESS_KEY or LOKI_S3_SECRET_KEY is not set}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic "$secret" --from-file=AWS_ACCESS_KEY_ID=<(printf %s "$(printenv LOKI_S3_ACCESS_KEY)") --from-file=AWS_SECRET_ACCESS_KEY=<(printf %s "$(printenv LOKI_S3_SECRET_KEY)") --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

**Step 5 — the values file** (CHANGES, operator host only). All seven components, the Reloader key from step 1 with the new Secret name, and the Objects store. The URL is the value of `$LOKI_S3_URL`:

```bash
# CHANGES  (writes the Loki values file on the operator host; changes no cluster)
source ~/nkp-app-01.env 2>/dev/null
APP_ID='grafana-loki-v3'
ann=''; : "${APP_ID:?}" "${LOKI_S3_URL:?}" "${ann:?the reloader annotation key from step 1}"
f="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml"
(umask 077 && cat > "$f" <<VALUES
loki:
  annotations:
    "$ann": loki-s3-creds
  structuredConfig:
    storage_config:
      aws:
        s3: "$LOKI_S3_URL"
        region: us-east-1
ingester: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
distributor: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
querier: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
queryFrontend: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
indexGateway: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
compactor: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
ruler: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
VALUES
)
```

- `region: us-east-1` for Nutanix Objects is [field] (the guide uses `us-east-1` for Objects with Insights [pdf p.1098]). UNKNOWN (D-05): the full Loki values for Objects (path-style access, a custom CA without `insecure_skip_verify`) are not settled. We read the compactor log after the change.
- The `extraEnvFrom` lists **replace** the default lists, so after this no component loads `dkp-loki`. That is wanted here; it is also why all seven lines must be present.
- `ann` is the reloader annotation key that step 1 prints; it stays empty with its `:?` guard until I have it. The heredoc is unquoted so `$ann` and `$LOKI_S3_URL` expand; the file holds no secret.
- If your CA is private, the `http_config` line goes under `aws:` — you decide, and I write what you decide.

**Step 6 — checks, plan, apply, check.** O3 item 2 syntax check, O3 item 3 server dry run (`cm` = the existing override name, or a new one such as `grafana-loki-v3-overrides-app-01`), then the plan and "yes", then O3 item 4 (apply the ConfigMap and patch the AppDeployment), then O6.

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
APP_ID='grafana-loki-v3'; : "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

**The plan, before the change.** Target: the cluster `app-01`, namespace `$ns`; a **new** Secret `loki-s3-creds`; the Loki AppDeployment override ConfigMap on the management cluster. Result: Loki writes new logs to the Objects bucket `loki-app-01`; the Ceph bucket `dkp-loki` is untouched and its Secret is not modified; the old logs stay in Ceph and are no longer readable from Loki; the Loki pods restart. I stop for "yes".

**Step 7 — check.** O6 (HelmRelease READY `True`, new release number), then the store:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'loki.*(ingester|compactor)'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs -l app.kubernetes.io/name=loki,app.kubernetes.io/component=compactor --tail=50 | grep -iE 's3|accessdenied|error'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get secrets | grep -E '^NAME|dkp-loki|loki-s3-creds'
```

Done when the compactor and ingester logs show no `S3` or `AccessDenied` error, and new logs arrive in Grafana Explore. An `AccessDenied`: the Objects policy for that key, or the bucket name in `LOKI_S3_URL`.

**Next.** Rotate the Objects key, answer the four questions, and I show step 1's output and the plan. I do not touch `dkp-loki`.

---

## nkp-identity-security S10

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-identity-security/SKILL.md` (Job → section, "Common failures"), `skills/nkp-identity-security/references/gatekeeper.md` (G5), `skills/nkp-platform-apps-gitops/SKILL.md` (step 5, for the "it comes back" part).

This is **not** Gatekeeper. It is the built-in Kubernetes ValidatingAdmissionPolicy `nkp-deletion-protection` that NKP ships (Flux Kustomization `kommander/cluster`). [live 2.19.0] The message you got is the `standard` case. Two limits decide the answer:

- `standard` **cannot be removed**. It can change to `revoked` (or to `strict`).
- `strict` can never change and can never be removed. A `strict` object can never be deleted.
- Only a user whose name does not start with `system:` can change `standard` to `revoked`. Flux or a controller cannot. So this must be a real user (your OIDC or admin kubeconfig), not a service account.
- I do not delete or edit the policy or its binding. Ever.

**Questions.** I would ask these with the question tool, before any change:
1. "Which NKP part owns this ConfigMap? Is `legacy-cfg` created by an app, a Flux Kustomization, or by hand?" — NKP protects an object for a reason. If an app or Flux owns it, a delete only comes back at the next reconcile, and we must change the source instead.
2. "Confirm the delete of `tools/legacy-cfg` on `app-01`, and that its content is not needed." (yes / no)

**Step 1 — read the object and the policy** (cluster `app-01`, `~/nkp-app-01.env`):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kind='configmap'; name='legacy-cfg'; ns='tools'; where='cluster'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" get validatingadmissionpolicy,validatingadmissionpolicybinding nkp-deletion-protection
kubectl --kubeconfig "$kc" -n "$ns" get "$kind" "$name" -L nkp.nutanix.com/deletion-protection
```

The `-L` column gives the current value. Then the three branches:

| Value | What I do |
|---|---|
| `strict` | **Stop.** The object cannot be deleted. I tell you that, and we look at why it is `strict`: the owning app must remove or rename the object. There is no label change. |
| `standard` | The plan below. This is your case. |
| `revoked` | The label is already weak, so the deny comes from something else. I give you the READ-ONLY check `kubectl get events -n tools` and `kubectl auth can-i delete configmaps -n tools` and we look again. |

**Step 2 — the plan, before the change.** Target: the cluster `app-01`, namespace `tools`, ConfigMap `legacy-cfg`. Two changes, in this order: (1) the label `nkp.nutanix.com/deletion-protection` goes from `standard` to `revoked`; (2) the ConfigMap is deleted. Result: the object is gone; the protection is gone with it. Risk that you must accept: NKP set `standard` for a reason, and if an app or Flux owns this object, it comes back — and it comes back protected again. This is not reversible: a deleted ConfigMap is gone. I stop here for "yes".

**Step 3 — set the label** (CHANGES, after "yes"):

```bash
# CHANGES  (sets the deletion-protection label of configmap tools/legacy-cfg to revoked)
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n tools label configmap legacy-cfg nkp.nutanix.com/deletion-protection=revoked --overwrite
```

**Step 4 — delete** (CHANGES, a second plan and "yes", because the delete is irreversible):

```bash
# CHANGES  (deletes configmap tools/legacy-cfg)
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n tools delete configmap legacy-cfg
```

**Step 5 — check.**

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n tools get configmap legacy-cfg
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n tools get configmaps
```

Done when `get configmap legacy-cfg` gives `NotFound` and the name is not back a few minutes later. If it comes back with the label: the owner recreates it — we change the owner's source, not the label again.

**Next.** I run step 1, tell you the current label value, and answer your question 1 from the object's labels and owner references. If the value is `strict`, the answer is "this cannot be deleted".

---

## What I did not check

- I did not run any block. This run has no cluster and no internet; every READ-ONLY block above is for the next turn.
- The GPU answers assume your image is not Rocky Linux 9.8 (no GPU support) and that the pool taint key is `nvidia.com/gpu`. The step 1 read confirms both; a different taint key needs an override, which is not "plain".
- The Slack answer depends on a network path from `app-01` to `hooks.slack.com`. On an air-gapped site there is usually no such path; the plan is void until you answer that question.
- Open skill unknowns that touch these jobs: D-05 and D-33 (Loki on Nutanix Objects), D-31 (a user Alertmanager Secret across value changes), D-42 (a `limits` GPU pod in DRA mode), D-40 (the DRA driver override on a workload cluster).
