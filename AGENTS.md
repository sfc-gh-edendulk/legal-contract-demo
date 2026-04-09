# Agent Instructions - Legal Contract Review Demo

## Project Overview
SPCS-hosted React+Flask application for AI-powered contract review using Snowflake Cortex AI functions. Includes an experimentation module for comparing extraction methods against CUAD ground truth.

## Key Decisions
- **Backend**: Flask (Python) with Snowpark
- **Frontend**: React 18 + Tailwind CSS
- **AI Models**: mistral-large2 (CORTEX.COMPLETE), AI_EXTRACT, AI_CLASSIFY (cortex-aisql)
- **Deployment**: SPCS with dedicated LEGAL_DEMO_CP compute pool
- **Database**: LEGAL_CONTRACT_DEMO (schemas: RAW, ANALYTICS, APP, EXPERIMENTS)
- **Dataset**: CUAD v1 (~30 curated contracts, 1189 ground truth annotations)
- **Best pipeline**: hybrid (AI_EXTRACT + AI_CLASSIFY) — F1 0.490, team accuracy 79.2%

## Snowflake Connection
- Connection name: `CURSOR-AZURE_NETHERLANDS`
- Role: `SS_ADMIN_ROLE` (general), `ACCOUNTADMIN` (SPCS)
- Warehouse: `COMPUTE_WH`
- Set `SNOWFLAKE_CONNECTION_NAME` env var to your active `snow` CLI connection name

## Python Environment
- Conda env: `crocevia` (`/opt/miniconda3/envs/crocevia`, Python 3.11, Snowpark 1.41.0)
- Install dependencies: `pip install -r backend/requirements.txt`
- Key packages: `snowflake-snowpark-python`, `flask`, `gunicorn`
- Run scripts with: `SNOWFLAKE_CONNECTION_NAME=CURSOR-AZURE_NETHERLANDS /opt/miniconda3/envs/crocevia/bin/python <script>`

## Git Workflow
- Main branch: `main`
- Feature branch: `legal-demo-ai-refactor` (experimentation module)
- Always commit and push after each task

## Project Structure
```
backend/app.py              # Flask API (includes /api/experiments/* endpoints)
frontend/src/App.jsx        # React router + nav
frontend/src/components/    # ExperimentDashboard.jsx, ContractViewer, etc.
scripts/
  run_analysis.py           # Main pipeline (--method complete|hybrid)
  run_experiments.py        # Python experiment runner (superseded by SPs)
  evaluate_results.py       # Score results vs CUAD ground truth
  load_ground_truth.py      # Parse CUAD_v1.json → CUAD_GROUND_TRUTH table
  pipeline_ai_extract.sql   # AI_EXTRACT SQL template
  pipeline_ai_classify.sql  # AI_CLASSIFY SQL template
snowflake/
  experiments_setup.sql     # CREATE SCHEMA/TABLE DDL for experiments
  experiment_sps.sql        # 3 stored procedures for running experiments
```

## Experimentation Module
### Running Experiments
Use the SQL stored procedures (avoid Python runner — Snowpark session timeouts):
```sql
CALL LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_EXPERIMENT_COMPLETE();    -- mistral-large2, ~8min
CALL LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_EXPERIMENT_AI_EXTRACT();  -- AI_EXTRACT × 26 categories, ~26min
CALL LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_EXPERIMENT_HYBRID();      -- AI_EXTRACT + AI_CLASSIFY, ~12min
```

### Evaluating Results
```bash
SNOWFLAKE_CONNECTION_NAME=CURSOR-AZURE_NETHERLANDS /opt/miniconda3/envs/crocevia/bin/python scripts/evaluate_results.py --all
```

### Metrics (from latest run)
| Method     | Precision | Recall | F1    | Team Acc | Text Overlap |
|------------|-----------|--------|-------|----------|--------------|
| hybrid     | 0.890     | 0.351  | 0.490 | 0.792    | 0.453        |
| ai_extract | 0.893     | 0.341  | 0.480 | 0.000    | 0.448        |
| complete   | 0.505     | 0.421  | 0.445 | 0.691    | 0.330        |

## Lint / Typecheck
- No lint or typecheck commands configured yet

## Testing
- Backend: run Flask locally on port 5000
- Frontend: React dev server on port 5173
- Docker: build and run locally before SPCS push
- Experiments dashboard: http://localhost:5173/experiments

## Team Routing Categories
- **Legal**: Governing Law, Anti-Assignment, Change of Control, Covenant Not To Sue, Third Party Beneficiary, Non-Disparagement, Termination for Convenience, ROFR/ROFO/ROFN
- **Technical/Ops**: IP Ownership, Joint IP, License Grant, Non-Transferable License, Source Code Escrow, Affiliate Licenses, Post-Termination Services, Warranty Duration
- **Sales**: Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Volume Restriction, Most Favored Nation, Exclusivity, Non-Compete, Audit Rights
- **Marketing**: Unlimited License, Irrevocable/Perpetual License, No-Solicit of Customers, No-Solicit of Employees, Competitive Restriction Exception

## Docker Build
- Always use `--platform linux/amd64` for SPCS compatibility
- Registry URL format: `<account>.registry.snowflakecomputing.com`
- Image path in registry: `/legal_contract_demo/app/image_repo/contract-review-app:latest`
- SPCS endpoint: `ibn7yc-sfsenorthamerica-horizon-lab-azure-consumer-edd.snowflakecomputing.app`

## Known Issues
- CORTEX.COMPLETE returns markdown-fenced JSON (` ```json ... ``` `) — must strip before parsing
- Snowpark `session.sql().collect()` can timeout on long Cortex calls — use stored procedures instead
- AI_EXTRACT with CROSS JOIN over 26 categories × 29 contracts = 754 AI calls (slow but thorough)
