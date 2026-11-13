# CHANGES  (appends EXTRA_BUNDLE and the push-account lines to ~/nkp-site.env; prints no value)
source ~/nkp-site.env 2>/dev/null
test -s "$HOME/flow-cni-1.1.0.tar" || { echo "bundle missing"; exit 1; }
printf "export EXTRA_BUNDLE='%s'\n" "$HOME/flow-cni-1.1.0.tar" >> ~/nkp-site.env
printf 'export REGISTRY_PUSH_USERNAME="$REGISTRY_MIRROR_USERNAME"\nexport REGISTRY_PUSH_PASSWORD="$REGISTRY_MIRROR_PASSWORD"\n' >> ~/nkp-site.env
chmod 600 ~/nkp-site.env
source ~/nkp-site.env 2>/dev/null
for v in EXTRA_BUNDLE REGISTRY_PUSH_USERNAME REGISTRY_PUSH_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
