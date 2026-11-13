# t1-pc-leftovers — delete `<old-mgmt-cluster>` leftovers from Prism Central

Goal: delete 2 floating IPs and 3 volume groups left behind by the already-deleted NKP cluster
`<old-mgmt-cluster>`, using only `ntnx-skills` (`skills/nutanix-api`, `skills/nutanix-networking`).
User approved these deletes. Do not touch the VPC `<vpc>`, its subnet, or anything else.

Skills read: `nutanix-api/SKILL.md`, `nutanix-api/REFERENCE.md`, `nutanix-networking/SKILL.md`,
`nutanix-networking/RECIPES.md`. All commands ran on the laptop (Python client), not on `<bastion>`.

## Step 1 — read state (FIPs)

Block (script `/tmp/t1-pc-leftovers/step1_fips.py`, `python3 -I`, `from ntnx import *`):

```python
N = '/networking/v4.4/config'
fips = list_all(f'{N}/floating-ips')
```

Output (2026-11-04T04:13Z):
- `total fips: 50`
- `named fip-dummy-name: 50` — every FIP on this PC has this generic name, so name is not a selector.
- 2 associated, 48 `NOT_ASSOCIATED` (matches the brief).

The two targets, matched on address + private IP, both in VPC `eddfb515-9a8c-44ec-bbb6-6421a53a057b`
(`by` GET of the VPC → name `<vpc>`, externalSubnet `7238c8d9-9e9b-4c3e-a21e-db7f3b529028`):

| address | extId | status | private IP |
|---|---|---|---|
| <net>.135 | `534eb1a7-9025-4c99-80ee-19ff8faafd59` | ASSOCIATED_TO_PRIVATE_IP | <vpc-net>.21 |
| <net>.137 | `a116803e-fb76-4fd4-87ae-1883852d8541` | ASSOCIATED_TO_PRIVATE_IP | <vpc-net>.22 |

## Step 2 — read state (volume groups)

`GET /volumes/v4.0/config/volume-groups` → `17` groups:

- 11 × `usageType: INTERNAL`, `isHidden: true`, each with a `VmAttachment` to `e578ed64-afe2-4b5c-8620-c0d98685471a` (the PC VM). Left alone (brief).
- 3 × `K8sClusterID:c374ed8a-.../ for skilltest-mgmt-01`, all attached to a VM. Left alone (another cluster's).
- 3 × `K8sClusterID:a6b09225-09c9-48a3-8c16-e12225e23ec6/ for <old-mgmt-cluster>`, `attachments: null`.

Fresh `GET` per group plus `GET .../{extId}/vm-attachments` → `OK count=0` for each:

| name | extId | ETag |
|---|---|---|
| pvc-b03f6188-9498-4d42-a7f6-2eb853670621 | `0820df1f-5efa-431d-6955-2444e47e3527` | `NA==` |
| pvc-17c09527-b798-454d-86f4-83121ae83762 | `71a4e12a-e014-4561-6069-018a4f846161` | `NA==` |
| pvc-bd479199-7e9f-4aa0-9edf-da9148f885a4 | `be69a12f-2673-4d06-5427-8ae9920e27fd` | `NQ==` |

`GET .../{extId}/external-attachments` → HTTP 404 (no such sub-resource on this PC).

## Step 3 — CHANGES block: floating IPs (disassociate, then delete)

Plan taken from `nutanix-networking/RECIPES.md` → "Floating IPs", last block:
`f.pop('association', None); put(F, f, etag)` then `delete(F, get(F)[1])` ("disassociate first").
The user already approved these two objects, so no extra go-ahead was requested.

Script `/tmp/t1-pc-leftovers/step5_fip_delete.py`. Per FIP: fresh `GET`, assert address + private IP
still match, `PUT` without `association`, re-`GET` (ETag is consumed), `DELETE`, `GET` → 404.

| address | PUT task | status after PUT | DELETE task | GET after |
|---|---|---|---|---|
| <net>.135 | `kFloatingIpUpdate` | NOT_ASSOCIATED | `kFloatingIpDelete` | 404 |
| <net>.137 | `kFloatingIpUpdate` | NOT_ASSOCIATED | `kFloatingIpDelete` | 404 |

Both mutations returned 202 + a task (the client waited). ETag after the PUT became
`YXBwbGljYXRpb24vanNvbg==:2` for both. Timing: ~6 s per FIP.

## Step 4 — CHANGES block: volume groups (DELETE only)

No recipe exists in either ntnx-skill for volume groups (the brief says so). Used the generic
`nutanix-api` rules: path guessed from the `volumes` namespace, `GET` for object + ETag,
`DELETE` with `If-Match`, fresh `GET`/404 as completion proof. Per group, before the delete:
assert name, assert `description` still holds `<old-mgmt-cluster>`, assert
`GET /volumes/v4.0/config/volume-groups/{extId}/vm-attachments` is empty (`data: null`).

| name | DELETE task | GET after |
|---|---|---|
| pvc-b03f6188-9498-4d42-a7f6-2eb853670621 | `VolumeGroupDelete` | 404 |
| pvc-17c09527-b798-454d-86f4-83121ae83762 | `VolumeGroupDelete` | 404 |
| pvc-bd479199-7e9f-4aa0-9edf-da9148f885a4 | `VolumeGroupDelete` | 404 |

Timing: ~3 s per group.

## Step 5 — proof of final state

Script `/tmp/t1-pc-leftovers/step7_final.py` (2026-11-04T04:15Z):

- `FIPs total: 48 | associated: 0`; addresses `<net>.135`/`.137` no longer listed.
- `VGs total: 14 | attached: 14`; `VGs with <old> in description: []`;
  `VGs with a6b09225 K8sClusterID: []`. Remaining: the 11 internal PC groups plus the 3
  `skilltest-mgmt-01` groups (not mine, untouched).
- `VPC <vpc>: eddfb515-9a8c-44ec-bbb6-6421a53a057b`, subnet `<vpc>-sn1`
  (`056c6a90-0806-4c4e-a885-463b93a787a3`) — both still present, untouched.

## Learnings

1. **[ntnx-skill nutanix-networking/RECIPES.md Floating IPs] A FIP name is not a selector on this
   PC.** All 50 FIPs are named `fip-dummy-name`, so `by_name(f'{N}/floating-ips', 'fip-dummy-name')`
   raises `50 objects named 'fip-dummy-name'` and `$filter name eq '...'` returns all 50. The
   recipes open with `by_name(...)` for FIPs and never say what to use when the name is not unique.
   Fix: add a gotcha row — "FIP name is often a bulk-create filler; select by
   `floatingIp.ipv4.value` (or `association.privateIp.ipv4.value`), then GET by extId."

2. **[ntnx-skill nutanix-api/REFERENCE.md Version map] The `volumes` namespace is missing.** The
   task could only be done by guessing `GET /volumes/v4.0/config/volume-groups` (it works on
   `ganges-7.6.0.10`). Fix: add a row: `volumes` | v4.0–v4.4 (only v4.0 probed) | volume groups |
   `/volumes/v4.0/config/volume-groups`, and note that a volume group's `attachments` array holds
   `volumes.v4.config.VmAttachment` entries and the `description` carries the owning
   `K8sClusterID:`/`for <cluster>` text.

3. **[ntnx-skill nutanix-api] No recipe or reference for volume groups at all**, while the NKP
   flow leaves them behind (PVC-backed groups with `attachments: null`). Fix: a short
   `nutanix-api` reference block, or a `nutanix-volume` skill:
   `list_all('/volumes/v4.0/config/volume-groups')`, VM attachment check via
   `GET .../{extId}/vm-attachments` (`data: null` when empty — not `[]`), `DELETE` with `If-Match`,
   and the warning that unattached ≠ safe: 11 internal PC groups are attached, so filter on
   `attachments == null` **and** the description, never on "hidden"/"internal" alone (the PC's own
   groups are `isHidden: true, usageType: INTERNAL`; the K8s ones are `False/None`).

4. **[fact] `GET /volumes/v4.0/config/volume-groups/{extId}/external-attachments` → HTTP 404**
   on `ganges-7.6.0.10`. The brief mentioned checking external attachments "if the API has them";
   it does not. Only `vm-attachments` exists.

5. **[ntnx-skill nutanix-api/REFERENCE.md Lists] Empty sub-resource lists return `data: null`, not
   an empty array.** `list_all` copes (`d.get('data') or []`), but a raw
   `req(...)[2]['data']` on `.../vm-attachments` gives `None` and will break naive
   `len(data)`. Fix: one line in Lists.

6. **[ntnx-skill nutanix-api/REFERENCE.md Mutation rules] Volume-group ETags are not numeric
   revisions.** Three groups returned `YXBwbGljYXRpb24vanNvbg==:NA==` (literally `NA`) and
   `...:NQ==`; the DELETE accepted them. Nothing to fix in the client, but worth a note so nobody
   treats a non-numeric ETag suffix as "object not versioned / skip If-Match".

7. **[fact] The FIP disassociate-then-delete plan from the recipe is correct and needed here.**
   `PUT` without `association` → `kFloatingIpUpdate` task, `associationStatus` becomes
   `NOT_ASSOCIATED`, ETag suffix moves to `2`; the following `DELETE` → `kFloatingIpDelete`.
   The recipe line `delete(F, get(F)[1])  # disassociate first` was enough — but it is the only
   place that says so, and it hides in a code block. Fix: say in prose, under Floating IPs, that
   the delete of an *associated* FIP needs the disassociating PUT first (the bulk-delete note only
   covers unassociated FIPs).

8. **[fact] The 48 unassociated FIPs the brief called "leave them" are all named
   `fip-dummy-name` in the same external subnet**, so a later cleanup cannot tell them apart by
   name. Not a skill bug; a lab-hygiene note for the next run: create FIPs with distinct names.
