# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "== os =="; . /etc/os-release 2>/dev/null && echo "$PRETTY_NAME"; uname -m
echo "== cgroup =="; stat -fc %T /sys/fs/cgroup
echo "== tools =="
for c in nkp kubectl docker podman tmux bash yq jq curl openssl tar ping ip awk sed grep seq stat df nproc free sha256sum python3 scp ssh; do
  if command -v "$c" >/dev/null 2>&1; then printf 'found: %-12s %s\n' "$c" "$(command -v "$c")"; else printf 'MISSING: %-10s\n' "$c"; fi
done
echo "== versions =="
nkp version 2>&1 | sed -n '1,12p'
kubectl version --client 2>&1 | head -3
docker version --format '{{.Server.Version}}' 2>&1 | head -2
tmux -V 2>&1
yq --version 2>&1
jq --version 2>&1
echo "== resources =="
nproc; free -g | head -2; df -h "${TMPDIR:-/tmp}" | tail -1
echo "== home files =="
ls -a ~ | grep -E 'nkp|flow' || echo "(no nkp/flow files in ~)"
