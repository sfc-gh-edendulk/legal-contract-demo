# Agent Instructions - Legal Contract Review Demo

## Project Overview
SPCS-hosted React+Flask application for AI-powered contract review using Snowflake Cortex AI functions.

## Key Decisions
- **Backend**: Flask (Python) with Snowpark
- **Frontend**: React 18 + Tailwind CSS
- **AI Model**: mistral-large2 via SNOWFLAKE_CORTEX.AI_COMPLETE
- **Deployment**: SPCS with dedicated LEGAL_DEMO_CP compute pool
- **Database**: LEGAL_CONTRACT_DEMO (schemas: RAW, ANALYTICS, APP)
- **Dataset**: CUAD v1 (~30 curated contracts)
- **Language**: English UI

## Conda Environment
Use `crocevia` environment: `/opt/miniconda3/envs/crocevia/bin/python`

## Snowflake Connection
- Account: SFSENORTHAMERICA-HORIZON_LAB_AZURE_CONSUMER_EDD
- Role: SS_ADMIN_ROLE
- Warehouse: COMPUTE_WH

## Git Workflow
- Main branch: `main`
- Always commit and push after each task
- GitHub: `sfc-gh-edendulk/legal-contract-demo`

## Testing
- Backend: run Flask locally on port 5000
- Frontend: React dev server on port 3000
- Docker: build and run locally before SPCS push

## Team Routing Categories
- Legal: Governing Law, Anti-Assignment, Change of Control, Covenant Not To Sue, Third Party Beneficiary, Non-Disparagement, Termination for Convenience, ROFR/ROFO/ROFN
- Technical/Ops: IP Ownership, Joint IP, License Grant, Non-Transferable License, Source Code Escrow, Affiliate Licenses, Post-Termination Services, Warranty Duration
- Sales: Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Volume Restriction, Most Favored Nation, Exclusivity, Non-Compete, Audit Rights
- Marketing: Unlimited License, Irrevocable/Perpetual License, No-Solicit of Customers, No-Solicit of Employees, Competitive Restriction Exception
