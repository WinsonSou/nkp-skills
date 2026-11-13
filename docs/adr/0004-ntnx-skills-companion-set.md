# The Prism Central API skills are a companion set in their own repo

The NKP skills need Prism Central (PC) actions that `nkp` and `kubectl` cannot do: find a free IP for a VIP, create and delete floating IPs, find and delete the CSI volume groups that a cluster delete leaves, read NTP and cluster values, check credentials. Before lab test 1 these steps said "the user does it in Prism Central". The `ntnx-skills` repo now has verified PC v4 recipes for each of them (`nutanix-api`, `nutanix-cluster`, `nutanix-iam`, `nutanix-networking`, `nutanix-nkp`, `nutanix-prism`, `nutanix-storage`, `nutanix-vm`, `nutanix-volumes`). We keep two repos. The NKP skills point to a companion skill by name and by the RECIPES heading (the anchor), and they never copy a recipe. Each pointer has a fallback: "If skill `<name>` is not installed, the user does it in Prism Central."

## Considered options

- Copy the PC recipes into the NKP skills: one install, but the recipes drift, and the NKP skills grow past the size budget (ADR 0001).
- Merge the two repos: one tag, but the PC skills are useful without NKP and have their own test cycle (they create `skilltest-*` PC objects).

## Consequences

- The check script accepts the nine companion names in a `` skill `<name>` `` pointer. When `../ntnx-skills/skills` exists, it also checks that each named companion skill exists there.
- The router (`nkp`) has one line that names the companion set.
- The eval model gets both skill sets (lab test 1 retro, decision Q10).
- A companion recipe change that moves an anchor breaks a pointer without an error from the check script. A release of the NKP skills must name the `ntnx-skills` commit that it was tested with.
- The companion client reads `PC_ENDPOINT`, `NUTANIX_USER`, `NUTANIX_PASSWORD` from `~/nkp-site.env` (ADR 0003). Its free-IP recipe runs `ping` and `ip neigh` and must run on a host on the target L2: the operator host.
