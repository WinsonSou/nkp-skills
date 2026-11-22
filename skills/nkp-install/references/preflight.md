# Preflight checks for NKP on Nutanix AHV

Use this file from skill `nkp-install`, section N3. It tests Prism Central, the PC certificate, `CP_VIP`, the LB range, the SSH key, the capacity of the PE cluster, and the site mirror. Run it before a create: the dry run (N4D of the provider file) finds the same problems, but it costs 4 to 6 min and a kind bootstrap cluster.

## N3. Check the infrastructure

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
nkp version
curl -sk -o /dev/null -w 'pc: %{http_code}\n' "$PC_ENDPOINT"
pc=${PC_ENDPOINT#https://}; pc=${pc%%[:/]*}
curl -sk --netrc-file <(printf 'machine %s login %s password %s\n' "$pc" "$(printenv NUTANIX_USER)" "$(printenv NUTANIX_PASSWORD)") -o /dev/null -w 'pc login: %{http_code}\n' "$PC_ENDPOINT/api/clustermgmt/v4.0/config/clusters"
curl -sk --netrc-file <(printf 'machine %s login %s password %s\n' "$pc" "$(printenv NUTANIX_USER)" "$(printenv NUTANIX_PASSWORD)") -X POST "https://$pc:9440/api/nutanix/v3/hosts/list" -H 'Content-Type: application/json' -d '{"kind":"host","length":64}' | jq -r '[.entities[].status.resources | select(.num_cpu_cores != null)] | "hosts=\(length) cores=\(map(.num_cpu_cores)|add) memory_GiB=\(map(.memory_capacity_mib // 0)|add/1024|floor)"'
openssl s_client -connect "$pc:9440" -servername "$pc" </dev/null 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName
ping -c 2 "$CP_VIP"
first=${LB_IP_RANGE%-*}; last=${LB_IP_RANGE#*-}
for i in $(seq "${first##*.}" "${last##*.}"); do ping -c 1 -W 1 "${first%.*}.$i" >/dev/null && echo "IN USE: ${first%.*}.$i" || echo "no reply: ${first%.*}.$i"; done
test -f "$SSH_PUBKEY_FILE" && echo "ssh key file found"
```

`--netrc-file <(...)` keeps the password out of the process list. A password with a space or a `"` fails in a netrc line: then the user checks the login in the UI. The LB loop expects the first and the last IP in the same /24.

- `hosts=` is the capacity of the PE cluster: `cores` and `memory_GiB`. `select(.num_cpu_cores != null)` is needed, because `hosts/list` also returns one entity with no cores (it holds `serial_number`, `controller_vm`, `block`). Host memory is `memory_capacity_mib`. [live 2.19.1]
- The default 3 control-plane nodes and 4 workers need 44 vCPU and 176 GiB (provider file, N1 "Node size"). Compare the `hosts=` line with the memory of the powered-on VMs plus those 176 GiB: skill `nutanix-vm`, RECIPES.md "Full inventory". The create makes no capacity message and no capacity pre-check. [live 2.19.1] The line covers every PE cluster of the PC: with more than one, count only the hosts of `PE_CLUSTER` (skill `nutanix-cluster`).

On a site mirror (4C, 5 mirror), test the registry host and then its project:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
reg=${REGISTRY_URL#https://}; reg=${reg%%/*}
curl -s --cacert "$REGISTRY_CA_FILE" -o /dev/null -w 'mirror: %{http_code}\n' "https://$reg/v2/"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file <(printf 'machine %s login %s password %s\n' "${reg%%:*}" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)") -o /dev/null -w 'mirror login: %{http_code}\n' "https://$reg/v2/"
```

The two lines above strip the project from `REGISTRY_URL`, so they test the host only. A host can answer `200` while the project has no images, and the create then fails at the first image pull. [live 2.19.1] Test the project:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; host="${h%%/*}"; proj="${h#*/}"; proj="${proj:+${proj%/}/}"
echo "project in REGISTRY_URL: ${proj:-none}"
curl -s --cacert "$REGISTRY_CA_FILE" -w '\nhttp=%{http_code}\n' --netrc-file /dev/stdin \
  "https://$host/v2/${proj}mesosphere/kommander-applications-server/tags/list" \
  <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD"
```

- `http=200` with a `tags` list: the project holds the NKP images. [live 2.19.1]
- `http=404`: the project is empty, or the image path is wrong. Do not create: seed the mirror with skill `nkp-airgap`, step 4. [live 2.19.1]
- A registry host can carry more than one project. On Harbor, `GET /api/v2.0/projects` (with the pull account) lists each project with `repo_count`: one site had `repos=457` on the seeded project and `repos=0` on the project in its site file. [live 2.19.1] So read `REGISTRY_URL` in the site file against that list before you trust it.

Done when:
- `pc:` is not `000` (`302` is normal). `pc login:` is `200` (`401` = wrong user or password). [live 2.19.0] More credential checks: skill `nutanix-iam`, RECIPES.md "Read-only credential check". If skill `nutanix-iam` is not installed, the user does it in Prism Central.
- `openssl` shows the PC certificate: see the provider file, N4 "PC certificate". `ping` of `CP_VIP` gets no reply, and the loop prints `no reply` for each LB IP. If the network blocks ICMP, "no reply" proves nothing. Use the free-IP check of the provider file, N1 "IP plan", or ask the user to confirm that no host uses these IPs.
- The output has "ssh key file found". The `hosts=` line prints `cores` and `memory_GiB`, and those numbers have room for 44 vCPU and 176 GiB. [live 2.19.1]
- On a mirror site, `mirror:` is `200` or `401`, `mirror login:` is `200`, and the project check prints `http=200`. [live 2.19.1]
