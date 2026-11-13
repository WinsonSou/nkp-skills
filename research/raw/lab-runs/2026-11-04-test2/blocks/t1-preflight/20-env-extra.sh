# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "== variables of the Flow CNI / push path (set/MISSING only) =="
for v in REGISTRY_PUSH_USERNAME REGISTRY_PUSH_PASSWORD EXTRA_BUNDLE IMAGE_BUNDLES FLOW_CNI_PULL_USERNAME FLOW_CNI_PULL_TOKEN; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
echo "== operator host leftovers (an old bootstrap cluster or cluster files) =="
docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}' 2>&1 | head -5
ls -a ~ | grep -E 'bootstrap\.conf|nkp-mgmt-01|skilltest' || echo "(no bootstrap.conf and no cluster files)"
echo "== disk for a 37 GiB bundle plus the image push temp =="
df -h "$HOME" | tail -1
echo "== podman is not installed; docker version =="
docker version --format '{{.Server.Version}}'
