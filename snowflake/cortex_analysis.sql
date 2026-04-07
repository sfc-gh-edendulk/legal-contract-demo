-- Legal Contract Review Demo - Cortex AI Analysis Pipeline
-- Run with role: SS_ADMIN_ROLE, warehouse: COMPUTE_WH

USE ROLE SS_ADMIN_ROLE;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE LEGAL_CONTRACT_DEMO;

-- Step 1: Extract clauses from each contract using Cortex AI
-- Process contracts in batches to manage rate limits

-- Clear previous analysis
TRUNCATE TABLE ANALYTICS.CLAUSE_ANALYSIS;
TRUNCATE TABLE ANALYTICS.CONTRACT_SUMMARY;
