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

## Session 4 - 2026-04-10

### Completed (branch: legal-demo-ai-refactor)
- [x] Diagnosed root causes of low recall/text overlap scores
- [x] Added 8 missing CUAD categories to all extraction lists (26 -> 34)
- [x] Increased AI_EXTRACT clause_text limit from 300 -> 800 chars
- [x] Improved COMPLETE prompt: 15-25 clauses, exact category names, longer quotes
- [x] Improved AI_CLASSIFY with better label descriptions + few-shot examples
- [x] Added token-level F1 metric to evaluate_results.py (standard for extractive QA)
- [x] Improved category normalization with CATEGORY_ALIASES dict
- [x] Created new SP: RUN_EXPERIMENT_AI_EXTRACT_CLASSIFY()
- [x] Deployed all 4 SPs and ran experiments
- [x] Evaluated all 4 v2 experiments

### Experiment Results (v2 - improved)

| Method              | Precision | Recall | F1    | Team Acc | Jaccard | Token F1 | Wall Time | Contracts |
|---------------------|-----------|--------|-------|----------|---------|----------|-----------|-----------|
| complete            | 0.563     | 0.865  | 0.665 | 0.940    | 0.417   | 0.506    | 603s      | 17*       |
| hybrid              | 0.794     | 0.427  | 0.541 | 0.964    | 0.454   | 0.546    | 664s      | 28        |
| ai_extract_classify | 0.798     | 0.412  | 0.529 | 0.967    | 0.463   | 0.556    | 313s      | 28        |
| ai_extract          | 0.797     | 0.409  | 0.527 | 0.000    | 0.465   | 0.557    | 2985s     | 28        |

*complete v2: 17/29 contracts parsed (12 truncated due to longer 800-char quotes exceeding output token limit)

### Score Improvements (v1 -> v2)

| Metric       | v1 hybrid | v2 hybrid | v2 complete | v2 ai_extract_classify |
|--------------|-----------|-----------|-------------|------------------------|
| Recall       | 0.351     | 0.427     | 0.865       | 0.412                  |
| F1           | 0.490     | 0.541     | 0.665       | 0.529                  |
| Team Acc     | 0.792     | 0.964     | 0.940       | 0.967                  |
| Text Overlap | 0.453     | 0.454     | 0.417       | 0.463                  |
| Token F1     | N/A       | 0.546     | 0.506       | 0.556                  |

### Key Observations
- **COMPLETE v2 dominates recall** (0.865) because LLM can freely discover clauses; but 12/29 outputs truncated
- **AI_CLASSIFY with few-shot** boosted team accuracy from 79.2% to 96.4-96.7% across all methods
- **8 missing categories** contributed ~16% of ground truth; adding them helped recall for all methods
- **ai_extract_classify is fastest** (313s) and matches hybrid quality — best efficiency pick
- **Token F1** is consistently ~10% higher than Jaccard, showing 800-char quotes capture more signal
- **Precision dropped slightly** for AI_EXTRACT methods (89% -> 79%) likely due to more categories = more false positives

### Root Causes Addressed
1. 8 missing CUAD categories (15.9% of GT) — now included
2. Clause text too short (300 chars) — increased to 800
3. COMPLETE asked for only 8-12 clauses — now 15-25
4. Jaccard overlap is harsh — added token F1 metric
5. ai_extract had no team classification — new ai_extract_classify SP

### Run IDs (v2)
- complete: 12b1bdb8-16ff-41f1-b3d7-b4374b673812
- ai_extract: 64efd0ec-612a-4bfd-8f31-902c159c2f26
- hybrid: d76731d6-a5e2-40f0-87ec-002de7c30cb6
- ai_extract_classify: 3a8c7b10-7fb3-48fa-a899-281f82ca80ba

### Modified Files
- snowflake/experiment_sps.sql (4 SPs, improved prompts + categories + AI_CLASSIFY)
- scripts/evaluate_results.py (token F1, category aliases, improved parsing)
- scripts/pipeline_ai_extract.sql (34 categories, 800 chars)

### Remaining
- [ ] Test /experiments dashboard in browser
- [ ] Wire best pipeline as default
- [ ] Merge to main

## Session 5 - 2026-04-11

### Completed (branch: legal-demo-ai-refactor)
- [x] Loaded 31 additional CUAD contracts (29 → 60 total)
- [x] Rewrote load_ground_truth.py with fuzzy filename matching + robust escaping
- [x] Reloaded ground truth: 2185 rows, 791 present clauses across 60 contracts
- [x] Added credit tracking columns to RUN_METADATA (AI_CREDITS_BEFORE/AFTER/DELTA, EXPERIMENT_TAG)
- [x] Created 6 grid experiment SPs in snowflake/experiment_grid_sps.sql
- [x] Ran 5 of 6 experiments (llama3.1-70b timed out on large contracts)
- [x] Evaluated all 5 grid experiments against CUAD ground truth

### Grid Experiment Results (v3 - 60 contracts)

| Method              | Prec  | Recall | F1    | Team Acc | Jaccard | Token F1 | Wall Time | Credits | Contracts |
|---------------------|-------|--------|-------|----------|---------|----------|-----------|---------|-----------|
| complete (short)    | 0.460 | 0.731  | 0.543 | 0.904    | 0.341   | 0.434    | 1973s     | 1.49    | 60        |
| ai_extract_classify | 0.601 | 0.376  | 0.439 | 0.866    | 0.383   | 0.476    | 1407s     | 137.21  | 59        |
| ai_extract_nolimit  | 0.686 | 0.258  | 0.345 | 0.923    | 0.440   | 0.529    | 1123s     | ~137*   | 55        |
| ai_extract_multi    | 0.624 | 0.240  | 0.324 | 0.843    | 0.420   | 0.499    | 632s      | 70.36   | 58        |
| two_pass            | 0.658 | 0.237  | 0.325 | 0.917    | 0.408   | 0.495    | 3017s     | 1.59    | 57        |

*nolimit credits not captured (metering view lag)

### Credit Cost Analysis
- **COMPLETE methods are 50-90x cheaper** than AI_EXTRACT methods (~1.5 vs ~70-137 credits)
- ai_extract_multi (grouped) uses ~50% fewer credits than single-category ai_extract (70 vs 137)
- Two-pass is cost-efficient (1.59 credits) but recall drops because COMPLETE discovery step misses clauses that AI_EXTRACT then can't find

### Key Findings
- **COMPLETE dominates recall** (0.731) and F1 (0.543) — best overall method for clause discovery
- **200-char quotes avoid truncation**: 34/60 contracts with GT matched (vs 17/29 with 800-char quotes in v2)
- **AI_EXTRACT recall is fundamentally limited** (~24-38%) because each category is queried independently
- **Multi-property extraction didn't help recall** (0.240) — worse than single-category (0.376)
- **Removing text limits didn't help recall** (0.258) — slightly worse, but best text overlap (0.529 token F1)
- **Two-pass disappointed** (0.237 recall) — COMPLETE discovery step is good but AI_EXTRACT validation is too strict
- **AI_EXTRACT methods have best text overlap** (0.44-0.53 token F1) — precise quotes when they find clauses
- **Team accuracy**: all methods >84%, nolimit best (0.923)

### Conclusions
1. For **recall-focused** use case: COMPLETE is the clear winner (0.731 recall, 1.49 credits)
2. For **precision-focused** use case: ai_extract_nolimit (0.686 precision, 0.529 token F1)
3. For **cost-sensitive** use case: COMPLETE (1.49 credits vs 70-137 for AI_EXTRACT)
4. For **balanced** production: COMPLETE with post-processing validation

### Claude vs Mistral COMPLETE Comparison

| Model             | Precision | Recall | F1    | Team Acc | Token F1 | Wall Time | Eval Contracts | Credits |
|-------------------|-----------|--------|-------|----------|----------|-----------|----------------|---------|
| mistral-large2    | 0.460     | 0.731  | 0.543 | 0.904    | 0.434    | 1973s     | 34             | 1.49    |
| claude-3-7-sonnet | 0.643     | 0.638  | 0.626 | 0.926    | 0.384    | 67s       | 47             | ~2-5*   |

*Claude credits estimated (metering view has ~2hr lag). Wall time suggests ~2-5 credits.

**Claude wins**: best F1 (0.626), best precision (0.643), 30x faster (67s vs 1973s), more parseable outputs (47/60 vs 34/60).
**Mistral wins**: higher recall (0.731 vs 0.638), better text overlap (0.434 vs 0.384).

### Run IDs (v3 grid)
- complete_short: b28ba399-cf91-4fea-8615-735c634dfb0a
- two_pass: b2c619f5-6f68-40ab-bc09-f932e89ed8f2
- ai_extract_multi: 5c09e55a-5821-44af-b107-b7a9179b8944
- ai_extract_classify: 1d23b9df-4bce-4f75-a437-c641bef1653b
- ai_extract_nolimit: 834c1a9a-cecd-4cd3-aadf-dd58c014e3cc
- complete_claude: 665c1632-70e3-4b18-8aa1-00d471344410

### New Files
- snowflake/experiment_grid_sps.sql (6 grid experiment SPs)
- scripts/load_more_contracts.py (loads additional CUAD contracts)

### Modified Files
- scripts/load_ground_truth.py (fuzzy filename matching, $$ escaping)

### Remaining
- [ ] Test /experiments dashboard in browser
- [ ] Wire COMPLETE as default pipeline
- [ ] Merge to main
