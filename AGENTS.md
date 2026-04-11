# Agent Instructions - Legal Contract Review Demo

## Project Overview
SPCS-hosted React+Flask application for AI-powered contract review using Snowflake Cortex AI functions.

## Key Decisions
- **Backend**: Flask (Python) with Snowpark
- **Frontend**: React 18 + Tailwind CSS
- **AI Models**: claude-3-7-sonnet (recommended) and mistral-large2 via SNOWFLAKE.CORTEX.COMPLETE
- **Deployment**: SPCS with dedicated LEGAL_DEMO_CP compute pool
- **Database**: LEGAL_CONTRACT_DEMO (schemas: RAW, ANALYTICS, APP, EXPERIMENTS)
- **Dataset**: CUAD v1 (60 contracts loaded, 510 available)

## Snowflake Connection
- Set `SNOWFLAKE_CONNECTION_NAME` env var to your active `snow` CLI connection name
- Default connection: `CURSOR-AZURE_NETHERLANDS`
- **SS_ADMIN_ROLE** for experiments and analysis
- **SYSADMIN** role required for: database, schema, table, stage, image repository setup
- **ACCOUNTADMIN** role required for: compute pool and SPCS service creation
- Default warehouse: `COMPUTE_WH`

## Python Environment
- Python 3.11+ required
- Conda env: `crocevia` (`/opt/miniconda3/envs/crocevia`)
- Install dependencies: `pip install -r backend/requirements.txt`
- Key packages: `snowflake-snowpark-python`, `flask`, `gunicorn`

## Git Workflow
- Main branch: `main`
- Experiment branch: `legal-demo-ai-refactor` (kept alive for iteration)
- Always commit and push after each task

## Testing
- Backend: run Flask locally on port 5000
- Frontend: React dev server on port 5173
- Docker: build and run locally before SPCS push

## Team Routing Categories
- **Legal**: Governing Law, Anti-Assignment, Change of Control, Covenant Not To Sue, Third Party Beneficiary, Non-Disparagement, Termination for Convenience, ROFR/ROFO/ROFN
- **Technical/Ops**: IP Ownership, Joint IP, License Grant, Non-Transferable License, Source Code Escrow, Post-Termination Services, Warranty Duration, Insurance
- **Sales**: Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Volume Restriction, Most Favored Nation, Exclusivity, Non-Compete, Audit Rights, Liquidated Damages, Cap/Uncapped Liability
- **Marketing**: Unlimited License, Irrevocable/Perpetual License, No-Solicit of Customers, No-Solicit of Employees, Competitive Restriction Exception, Affiliate Licenses

## Docker Build
- Always use `--platform linux/amd64` for SPCS compatibility
- Registry URL format: `<account>.registry.snowflakecomputing.com`
- Image path in registry: `/legal_contract_demo/app/image_repo/contract-review-app:latest`

---

## AI Experiment Framework

### Overview
Experiments extract clauses from CUAD v1 legal contracts using Snowflake Cortex AI functions, then evaluate against CUAD ground truth annotations. All experiments run as SQL stored procedures in `LEGAL_CONTRACT_DEMO.EXPERIMENTS`.

### Cortex AI Functions Used
- **SNOWFLAKE.CORTEX.COMPLETE**: Free-form LLM extraction (returns JSON array of clauses)
- **AI_EXTRACT**: Structured extraction per category (one property per call or multi-property)
- **AI_CLASSIFY**: Classification with labels and few-shot examples (risk level, team routing)

### Experiment Methods

| Method | Description | Strengths | Weaknesses |
|--------|-------------|-----------|------------|
| `complete` | Single CORTEX.COMPLETE call per contract, returns all clauses as JSON | Best recall, cheapest | Lower precision, output truncation risk |
| `ai_extract_classify` | AI_EXTRACT per category + AI_CLASSIFY for risk/team | High precision, good text overlap | Low recall (~38%), expensive |
| `ai_extract_multi` | Multi-property AI_EXTRACT (8 related categories per call) | Faster than single-category | Lower recall than single-category |
| `two_pass` | COMPLETE discovers clause types, AI_EXTRACT validates | Combines strengths in theory | Recall drops due to strict validation |
| `ai_extract_nolimit` | AI_EXTRACT without text length limits + AI_CLASSIFY | Best text overlap, high precision | Low recall, expensive |

### Best Results (v3 Grid, 60 contracts)

| Model | Method | Precision | Recall | F1 | Team Acc | Token F1 | Wall Time | Credits |
|-------|--------|-----------|--------|----|----------|----------|-----------|---------|
| **claude-3-7-sonnet** | complete | **0.643** | 0.638 | **0.626** | **0.926** | 0.384 | **67s** | ~2-5 |
| mistral-large2 | complete | 0.460 | **0.731** | 0.543 | 0.904 | 0.434 | 1973s | 1.49 |
| cortex-aisql | ai_extract_classify | 0.601 | 0.376 | 0.439 | 0.866 | 0.476 | 1407s | 137.21 |
| cortex-aisql | ai_extract_nolimit | **0.686** | 0.258 | 0.345 | 0.923 | **0.529** | 1123s | ~137 |
| cortex-aisql | ai_extract_multi | 0.624 | 0.240 | 0.324 | 0.843 | 0.499 | 632s | 70.36 |
| mistral-large2+cortex-aisql | two_pass | 0.658 | 0.237 | 0.325 | 0.917 | 0.495 | 3017s | 1.59 |

### Recommended Production Configuration
- **Model**: `claude-3-7-sonnet` — best F1 (0.626), best precision (0.643), 30x faster than Mistral
- **Method**: `complete` with 200-char quote limit to avoid output truncation
- **Fallback model**: `mistral-large2` — higher recall (0.731) but slower and lower precision
- **Cost**: COMPLETE methods use ~1-5 credits vs 70-137 for AI_EXTRACT methods (50-90x cheaper)

### Key Learnings
1. **COMPLETE dominates** for recall and F1 — LLM freely discovers clauses vs structured extraction
2. **AI_EXTRACT recall is fundamentally capped** (~24-38%) because each category is queried independently
3. **Claude 3.7 Sonnet > Mistral Large 2** for balanced F1/precision, and 30x faster
4. **200-char quotes** prevent output truncation (47/60 parseable vs 17/29 with 800-char quotes)
5. **AI_CLASSIFY with few-shot examples** achieves 92-97% team accuracy across all methods
6. **Multi-property extraction** didn't improve recall — actually slightly worse
7. **Two-pass approach** disappointed — COMPLETE discovery is good but AI_EXTRACT validation too strict

### Evaluation Metrics
- **Precision**: fraction of detected clauses that match ground truth categories
- **Recall**: fraction of ground truth clauses that were detected
- **F1**: harmonic mean of precision and recall
- **Team Accuracy**: fraction of matched clauses with correct team assignment
- **Jaccard**: word-level overlap between extracted text and ground truth spans
- **Token F1**: token-level precision/recall/F1 between extracted and ground truth text

### Files
- `snowflake/experiment_sps.sql` — 4 core experiment SPs (v2: complete, ai_extract, hybrid, ai_extract_classify)
- `snowflake/experiment_grid_sps.sql` — 7 grid experiment SPs (v3: complete_short, complete_llama, complete_claude, ai_extract_classify, ai_extract_multi, two_pass, ai_extract_nolimit)
- `snowflake/experiments_setup.sql` — Schema and table DDL
- `scripts/evaluate_results.py` — Evaluation scorer against CUAD ground truth
- `scripts/load_ground_truth.py` — CUAD ground truth loader (fuzzy filename matching)
- `scripts/load_more_contracts.py` — Loads additional CUAD contracts into Snowflake
- `scripts/run_experiments.py` — Python experiment runner (legacy, use SPs instead)
- `scripts/pipeline_ai_extract.sql` — Standalone AI_EXTRACT pipeline
- `scripts/pipeline_ai_classify.sql` — Standalone AI_CLASSIFY pipeline

### Running Experiments
```sql
-- Deploy SPs
-- Run the SQL in snowflake/experiment_grid_sps.sql to create all SPs

-- Run an experiment
CALL LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_GRID_COMPLETE_CLAUDE();
-- Returns a RUN_ID

-- Evaluate
-- python scripts/evaluate_results.py --run-id <RUN_ID>
-- python scripts/evaluate_results.py --all
```

### CUAD Ground Truth
- 510 contracts available in CUAD_v1/full_contract_txt/
- 60 loaded into Snowflake (LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT)
- 2185 ground truth annotations, 791 with clauses present
- 34 clause categories across 4 teams
- Load more: `python scripts/load_more_contracts.py` (edit TARGET_TOTAL)
- Reload GT: `python scripts/load_ground_truth.py`
