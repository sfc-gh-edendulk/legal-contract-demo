# Legal Contract Review Demo

AI-powered contract review application built on Snowflake, using Cortex AI functions to analyze commercial contracts, classify clauses by responsible team, and highlight risky passages.

## Problem Statement

Legal teams often lack the technical or commercial expertise to review all clauses in complex contracts. This application:
- Ingests contracts (PDF/text)
- Extracts and classifies clauses by responsible team (Legal, Technical/Ops, Sales, Marketing)
- Highlights risky passages with explanations
- Routes review tasks to the right people

## Architecture

- **Frontend**: React 18 + Tailwind CSS
- **Backend**: Flask + Snowpark Python
- **AI Engine**: Snowflake Cortex AI (mistral-large2)
- **Deployment**: Snowpark Container Services (SPCS)
- **Database**: Snowflake (LEGAL_CONTRACT_DEMO)

## Dataset

Uses the [CUAD v1 dataset](https://www.atticusprojectai.org/cuad) - 510 commercial legal contracts with 41 labeled clause categories. A curated subset of ~30 contracts is used for the demo.

## Prerequisites

- Snowflake account with SPCS and Cortex AI enabled
- Docker Desktop
- Node.js 20+ and npm
- Python 3.11+ (conda env `crocevia`)
- Snowflake CLI (`snow`)

## Quick Start

### 1. Snowflake Setup

```sql
-- Run the setup scripts in order:
-- snowflake/setup.sql       - Creates database, schemas, stages, tables
-- snowflake/load_data.sql   - Loads contract data
-- snowflake/cortex_analysis.sql - Runs AI analysis pipeline
```

### 2. Local Development

```bash
# Backend
cd backend
pip install -r requirements.txt
SNOWFLAKE_CONNECTION_NAME=default python app.py

# Frontend (separate terminal)
cd frontend
npm install
npm start
```

### 3. Docker Build

```bash
cd deploy
docker build --platform linux/amd64 -t contract-review .
docker run -p 5000:5000 --env-file env.list contract-review
```

### 4. SPCS Deployment

```sql
-- Run snowflake/spcs_setup.sql
-- Push Docker image to Snowflake registry
-- Create and start service
```

## Project Structure

```
legal_demo/
├── snowflake/          # SQL setup and analysis scripts
├── backend/            # Flask API
├── frontend/           # React application
├── deploy/             # Docker and SPCS deployment files
└── scripts/            # Data curation utilities
```
