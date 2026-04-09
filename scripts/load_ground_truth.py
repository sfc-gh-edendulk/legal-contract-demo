import os
import json
import hashlib
from snowflake.snowpark import Session

CONNECTION_NAME = os.getenv("SNOWFLAKE_CONNECTION_NAME") or "CURSOR-AZURE_NETHERLANDS"

TEAM_MAP = {
    "Governing Law": "Legal",
    "Anti-Assignment": "Legal",
    "Change of Control": "Legal",
    "Termination For Convenience": "Legal",
    "Non-Disparagement": "Legal",
    "Rofr/Rofo/Rofn": "Legal",
    "Covenant Not To Sue": "Legal",
    "Third Party Beneficiary": "Legal",
    "IP Ownership Assignment": "Technical/Ops",
    "Joint IP Ownership": "Technical/Ops",
    "License Grant": "Technical/Ops",
    "Non-Transferable License": "Technical/Ops",
    "Source Code Escrow": "Technical/Ops",
    "Post-Termination Services": "Technical/Ops",
    "Warranty Duration": "Technical/Ops",
    "Insurance": "Technical/Ops",
    "Revenue/Profit Sharing": "Sales",
    "Price Restrictions": "Sales",
    "Minimum Commitment": "Sales",
    "Volume Restriction": "Sales",
    "Exclusivity": "Sales",
    "Non-Compete": "Sales",
    "Audit Rights": "Sales",
    "Most Favored Nation": "Sales",
    "Liquidated Damages": "Sales",
    "Uncapped Liability": "Sales",
    "Cap On Liability": "Sales",
    "Unlimited/All-You-Can-Eat-License": "Marketing",
    "Irrevocable Or Perpetual License": "Marketing",
    "No-Solicit Of Customers": "Marketing",
    "No-Solicit Of Employees": "Marketing",
    "Competitive Restriction Exception": "Marketing",
    "Affiliate License-Licensor": "Marketing",
    "Affiliate License-Licensee": "Marketing",
}

SKIP_CATEGORIES = {"Document Name", "Parties", "Agreement Date", "Effective Date", "Expiration Date"}


def filename_to_contract_id(filename):
    return hashlib.md5(filename.encode()).hexdigest()[:12]


def main():
    session = Session.builder.config("connection_name", CONNECTION_NAME).create()
    session.sql("USE WAREHOUSE COMPUTE_WH").collect()

    loaded_contracts = session.sql(
        "SELECT CONTRACT_ID, FILENAME FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT"
    ).collect()
    loaded_map = {}
    for r in loaded_contracts:
        base = r["FILENAME"].rsplit(".", 1)[0] if "." in r["FILENAME"] else r["FILENAME"]
        loaded_map[base] = r["CONTRACT_ID"]
    print(f"Found {len(loaded_map)} loaded contracts in Snowflake")

    cuad_path = os.path.join(os.path.dirname(__file__), "..", "CUAD_v1", "CUAD_v1.json")
    if not os.path.exists(cuad_path):
        cuad_path = os.path.join(os.path.dirname(__file__), "..", "Atticus Open Contract Dataset", "CUAD_v1.json")
    if not os.path.exists(cuad_path):
        print("ERROR: Cannot find CUAD_v1.json. Download from https://www.atticusprojectai.org/cuad/")
        return

    with open(cuad_path) as f:
        cuad = json.load(f)

    print(f"CUAD dataset: {len(cuad['data'])} contracts")

    rows = []
    matched = 0
    for doc in cuad["data"]:
        title = doc["title"]
        base = title.rsplit(".", 1)[0] if "." in title else title
        contract_id = loaded_map.get(base)
        if not contract_id:
            continue
        matched += 1

        for para in doc["paragraphs"]:
            for qa in para["qas"]:
                category = qa["id"].rsplit("/", 1)[-1] if "/" in qa["id"] else qa["id"]
                parts = category.split("__")
                if len(parts) >= 2:
                    category = parts[-1].replace("-", " ").title().replace(" ", " ")
                    raw_cat = parts[-1]
                else:
                    raw_cat = category

                cuad_cat = qa.get("question", "").split("?")[0].strip() if qa.get("question") else raw_cat

                for known in list(TEAM_MAP.keys()) + list(SKIP_CATEGORIES):
                    if known.lower().replace(" ", "").replace("-", "").replace("/", "") in \
                       cuad_cat.lower().replace(" ", "").replace("-", "").replace("/", ""):
                        cuad_cat = known
                        break

                if cuad_cat in SKIP_CATEGORIES:
                    continue

                is_impossible = qa.get("is_impossible", True)
                answers = qa.get("answers", [])
                spans = [{"text": a["text"], "answer_start": a["answer_start"]} for a in answers]
                team = TEAM_MAP.get(cuad_cat, "")

                rows.append({
                    "contract_id": contract_id,
                    "filename": title,
                    "cuad_category": cuad_cat,
                    "is_present": not is_impossible,
                    "answer_spans": spans,
                    "expected_team": team,
                })

    print(f"Matched {matched} contracts, {len(rows)} category annotations")

    session.sql("TRUNCATE TABLE LEGAL_CONTRACT_DEMO.EXPERIMENTS.CUAD_GROUND_TRUTH").collect()

    batch_size = 100
    inserted = 0
    for i in range(0, len(rows), batch_size):
        batch = rows[i:i + batch_size]
        for r in batch:
            spans_json = json.dumps(r["answer_spans"]).replace("'", "''")
            session.sql(f"""
                INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.CUAD_GROUND_TRUTH
                (CONTRACT_ID, FILENAME, CUAD_CATEGORY, IS_PRESENT, ANSWER_SPANS, EXPECTED_TEAM)
                SELECT '{r["contract_id"]}',
                       '{r["filename"].replace("'", "''")}',
                       '{r["cuad_category"].replace("'", "''")}',
                       {str(r["is_present"]).upper()},
                       PARSE_JSON('{spans_json}'),
                       '{r["expected_team"]}'
            """).collect()
            inserted += 1

        print(f"  Inserted {inserted}/{len(rows)} rows...")

    final = session.sql("SELECT COUNT(*) AS CNT FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.CUAD_GROUND_TRUTH").collect()
    present = session.sql("SELECT COUNT(*) AS CNT FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.CUAD_GROUND_TRUTH WHERE IS_PRESENT").collect()
    print(f"\nDone! {final[0]['CNT']} rows total, {present[0]['CNT']} with clauses present")
    session.close()


if __name__ == "__main__":
    main()
