#!/usr/bin/env python3
"""Check the NKP skills. Python 3 stdlib only.

Usage:
  python3 scripts/check_skills.py              # check, exit 0 = pass
  python3 scripts/check_skills.py --sync       # copy the master rules block into each SKILL.md, then check
  python3 scripts/check_skills.py --self-test  # test this script in a temp dir

Each error is "<file>: <code>: <message>". The codes are listed in CODES.
"""
import contextlib
import io
import re
import sys
import tempfile
from pathlib import Path

BEGIN = "<!-- RULES:BEGIN -->"
END = "<!-- RULES:END -->"
MAX_SKILL_LINES = 250
MAX_REF_LINES = 400
MAX_DESC_CHARS = 1024
MAX_DESC_WORDS = 60
REQUIRED_META = ("nkp_versions", "last_verified", "sources")
SHELL_VARS = {"HOME", "PATH", "TMPDIR", "KUBECONFIG", "PWD"}
MARKS = ("# READ-ONLY", "# CHANGES", "# USER-TERMINAL")
SITE_SOURCE = "source ~/nkp-site.env 2>/dev/null"
CLUSTER_PATH = "~/nkp-<cluster>.env"
CLUSTER_SOURCE = f"source {CLUSTER_PATH} 2>/dev/null"
NON_SHELL_LANGS = {"text", "yaml", "yml", "json", "toml", "ini", "markdown", "md", "mermaid"}
# Kubernetes default CIDRs, plus the fixed no-proxy entries of the NKP guide (loopback, metadata, link-local, AWS default VPC).
ALLOWED_IPS = {"192.168.0.0/16", "10.96.0.0/12", "127.0.0.1", "169.254.169.254", "169.254.0.0/24", "10.0.0.0/16"}
ALLOWED_DOMAIN_SUFFIXES = (
    "nutanix.com", "nutanix.io", "d2iq.io", "d2iq.com", "mesosphere.io", "mesosphere.com", "x-k8s.io",
    "k8s.io", "kubernetes.io", "docker.io", "ghcr.io", "fluxcd.io", "k8s.ovn.org", "traefik.io",
    "kubefed.io", "metallb.io", "cert-manager.io", "cluster.local", "example.com", "example.local",
    "letsencrypt.org", "rook.io", "velero.io", "nvidia.com", "nvcr.io",
)
# Companion PC API skills in ../ntnx-skills (ADR 0004). A pointer may name them.
COMPANION_SKILLS = {"nutanix-api", "nutanix-cluster", "nutanix-iam", "nutanix-networking", "nutanix-nkp",
                    "nutanix-prism", "nutanix-storage", "nutanix-vm", "nutanix-volumes"}
TLDS = ("com|net|org|io|local|lan|internal|corp|intra|home|cloud|dev|app|co|us|uk|eu|de|ch|fr|nl|"
        "at|be|it|es|se|no|dk|fi|pl|au|nz|jp|cn|kr|sg|hk|in|ca|br|biz|info|xyz|site|online|tech|arpa|gov|mil|edu")
CODES = (
    "rules-missing", "rules-differs", "rules-position", "fm-missing", "fm-name", "fm-desc", "fm-meta",
    "too-long", "link", "mark", "source", "var", "placeholder", "lower-in-block", "ipv4", "fqdn",
    "token", "unknown-form", "unknown-id", "skill-name", "readonly-writes", "user-terminal",
    "secret-literal", "table-pipe", "rm-glob", "grep-secret", "eval-id",
)

LINK_RE = re.compile(r"(?<![\w/.-])((?:references|assets)/[\w./-]*[\w-])")
SKILL_LINK_RE = re.compile(r"\]\(\.\./([a-z0-9-]+)/")
FENCE_RE = re.compile(r"^([ \t]*)(`{3,}|~{3,})([\w-]*)[^\n]*\n(.*?)^[ \t]*\2[ \t]*$", re.M | re.S)
VAR_RE = re.compile(r"\$\{?([A-Z][A-Z0-9_]*)\b")  # $UPPER_SNAKE only; $lower is a loop variable
UPPER_TOKEN_RE = re.compile(r"<[A-Z][A-Z0-9_]*>")
LOWER_TOKEN_RE = re.compile(r"<[a-z][a-z0-9._-]*>")
IPV4_RE = re.compile(r"(?<![\d.])(\d{1,3}(?:\.\d{1,3}){3})(/\d{1,2})?(?!\d|\.\d)")
FQDN_RE = re.compile(r"(?<![\w.-])((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+(?:" + TLDS + r"))(?![\w-])", re.I)
TOKEN_RE = re.compile(r"\beyJ[\w-]{10,}|\b(?:ghp|glpat|xox[bp])[-_][\w-]{10,}|\b[A-Za-z0-9+/]{40,}={0,2}")
UNKNOWN_TRIGGER_RE = re.compile(r"\bUNKNOWN\s*[(:]")
UNKNOWN_RE = re.compile(r"UNKNOWN \(([A-Z]-\d{2})\): [^\n]+?\. Find out with: `[^`]+`")
SKILL_REF_RE = re.compile(r"skills? `([a-z0-9][a-z0-9-]*)`")
BARE_SKILL_RE = re.compile(r"`((?:nkp|kubernetes)-[a-z0-9-]+)`")
RM_GLOB_RE = re.compile(r"\brm\b.*\$\{?CLUSTER_NAME\}?[-.][^\s\"']*[\"']?\*")
GREP_E_RE = re.compile(r"\bgrep\b(?!.*\s-c\b).*?-E\s+'([^']*)'.*dryrun")
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PIPE_IN_CODE_RE = re.compile(r"`[^`\n]*\\\|[^`\n]*`")
MUTATING_RE = re.compile(
    r"\b(?:kubectl|nkp)\s+(?:delete|apply|create|patch|edit|scale|rotate|install|upgrade|push|move|"
    r"annotate|label|replace|set|update|attach|detach|import|upload)\b|\bnkp\s+get\s+kubeconfig\b|"
    r"\b(?:chmod|chown|tee|rm|mv|cp|touch|mkdir)\b|\bdocker\s+(?:load|rm|run|push)\b")
REDIRECT_RE = re.compile(r"(?<![<>&\d-])\d?>{1,2}(?!&)\s*(?!/dev/null\b)\S")


def secret_prints(line, secrets):
    """True if the line shows a secret on the screen."""
    alt = "|".join(sorted(secrets)) or "(?!x)x"
    pats = (
        r"\bnkp\s+get\s+dashboard\b",
        r"\bget\s+secrets?\b[^\n]*\s-o\b",
        r"\bbase64\s+(?:-d|--decode)\b",
        r"\b(?:cat|less|more|head|tail|vi|vim|nano|view)\s+[^\n|;]*\.env\b",
        r"\b(?:echo|printf)\b[^\n]*\$\{?(?:" + alt + r")\b",
        r"(?<!\$\()\bprintenv\s+(?!\S+\s*>\s*/dev/null)\S+",
        r"(?:^|[;&|]\s*)(?:env|set)\s*$",  # bare env or set as a command
    )
    return any(re.search(p, line) for p in pats)


def extract_block(text):
    """Return the text from BEGIN to END (markers included), or None."""
    start, end = text.find(BEGIN), text.find(END)
    if start < 0 or end < 0 or end < start:
        return None
    return text[start:end + len(END)]


def read(path):
    return path.read_text(encoding="utf-8-sig")  # utf-8-sig drops a byte-order mark


def fm_bounds(lines):
    """Index of the closing '---' of the front matter, or None."""
    if not lines or lines[0].strip() != "---":
        return None
    return next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)


def parse_front_matter(text):
    """Return (top-level keys -> str, metadata keys -> str), or None if absent.

    Supports `key: value`, folded continuation lines, one nested `metadata:` map,
    and YAML block lists (`- item`) under a metadata key (joined with ", ").
    """
    lines = text.splitlines()
    close = fm_bounds(lines)
    if close is None:
        return None
    top, meta = {}, {}
    current = meta_key = None
    for line in lines[1:close]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            current, meta_key = m.group(1), None
            top[current] = m.group(2).strip()
            continue
        nested = re.match(r"^\s+([A-Za-z_][\w-]*):\s*(.*)$", line)
        item = re.match(r"^\s+-\s+(.*)$", line)
        if current == "metadata" and nested:
            meta_key = nested.group(1)
            meta[meta_key] = nested.group(2).strip()
        elif current == "metadata" and item and meta_key:
            meta[meta_key] = ", ".join(v for v in (meta[meta_key], item.group(1).strip()) if v)
        elif current is not None:
            prev = "" if top[current] in (">", "|", ">-", "|-") else top[current]
            top[current] = (prev + " " + line.strip()).strip()
    return top, meta


def site_vars(rules_text):
    """(all site variables, cluster-file variables, secret variables) from the rules table rows."""
    all_vars, cluster, secret = set(), set(), set()
    for row in re.findall(r"^\|[^\n]*\|\s*$", rules_text, re.M):
        cells = row.strip("|").split("|")
        names = set(re.findall(r"`([A-Z][A-Z0-9_]*)`", row))
        all_vars |= names
        first = cells[0] if cells else ""
        if "<cluster>" in first:
            cluster |= names
        if "secret" in first.lower():
            secret |= names
    return all_vars, cluster, secret


LOCAL_TABLE_RE = re.compile(r"^\| *File *\| *Site variables *\|[^\n]*\n\|[-| :]+\|\n((?:\|[^\n]*\|[ \t]*(?:\n|$))+)", re.M)


def local_site_vars(texts):
    """Extra site variables from `| File | Site variables |` tables in one skill (outside the rules block)."""
    rows = "".join(m.group(1) for t in texts for m in LOCAL_TABLE_RE.finditer(t))
    return site_vars(rows)


def open_item_ids(root):
    path = root / "research" / "OPEN-ITEMS.md"
    return set(re.findall(r"^\| ([A-Z]-\d{2}) \|", read(path), re.M)) if path.is_file() else set()


def open_item_owners(root):
    """{ID: 'Blocks skill' cell} for the open rows (6 columns) of research/OPEN-ITEMS.md."""
    path = root / "research" / "OPEN-ITEMS.md"
    rows = re.findall(r"^\| ([A-Z]-\d{2}) \|(?:[^|\n]*\|){4}([^|\n]*)\|\s*$", read(path), re.M) if path.is_file() else []
    return {i: cell.strip() for i, cell in rows}


def check_evals(root):
    """An eval for skill X that names an open item must name one that X owns (catches renumbered IDs).
    IDs that are not in OPEN-ITEMS are allowed: an eval can quote a made-up ID as a FAIL example."""
    owners, errors = open_item_owners(root), []
    for f in sorted((root / "evals").glob("*.md")):
        for i in sorted(set(re.findall(r"\b([A-Z]-\d{2})\b", read(f)))):
            cell = owners.get(i)
            if cell is not None and cell != "all" and f.stem not in re.split(r"[,\s]+", cell):
                errors.append(f"{f.as_posix()}: eval-id: {i} belongs to '{cell}', not {f.stem}")
    return errors


def router_skills(root):
    """Skill names in the router's 'Job -> skill' table (last column), plus 'nkp'."""
    path = root / "skills" / "nkp" / "SKILL.md"
    if not path.is_file():
        return None
    names = set(re.findall(r"^\|.*\| `([a-z0-9-]+)`.*\|\s*$", read(path), re.M))
    return names | {"nkp"} | companion_skills(root)


def companion_skills(root):
    """The companion names; when ../ntnx-skills/skills exists, only those that are there."""
    folder = root.parent / "ntnx-skills" / "skills"
    if not folder.is_dir():
        return set(COMPANION_SKILLS)
    return {n for n in COMPANION_SKILLS if (folder / n / "SKILL.md").is_file()}


def check_block(rel, lang, body, ctx):
    errors = []
    lines = [l.strip() for l in body.splitlines()]
    first = lines[0] if lines else ""
    mark = next((m for m in MARKS if first == m or first.startswith(m + " ")), None)
    if mark is None:
        errors.append(f"{rel}: mark: command block line 1 is {first!r}, not a mark")
    cmds = [l for l in lines[1:] if l and not l.startswith("#") and l not in (SITE_SOURCE, CLUSTER_SOURCE)]
    used = set(VAR_RE.findall(body)) - SHELL_VARS
    if used:
        second = lines[1] if len(lines) > 1 else ""
        want = CLUSTER_SOURCE if used & ctx["cluster"] else SITE_SOURCE
        if second != want:
            errors.append(f"{rel}: source: line 2 is {second!r}, want {want!r}")
    for var in sorted(used - ctx["vars"]):
        errors.append(f"{rel}: var: ${var} is not a site variable or an allowed shell variable")
    for tok in sorted(set(LOWER_TOKEN_RE.findall(body.replace(CLUSTER_PATH, "")))):
        errors.append(f"{rel}: lower-in-block: {tok} in a command block (prose only)")
    for l in cmds:
        if RM_GLOB_RE.search(l):
            errors.append(f"{rel}: rm-glob: {l[:60]!r} (a glob after the cluster name matches other clusters)")
        m = GREP_E_RE.search(l)
        if m and any(":" not in alt for alt in re.sub(r"\([^()]*\):", "x:", m.group(1)).split("|")):
            errors.append(f"{rel}: grep-secret: {m.group(1)[:40]!r} has a pattern without ':' on a file with Secrets")
    shows = [l for l in cmds if secret_prints(l, ctx["secret"])]
    if shows and mark != "# USER-TERMINAL":
        errors.append(f"{rel}: user-terminal: {shows[0][:60]!r} shows a secret, mark it # USER-TERMINAL")
    if mark == "# READ-ONLY":
        for l in cmds:
            if "--help" in l:
                continue
            bare = re.sub(r"'[^']*'|\"[^\"]*\"|<[a-z][a-z0-9._-]*>", "", l)  # quotes and <name> tokens
            if MUTATING_RE.search(bare) or REDIRECT_RE.search(bare):
                errors.append(f"{rel}: readonly-writes: {l[:60]!r} changes state but the mark is READ-ONLY")
                break
    alt = "|".join(sorted(ctx["secret"])) or "(?!x)x"
    if re.search(r"\b(?:" + alt + r")=(?!['\"]?\$|''|\"\"|\s|$)", body):
        errors.append(f"{rel}: secret-literal: a secret value is written in a command block")
    return errors


def scan_text(rel, text, ctx, is_skill_md):
    """Checks that apply to SKILL.md and reference files. `text` has the rules block removed."""
    errors = []
    for f in FENCE_RE.finditer(text):
        if f.group(3).lower() not in NON_SHELL_LANGS:
            errors += check_block(rel, f.group(3).lower(), f.group(4), ctx)
    prose = FENCE_RE.sub("", text)
    for tok in sorted(set(UPPER_TOKEN_RE.findall(text))):
        errors.append(f"{rel}: placeholder: {tok} (use a site variable)")
    for ip, cidr in IPV4_RE.findall(text):
        if ip + cidr not in ALLOWED_IPS:
            errors.append(f"{rel}: ipv4: {ip}{cidr}")
    for host in sorted(set(h.lower() for h in FQDN_RE.findall(text))):
        if not any(host == s or host.endswith("." + s) for s in ALLOWED_DOMAIN_SUFFIXES):
            errors.append(f"{rel}: fqdn: {host}")
    for tok in sorted(set(TOKEN_RE.findall(text))):
        errors.append(f"{rel}: token: {tok[:12]}...")
    for span in sorted(set(PIPE_IN_CODE_RE.findall(text))):
        errors.append(f"{rel}: table-pipe: {span[:40]} (move the command out of the table)")
    for line in prose.splitlines():
        if not UNKNOWN_TRIGGER_RE.search(line):
            continue
        m = UNKNOWN_RE.search(line)
        if not m:
            errors.append(f"{rel}: unknown-form: {line.strip()[:80]}")
        elif m.group(1) not in ctx["ids"]:
            errors.append(f"{rel}: unknown-id: {m.group(1)} is not in research/OPEN-ITEMS.md")
    if ctx["skills"] is not None:
        names = set(SKILL_REF_RE.findall(prose)) | set(SKILL_LINK_RE.findall(prose))
        for line in prose.splitlines():
            if is_skill_md or "skill" in line.lower():
                names |= set(BARE_SKILL_RE.findall(re.sub(r"`[^`]*`\s+bundles?\b", "", line)))
        for name in sorted(names - ctx["skills"]):
            errors.append(f"{rel}: skill-name: {name} is not in the router table or the companion set")
    return errors


def check_skill(skill_md, ctx):
    errors = []
    folder = skill_md.parent
    text = read(skill_md)
    rel = skill_md.as_posix()
    lines = text.splitlines()

    block = extract_block(text)
    if block is None:
        errors.append(f"{rel}: rules-missing: rules block markers missing")
    elif block != ctx["master"]:
        errors.append(f"{rel}: rules-differs: rules block differs from master (run --sync)")

    fm = parse_front_matter(text)
    if fm is None:
        errors.append(f"{rel}: fm-missing: front matter missing")
    else:
        top, meta = fm
        name = top.get("name", "")
        if name != folder.name:
            errors.append(f"{rel}: fm-name: name {name!r} != folder {folder.name!r}")
        elif not NAME_RE.match(name) or len(name) > 64:
            errors.append(f"{rel}: fm-name: name must be lowercase-hyphen, max 64 characters")
        desc = top.get("description", "")
        if not desc:
            errors.append(f"{rel}: fm-desc: description missing")
        elif len(desc) > MAX_DESC_CHARS or len(desc.split()) > MAX_DESC_WORDS:
            errors.append(f"{rel}: fm-desc: description over {MAX_DESC_WORDS} words or {MAX_DESC_CHARS} characters")
        if "metadata" not in top:
            errors.append(f"{rel}: fm-meta: metadata missing")
        elif top["metadata"].startswith("{"):
            errors.append(f"{rel}: fm-meta: write metadata as a block map, not a flow map")
        for key in REQUIRED_META:
            if not meta.get(key):
                errors.append(f"{rel}: fm-meta: metadata.{key} missing")
        body = [l.strip() for l in lines[fm_bounds(lines) + 1:] if l.strip()]
        if block is not None and (len(body) < 2 or not body[0].startswith("# ") or body[1] != BEGIN):
            errors.append(f"{rel}: rules-position: the rules block must come directly after the H1 title")

    refs = sorted((folder / "references").glob("*.md"))
    stripped = text.replace(block, "") if block else text
    extra = local_site_vars([stripped] + [read(r) for r in refs])
    ctx = dict(ctx, vars=ctx["vars"] | extra[0], cluster=ctx["cluster"] | extra[1], secret=ctx["secret"] | extra[2])

    if len(lines) > MAX_SKILL_LINES:
        errors.append(f"{rel}: too-long: {len(lines)} lines > {MAX_SKILL_LINES}")
    errors += scan_text(rel, stripped, ctx, True)

    for ref in refs:
        rtext = read(ref)
        rn = len(rtext.splitlines())
        if rn > MAX_REF_LINES:
            errors.append(f"{ref.as_posix()}: too-long: {rn} lines > {MAX_REF_LINES}")
        errors += scan_text(ref.as_posix(), rtext, ctx, False)
    for f in [skill_md] + refs:
        for target in sorted(set(LINK_RE.findall(read(f)))):
            if not (folder / target).is_file():
                errors.append(f"{f.as_posix()}: link: {target} does not resolve")
    return errors


def skill_files(root):
    return sorted(p for p in (root / "skills").glob("*/SKILL.md") if p.parent.name != "_shared")


def context(root):
    path = root / "skills" / "_shared" / "RULES.md"
    rules = read(path) if path.is_file() else ""
    block = extract_block(rules)
    if block is None:
        raise SystemExit(f"{path}: master rules block not found")
    all_vars, cluster, secret = site_vars(block)
    return {"master": block, "vars": all_vars, "cluster": cluster, "secret": secret,
            "ids": open_item_ids(root), "skills": router_skills(root)}


def sync(root):
    block = context(root)["master"]
    for skill_md in skill_files(root):
        text = read(skill_md)
        old = extract_block(text)
        if old is None:
            print(f"{skill_md}: no markers, add them by hand", file=sys.stderr)
        elif old != block:
            skill_md.write_text(text.replace(old, block), encoding="utf-8")
            print(f"synced {skill_md}")


def check(root):
    ctx = context(root)
    skills = skill_files(root)
    errors = [e for s in skills for e in check_skill(s, ctx)] + check_evals(root)
    for e in errors:
        print(e)
    print(f"{len(skills)} skills checked, {len(errors)} errors")
    return 0 if not errors else 1


def codes(errors):
    return {e.split(": ")[1] for e in errors}


def self_test():
    table = ("| File | Site variables |\n|---|---|\n| `~/nkp-site.env` | `MGMT_KUBECONFIG` `PE_CLUSTER` |\n"
             "| `~/nkp-site.env` secrets | `NUTANIX_PASSWORD` |\n| `~/nkp-<cluster>.env` | `CLUSTER_NAME` `CP_VIP` |\n")
    rules_block = f"{BEGIN}\nrule one\n\n{table}{END}"
    rules = f"# master\n{rules_block}\n"
    fm = ("---\nname: {name}\ndescription: >\n  Does good things.\nmetadata:\n"
          "  nkp_versions:\n    - '2.19'\n  last_verified: '2026-11-02'\n  sources: live\n---\n")
    good = ("\ufeff" + fm.format(name="good") + f"# Good\n\n{rules_block}\n"
            "See [x](references/x.md). Use skill `nkp` and skill `nkp-good`. Pod CIDR 192.168.0.0/16.\n"
            "UNKNOWN (A-05): where the file is. Find out with: `ls -l ./*.conf`.\n"
            "This is rule 6 for UNKNOWN lines.\n"
            "A `<cluster-name>.conf` file. Docs at portal.nutanix.com. Read `nutanix.md` and `nkp-site.env`.\n"
            "Related: `nkp-good`. Grep with `grep -E 'a|b'` in prose.\n"
            "```bash\n# READ-ONLY\nsource ~/nkp-site.env 2>/dev/null\nkubectl --kubeconfig \"$MGMT_KUBECONFIG\" get nodes\n"
            "printenv NUTANIX_PASSWORD >/dev/null && echo set\n[ -n \"$(printenv NUTANIX_PASSWORD)\" ] && echo set\n"
            "nkp create cluster nutanix --help | grep -- '--bundle '\n```\n"
            "1. In a list:\n\n   ```bash\n   # CHANGES  (comment)\n   source ~/nkp-<cluster>.env 2>/dev/null\n"
            "   echo \"export CP_VIP='x'\" >> ~/nkp-<cluster>.env && nkp delete bootstrap -c \"$CLUSTER_NAME\"\n   ```\n"
            "```bash\n# USER-TERMINAL\nsource ~/nkp-site.env 2>/dev/null\nnkp get dashboard --kubeconfig \"$MGMT_KUBECONFIG\"\n```\n"
            "```bash\n# USER-TERMINAL\nvi ~/nkp-site.env\n```\n"
            "```text\nNAME   READY\nMachine/x   True <value>\n```\n```yaml\nkey: <value>\n```\n")
    router = "| Job | Skill |\n|---|---|\n| a | `nkp-good` |\n"
    bad = (fm.format(name="wrong").replace("  sources: live\n", "")
           + f"Intro line\n{BEGIN}\nold rule\n{END}\nSee references/missing.md. Use skill `nkp-airgapp`.\n"
           "Set <FOO_BAR>. Host 10.1.2.3 and reg.customer.corp. Token eyJhbGciOiJIUzI1NiJ9abc.\n"
           "UNKNOWN (Z-99): made up. Find out with: `ls`.\nUNKNOWN: no id here.\n"
           "| a | `base64 < f \\| tr -d x` |\n"
           "```bash\nkubectl delete ns kommander\n```\n"
           "```bash\n# CHANGES\nnkp create cluster -c \"$CLUSTER_NAME\" --x \"$SECRET_X\" <provider>\n```\n"
           + "x\n" * 260)
    long_desc = fm.format(name="wordy").replace("Does good things.", "word " * 70) + "# W\n" + rules_block + "\n"

    def one(text):
        """Codes found by scan_text in one snippet."""
        return codes(scan_text("t", text, ctx, False))

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / "nkp-skills"
        root.mkdir()
        (root / "skills/_shared").mkdir(parents=True)
        (root / "skills/_shared/RULES.md").write_text(rules)
        (root / "research").mkdir()
        (root / "research/OPEN-ITEMS.md").write_text("| ID | Topic |\n|---|---|\n| A-05 | kubeconfig |\n"
                                                     "| P-13 | t | q | w | lab | nkp-good, nkp-x |\n")
        (root / "evals").mkdir()
        (root / "evals/nkp-good.md").write_text("May quote P-13. Not S-01.\n")
        (root / "evals/nkp-bad.md").write_text("May quote P-13.\n")
        for name, text in (("good", good), ("bad", bad), ("wordy", long_desc)):
            (root / f"skills/{name}/references").mkdir(parents=True)
            (root / f"skills/{name}/SKILL.md").write_text(text, encoding="utf-8")
        (root / "skills/nkp").mkdir()
        (root / "skills/nkp/SKILL.md").write_text(router)
        (root / "skills/good/references/x.md").write_text(
            "| File | Site variables |\n|---|---|\n| `~/nkp-site.env` | `AWS_REGION` |\n"
            "| `~/nkp-site.env` secrets | `AWS_SECRET_ACCESS_KEY` |\n| `~/nkp-<cluster>.env` | `CP_HOSTS` |\n\n"
            "```bash\n# READ-ONLY\nsource ~/nkp-<cluster>.env 2>/dev/null\necho \"$AWS_REGION\" \"$CP_HOSTS\"\n```\n")
        (root / "skills/wordy/references/y.md").write_text(
            "```bash\n# READ-ONLY\nsource ~/nkp-site.env 2>/dev/null\necho \"$AWS_REGION\"\n```\n")
        (root / "skills/bad/references/long.md").write_text("y\n" * 401)

        top, meta = parse_front_matter(read(root / "skills/good/SKILL.md"))
        assert top["name"] == "good" and top["description"].endswith("Does good things."), top
        assert meta == {"nkp_versions": "'2.19'", "last_verified": "'2026-11-02'", "sources": "live"}, meta
        assert parse_front_matter("no front matter") is None

        ctx = context(root)
        assert ctx["vars"] == {"MGMT_KUBECONFIG", "PE_CLUSTER", "NUTANIX_PASSWORD", "CLUSTER_NAME", "CP_VIP"}
        assert ctx["cluster"] == {"CLUSTER_NAME", "CP_VIP"} and ctx["secret"] == {"NUTANIX_PASSWORD"}
        assert ctx["ids"] == {"A-05", "P-13"} and ctx["skills"] == {"nkp", "nkp-good"} | COMPANION_SKILLS
        # companion skills: all nine accepted without ../ntnx-skills; only the present ones with it
        assert one("Use skill `nutanix-storage`.\n") == set()
        assert one("Use skill `nutanix-storge`.\n") == {"skill-name"}
        (root.parent / "ntnx-skills/skills/nutanix-storage").mkdir(parents=True)
        (root.parent / "ntnx-skills/skills/nutanix-storage/SKILL.md").write_text("x\n")
        assert companion_skills(root) == {"nutanix-storage"}
        ctx = context(root)
        assert one("Use skill `nutanix-storage`.\n") == set() and one("Use skill `nutanix-vm`.\n") == {"skill-name"}
        (root.parent / "ntnx-skills/skills/nutanix-storage/SKILL.md").unlink()
        (root.parent / "ntnx-skills/skills/nutanix-storage").rmdir()
        (root.parent / "ntnx-skills/skills").rmdir()
        (root.parent / "ntnx-skills").rmdir()
        ctx = context(root)

        got = check_skill(root / "skills/good/SKILL.md", ctx)
        assert got == [], got
        got = check_skill(root / "skills/bad/SKILL.md", ctx)
        expect = {"rules-differs", "rules-position", "fm-name", "fm-meta", "too-long", "link", "mark", "source",
                  "var", "lower-in-block", "placeholder", "ipv4", "fqdn", "token", "unknown-form",
                  "unknown-id", "skill-name", "table-pipe"}
        assert codes(got) == expect, sorted(codes(got) ^ expect)
        assert any("$SECRET_X" in e for e in got) and not any("$CLUSTER_NAME is" in e for e in got)
        assert codes(check_skill(root / "skills/wordy/SKILL.md", ctx)) == {"fm-desc", "var"}  # local vars do not leak
        assert [e.split(": ")[1] for e in check_evals(root)] == ["eval-id"] and "nkp-bad" in check_evals(root)[0]
        assert local_site_vars([read(root / "skills/good/references/x.md")]) == (
            {"AWS_REGION", "AWS_SECRET_ACCESS_KEY", "CP_HOSTS"}, {"CP_HOSTS"}, {"AWS_SECRET_ACCESS_KEY"})

        ro = "```bash\n# READ-ONLY\n{}\n```\n"
        # source line: none without variables; site form for site variables; cluster form for cluster variables
        assert one(ro.format("nkp version")) == set()
        assert one(ro.format('df -h "$TMPDIR"')) == set()
        assert one(ro.format('nkp version "$PE_CLUSTER"')) == {"source"}
        assert one(ro.format('source ~/nkp-site.env\nnkp version "$PE_CLUSTER"')) == {"source"}  # no 2>/dev/null
        assert one(ro.format('source ~/nkp-site.env 2>/dev/null\necho "$CP_VIP"')) == {"source"}
        assert one(ro.format('source ~/nkp-<cluster>.env 2>/dev/null\necho "$CP_VIP"')) == set()
        assert {"source", "lower-in-block"} <= one(ro.format('source ~/nkp-<other>.env 2>/dev/null\necho "$CP_VIP"'))
        # M7: indented fences, ~~~ fences, other languages, plain fences
        assert one("1. x\n\n   ```bash\n   kubectl delete ns kommander\n   ```\n") == {"mark"}
        assert one("~~~bash\nkubectl delete ns kommander\n~~~\n") == {"mark"}
        assert one("```zsh\nls\n```\n") == {"mark"} and one("```console\nls\n```\n") == {"mark"}
        assert one("```\nkubectl delete ns x\n```\n") == {"mark"}
        assert one("```text\noutput only\n```\n") == set()
        # M7: READ-ONLY on a command that changes state
        assert one(ro.format("kubectl delete ns kommander")) == {"readonly-writes"}
        assert one(ro.format("nkp version > out.txt")) == {"readonly-writes"}
        assert one(ro.format('source ~/nkp-site.env 2>/dev/null\nnkp get kubeconfig -c x --kubeconfig "$MGMT_KUBECONFIG"')) == {"readonly-writes"}
        assert one(ro.format("chmod 600 f")) == {"readonly-writes"}
        assert one(ro.format("nkp version 2>/dev/null")) == set()
        assert one(ro.format('bash -n ~/nkp-<cluster>.env 2>/dev/null && echo "a > b" || echo "MISSING: x"')) == set()
        assert one(ro.format("kubectl get pods -o jsonpath='{.a}{\"\\n\"}'")) == set()
        # USER-TERMINAL: commands that show a secret
        assert one(ro.format("cat ~/nkp-site.env")) == {"user-terminal"}
        assert one(ro.format('source ~/nkp-site.env 2>/dev/null\nnkp get dashboard --kubeconfig "$MGMT_KUBECONFIG"')) == {"user-terminal"}
        assert one(ro.format("kubectl get secret x -n y -o yaml")) == {"user-terminal"}
        assert one(ro.format("echo abc | base64 -d")) == {"user-terminal"}
        assert one(ro.format("echo abc | base64 --decode")) == {"user-terminal"}
        assert one(ro.format('source ~/nkp-site.env 2>/dev/null\necho "$NUTANIX_PASSWORD"')) == {"user-terminal"}
        assert one(ro.format("printenv NUTANIX_PASSWORD")) == {"user-terminal"}
        assert one("```bash\n# CHANGES\nvi ~/nkp-site.env\n```\n") == {"user-terminal"}
        assert one("```bash\n# USER-TERMINAL\ncat ~/nkp-site.env\n```\n") == set()
        # M7: a literal secret value in a block
        assert one("```bash\n# CHANGES\ncat >> f <<'EOF'\nexport NUTANIX_PASSWORD='example-P@ssw0rd'\nEOF\n```\n") == {"secret-literal"}
        assert one("```bash\n# CHANGES\nNUTANIX_PASSWORD=abc nkp version\n```\n") == {"secret-literal"}
        # M7: hostnames in URLs, other TLDs, upper case; IPv4 before a path
        for h in ("https://reg.customer.corp/nkp", "harbor.acme.ch", "nkp.lab.cloud", "REG.CUSTOMER.CORP"):
            assert one(f"Use {h} here.\n") == {"fqdn"}, h
        assert one("Open http://10.1.2.3/ui now.\n") == {"ipv4"}
        assert one("Read SKILL.md, kommander.yaml, and helm-repository.caren-system.svc.\n") == set()
        assert one("Pull from docker.io/nutanix and registry.k8s.io.\n") == set()
        # M7: bare backtick skill names (SKILL.md, or lines with "skill") and ../skill links
        assert codes(scan_text("t", "Related: `nkp-airgapp`.\n", ctx, True)) == {"skill-name"}
        assert codes(scan_text("t", "Related: `nkp-airgapp`.\n", ctx, False)) == set()
        assert one("Use the skill `nkp-airgapp`.\n") == {"skill-name"}
        assert one("The skill uses the `nkp-release-specs` bundle.\n") == set()
        assert one("See [x](../nkp-nope/SKILL.md).\n") == {"skill-name"}
        # M7: UNKNOWN needs a backtick check command; prose "UNKNOWN lines" is no UNKNOWN line
        assert one("UNKNOWN (A-05): x. Find out with: ask the user.\n") == {"unknown-form"}
        assert one("Rule 6 covers UNKNOWN lines.\n") == set()
        # batch 1 fix pass: rm glob after the cluster name; dry-run grep patterns without ':'
        assert one('```bash\n# CHANGES\nsource ~/nkp-<cluster>.env 2>/dev/null\nrm -f -- "$HOME/nkp-$CLUSTER_NAME-"*\n```\n') == {"rm-glob"}
        assert one('```bash\n# CHANGES\nsource ~/nkp-<cluster>.env 2>/dev/null\nrm -f -- "$HOME/nkp-$CLUSTER_NAME.env"\n```\n') == set()
        g = '```bash\n# READ-ONLY\nsource ~/nkp-<cluster>.env 2>/dev/null\ngrep -n -E \'{}\' "$PWD/$CLUSTER_NAME-dryrun.yaml"\n```\n'
        assert one(g.format("^kind:|image|url:")) == {"grep-secret"}
        assert one(g.format("^kind:|^ +(image|ami|url):|host:")) == set()
        # M3: \| in a code span
        assert one("| a | `grep -E 'a\\|b'` |\n") == {"table-pipe"}

        # front matter: trailing space on the closing line, flow map metadata
        fm_space = fm.format(name="sp").replace("\n---\n", "\n--- \n", 1).replace("---\nname", "---\nname", 1)
        (root / "skills/sp").mkdir()
        (root / "skills/sp/SKILL.md").write_text(fm_space + "# Sp\n" + rules_block + "\n")
        assert check_skill(root / "skills/sp/SKILL.md", ctx) == []
        flow = "---\nname: fl\ndescription: d\nmetadata: {nkp_versions: '2.19'}\n---\n# Fl\n" + rules_block + "\n"
        (root / "skills/fl").mkdir()
        (root / "skills/fl/SKILL.md").write_text(flow)
        assert codes(check_skill(root / "skills/fl/SKILL.md", ctx)) == {"fm-meta"}

        # missing markers and missing front matter
        (root / "skills/bare").mkdir()
        (root / "skills/bare/SKILL.md").write_text("# Bare\nno markers\n")
        assert codes(check_skill(root / "skills/bare/SKILL.md", ctx)) == {"rules-missing", "fm-missing"}

        quiet = io.StringIO()
        with contextlib.redirect_stdout(quiet), contextlib.redirect_stderr(quiet):
            sync(root)  # also must not crash on "bare" (no markers)
            assert "rules-differs" not in codes(check_skill(root / "skills/bad/SKILL.md", ctx))
            assert check(root) == 1
        assert "no markers, add them by hand" in quiet.getvalue()
    assert set(CODES) >= expect | {"fm-desc", "readonly-writes", "user-terminal", "secret-literal"}
    print("self-test passed")
    return 0


def main(argv):
    root = Path(__file__).resolve().parent.parent
    if "--self-test" in argv:
        return self_test()
    if "--sync" in argv:
        sync(root)
    return check(root)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
