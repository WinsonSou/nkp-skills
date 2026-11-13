# CHANGES  (pushes the images of the Flow CNI dark-site bundle into the site registry, in tmux)
source ~/nkp-site.env 2>/dev/null
tmux new-session -d -s push-flow-cni "bash -c 'source ~/nkp-site.env 2>/dev/null; nkp push bundle --bundle \"\$EXTRA_BUNDLE\" --to-registry \"\$REGISTRY_URL\" --to-registry-ca-cert-file \"\$REGISTRY_CA_FILE\" --to-registry-username \"\$REGISTRY_PUSH_USERNAME\" --to-registry-password \"\$REGISTRY_PUSH_PASSWORD\" > ~/push-flow-cni.log 2>&1; echo RC=\$? >> ~/push-flow-cni.log'"
echo "started: push-flow-cni"
