-- Method C: AI_CLASSIFY for risk + team classification
-- Two-step: uses AI_CLASSIFY on already-extracted clause text to assign risk and team.
-- Expects clauses already inserted with CLAUSE_TYPE and CLAUSE_TEXT populated.
-- Run after pipeline_ai_extract.sql (extraction-only mode) or after COMPLETE extraction.

-- Step 1: Classify risk level
UPDATE LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS
SET RISK_LEVEL = AI_CLASSIFY(
    CLAUSE_TEXT,
    [
        {'label': 'High', 'description': 'One-sided terms, uncapped liability, broad restrictions, no termination rights'},
        {'label': 'Medium', 'description': 'Notable terms that need review but are not extreme'},
        {'label': 'Low', 'description': 'Standard balanced terms, common boilerplate'}
    ],
    {'task_description': 'Classify the risk level of this contract clause for legal review'}
):labels[0]::VARCHAR
WHERE RISK_LEVEL IS NULL OR RISK_LEVEL = '';

-- Step 2: Classify team assignment
UPDATE LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS
SET ASSIGNED_TEAM = AI_CLASSIFY(
    CLAUSE_TYPE || ': ' || SUBSTR(CLAUSE_TEXT, 1, 500),
    [
        {'label': 'Legal', 'description': 'Governing Law, Termination, Indemnification, Confidentiality, Anti-Assignment, Change of Control, Non-Disparagement'},
        {'label': 'Technical/Ops', 'description': 'IP Ownership, License Grant, Warranty, Source Code Escrow, SLAs, Post-Termination Services'},
        {'label': 'Sales', 'description': 'Revenue Sharing, Pricing, Minimum Commitment, Exclusivity, Non-Compete, Audit Rights, Liquidated Damages'},
        {'label': 'Marketing', 'description': 'Promotional rights, Branding, No-Solicit, Unlimited License, Competitive Restriction'}
    ],
    {'task_description': 'Route this contract clause to the responsible review team based on clause type and content'}
):labels[0]::VARCHAR
WHERE ASSIGNED_TEAM IS NULL OR ASSIGNED_TEAM = '';
