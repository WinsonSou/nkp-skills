# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "== raw tar layout sample (N-30) =="
tar -tf <flow-bundle> | head -5
echo "-- lines matching tags --"
tar -tf <flow-bundle> | grep '_manifests/tags' | head -20
echo "-- count --"
tar -tf <flow-bundle> | wc -l
echo "-- top-level dirs --"
tar -tf <flow-bundle> | awk -F/ '{print $1}' | sort -u | head
