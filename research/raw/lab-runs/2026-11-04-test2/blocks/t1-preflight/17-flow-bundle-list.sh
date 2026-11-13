# READ-ONLY  (nkp-flow-cni step 2, UNKNOWN N-30: the image names and tags in the Flow CNI dark-site bundle. File list only, no extract.)
source ~/nkp-site.env 2>/dev/null
b="$HOME/flow-cni-1.1.0.tar"
ls -l "$b"
echo "== top-level layout =="
tar -tf "$b" | awk -F/ '{print $1"/"$2"/"$3}' | sort -u | head -20
echo "== entry count =="
tar -tf "$b" | wc -l
echo "== repositories and tags (registry v2 layout) =="
tar -tf "$b" | sed -n 's#^docker/registry/v2/repositories/\(.*\)/_manifests/tags/\([^/]*\)/current/link$#\1:\2#p' | sort -u
echo "== also: any index/manifest json =="
tar -tf "$b" | grep -E 'index\.json$|manifest\.json$|\.metadata' | head -10
