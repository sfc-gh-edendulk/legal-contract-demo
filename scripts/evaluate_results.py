import os
import json
import argparse
from difflib import SequenceMatcher
from snowflake.snowpark import Session

CONNECTION_NAME = os.getenv("SNOWFLAKE_CONNECTION_NAME") or "CURSOR-AZURE_NETHERLANDS"


def get_session():
    return Session.builder.config("connection_name", CONNECTION_NAME).create()


def normalize(s):
    return s.lower().strip().replace("-", " ").replace("/", " ").replace("_", " ")


def fuzzy_match_category(detected_type, cuad_categories):
    detected_norm = normalize(detected_type)
    best_score = 0
    best_cat = None
    for cat in cuad_categories:
        cat_norm = normalize(cat)
        score = SequenceMatcher(None, detected_norm, cat_norm).ratio()
        if score > best_score:
            best_score = score
            best_cat = cat
        if detected_norm in cat_norm or cat_norm in detected_norm:
            score = max(score, 0.85)
            if score > best_score:
                best_score = score
                best_cat = cat
    return (best_cat, best_score) if best_score >= 0.55 else (None, 0)


def jaccard_similarity(text_a, text_b):
    words_a = set(normalize(text_a).split())
    words_b = set(normalize(text_b).split())
    if not words_a or not words_b:
        return 0.0
    intersection = words_a & words_b
    union = words_a | words_b
    return len(intersection) / len(union)


def evaluate_run(session, run_id):
    print(f"\nEvaluating run: {run_id}")

    run_meta = session.sql(f"""
        SELECT METHOD, MODEL, CONTRACT_COUNT
        FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        WHERE RUN_ID = '{run_id}'
    """).collect()
    if not run_meta:
        print(f"  Run {run_id} not found")
        return
    method = run_meta[0]["METHOD"]
    print(f"  Method: {method}")

    results = session.sql(f"""
        SELECT CONTRACT_ID, PARSED_OUTPUT, OUTPUT_RAW
        FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
        WHERE RUN_ID = '{run_id}' AND STEP = 'clause_extraction' AND ERROR IS NULL
    """).collect()
    print(f"  Results: {len(results)} contracts")

    ground_truth = session.sql("""
        SELECT CONTRACT_ID, CUAD_CATEGORY, IS_PRESENT, ANSWER_SPANS, EXPECTED_TEAM
        FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.CUAD_GROUND_TRUTH
        WHERE IS_PRESENT = TRUE AND EXPECTED_TEAM != ''
    """).collect()

    gt_by_contract = {}
    for r in ground_truth:
        cid = r["CONTRACT_ID"]
        if cid not in gt_by_contract:
            gt_by_contract[cid] = []
        spans_raw = r["ANSWER_SPANS"]
        spans = json.loads(spans_raw) if isinstance(spans_raw, str) else spans_raw
        gt_by_contract[cid].append({
            "category": r["CUAD_CATEGORY"],
            "team": r["EXPECTED_TEAM"],
            "spans": spans if isinstance(spans, list) else [],
        })

    all_cuad_categories = list(set(r["CUAD_CATEGORY"] for r in ground_truth))

    session.sql(f"DELETE FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.EVAL_METRICS WHERE RUN_ID = '{run_id}'").collect()

    metrics_to_insert = []

    for res in results:
        cid = res["CONTRACT_ID"]
        gt_clauses = gt_by_contract.get(cid, [])
        if not gt_clauses:
            continue

        parsed = res["PARSED_OUTPUT"]
        if parsed is None:
            raw = res["OUTPUT_RAW"]
            if raw:
                if isinstance(raw, str):
                    raw = raw.strip()
                    if raw.startswith("```"):
                        raw = raw.split("\n", 1)[-1] if "\n" in raw else raw[3:]
                    if raw.endswith("```"):
                        raw = raw[:-3].strip()
                try:
                    parsed = json.loads(raw) if isinstance(raw, str) else raw
                except (json.JSONDecodeError, TypeError):
                    continue
            else:
                continue

        if isinstance(parsed, str):
            try:
                parsed = json.loads(parsed)
            except (json.JSONDecodeError, TypeError):
                continue

        if isinstance(parsed, dict):
            detected_clauses = parsed.get("clauses", [parsed])
        elif isinstance(parsed, list):
            detected_clauses = parsed
        else:
            continue

        detected_types = []
        for c in detected_clauses:
            if isinstance(c, dict):
                ct = c.get("clause_type", c.get("type", ""))
                if ct:
                    detected_types.append(ct)

        gt_categories = [g["category"] for g in gt_clauses]
        true_positives = 0
        matched_gt = set()
        team_correct = 0
        team_total = 0
        overlap_scores = []

        for c in detected_clauses:
            if not isinstance(c, dict):
                continue
            ct = c.get("clause_type", c.get("type", ""))
            if not ct:
                continue
            matched_cat, match_score = fuzzy_match_category(ct, gt_categories)
            if matched_cat and matched_cat not in matched_gt:
                true_positives += 1
                matched_gt.add(matched_cat)

                gt_entry = next((g for g in gt_clauses if g["category"] == matched_cat), None)
                if gt_entry:
                    detected_team = c.get("assigned_team", "")
                    if detected_team:
                        team_total += 1
                        if normalize(detected_team) == normalize(gt_entry["team"]):
                            team_correct += 1

                    clause_text = c.get("clause_text", "")
                    if clause_text and gt_entry["spans"]:
                        gt_text = " ".join(s.get("text", "") for s in gt_entry["spans"] if isinstance(s, dict))
                        if gt_text:
                            overlap = jaccard_similarity(clause_text, gt_text)
                            overlap_scores.append(overlap)

        precision = true_positives / len(detected_clauses) if detected_clauses else 0
        recall = true_positives / len(gt_clauses) if gt_clauses else 0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
        team_acc = team_correct / team_total if team_total > 0 else 0
        avg_overlap = sum(overlap_scores) / len(overlap_scores) if overlap_scores else 0

        metrics_to_insert.extend([
            (run_id, cid, "clause_detection_precision", precision),
            (run_id, cid, "clause_detection_recall", recall),
            (run_id, cid, "clause_detection_f1", f1),
            (run_id, cid, "team_accuracy", team_acc),
            (run_id, cid, "text_overlap_jaccard", avg_overlap),
        ])

    for run_id_v, cid_v, metric, value in metrics_to_insert:
        session.sql(f"""
            INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.EVAL_METRICS
            (RUN_ID, CONTRACT_ID, METRIC_NAME, METRIC_VALUE)
            SELECT '{run_id_v}', '{cid_v}', '{metric}', {value}
        """).collect()

    summary = session.sql(f"""
        SELECT METRIC_NAME, AVG(METRIC_VALUE) AS AVG_VAL, COUNT(*) AS CNT
        FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.EVAL_METRICS
        WHERE RUN_ID = '{run_id}'
        GROUP BY METRIC_NAME
        ORDER BY METRIC_NAME
    """).collect()

    print(f"\n  Summary for {method}:")
    for r in summary:
        print(f"    {r['METRIC_NAME']}: {r['AVG_VAL']:.3f} (n={r['CNT']})")


def main():
    parser = argparse.ArgumentParser(description="Evaluate experiment results against CUAD ground truth")
    parser.add_argument("--run-id", help="Specific run ID to evaluate")
    parser.add_argument("--all", action="store_true", help="Evaluate all runs")
    args = parser.parse_args()

    session = get_session()
    session.sql("USE WAREHOUSE COMPUTE_WH").collect()

    if args.run_id:
        evaluate_run(session, args.run_id)
    elif args.all:
        runs = session.sql("""
            SELECT RUN_ID, METHOD
            FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
            WHERE FINISHED_AT IS NOT NULL
            ORDER BY STARTED_AT
        """).collect()
        if not runs:
            print("No completed runs found")
        for r in runs:
            evaluate_run(session, r["RUN_ID"])
    else:
        runs = session.sql("""
            SELECT RUN_ID, METHOD
            FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
            ORDER BY STARTED_AT DESC
            LIMIT 1
        """).collect()
        if runs:
            evaluate_run(session, runs[0]["RUN_ID"])
        else:
            print("No runs found. Run experiments first with run_experiments.py")

    session.close()


if __name__ == "__main__":
    main()
