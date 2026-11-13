# READ-ONLY
nkp create cluster nutanix --help 2>&1 | grep -nE 'insecure|cacert|certificate|prism-central' 
echo "== full flag list (names only) =="
nkp create cluster nutanix --help 2>&1 | grep -E '^ +--' | awk '{print $1}' | tr '\n' ' '
