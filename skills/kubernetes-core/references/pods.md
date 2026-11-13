# Pod states, logs, probes, and `kubectl debug`

Use this file from skill `kubernetes-core`, after step 1 of `SKILL.md`. Each block uses the cluster env file. Set the empty shell values from the user or from step 1 output.

## P1. Read the container state

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='{range .status.initContainerStatuses[*]}init {.name}: ready={.ready} restarts={.restartCount} waiting={.state.waiting.reason} last={.lastState.terminated.reason} exit={.lastState.terminated.exitCode}{"\n"}{end}{range .status.containerStatuses[*]}{.name}: ready={.ready} restarts={.restartCount} waiting={.state.waiting.reason} last={.lastState.terminated.reason} exit={.lastState.terminated.exitCode}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='{range .spec.containers[*]}{.name}: requests={.resources.requests} limits={.resources.limits}{"\n"}{end}'
```

| `waiting` or `last` | Exit code | Meaning | Next |
|---|---|---|---|
| `CrashLoopBackOff`, last `Error` | 1, 2, or app code | The app exits. | P2 (`--previous` logs). |
| last `OOMKilled` | 137 | The container used more memory than its limit. | P4. |
| last `Error` | 137, no OOM | SIGKILL: a failed liveness probe or a kill after the grace period. | P3. |
| last `Error` | 143 | SIGTERM: a normal stop, or a liveness restart. | P3. |
| last `ContainerCannotRun` or `StartError` | 126, 127, 128 | The command or the entrypoint is wrong or not in the image. | `describe pod`, field `Command`/`Args`; fix the image or the command. |
| `CreateContainerConfigError` | – | A ConfigMap, a Secret, or a key that the pod uses does not exist. | P5. |
| `ImagePullBackOff`, `ErrImagePull`, `InvalidImageName` | – | The node cannot pull the image. | skill `nkp-airgap` (registry, mirror, `x509`). |
| `ContainerCreating` (long) | – | Volume mount, CNI, or a Secret volume. | `describe pod` Events: `FailedMount`, `FailedAttachVolume` → skill `nkp-storage-backup`; `FailedCreatePodSandBox` → skill `nkp-networking`. |
| `Init:CrashLoopBackOff`, `Init:Error` | – | An init container fails. The app containers do not start. | P2 with `-c` and the init container name. |
| `Running`, `ready=false` | – | The readiness probe fails. The pod gets no Service traffic. | P3. |

Done when: you know the container, its state, and the exit code.

## P2. Logs

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''; c=''
: "${ns:?}" "${pod:?}" "${c:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs "$pod" -c "$c" --previous --tail=100 --timestamps
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs "$pod" -c "$c" --tail=100 --timestamps
```

- `--previous` (`-p`) shows the log of the last container that stopped. Use it for `CrashLoopBackOff`. "previous terminated container not found": the container did not restart yet.
- Other flags [live 2.19.0]: `--all-containers`, `--since=10m`, `--since-time`, `--limit-bytes`, `-l <selector> --prefix` (all pods of one label), `--max-log-requests` (default 5).
- `kubectl logs deploy/<name>` and `kubectl logs job/<name>` read one pod of the object.
- An empty log and a fast exit: the command fails before the app writes. Read the `Command` and `Args` in `describe pod`.
- Logs can hold secrets that the app prints. Show the user only the lines that are needed.

## P3. Probes

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}  startup={.startupProbe}{"\n"}  liveness={.livenessProbe}{"\n"}  readiness={.readinessProbe}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" events --for "pod/$pod" --types=Warning
```

- `Liveness probe failed`: the kubelet kills and restarts the container (exit 137 or 143). The restart count goes up.
- `Readiness probe failed`: no restart. The pod is not in the Service endpoints.
- `Startup probe failed`: the liveness and readiness probes wait until the startup probe passes. A slow app needs a startup probe with a larger `failureThreshold` × `periodSeconds`.
- Common causes: wrong port or path, the app listens only on `127.0.0.1` (an `httpGet` probe goes to the pod IP), `initialDelaySeconds` too short, a `timeoutSeconds` of 1 s on a slow endpoint.
- The fields: `kubectl explain pod.spec.containers.livenessProbe`.

## P4. Resources and `OOMKilled`

- A memory limit is hard. Above the limit, the kernel kills the container (`OOMKilled`, 137). Raise the limit, or fix the app.
- A CPU limit only slows the container (throttling). It does not kill it.
- The scheduler uses the **requests**, not the real use. Too large requests → `Pending` (file [scheduling.md](scheduling.md), S1).
- No `limits` and a `LimitRange` in the namespace: the LimitRange sets the defaults. Read it: `kubectl get limitrange -n <ns> -o yaml`.
- Real use needs the Metrics API (`kubectl top pod`). The Starter lab has no Metrics API: `kubectl top` prints `error: Metrics API not available`. [live 2.19.0]
- UNKNOWN (Q-10): which NKP licence tiers or apps give the Metrics API for `kubectl top`. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get apiservices | grep metrics`.

Change the resources (CHANGES, after the `SKILL.md` step 3 check). It makes new pods:

```bash
# CHANGES  (sets requests and limits of one container; the workload rolls out new pods)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; kind=''; name=''; c=''; req=''; lim=''
: "${ns:?}" "${kind:?}" "${name:?}" "${c:?}" "${req:?}" "${lim:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" set resources "$kind/$name" -c "$c" --requests="$req" --limits="$lim"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=300s
```

`req` and `lim` have the form `cpu=250m,memory=256Mi`. Add `--dry-run=server` to the `set` line for a preview.

## P5. `CreateContainerConfigError`: missing ConfigMap or Secret

Read the names only. Never print Secret data (rule 5).

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" events --for "pod/$pod" --types=Warning
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o json | jq -r '[.spec.containers[], (.spec.initContainers // [])[]] | .[] | (.env // [])[] | select(.valueFrom) | "\(.name) <- \(.valueFrom | to_entries[0] | "\(.key) \(.value.name)/\(.value.key)")"'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get secrets,configmaps
```

- The event names the missing object or key (`secret "x" not found`, `couldn't find key y in Secret`).
- To see the key names of a Secret without the values: `kubectl describe secret <name> -n <ns>` (it prints only the key names and sizes).
- Never run `exec ... -- env`, `printenv`, or `get secret -o yaml`. They print secret values.

## P6. Pod stays `Terminating`

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='node={.spec.nodeName} finalizers={.metadata.finalizers} deletion={.metadata.deletionTimestamp} grace={.metadata.deletionGracePeriodSeconds}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
```

- The node is `NotReady`: the kubelet cannot confirm the stop. Fix the node first (skill `nkp-troubleshooting`, rung 6).
- A finalizer: the controller that owns it must remove it. Use skill `nkp-troubleshooting`, file `deletes.md`.
- Force delete is the last resort. For a StatefulSet pod, a force delete while the old container still runs can give two pods with the same identity and the same volume. Tell the user this in the plan.

```bash
# CHANGES  (force-deletes one pod from the API; the container can still run on a lost node)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" delete pod "$pod" --grace-period=0 --force
```

## P7. `kubectl debug` (a container with tools next to the app)

Use it when the app image has no shell, or to test the network from the pod. Flags [live 2.19.0]: `--image`, `--target` (share the process namespace of one container), `--profile` (`general`, `baseline`, `restricted`, `netadmin`, `sysadmin`; default `general`), `--copy-to`, `--set-image`, `--share-processes`, `-c` (debug container name), `-i`, `-q`.

Images in the 2.19.0 bundles, so in the registry mirror: `busybox:1` (konvoy and kommander bundles), `curlimages/curl:8.20.0` and `alpine/curl:8.17.0` (kommander bundle). [live 2.19.0] If the pull fails, use skill `nkp-airgap`.

**Ephemeral container in the running pod.** It shares the network of the pod, so it sees what the app sees. An ephemeral container stays in the pod spec until the pod is replaced. It cannot be removed. The block uses a new `-c` name each time.

```bash
# CHANGES  (adds an ephemeral debug container to one running pod; the pod does not restart)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''; target=''
: "${ns:?}" "${pod:?}" "${target:?}"
d="dbg-$(date +%s)"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" debug "pod/$pod" -c "$d" --image=busybox:1 --target="$target" --profile=general -- sh -c 'cat /etc/resolv.conf; nslookup kubernetes.default.svc.cluster.local; ps'
sleep 20
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs "$pod" -c "$d"
```

- The block does not attach a terminal. It reads the output with `logs`. Do not use `-it` in the agent shell.
- Change the command after `sh -c` to the test that you need. `wget`, `nc`, `nslookup`, and `ps` are in `busybox`. `ps` shows the app processes because of `--target`. For HTTPS and headers, use `--image=curlimages/curl:8.20.0` with `-- curl -sv -m 5` and the URL.
- `ErrImagePull` on the debug container: the image is not in the registry mirror (skill `nkp-airgap`).
- A namespace with Pod Security `restricted` rejects this debug container (`violates PodSecurity`). `--profile=restricted` makes it run as non-root, but `busybox:1` runs as root, so it does not start. For a DNS or Service test in such a namespace, use the test pod of [networking.md](networking.md), N2. It sets a non-root user.

**Copy of a crashing pod.** `--copy-to` makes a new pod (same spec, new name) and changes the command, so you can look inside the image. The copy has the labels removed by default (`--keep-labels=false`), so it gets no Service traffic. [live 2.19.0]

```bash
# CHANGES  (makes a copy pod of one pod with the command "sleep 3600"; delete it after use)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''; c=''
: "${ns:?}" "${pod:?}" "${c:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" debug "$pod" --copy-to="$pod-debug" --container="$c" -- sleep 3600
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" wait --for=condition=Ready "pod/$pod-debug" --timeout=120s
```

Then read files with `kubectl exec "$pod-debug" -c "$c" -- ls -l /path` (READ-ONLY commands only). The copy pod uses the same PVCs. A `ReadWriteOnce` volume on another node blocks the copy. Delete the copy when you are done (CHANGES: `kubectl delete pod "$pod-debug" -n "$ns"`).

**Node.** `kubectl debug node/<node>` makes a pod on that node with the host namespaces and the host file system at `/host`. [live 2.19.0] It is CHANGES, it needs a namespace that allows host namespaces (Pod Security `privileged`), and the pod stays until you delete it. Prefer the node checks of skill `nkp-troubleshooting` (rung 6).
