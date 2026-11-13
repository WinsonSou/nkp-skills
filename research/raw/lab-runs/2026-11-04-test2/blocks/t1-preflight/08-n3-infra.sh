# READ-ONLY  (nkp-install references/nutanix.md N3; the cluster env files do not exist yet, so the VIP and the three LB ranges are set here)
source ~/nkp-site.env 2>/dev/null
nkp version | grep -E '^nkp:'
curl -sk -o /dev/null -w 'pc: %{http_code}\n' "$PC_ENDPOINT"
pc=${PC_ENDPOINT#https://}; pc=${pc%%[:/]*}
curl -sk --netrc-file <(printf 'machine %s login %s password %s\n' "$pc" "$(printenv NUTANIX_USER)" "$(printenv NUTANIX_PASSWORD)") -o /dev/null -w 'pc login: %{http_code}\n' "$PC_ENDPOINT/api/clustermgmt/v4.0/config/clusters"
openssl s_client -connect "$pc:9440" -servername "$pc" </dev/null 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName
test -f "$SSH_PUBKEY_FILE" && echo "ssh key file found"
echo "== ping the three VIPs and the three LB ranges =="
for spec in "<net>.50:<net>.51-<net>.55" "<net>.60:<net>.61-<net>.65" "<net>.70:<net>.71-<net>.75"; do
  vip=${spec%%:*}; range=${spec#*:}
  first=${range%-*}; last=${range#*-}
  ping -c 2 -W 1 "$vip" >/dev/null && echo "IN USE: $vip" || echo "no reply: $vip"
  for i in $(seq "${first##*.}" "${last##*.}"); do ping -c 1 -W 1 "${first%.*}.$i" >/dev/null && echo "IN USE: ${first%.*}.$i" || echo "no reply: ${first%.*}.$i"; done
done
