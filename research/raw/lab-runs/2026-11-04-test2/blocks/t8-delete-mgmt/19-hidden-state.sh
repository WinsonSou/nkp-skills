# READ-ONLY
echo "== ~/.kube =="
ls -l ~/.kube 2>&1
grep -c 'nkp-mgmt-01' ~/.kube/config 2>/dev/null || echo "~/.kube/config: no match or no file"
echo "== other dot dirs that NKP uses =="
ls -d ~/.konvoy ~/.nkp ~/.kind ~/.cache/nkp ~/.config/nkp 2>&1
echo "== any file in HOME with the name in its content (cheap: 2 levels, no bundle) =="
grep -rl --exclude-dir='nkp-v2.19.0' --exclude='*.tar*' -F 'nkp-mgmt-01' ~ 2>/dev/null | head -10 || true
echo "== docker volumes / kind =="
docker volume ls --format '{{.Name}}' 2>&1 | head -10
