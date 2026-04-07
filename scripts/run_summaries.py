import os
import json
import time
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, lit, concat, substr, call_function

CONNECTION_NAME = os.getenv("SNOWFLAKE_CONNECTION_NAME") or "CURSOR-AZURE_NETHERLANDS"

def get_session():
    return Session.builder.config("connection_name", CONNECTION_NAME).create()

def parse_json_response(raw):
    if not raw:
        return None
    raw = raw.strip()
    if raw.startswith("```"):
        lines = raw.split("\n")
        start_idx = 1
        end_idx = len(lines)
        for i in range(len(lines)-1, 0, -1):
            if lines[i].strip() == "```":
                end_idx = i
                break
        raw = "\n".join(lines[start_idx:end_idx]).strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass
    for ch, end_ch in [("{", "}"), ("[", "]")]:
        idx = raw.find(ch)
        end_idx = raw.rfind(end_ch)
        if idx >= 0 and end_idx > idx:
            try:
                return json.loads(raw[idx:end_idx+1])
            except json.JSONDecodeError:
                pass
    return None

SUMMARY_PROMPT = 'Analyze this contract and return a JSON object with: {"contract_name":"title", "parties":"party1; party2", "effective_date":"date or Not specified", "expiration_date":"date or Not specified", "overall_risk":"High|Medium|Low", "summary_text":"3-5 sentence summary", "key_findings":["finding1","finding2","finding3"]}. Return ONLY valid JSON, no markdown code blocks. CONTRACT: '

def main():
    session = get_session()
    session.sql("USE WAREHOUSE COMPUTE_WH").collect()
    session.sql("TRUNCATE TABLE LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY").collect()

    contracts = session.sql("""
        SELECT CONTRACT_ID, CONTRACT_TYPE
        FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT
        ORDER BY LENGTH(FULL_TEXT) ASC
    """).collect()

    print(f"Generating summaries for {len(contracts)} contracts\n")
    success = 0

    for i, row in enumerate(contracts):
        cid = row["CONTRACT_ID"]
        ctype = row["CONTRACT_TYPE"]
        print(f"[{i+1}/{len(contracts)}] {cid} ({ctype})", end=" ... ", flush=True)

        try:
            df = session.table("LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT").filter(col("CONTRACT_ID") == cid)
            result_df = df.select(
                call_function("SNOWFLAKE.CORTEX.COMPLETE",
                    lit("mistral-large2"),
                    concat(lit(SUMMARY_PROMPT), substr(col("FULL_TEXT"), lit(1), lit(60000)))
                ).alias("RESULT")
            )
            result = result_df.collect()

            if result:
                summary = parse_json_response(result[0]["RESULT"])
                if isinstance(summary, dict) and "contract_name" in summary:
                    import pandas as pd
                    from snowflake.snowpark import Row

                    kf = json.dumps(summary.get("key_findings", []))
                    ts = json.dumps({"Legal":"pending","Technical/Ops":"pending","Sales":"pending","Marketing":"pending"})

                    session.sql("""
                        INSERT INTO LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY
                        (CONTRACT_ID, CONTRACT_NAME, CONTRACT_TYPE, PARTIES, EFFECTIVE_DATE,
                         EXPIRATION_DATE, OVERALL_RISK, SUMMARY_TEXT, KEY_FINDINGS, TEAM_REVIEW_STATUS)
                        SELECT ?, ?, ?, ?, ?, ?, ?, ?, PARSE_JSON(?), PARSE_JSON(?)
                    """, params=[
                        cid,
                        str(summary.get("contract_name", "Unknown"))[:500],
                        ctype,
                        str(summary.get("parties", ""))[:1000],
                        str(summary.get("effective_date", ""))[:100],
                        str(summary.get("expiration_date", ""))[:100],
                        str(summary.get("overall_risk", "Medium"))[:10],
                        str(summary.get("summary_text", ""))[:4000],
                        kf,
                        ts,
                    ]).collect()

                    print(f"OK ({summary.get('overall_risk', '?')})")
                    success += 1
                else:
                    print(f"PARSE FAIL")
                    if summary:
                        print(f"    Got: {str(summary)[:120]}")
        except Exception as e:
            print(f"ERROR: {str(e)[:120]}")

        time.sleep(0.5)

    print(f"\nDone! {success}/{len(contracts)} summaries generated")
    session.close()

if __name__ == "__main__":
    main()
