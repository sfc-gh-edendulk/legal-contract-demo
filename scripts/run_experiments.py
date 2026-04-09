import os
import json
import time
import argparse
import uuid
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, lit, concat, substr, call_function

CONNECTION_NAME = os.getenv("SNOWFLAKE_CONNECTION_NAME") or "CURSOR-AZURE_NETHERLANDS"

CLAUSE_PROMPT = """Extract 8-12 key clauses from this contract as a JSON array. Each element must have: {"clause_type":"...", "clause_text":"exact quote up to 300 chars", "assigned_team":"Legal|Technical/Ops|Sales|Marketing", "risk_level":"High|Medium|Low", "risk_explanation":"1 sentence"}

Team assignment rules:
- Legal: Governing Law, Anti-Assignment, Change of Control, Termination, Indemnification, Confidentiality, Non-Disparagement, ROFR/ROFO
- Technical/Ops: IP Ownership, License Grant, Warranty, Source Code Escrow, SLAs, Technical specs, Post-Termination Services
- Sales: Revenue Sharing, Pricing, Minimum Commitment, Exclusivity, Non-Compete, Audit Rights, Payment Terms
- Marketing: Promotional rights, Branding, No-Solicit, Competitive Restriction, Unlimited License

Risk rules:
- High: One-sided terms, uncapped liability, broad restrictions, no termination rights
- Medium: Notable terms needing review
- Low: Standard balanced terms

Return ONLY a JSON array, no other text.

CONTRACT:
"""

AI_EXTRACT_CATEGORIES = [
    'Governing Law', 'Anti-Assignment', 'Change of Control',
    'Termination For Convenience', 'Non-Disparagement',
    'IP Ownership Assignment', 'License Grant', 'Non-Transferable License',
    'Revenue/Profit Sharing', 'Price Restrictions', 'Minimum Commitment',
    'Exclusivity', 'Non-Compete', 'Audit Rights',
    'Unlimited/All-You-Can-Eat-License', 'Irrevocable Or Perpetual License',
    'No-Solicit Of Customers', 'Warranty Duration',
    'Source Code Escrow', 'Post-Termination Services',
    'Most Favored Nation', 'Liquidated Damages',
    'Cap On Liability', 'Uncapped Liability',
    'Competitive Restriction Exception', 'Insurance',
]

TEAM_MAP = {
    "Governing Law": "Legal",
    "Anti-Assignment": "Legal",
    "Change of Control": "Legal",
    "Termination For Convenience": "Legal",
    "Non-Disparagement": "Legal",
    "IP Ownership Assignment": "Technical/Ops",
    "License Grant": "Technical/Ops",
    "Non-Transferable License": "Technical/Ops",
    "Revenue/Profit Sharing": "Sales",
    "Price Restrictions": "Sales",
    "Minimum Commitment": "Sales",
    "Exclusivity": "Sales",
    "Non-Compete": "Sales",
    "Audit Rights": "Sales",
    "Unlimited/All-You-Can-Eat-License": "Marketing",
    "Irrevocable Or Perpetual License": "Marketing",
    "No-Solicit Of Customers": "Marketing",
    "Warranty Duration": "Technical/Ops",
    "Source Code Escrow": "Technical/Ops",
    "Post-Termination Services": "Technical/Ops",
    "Most Favored Nation": "Sales",
    "Liquidated Damages": "Sales",
    "Cap On Liability": "Sales",
    "Uncapped Liability": "Sales",
    "Competitive Restriction Exception": "Marketing",
    "Insurance": "Technical/Ops",
}


_session = None

def get_session():
    global _session
    if _session is not None:
        try:
            _session.sql("SELECT 1").collect()
            return _session
        except Exception:
            _session = None
    _session = Session.builder.config("connection_name", CONNECTION_NAME).create()
    _session.sql("USE WAREHOUSE COMPUTE_WH").collect()
    return _session


def safe_sql_string(s):
    return s.replace("\\", "\\\\").replace("'", "''")


def parse_json_response(raw):
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        start = 1
        end = len(lines)
        for i in range(len(lines) - 1, 0, -1):
            if lines[i].strip().startswith("```"):
                end = i
                break
        cleaned = "\n".join(lines[start:end])
    for ch in ["[", "{"]:
        idx = cleaned.find(ch)
        if idx >= 0:
            end_ch = "]" if ch == "[" else "}"
            end_idx = cleaned.rfind(end_ch)
            if end_idx > idx:
                try:
                    return json.loads(cleaned[idx:end_idx + 1])
                except json.JSONDecodeError:
                    pass
    return None


def run_complete(session, contracts, run_id):
    total_clauses = 0
    for i, row in enumerate(contracts):
        cid = row["CONTRACT_ID"]
        tlen = row["TEXT_LEN"]
        truncate_len = min(tlen, 60000)
        print(f"  [{i + 1}/{len(contracts)}] {cid} ({tlen} chars)", end=" ... ", flush=True)

        session = get_session()
        t0 = time.time()
        error = None
        output_raw = ""
        clause_count = 0

        try:
            result = session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.COMPLETE(
                    'mistral-large2',
                    CONCAT('{safe_sql_string(CLAUSE_PROMPT)}', SUBSTR(FULL_TEXT, 1, {truncate_len}))
                ) AS result
                FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT
                WHERE CONTRACT_ID = '{cid}'
            """).collect()

            if result:
                output_raw = result[0]["RESULT"] or ""
                clauses = parse_json_response(output_raw)
                if isinstance(clauses, list):
                    clause_count = len(clauses)
                    total_clauses += clause_count
        except Exception as e:
            error = str(e)[:500]

        wall_ms = (time.time() - t0) * 1000

        session.sql(f"""
            INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
            (RUN_ID, CONTRACT_ID, STEP, WALL_TIME_MS, INPUT_CHARS, OUTPUT_RAW, PARSED_OUTPUT, CLAUSE_COUNT, ERROR)
            SELECT '{run_id}', '{cid}', 'clause_extraction', {wall_ms}, {tlen},
                   '{safe_sql_string(output_raw[:16000])}',
                   TRY_PARSE_JSON('{safe_sql_string(output_raw[:16000])}'),
                   {clause_count},
                   {f"'{safe_sql_string(error)}'" if error else 'NULL'}
        """).collect()

        print(f"{clause_count} clauses ({wall_ms:.0f}ms)" if not error else f"ERROR: {error[:80]}")
        time.sleep(0.3)

    return total_clauses


def run_ai_extract(session, contracts, run_id):
    total_clauses = 0
    for i, row in enumerate(contracts):
        cid = row["CONTRACT_ID"]
        tlen = row["TEXT_LEN"]
        print(f"  [{i + 1}/{len(contracts)}] {cid} ({tlen} chars)", end=" ... ", flush=True)

        t0 = time.time()
        error = None
        output_raw = ""
        clause_count = 0
        clauses_found = []

        for cat in AI_EXTRACT_CATEGORIES:
            try:
                result = session.sql(f"""
                    SELECT AI_EXTRACT(
                        text => SUBSTR(FULL_TEXT, 1, 60000),
                        responseFormat => {{
                            'schema': {{
                                'type': 'object',
                                'properties': {{
                                    'clause_text': {{
                                        'description': 'Exact quote of the {cat} clause, up to 300 characters. Return empty string if not found.',
                                        'type': 'string'
                                    }}
                                }}
                            }}
                        }}
                    ) AS EXTRACTION
                    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT
                    WHERE CONTRACT_ID = '{cid}'
                """).collect()

                if result:
                    ext = result[0]["EXTRACTION"]
                    if ext:
                        parsed = json.loads(ext) if isinstance(ext, str) else ext
                        resp = parsed.get("response", {}) if isinstance(parsed, dict) else {}
                        clause_text = resp.get("clause_text", "")
                        if clause_text and len(clause_text) > 10:
                            clauses_found.append({
                                "clause_type": cat,
                                "clause_text": clause_text,
                                "assigned_team": TEAM_MAP.get(cat, "Legal"),
                            })
            except Exception as e:
                if not error:
                    error = f"{cat}: {str(e)[:200]}"

        clause_count = len(clauses_found)
        total_clauses += clause_count
        output_raw = json.dumps(clauses_found)

        wall_ms = (time.time() - t0) * 1000

        session.sql(f"""
            INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
            (RUN_ID, CONTRACT_ID, STEP, WALL_TIME_MS, INPUT_CHARS, OUTPUT_RAW, PARSED_OUTPUT, CLAUSE_COUNT, ERROR)
            SELECT '{run_id}', '{cid}', 'clause_extraction', {wall_ms}, {tlen},
                   '{safe_sql_string(output_raw[:16000])}',
                   TRY_PARSE_JSON('{safe_sql_string(output_raw[:16000])}'),
                   {clause_count},
                   {f"'{safe_sql_string(error)}'" if error else 'NULL'}
        """).collect()

        print(f"{clause_count} clauses ({wall_ms:.0f}ms)" if not error else f"ERROR: {error[:80]}")

    return total_clauses


def run_hybrid(session, contracts, run_id):
    total_clauses = 0
    for i, row in enumerate(contracts):
        cid = row["CONTRACT_ID"]
        tlen = row["TEXT_LEN"]
        print(f"  [{i + 1}/{len(contracts)}] {cid} ({tlen} chars)", end=" ... ", flush=True)

        t0_extract = time.time()
        error = None
        clauses_found = []

        for cat in AI_EXTRACT_CATEGORIES:
            try:
                result = session.sql(f"""
                    SELECT AI_EXTRACT(
                        text => SUBSTR(FULL_TEXT, 1, 60000),
                        responseFormat => {{
                            'schema': {{
                                'type': 'object',
                                'properties': {{
                                    'clause_text': {{
                                        'description': 'Exact quote of the {cat} clause, up to 300 chars. Return empty if not found.',
                                        'type': 'string'
                                    }}
                                }}
                            }}
                        }}
                    ) AS EXTRACTION
                    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT
                    WHERE CONTRACT_ID = '{cid}'
                """).collect()

                if result:
                    ext = result[0]["EXTRACTION"]
                    if ext:
                        parsed = json.loads(ext) if isinstance(ext, str) else ext
                        resp = parsed.get("response", {}) if isinstance(parsed, dict) else {}
                        clause_text = resp.get("clause_text", "")
                        if clause_text and len(clause_text) > 10:
                            clauses_found.append({
                                "clause_type": cat,
                                "clause_text": clause_text,
                            })
            except Exception as e:
                if not error:
                    error = f"extract/{cat}: {str(e)[:200]}"

        extract_ms = (time.time() - t0_extract) * 1000

        t0_classify = time.time()
        for clause in clauses_found:
            try:
                risk_result = session.sql(f"""
                    SELECT AI_CLASSIFY(
                        '{safe_sql_string(clause["clause_text"][:500])}',
                        [
                            {{'label': 'High', 'description': 'One-sided terms, uncapped liability, broad restrictions'}},
                            {{'label': 'Medium', 'description': 'Notable terms needing review'}},
                            {{'label': 'Low', 'description': 'Standard balanced terms'}}
                        ],
                        {{'task_description': 'Classify contract clause risk level'}}
                    ):labels[0]::VARCHAR AS RISK
                """).collect()
                clause["risk_level"] = risk_result[0]["RISK"] if risk_result else "Medium"
            except Exception:
                clause["risk_level"] = "Medium"

            try:
                team_result = session.sql(f"""
                    SELECT AI_CLASSIFY(
                        '{safe_sql_string(clause["clause_type"] + ": " + clause["clause_text"][:500])}',
                        [
                            {{'label': 'Legal', 'description': 'Governing Law, Termination, Indemnification, Anti-Assignment'}},
                            {{'label': 'Technical/Ops', 'description': 'IP Ownership, License, Warranty, Source Code'}},
                            {{'label': 'Sales', 'description': 'Revenue, Pricing, Exclusivity, Non-Compete, Audit'}},
                            {{'label': 'Marketing', 'description': 'Branding, No-Solicit, Unlimited License'}}
                        ],
                        {{'task_description': 'Route contract clause to responsible review team'}}
                    ):labels[0]::VARCHAR AS TEAM
                """).collect()
                clause["assigned_team"] = team_result[0]["TEAM"] if team_result else TEAM_MAP.get(clause["clause_type"], "Legal")
            except Exception:
                clause["assigned_team"] = TEAM_MAP.get(clause["clause_type"], "Legal")

        classify_ms = (time.time() - t0_classify) * 1000
        total_ms = extract_ms + classify_ms

        clause_count = len(clauses_found)
        total_clauses += clause_count
        output_raw = json.dumps(clauses_found)

        session.sql(f"""
            INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
            (RUN_ID, CONTRACT_ID, STEP, WALL_TIME_MS, INPUT_CHARS, OUTPUT_RAW, PARSED_OUTPUT, CLAUSE_COUNT, ERROR)
            SELECT '{run_id}', '{cid}', 'clause_extraction', {total_ms}, {tlen},
                   '{safe_sql_string(output_raw[:16000])}',
                   TRY_PARSE_JSON('{safe_sql_string(output_raw[:16000])}'),
                   {clause_count},
                   {f"'{safe_sql_string(error)}'" if error else 'NULL'}
        """).collect()

        print(f"{clause_count} clauses (extract={extract_ms:.0f}ms, classify={classify_ms:.0f}ms)")

    return total_clauses


def main():
    parser = argparse.ArgumentParser(description="Run contract analysis experiments")
    parser.add_argument("--method", choices=["complete", "ai_extract", "hybrid", "all"], default="all")
    parser.add_argument("--limit", type=int, default=0, help="Limit number of contracts (0=all)")
    args = parser.parse_args()

    session = get_session()
    session.sql("USE WAREHOUSE COMPUTE_WH").collect()

    limit_clause = f"LIMIT {args.limit}" if args.limit > 0 else ""
    contracts = session.sql(f"""
        SELECT CONTRACT_ID, CONTRACT_TYPE, LENGTH(FULL_TEXT) AS TEXT_LEN
        FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT
        ORDER BY TEXT_LEN ASC
        {limit_clause}
    """).collect()

    print(f"Running experiments on {len(contracts)} contracts\n")

    methods = [args.method] if args.method != "all" else ["complete", "ai_extract", "hybrid"]

    for method in methods:
        run_id = str(uuid.uuid4())[:12]
        print(f"\n{'='*60}")
        print(f"Method: {method} | Run ID: {run_id}")
        print(f"{'='*60}\n")

        model = "mistral-large2" if method == "complete" else "cortex-aisql"

        session.sql(f"""
            INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
            (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES)
            SELECT '{run_id}', '{method}', '{model}', {len(contracts)},
                   'Experiment run with {len(contracts)} contracts'
        """).collect()

        t0 = time.time()

        if method == "complete":
            total_clauses = run_complete(session, contracts, run_id)
        elif method == "ai_extract":
            total_clauses = run_ai_extract(session, contracts, run_id)
        elif method == "hybrid":
            total_clauses = run_hybrid(session, contracts, run_id)
        else:
            print(f"Unknown method: {method}")
            continue

        total_secs = time.time() - t0

        session.sql(f"""
            UPDATE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
            SET FINISHED_AT = CURRENT_TIMESTAMP(),
                TOTAL_WALL_TIME_SECS = {total_secs},
                CLAUSE_COUNT = {total_clauses}
            WHERE RUN_ID = '{run_id}'
        """).collect()

        print(f"\n{method} complete: {total_clauses} clauses in {total_secs:.1f}s")

    print("\nAll experiments complete!")
    session.close()


if __name__ == "__main__":
    main()
