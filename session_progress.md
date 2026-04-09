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
