# Gate G2: Docker Hub credentials

Use this file from skill `nkp-upgrade`, step 2 (gate G2).

If the site is not air-gapped, set the Nutanix Docker Hub credentials on the management cluster and on every workload cluster **before** `nkp upgrade kommander`. NKP uses them to pull its images from `docker.io/nutanix`. [pdf p.1017] Without them, the Kommander upgrade stops with "docker.io/nutanix credentials are missing for N cluster(s)". [pdf p.1017] Air-gapped sites skip this gate. For the token rules, use skill `nkp-airgap`, step 3.

UNKNOWN (P-26): whether a connected site whose clusters use a registry mirror also needs these credentials. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get secrets -A | grep dockerhub-nutanix-credentials`. Until then, set them on every connected site.

1. The second list shows the clusters that already have the Secret `<cluster>-dockerhub-nutanix-credentials`. [live 2.19.0] An empty MIRROR column means the cluster pulls from Docker Hub.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MIRROR:.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.globalImageRegistryMirror.url'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get secrets -A | grep dockerhub-nutanix-credentials
for v in NUTANIX_REGISTRY_USERNAME NUTANIX_REGISTRY_TOKEN; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

2. If a name is `MISSING`, the user gets the username and the token (PAT) from the NKP downloads page of the Nutanix portal [pdf p.1017], and adds them with an editor (rule 5):

```bash
# USER-TERMINAL  (the user adds NUTANIX_REGISTRY_USERNAME and NUTANIX_REGISTRY_TOKEN with an editor)
vi ~/nkp-site.env
```

3. Set the credentials on all clusters of the fleet. [pdf p.1017][live 2.19.0] The CLI takes the token only as a flag. Other users on the host can see it in the process list. Tell the user this.

```bash
# CHANGES  (writes the Docker Hub credentials Secret of the management cluster and of every workload cluster)
source ~/nkp-site.env 2>/dev/null
nkp update cluster nutanix-registry-credentials --all-namespaces --nutanix-registry-username "$NUTANIX_REGISTRY_USERNAME" --nutanix-registry-password "$NUTANIX_REGISTRY_TOKEN" --kubeconfig "$MGMT_KUBECONFIG"
```

Done when: block 1 shows one Secret for each cluster.
