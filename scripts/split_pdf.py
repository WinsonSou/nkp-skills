"""Split the NKP PDF into one text file per level-2 TOC section, for subagent reading."""
import re, sys, pymupdf
pdf, out = sys.argv[1], sys.argv[2]
d = pymupdf.open(pdf)
toc = [(l, t, p) for l, t, p in d.get_toc() if l <= 2]
idx = []
for i, (l, t, p) in enumerate(toc):
    end = next((q for (l2, _, q) in toc[i+1:] if l2 <= l), d.page_count + 1)
    if l == 2 or not any(l2 == 2 for l2, _, q in toc[i+1:i+2]):
        slug = re.sub(r'[^a-z0-9]+', '-', t.lower()).strip('-')[:60]
        name = f"{p:04d}-{slug}.txt"
        with open(f"{out}/{name}", "w") as f:
            for n in range(p - 1, end - 1):
                f.write(f"\n--- page {n+1} ---\n" + d[n].get_text())
        idx.append(f"{name}\tpages {p}-{end-1}\t{t}")
open(f"{out}/INDEX.tsv", "w").write("\n".join(idx) + "\n")
print(len(idx))
