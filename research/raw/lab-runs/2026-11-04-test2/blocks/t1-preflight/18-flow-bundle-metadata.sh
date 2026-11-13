# READ-ONLY  (read-only tar -xO of two metadata files to stdout; no extract to disk)
b="$HOME/flow-cni-1.1.0.tar"
echo "===== charts.yaml ====="
tar -xOf "$b" charts.yaml | head -40
echo "===== images.yaml ====="
tar -xOf "$b" images.yaml | head -60
