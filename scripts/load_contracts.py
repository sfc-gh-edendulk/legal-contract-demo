import os
import hashlib
from snowflake.snowpark import Session

CUAD_DIR = "/Users/edendulk/code/legal_demo/CUAD_v1"
TXT_DIR = os.path.join(CUAD_DIR, "full_contract_txt")
SELECTED_FILE = "/Users/edendulk/code/legal_demo/scripts/selected_contracts.txt"

CONNECTION_NAME = os.getenv("SNOWFLAKE_CONNECTION_NAME") or "CURSOR-AZURE_NETHERLANDS"

def get_session():
    return Session.builder.config("connection_name", CONNECTION_NAME).create()

def find_txt_file(filename):
    base = filename.replace(".pdf", "").replace(".PDF", "")
    all_txt = os.listdir(TXT_DIR)
    for f in all_txt:
        f_base = f.replace(".txt", "")
        if base == f_base:
            return os.path.join(TXT_DIR, f)
    for f in all_txt:
        f_base = f.replace(".txt", "")
        if base[:40] in f_base or f_base[:40] in base:
            return os.path.join(TXT_DIR, f)
    return None

def main():
    with open(SELECTED_FILE, "r") as f:
        lines = f.readlines()

    session = get_session()
    session.sql("USE DATABASE LEGAL_CONTRACT_DEMO").collect()
    session.sql("USE SCHEMA RAW").collect()
    session.sql("USE WAREHOUSE COMPUTE_WH").collect()

    rows = []
    for line in lines:
        parts = line.strip().split("|")
        if len(parts) < 2:
            continue
        filename = parts[0]
        contract_type = parts[1]

        txt_path = find_txt_file(filename)
        if not txt_path:
            print(f"  SKIP (no txt): {filename[:60]}")
            continue

        with open(txt_path, "r", encoding="utf-8", errors="replace") as tf:
            full_text = tf.read()

        if len(full_text) < 100:
            print(f"  SKIP (too short): {filename[:60]}")
            continue

        if len(full_text) > 500000:
            full_text = full_text[:500000]

        contract_id = hashlib.md5(filename.encode()).hexdigest()[:12]
        rows.append((contract_id, filename, contract_type, full_text))
        print(f"  Prepared [{contract_type}]: {filename[:70]}")

    if rows:
        import pandas as pd
        pdf = pd.DataFrame(rows, columns=["CONTRACT_ID", "FILENAME", "CONTRACT_TYPE", "FULL_TEXT"])
        sp_df = session.create_dataframe(pdf)
        sp_df.write.mode("append").save_as_table(
            "LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT",
            column_order="name"
        )
        print(f"\nLoaded {len(rows)} contracts into LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT")
    else:
        print("No contracts to load")

    session.close()

if __name__ == "__main__":
    main()
