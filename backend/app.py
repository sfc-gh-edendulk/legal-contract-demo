import os
import json
from flask import Flask, jsonify, request, send_from_directory
from snowflake_utils import get_session

app = Flask(__name__, static_folder="../frontend/build", static_url_path="")


@app.route("/api/contracts", methods=["GET"])
def list_contracts():
    session = get_session()
    team_filter = request.args.get("team")
    risk_filter = request.args.get("risk")
    search = request.args.get("search", "")

    query = """
        SELECT
            cs.CONTRACT_ID,
            cs.CONTRACT_NAME,
            cs.CONTRACT_TYPE,
            cs.PARTIES,
            cs.EFFECTIVE_DATE,
            cs.EXPIRATION_DATE,
            cs.OVERALL_RISK,
            cs.SUMMARY_TEXT,
            cs.TEAM_REVIEW_STATUS,
            ct.UPLOADED_AT,
            (SELECT COUNT(*) FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS ca
             WHERE ca.CONTRACT_ID = cs.CONTRACT_ID) as CLAUSE_COUNT,
            (SELECT COUNT(*) FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS ca
             WHERE ca.CONTRACT_ID = cs.CONTRACT_ID AND ca.RISK_LEVEL = 'High') as HIGH_RISK_COUNT
        FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY cs
        JOIN LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT ct ON cs.CONTRACT_ID = ct.CONTRACT_ID
        WHERE 1=1
    """

    if risk_filter:
        query += f" AND cs.OVERALL_RISK = '{risk_filter}'"
    if search:
        safe_search = search.replace("'", "''")
        query += f" AND (cs.CONTRACT_NAME ILIKE '%{safe_search}%' OR cs.PARTIES ILIKE '%{safe_search}%' OR cs.CONTRACT_TYPE ILIKE '%{safe_search}%')"

    query += " ORDER BY cs.OVERALL_RISK DESC, cs.CONTRACT_NAME"

    rows = session.sql(query).collect()
    contracts = []
    for r in rows:
        contracts.append({
            "contract_id": r["CONTRACT_ID"],
            "contract_name": r["CONTRACT_NAME"],
            "contract_type": r["CONTRACT_TYPE"],
            "parties": r["PARTIES"],
            "effective_date": r["EFFECTIVE_DATE"],
            "expiration_date": r["EXPIRATION_DATE"],
            "overall_risk": r["OVERALL_RISK"],
            "summary_text": r["SUMMARY_TEXT"],
            "team_review_status": json.loads(r["TEAM_REVIEW_STATUS"]) if r["TEAM_REVIEW_STATUS"] else {},
            "clause_count": r["CLAUSE_COUNT"],
            "high_risk_count": r["HIGH_RISK_COUNT"],
            "uploaded_at": str(r["UPLOADED_AT"]) if r["UPLOADED_AT"] else None,
        })
    return jsonify(contracts)


@app.route("/api/contracts/<contract_id>", methods=["GET"])
def get_contract(contract_id):
    session = get_session()

    summary = session.sql(f"""
        SELECT * FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY
        WHERE CONTRACT_ID = '{contract_id}'
    """).collect()

    text = session.sql(f"""
        SELECT FULL_TEXT, FILENAME, CONTRACT_TYPE
        FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT
        WHERE CONTRACT_ID = '{contract_id}'
    """).collect()

    if not summary or not text:
        return jsonify({"error": "Contract not found"}), 404

    s = summary[0]
    t = text[0]

    return jsonify({
        "contract_id": contract_id,
        "contract_name": s["CONTRACT_NAME"],
        "contract_type": s["CONTRACT_TYPE"],
        "parties": s["PARTIES"],
        "effective_date": s["EFFECTIVE_DATE"],
        "expiration_date": s["EXPIRATION_DATE"],
        "overall_risk": s["OVERALL_RISK"],
        "summary_text": s["SUMMARY_TEXT"],
        "key_findings": json.loads(s["KEY_FINDINGS"]) if s["KEY_FINDINGS"] else [],
        "team_review_status": json.loads(s["TEAM_REVIEW_STATUS"]) if s["TEAM_REVIEW_STATUS"] else {},
        "full_text": t["FULL_TEXT"],
        "filename": t["FILENAME"],
    })


@app.route("/api/contracts/<contract_id>/clauses", methods=["GET"])
def get_clauses(contract_id):
    session = get_session()
    team_filter = request.args.get("team")

    query = f"""
        SELECT CLAUSE_ID, CLAUSE_TYPE, CLAUSE_TEXT, ASSIGNED_TEAM,
               RISK_LEVEL, RISK_EXPLANATION, REVIEW_STATUS, ANALYZED_AT
        FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS
        WHERE CONTRACT_ID = '{contract_id}'
    """
    if team_filter:
        query += f" AND ASSIGNED_TEAM = '{team_filter}'"
    query += " ORDER BY CASE RISK_LEVEL WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END, CLAUSE_TYPE"

    rows = session.sql(query).collect()
    clauses = []
    for r in rows:
        clauses.append({
            "clause_id": r["CLAUSE_ID"],
            "clause_type": r["CLAUSE_TYPE"],
            "clause_text": r["CLAUSE_TEXT"],
            "assigned_team": r["ASSIGNED_TEAM"],
            "risk_level": r["RISK_LEVEL"],
            "risk_explanation": r["RISK_EXPLANATION"],
            "review_status": r["REVIEW_STATUS"],
        })
    return jsonify(clauses)


@app.route("/api/contracts/<contract_id>/clauses/<clause_id>/review", methods=["POST"])
def update_clause_review(contract_id, clause_id):
    session = get_session()
    data = request.get_json()
    status = data.get("status", "reviewed")

    session.sql(f"""
        UPDATE LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS
        SET REVIEW_STATUS = '{status}'
        WHERE CLAUSE_ID = '{clause_id}' AND CONTRACT_ID = '{contract_id}'
    """).collect()

    return jsonify({"success": True})


@app.route("/api/teams/<team>/review", methods=["GET"])
def get_team_review(team):
    session = get_session()
    safe_team = team.replace("'", "''")

    rows = session.sql(f"""
        SELECT ca.CLAUSE_ID, ca.CONTRACT_ID, ca.CLAUSE_TYPE, ca.CLAUSE_TEXT,
               ca.RISK_LEVEL, ca.RISK_EXPLANATION, ca.REVIEW_STATUS,
               cs.CONTRACT_NAME, cs.CONTRACT_TYPE
        FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS ca
        JOIN LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY cs
            ON ca.CONTRACT_ID = cs.CONTRACT_ID
        WHERE ca.ASSIGNED_TEAM = '{safe_team}'
        ORDER BY CASE ca.RISK_LEVEL WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END,
                 cs.CONTRACT_NAME
    """).collect()

    clauses = []
    for r in rows:
        clauses.append({
            "clause_id": r["CLAUSE_ID"],
            "contract_id": r["CONTRACT_ID"],
            "contract_name": r["CONTRACT_NAME"],
            "contract_type": r["CONTRACT_TYPE"],
            "clause_type": r["CLAUSE_TYPE"],
            "clause_text": r["CLAUSE_TEXT"],
            "risk_level": r["RISK_LEVEL"],
            "risk_explanation": r["RISK_EXPLANATION"],
            "review_status": r["REVIEW_STATUS"],
        })
    return jsonify(clauses)


@app.route("/api/dashboard/stats", methods=["GET"])
def get_dashboard_stats():
    session = get_session()

    total = session.sql("SELECT COUNT(*) as CNT FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY").collect()[0]["CNT"]
    risk_dist = session.sql("""
        SELECT OVERALL_RISK, COUNT(*) as CNT
        FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CONTRACT_SUMMARY
        GROUP BY OVERALL_RISK
    """).collect()
    team_dist = session.sql("""
        SELECT ASSIGNED_TEAM, RISK_LEVEL, COUNT(*) as CNT
        FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS
        GROUP BY ASSIGNED_TEAM, RISK_LEVEL
    """).collect()
    review_status = session.sql("""
        SELECT ASSIGNED_TEAM, REVIEW_STATUS, COUNT(*) as CNT
        FROM LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS
        GROUP BY ASSIGNED_TEAM, REVIEW_STATUS
    """).collect()

    return jsonify({
        "total_contracts": total,
        "risk_distribution": {r["OVERALL_RISK"]: r["CNT"] for r in risk_dist},
        "team_distribution": [{"team": r["ASSIGNED_TEAM"], "risk": r["RISK_LEVEL"], "count": r["CNT"]} for r in team_dist],
        "review_status": [{"team": r["ASSIGNED_TEAM"], "status": r["REVIEW_STATUS"], "count": r["CNT"]} for r in review_status],
    })


@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def serve_react(path):
    if path and os.path.exists(os.path.join(app.static_folder, path)):
        return send_from_directory(app.static_folder, path)
    return send_from_directory(app.static_folder, "index.html")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=os.environ.get("FLASK_DEBUG", "false").lower() == "true")
