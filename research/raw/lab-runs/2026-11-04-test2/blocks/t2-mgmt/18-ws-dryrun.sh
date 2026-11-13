# CHANGES  (dry run only: prints the Workspace object; creates nothing)
source ~/nkp-site.env 2>/dev/null
ws='skilltest-flow'; display='skilltest flow'
: "${ws:?}" "${display:?}"
nkp create workspace "$ws" --display-name "$display" --kubeconfig "$MGMT_KUBECONFIG" --dry-run -o yaml
