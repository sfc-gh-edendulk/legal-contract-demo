import os
import json
import time
from snowflake.snowpark import Session

CONNECTION_NAME = os.getenv("SNOWFLAKE_CONNECTION_NAME") or "CURSOR-AZURE_NETHERLANDS"

def get_session():
    return Session.builder.config("connection_name", CONNECTION_NAME).create()

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

SUMMARY_PROMPT = """Analyze this contract and return a JSON object with: {"contract_name":"title of agreement", "parties":"party1; party2", "effective_date":"date or Not specified", "expiration_date":"date or Not specified", "overall_risk":"High|Medium|Low", "summary_text":"3-5 sentence summary", "key_findings":["finding1","finding2","finding3"]}

Return ONLY valid JSON, no other text.

CONTRACT:
"""

def safe_sql_string(s):
    return s.replace("\\", "\\\\").replace("'", "''")

def parse_json_response(raw):
    if not raw:
        return None
    try:
        parsed = json.loads(raw)
        return parsed
    except json.JSONDecodeError:
        pass
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        start = 1
        if lines[0].strip().startswith("```"):
            start = 1
        end = len(lines)
        for i in range(len(lines)-1, 0, -1):
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
                    return json.loads(cleaned[idx:end_idx+1])
                except json.JSONDecodeError:
                    pass
    return None

def main():
    session = get_session()
    session.sql("USE WAREHOUSE COMPUTE_WH").collect()

    session.sql("TRUNCATE TABLE LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS").collect()
    session.sql("TRUNCATE TABLE LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY").collect()

    contracts = session.sql("""
        SELECT CONTRACT_ID, CONTRACT_TYPE, FILENAME, LENGTH(FULL_TEXT) as TEXT_LEN
        FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT
        ORDER BY TEXT_LEN ASC
    """).collect()

    print(f"Processing {len(contracts)} contracts\n")

    for i, row in enumerate(contracts):
        cid = row["CONTRACT_ID"]
        ctype = row["CONTRACT_TYPE"]
        fname = row["FILENAME"][:60]
        tlen = row["TEXT_LEN"]
        truncate_len = min(tlen, 60000)

        print(f"[{i+1}/{len(contracts)}] {cid} ({ctype}, {tlen} chars)")

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
                clauses = parse_json_response(result[0]["RESULT"])
                if isinstance(clauses, list):
                    for clause in clauses:
                        ct = safe_sql_string(str(clause.get("clause_type", "Unknown")))[:200]
                        cx = safe_sql_string(str(clause.get("clause_text", "")))[:4000]
                        team = safe_sql_string(str(clause.get("assigned_team", "Legal")))[:50]
                        risk = safe_sql_string(str(clause.get("risk_level", "Medium")))[:10]
                        expl = safe_sql_string(str(clause.get("risk_explanation", "")))[:4000]

                        session.sql(f"""
                            INSERT INTO LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS
                            (CONTRACT_ID, CLAUSE_TYPE, CLAUSE_TEXT, ASSIGNED_TEAM, RISK_LEVEL, RISK_EXPLANATION)
                            VALUES ('{cid}', '{ct}', '{cx}', '{team}', '{risk}', '{expl}')
                        """).collect()

                    print(f"  Clauses: {len(clauses)}")
                else:
                    print(f"  WARNING: Could not parse clauses")
        except Exception as e:
            print(f"  ERROR (clauses): {str(e)[:100]}")

        try:
            result = session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.COMPLETE(
                    'mistral-large2',
                    CONCAT('{safe_sql_string(SUMMARY_PROMPT)}', SUBSTR(FULL_TEXT, 1, {truncate_len}))
                ) AS result
                FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT
                WHERE CONTRACT_ID = '{cid}'
            """).collect()

            if result:
                summary = parse_json_response(result[0]["RESULT"])
                if isinstance(summary, dict):
                    cn = safe_sql_string(str(summary.get("contract_name", "Unknown")))[:500]
                    parties = safe_sql_string(str(summary.get("parties", "")))[:1000]
                    ed = safe_sql_string(str(summary.get("effective_date", "")))[:100]
                    xd = safe_sql_string(str(summary.get("expiration_date", "")))[:100]
                    risk = safe_sql_string(str(summary.get("overall_risk", "Medium")))[:10]
                    st = safe_sql_string(str(summary.get("summary_text", "")))[:4000]
                    kf = safe_sql_string(json.dumps(summary.get("key_findings", [])))
                    ts = safe_sql_string(json.dumps({"Legal":"pending","Technical/Ops":"pending","Sales":"pending","Marketing":"pending"}))

                    session.sql(f"""
                        INSERT INTO LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY
                        (CONTRACT_ID, CONTRACT_NAME, CONTRACT_TYPE, PARTIES, EFFECTIVE_DATE,
                         EXPIRATION_DATE, OVERALL_RISK, SUMMARY_TEXT, KEY_FINDINGS, TEAM_REVIEW_STATUS)
                        VALUES ('{cid}', '{cn}', '{safe_sql_string(ctype)}',
                                '{parties}', '{ed}', '{xd}', '{risk}', '{st}',
                                PARSE_JSON('{kf}'), PARSE_JSON('{ts}'))
                    """).collect()
                    print(f"  Summary: {risk} risk")
                else:
                    print(f"  WARNING: Could not parse summary")
        except Exception as e:
            print(f"  ERROR (summary): {str(e)[:100]}")

        time.sleep(0.5)

    clause_count = session.sql("SELECT COUNT(*) as CNT FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS").collect()[0]["CNT"]
    summary_count = session.sql("SELECT COUNT(*) as CNT FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY").collect()[0]["CNT"]
    print(f"\nDone! {clause_count} clauses, {summary_count} summaries")

    session.close()

if __name__ == "__main__":
    main()
