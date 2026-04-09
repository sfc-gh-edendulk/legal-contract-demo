# Session Progress - Legal Contract Review Demo

## Session 1 - 2026-04-03

### Completed
- [x] Project planning and architecture design
- [x] Project scaffold, git repo, GitHub remote
- [x] Snowflake database, schema, stages, data loading
- [x] Cortex AI contract analysis pipeline
- [x] Flask backend API
- [x] React frontend application
- [x] Docker image and SPCS deployment
- [x] Testing and documentation

### Key Decisions
- Backend: Flask (Python) with Snowpark
- Frontend: React 18 + Tailwind CSS
- Database: LEGAL_CONTRACT_DEMO
- Compute pool: LEGAL_DEMO_CP (new, CPU_X64_S)
- Dataset: ~30 curated CUAD contracts
- UI language: English
- GitHub: sfc-gh-edendulk/legal-contract-demo

### Notes
- CUAD v1 dataset has 510 contracts, 41 clause categories
- Contracts are ~13-30KB text each
- Using crocevia conda env (Python 3.11, Snowpark 1.41.0)

## Session 2 - 2026-04-09

### Completed (branch: legal-demo-ai-refactor)
- [x] Task 1: EXPERIMENTS schema + 4 tables (RUN_METADATA, RUN_RESULTS, EVAL_METRICS, CUAD_GROUND_TRUTH)
- [x] Task 2: AI SQL pipeline scripts (pipeline_ai_extract.sql, pipeline_ai_classify.sql)
- [x] Task 3: CUAD ground truth loader (load_ground_truth.py) — 1189 rows loaded
- [x] Task 4: Experiment runner (run_experiments.py) — supports complete, ai_extract, hybrid methods
- [x] Task 5: Evaluation scoring (evaluate_results.py) — precision/recall/F1, team accuracy, text overlap
- [x] Task 6: Experiment Dashboard (ExperimentDashboard.jsx + 3 backend endpoints)
- [x] Task 7: run_analysis.py --method flag (complete|hybrid) + README updated

### New Files
- snowflake/experiments_setup.sql
- scripts/load_ground_truth.py
- scripts/pipeline_ai_extract.sql
- scripts/pipeline_ai_classify.sql
- scripts/run_experiments.py
- scripts/evaluate_results.py
- frontend/src/components/ExperimentDashboard.jsx

### Modified Files
- backend/app.py (added /api/experiments/* endpoints)
- frontend/src/App.jsx (added /experiments route + nav)
- scripts/run_analysis.py (added --method flag, hybrid pipeline)
- README.md (experiment docs, updated project structure)

## Session 3 - 2026-04-09

### Completed (branch: legal-demo-ai-refactor)
- [x] Pivoted from Python experiment runner to SQL Stored Procedures (Snowpark session timeouts)
- [x] Created 3 SPs: RUN_EXPERIMENT_COMPLETE(), RUN_EXPERIMENT_AI_EXTRACT(), RUN_EXPERIMENT_HYBRID()
- [x] Ran all 3 experiments on 29 contracts
- [x] Scored results against CUAD ground truth with evaluate_results.py --all
- [x] Fixed evaluate_results.py to handle markdown code fences in CORTEX.COMPLETE output
- [x] Committed and pushed snowflake/experiment_sps.sql + evaluation fix

### Experiment Results

| Method     | Precision | Recall | F1    | Team Acc | Text Overlap | Wall Time | Contracts |
|------------|-----------|--------|-------|----------|--------------|-----------|-----------|
| hybrid     | 0.890     | 0.351  | 0.490 | 0.792    | 0.453        | 750s      | 28        |
| ai_extract | 0.893     | 0.341  | 0.480 | 0.000    | 0.448        | 1562s     | 28        |
| complete   | 0.505     | 0.421  | 0.445 | 0.691    | 0.330        | 477s      | 29        |

**Winner: hybrid** — best F1, team accuracy, and text overlap. ~2x faster than pure AI_EXTRACT.

### Key Observations
- AI_EXTRACT/HYBRID have high precision (~89%) but lower recall — find correct clauses but miss some
- COMPLETE has better recall (0.421) but worse precision (0.505) — hallucinates clause types
- ai_extract shows 0% team accuracy because it doesn't assign teams (no AI_CLASSIFY step)
- Stored procedures avoid Snowpark client session timeout issues on long-running Cortex calls

### New Files
- snowflake/experiment_sps.sql (3 stored procedures, no LIMIT params)

### Modified Files
- scripts/evaluate_results.py (markdown fence stripping for COMPLETE output)
- scripts/run_experiments.py (session refresh pattern)

### Run IDs
- complete: 468fed36-ee87-4ffe-8178-1efa68f17cd3
- ai_extract: 23e41501-2acd-43af-9517-c345865ea5b1
- hybrid: 75b8b09e-2469-4d72-9746-71ac49268e50

### Remaining
- [ ] Test /experiments dashboard in browser
- [ ] Wire hybrid as default pipeline (Task 7 of plan)
- [ ] Merge to main
