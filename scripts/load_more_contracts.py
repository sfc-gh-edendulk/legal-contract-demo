import os
import json
import hashlib
from snowflake.snowpark import Session

CONNECTION_NAME = os.getenv("SNOWFLAKE_CONNECTION_NAME") or "CURSOR-AZURE_NETHERLANDS"
TARGET_TOTAL = 60

def filename_to_contract_id(filename):
    return hashlib.md5(filename.encode()).hexdigest()[:12]


def main():
    session = Session.builder.config("connection_name", CONNECTION_NAME).create()
    session.sql("USE WAREHOUSE COMPUTE_WH").collect()

    existing = session.sql(
        "SELECT FILENAME FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT"
    ).collect()
    existing_bases = set()
    for r in existing:
        base = r["FILENAME"].rsplit(".", 1)[0]
        existing_bases.add(base)
    print(f"Already loaded: {len(existing_bases)} contracts")

    cuad_path = os.path.join(os.path.dirname(__file__), "..", "CUAD_v1", "CUAD_v1.json")
    with open(cuad_path) as f:
        cuad = json.load(f)

    txt_dir = os.path.join(os.path.dirname(__file__), "..", "CUAD_v1", "full_contract_txt")
    txt_files = {f.rsplit(".txt", 1)[0]: f for f in os.listdir(txt_dir) if f.endswith(".txt")}

    cuad_titles = {}
    for doc in cuad["data"]:
        title = doc["title"]
        present_count = 0
        for para in doc["paragraphs"]:
            for qa in para["qas"]:
                if not qa.get("is_impossible", True):
                    present_count += 1
        for base, fname in txt_files.items():
            if base.startswith(title) or title.startswith(base):
                cuad_titles[title] = {"txt_file": fname, "txt_base": base, "present_count": present_count}
                break

    print(f"CUAD docs with txt files: {len(cuad_titles)}")

    candidates = []
    for title, info in cuad_titles.items():
        base = info["txt_base"]
        if base not in existing_bases:
            candidates.append((title, info))

    candidates.sort(key=lambda x: -x[1]["present_count"])
    need = TARGET_TOTAL - len(existing_bases)
    to_load = candidates[:need]
    print(f"Loading {len(to_load)} new contracts (target total: {TARGET_TOTAL})")

    loaded = 0
    for title, info in to_load:
        txt_path = os.path.join(txt_dir, info["txt_file"])
        with open(txt_path, "r", errors="replace") as f:
            text = f.read()

        pdf_filename = info["txt_base"] + ".pdf"
        contract_id = filename_to_contract_id(pdf_filename)

        text_escaped = text.replace("\\", "\\\\").replace("'", "''")
        if len(text_escaped) > 1_000_000:
            text_escaped = text_escaped[:1_000_000]

        try:
            session.sql(f"""
                INSERT INTO LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT
                (CONTRACT_ID, FILENAME, FULL_TEXT, UPLOADED_AT)
                SELECT '{contract_id}',
                       '{pdf_filename.replace("'", "''")}',
                       '{text_escaped}',
                       CURRENT_TIMESTAMP()
            """).collect()
            loaded += 1
            if loaded % 10 == 0:
                print(f"  Loaded {loaded}/{len(to_load)}...")
        except Exception as e:
            print(f"  SKIP {info['txt_file'][:60]}: {str(e)[:100]}")

    total = session.sql("SELECT COUNT(*) AS CNT FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT").collect()
    print(f"\nDone! Total contracts in Snowflake: {total[0]['CNT']}")
    session.close()


if __name__ == "__main__":
    main()
