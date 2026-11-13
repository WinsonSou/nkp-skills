# READ-ONLY  (nkp-airgap step 2 "Check the bundle": the Kubernetes version that NKP 2.19.0 ships, to compare with the site image name)
source ~/nkp-site.env 2>/dev/null
ls "$BUNDLE_DIR"/container-images/ | grep -E 'kubernetes-os|konvoy-image-bundle|kommander-image-bundle|nkp-release-specs'
ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar
"$BUNDLE_DIR"/cli/nkp version | grep -E '^nkp:'
