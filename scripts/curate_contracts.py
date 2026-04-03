import csv
import os
import re

CUAD_DIR = "/Users/edendulk/code/legal_demo/CUAD_v1"
CSV_PATH = os.path.join(CUAD_DIR, "master_clauses.csv")
TXT_DIR = os.path.join(CUAD_DIR, "full_contract_txt")
OUTPUT_DIR = "/Users/edendulk/code/legal_demo/scripts"

CONTRACT_TYPE_PATTERNS = {
    "License Agreement": r"license",
    "Distribution Agreement": r"distribut",
    "Agency Agreement": r"agency",
    "Joint Venture": r"joint venture",
    "Franchise Agreement": r"franchise",
    "Hosting Agreement": r"hosting",
    "IP Agreement": r"\bip\b|intellectual property",
    "Endorsement Agreement": r"endorsement",
    "Co-Branding Agreement": r"co-?brand",
    "Consulting Agreement": r"consult",
    "Services Agreement": r"service",
    "Cooperation Agreement": r"cooperat",
    "Development Agreement": r"develop",
    "Reseller Agreement": r"resell",
    "Strategic Alliance": r"strategic alliance",
    "Manufacturing Agreement": r"manufactur",
    "Content License": r"content license",
    "Affiliate Agreement": r"affiliate",
    "Site Development": r"site development",
}

CLAUSE_COLUMNS = [
    "Governing Law", "Most Favored Nation", "Non-Compete", "Exclusivity",
    "No-Solicit Of Customers", "No-Solicit Of Employees", "Non-Disparagement",
    "Termination For Convenience", "Rofr/Rofo/Rofn", "Change Of Control",
    "Anti-Assignment", "Revenue/Profit Sharing", "Price Restrictions",
    "Minimum Commitment", "Volume Restriction", "Ip Ownership Assignment",
    "Joint Ip Ownership", "License Grant", "Non-Transferable License",
    "Affiliate License-Licensor", "Affiliate License-Licensee",
    "Unlimited/All-You-Can-Eat-License", "Irrevocable Or Perpetual License",
    "Source Code Escrow", "Post-Termination Services", "Audit Rights",
    "Uncapped Liability", "Cap On Liability", "Liquidated Damages",
    "Warranty Duration", "Insurance", "Covenant Not To Sue",
    "Third Party Beneficiary"
]


def detect_contract_type(filename):
    fn_lower = filename.lower()
    for ctype, pattern in CONTRACT_TYPE_PATTERNS.items():
        if re.search(pattern, fn_lower):
            return ctype
    return "Other"


def count_non_empty_clauses(row, headers):
    count = 0
    for col in CLAUSE_COLUMNS:
        idx = None
        for i, h in enumerate(headers):
            if col.lower() in h.lower() and "answer" not in h.lower():
                idx = i
                break
        if idx is not None and idx < len(row) and row[idx].strip() and row[idx].strip() != "[]":
            count += 1
    return count


def main():
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        headers = next(reader)
        rows = list(reader)

    contracts = []
    for row in rows:
        filename = row[0]
        ctype = detect_contract_type(filename)
        clause_count = count_non_empty_clauses(row, headers)
        txt_match = None
        if os.path.exists(TXT_DIR):
            for txt_file in os.listdir(TXT_DIR):
                base = filename.replace(".pdf", "")
                if base in txt_file or txt_file.startswith(base[:30]):
                    txt_match = txt_file
                    break
        contracts.append({
            "filename": filename,
            "type": ctype,
            "clause_count": clause_count,
            "txt_file": txt_match,
        })

    type_groups = {}
    for c in contracts:
        type_groups.setdefault(c["type"], []).append(c)

    for t in type_groups:
        type_groups[t].sort(key=lambda x: x["clause_count"], reverse=True)

    selected = []
    target = 30
    per_type = max(2, target // len(type_groups))

    for ctype, group in sorted(type_groups.items()):
        take = min(per_type, len(group))
        selected.extend(group[:take])

    if len(selected) < target:
        remaining = [c for c in contracts if c not in selected]
        remaining.sort(key=lambda x: x["clause_count"], reverse=True)
        selected.extend(remaining[:target - len(selected)])

    selected = selected[:target]

    print(f"Selected {len(selected)} contracts across {len(set(c['type'] for c in selected))} types:\n")
    for c in selected:
        print(f"  [{c['type']}] {c['filename'][:80]} (clauses: {c['clause_count']})")

    output_file = os.path.join(OUTPUT_DIR, "selected_contracts.txt")
    with open(output_file, "w") as f:
        for c in selected:
            f.write(f"{c['filename']}|{c['type']}|{c['txt_file'] or ''}\n")

    print(f"\nWrote selection to {output_file}")


if __name__ == "__main__":
    main()
