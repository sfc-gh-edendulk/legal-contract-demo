# Agent Instructions - Legal Contract Review Demo

## Project Overview
SPCS-hosted React+Flask application for AI-powered contract review using Snowflake Cortex AI functions.

## Key Decisions
- **Backend**: Flask (Python) with Snowpark
- **Frontend**: React 18 + Tailwind CSS
- **AI Model**: mistral-large2 via SNOWFLAKE.CORTEX.COMPLETE
- **Deployment**: SPCS with dedicated LEGAL_DEMO_CP compute pool
- **Database**: LEGAL_CONTRACT_DEMO (schemas: RAW, ANALYTICS, APP)
- **Dataset**: CUAD v1 (~30 curated contracts)

## Snowflake Connection
- Set `SNOWFLAKE_CONNECTION_NAME` env var to your active `snow` CLI connection name
- **SYSADMIN** role required for: database, schema, table, stage, image repository setup
- **ACCOUNTADMIN** role required for: compute pool and SPCS service creation
- Default warehouse assumed: `COMPUTE_WH` — update SQL scripts if yours differs

## Python Environment
- Python 3.11+ required
- Install dependencies: `pip install -r backend/requirements.txt`
- Key packages: `snowflake-snowpark-python`, `flask`, `gunicorn`
- Any Python 3.11 virtual environment works

## Git Workflow
- Main branch: `main`
- Always commit and push after each task

## Testing
- Backend: run Flask locally on port 5000
- Frontend: React dev server on port 5173
- Docker: build and run locally before SPCS push

## Team Routing Categories
- **Legal**: Governing Law, Anti-Assignment, Change of Control, Covenant Not To Sue, Third Party Beneficiary, Non-Disparagement, Termination for Convenience, ROFR/ROFO/ROFN
- **Technical/Ops**: IP Ownership, Joint IP, License Grant, Non-Transferable License, Source Code Escrow, Affiliate Licenses, Post-Termination Services, Warranty Duration
- **Sales**: Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Volume Restriction, Most Favored Nation, Exclusivity, Non-Compete, Audit Rights
- **Marketing**: Unlimited License, Irrevocable/Perpetual License, No-Solicit of Customers, No-Solicit of Employees, Competitive Restriction Exception

## Docker Build
- Always use `--platform linux/amd64` for SPCS compatibility
- Registry URL format: `<account>.registry.snowflakecomputing.com`
- Image path in registry: `/legal_contract_demo/app/image_repo/contract-review-app:latest`
