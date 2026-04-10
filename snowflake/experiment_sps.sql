USE ROLE SS_ADMIN_ROLE;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE LEGAL_CONTRACT_DEMO;
USE SCHEMA EXPERIMENTS;

-- ============================================================
-- SP 1: COMPLETE method (mistral-large2 via CORTEX.COMPLETE)
-- Processes all 29 contracts with a single LLM call each.
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_EXPERIMENT_COMPLETE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
BEGIN
    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES)
    SELECT :v_run_id, 'complete', 'mistral-large2', 0, 'SP-driven experiment';

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
        (RUN_ID, CONTRACT_ID, STEP, INPUT_CHARS, OUTPUT_RAW)
    SELECT
        :v_run_id,
        CONTRACT_ID,
        'clause_extraction',
        LENGTH(FULL_TEXT),
        SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large2',
            'Extract ALL relevant clauses from this contract as a JSON array (expect 15-25 clauses). Each element must have: {"clause_type":"...", "clause_text":"exact quote up to 800 chars", "assigned_team":"Legal|Technical/Ops|Sales|Marketing", "risk_level":"High|Medium|Low", "risk_explanation":"1 sentence"}
Use ONLY these clause_type values:
Governing Law, Anti-Assignment, Change of Control, Termination For Convenience, Non-Disparagement, IP Ownership Assignment, License Grant, Non-Transferable License, Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Exclusivity, Non-Compete, Audit Rights, Unlimited/All-You-Can-Eat-License, Irrevocable Or Perpetual License, No-Solicit Of Customers, Warranty Duration, Source Code Escrow, Post-Termination Services, Most Favored Nation, Liquidated Damages, Cap On Liability, Uncapped Liability, Competitive Restriction Exception, Insurance, Covenant Not To Sue, Volume Restriction, Joint IP Ownership, No-Solicit Of Employees, Affiliate License-Licensee, Rofr/Rofo/Rofn, Affiliate License-Licensor, Third Party Beneficiary
Team assignment rules:
- Legal: Governing Law, Anti-Assignment, Change of Control, Termination For Convenience, Non-Disparagement, Rofr/Rofo/Rofn, Covenant Not To Sue, Third Party Beneficiary
- Technical/Ops: IP Ownership Assignment, Joint IP Ownership, License Grant, Non-Transferable License, Source Code Escrow, Post-Termination Services, Warranty Duration, Insurance
- Sales: Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Volume Restriction, Exclusivity, Non-Compete, Audit Rights, Most Favored Nation, Liquidated Damages, Uncapped Liability, Cap On Liability
- Marketing: Unlimited/All-You-Can-Eat-License, Irrevocable Or Perpetual License, No-Solicit Of Customers, No-Solicit Of Employees, Competitive Restriction Exception, Affiliate License-Licensee, Affiliate License-Licensor
Risk rules:
- High: One-sided terms, uncapped liability, broad restrictions, no termination rights
- Medium: Notable terms needing review
- Low: Standard balanced terms
Return ONLY a JSON array, no other text.
CONTRACT:
' || SUBSTR(FULL_TEXT, 1, 60000)
        )
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT;

    SELECT COUNT(*) INTO :v_count
    FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
    WHERE RUN_ID = :v_run_id;

    UPDATE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
    SET FINISHED_AT = CURRENT_TIMESTAMP(),
        CONTRACT_COUNT = :v_count,
        TOTAL_WALL_TIME_SECS = DATEDIFF('second', STARTED_AT, CURRENT_TIMESTAMP())
    WHERE RUN_ID = :v_run_id;

    RETURN :v_run_id;
END;
$$;


-- ============================================================
-- SP 4: AI_EXTRACT + AI_CLASSIFY method
-- Step 1: Extract clauses via AI_EXTRACT (no team/risk in extraction)
-- Step 2: Classify team + risk via separate AI_CLASSIFY calls
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_EXPERIMENT_AI_EXTRACT_CLASSIFY()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
BEGIN
    USE DATABASE LEGAL_CONTRACT_DEMO;
    USE SCHEMA EXPERIMENTS;

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES)
    SELECT :v_run_id, 'ai_extract_classify', 'cortex-aisql', 0, 'SP-driven (AI_EXTRACT then AI_CLASSIFY)';

    CREATE OR REPLACE TEMPORARY TABLE _aec_extracted AS
    WITH categories AS (
        SELECT c.value::VARCHAR AS cat
        FROM TABLE(FLATTEN(input => ARRAY_CONSTRUCT(
            'Governing Law', 'Anti-Assignment', 'Change of Control',
            'Termination For Convenience', 'Non-Disparagement',
            'IP Ownership Assignment', 'License Grant', 'Non-Transferable License',
            'Revenue/Profit Sharing', 'Price Restrictions', 'Minimum Commitment',
            'Exclusivity', 'Non-Compete', 'Audit Rights',
            'Unlimited/All-You-Can-Eat-License', 'Irrevocable Or Perpetual License',
            'No-Solicit Of Customers', 'Warranty Duration',
            'Source Code Escrow', 'Post-Termination Services',
            'Most Favored Nation', 'Liquidated Damages',
            'Cap On Liability', 'Uncapped Liability',
            'Competitive Restriction Exception', 'Insurance',
            'Covenant Not To Sue', 'Volume Restriction', 'Joint IP Ownership',
            'No-Solicit Of Employees', 'Affiliate License-Licensee',
            'Rofr/Rofo/Rofn', 'Affiliate License-Licensor', 'Third Party Beneficiary'
        ))) c
    )
    SELECT
        ct.CONTRACT_ID,
        LENGTH(ct.FULL_TEXT) AS INPUT_CHARS,
        cat.cat AS CLAUSE_TYPE,
        AI_EXTRACT(
            text => SUBSTR(ct.FULL_TEXT, 1, 60000),
            responseFormat => {
                'schema': {
                    'type': 'object',
                    'properties': {
                        'clause_text': {
                            'description': 'Exact quote of the ' || cat.cat || ' clause, up to 800 chars. Return empty string if not found.',
                            'type': 'string'
                        }
                    }
                }
            }
        ):response:clause_text::VARCHAR AS CLAUSE_TEXT
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT ct
    CROSS JOIN categories cat;

    DELETE FROM _aec_extracted WHERE CLAUSE_TEXT IS NULL OR LENGTH(CLAUSE_TEXT) <= 10;

    CREATE OR REPLACE TEMPORARY TABLE _aec_classified AS
    SELECT
        CONTRACT_ID, INPUT_CHARS, CLAUSE_TYPE, CLAUSE_TEXT,
        AI_CLASSIFY(
            CLAUSE_TEXT,
            [
                {'label': 'High', 'description': 'One-sided terms, uncapped liability, broad restrictions'},
                {'label': 'Medium', 'description': 'Notable terms needing review'},
                {'label': 'Low', 'description': 'Standard balanced terms'}
            ],
            {'task_description': 'Classify contract clause risk level'}
        ):labels[0]::VARCHAR AS RISK_LEVEL,
        AI_CLASSIFY(
            CLAUSE_TYPE || ': ' || SUBSTR(CLAUSE_TEXT, 1, 500),
            [
                {'label': 'Legal', 'description': 'Governing Law, Anti-Assignment, Change of Control, Termination, Non-Disparagement, Covenant Not To Sue, Third Party Beneficiary, Rofr/Rofo/Rofn'},
                {'label': 'Technical/Ops', 'description': 'IP Ownership, Joint IP, License Grant, Non-Transferable License, Source Code Escrow, Post-Termination Services, Warranty Duration, Insurance'},
                {'label': 'Sales', 'description': 'Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Volume Restriction, Exclusivity, Non-Compete, Audit Rights, Most Favored Nation, Liquidated Damages, Cap/Uncapped Liability'},
                {'label': 'Marketing', 'description': 'Unlimited License, Irrevocable/Perpetual License, No-Solicit of Customers/Employees, Competitive Restriction, Affiliate Licenses'}
            ],
            {
                'task_description': 'Route contract clause to responsible review team based on clause type',
                'examples': [
                    {'input': 'Governing Law: This Agreement shall be governed by the laws of the State of New York', 'labels': ['Legal'], 'explanation': 'Governing law is a Legal team clause'},
                    {'input': 'Revenue/Profit Sharing: Licensee shall pay 5% of net revenue quarterly', 'labels': ['Sales'], 'explanation': 'Revenue sharing is a Sales team clause'},
                    {'input': 'IP Ownership Assignment: All inventions made by Employee shall be assigned to Company', 'labels': ['Technical/Ops'], 'explanation': 'IP ownership is Technical/Ops'},
                    {'input': 'No-Solicit Of Customers: Party shall not solicit customers for 2 years', 'labels': ['Marketing'], 'explanation': 'No-solicit clauses route to Marketing'}
                ]
            }
        ):labels[0]::VARCHAR AS ASSIGNED_TEAM
    FROM _aec_extracted;

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
        (RUN_ID, CONTRACT_ID, STEP, INPUT_CHARS, OUTPUT_RAW, PARSED_OUTPUT, CLAUSE_COUNT)
    SELECT
        :v_run_id, CONTRACT_ID, 'clause_extraction',
        MAX(INPUT_CHARS),
        ARRAY_AGG(OBJECT_CONSTRUCT(
            'clause_type', CLAUSE_TYPE, 'clause_text', CLAUSE_TEXT,
            'risk_level', RISK_LEVEL, 'assigned_team', ASSIGNED_TEAM
        ))::VARCHAR,
        ARRAY_AGG(OBJECT_CONSTRUCT(
            'clause_type', CLAUSE_TYPE, 'clause_text', CLAUSE_TEXT,
            'risk_level', RISK_LEVEL, 'assigned_team', ASSIGNED_TEAM
        )),
        COUNT(*)
    FROM _aec_classified
    GROUP BY CONTRACT_ID;

    DROP TABLE IF EXISTS _aec_extracted;
    DROP TABLE IF EXISTS _aec_classified;

    SELECT COUNT(*) INTO :v_count
    FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS WHERE RUN_ID = :v_run_id;

    UPDATE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
    SET FINISHED_AT = CURRENT_TIMESTAMP(),
        CONTRACT_COUNT = :v_count,
        TOTAL_WALL_TIME_SECS = DATEDIFF('second', STARTED_AT, CURRENT_TIMESTAMP())
    WHERE RUN_ID = :v_run_id;

    RETURN :v_run_id;
END;
$$;


-- ============================================================
-- SP 2: AI_EXTRACT method
-- CROSS JOINs 34 clause categories × all contracts.
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_EXPERIMENT_AI_EXTRACT()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
BEGIN
    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES)
    SELECT :v_run_id, 'ai_extract', 'cortex-aisql', 0, 'SP-driven experiment';

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
        (RUN_ID, CONTRACT_ID, STEP, INPUT_CHARS, OUTPUT_RAW, PARSED_OUTPUT, CLAUSE_COUNT)
    WITH categories AS (
        SELECT c.value::VARCHAR AS cat
        FROM TABLE(FLATTEN(input => ARRAY_CONSTRUCT(
            'Governing Law', 'Anti-Assignment', 'Change of Control',
            'Termination For Convenience', 'Non-Disparagement',
            'IP Ownership Assignment', 'License Grant', 'Non-Transferable License',
            'Revenue/Profit Sharing', 'Price Restrictions', 'Minimum Commitment',
            'Exclusivity', 'Non-Compete', 'Audit Rights',
            'Unlimited/All-You-Can-Eat-License', 'Irrevocable Or Perpetual License',
            'No-Solicit Of Customers', 'Warranty Duration',
            'Source Code Escrow', 'Post-Termination Services',
            'Most Favored Nation', 'Liquidated Damages',
            'Cap On Liability', 'Uncapped Liability',
            'Competitive Restriction Exception', 'Insurance',
            'Covenant Not To Sue', 'Volume Restriction', 'Joint IP Ownership',
            'No-Solicit Of Employees', 'Affiliate License-Licensee',
            'Rofr/Rofo/Rofn', 'Affiliate License-Licensor', 'Third Party Beneficiary'
        ))) c
    ),
    extractions AS (
        SELECT
            ct.CONTRACT_ID,
            LENGTH(ct.FULL_TEXT) AS INPUT_CHARS,
            cat.cat AS CLAUSE_TYPE,
            AI_EXTRACT(
                text => SUBSTR(ct.FULL_TEXT, 1, 60000),
                responseFormat => {
                    'schema': {
                        'type': 'object',
                        'properties': {
                            'clause_text': {
                                'description': 'Exact quote of the ' || cat.cat || ' clause, up to 800 chars. Return empty string if not found.',
                                'type': 'string'
                            }
                        }
                    }
                }
            ) AS EXTRACTION
        FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT ct
        CROSS JOIN categories cat
    ),
    filtered AS (
        SELECT *,
            EXTRACTION:response:clause_text::VARCHAR AS CLAUSE_TEXT
        FROM extractions
        WHERE EXTRACTION:response:clause_text::VARCHAR IS NOT NULL
          AND LENGTH(EXTRACTION:response:clause_text::VARCHAR) > 10
    ),
    per_contract AS (
        SELECT
            CONTRACT_ID,
            MAX(INPUT_CHARS) AS INPUT_CHARS,
            ARRAY_AGG(OBJECT_CONSTRUCT('clause_type', CLAUSE_TYPE, 'clause_text', CLAUSE_TEXT)) AS CLAUSES_ARR,
            COUNT(*) AS CLAUSE_CNT
        FROM filtered
        GROUP BY CONTRACT_ID
    )
    SELECT
        :v_run_id, CONTRACT_ID, 'clause_extraction',
        INPUT_CHARS, CLAUSES_ARR::VARCHAR, CLAUSES_ARR, CLAUSE_CNT
    FROM per_contract;

    SELECT COUNT(*) INTO :v_count
    FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS WHERE RUN_ID = :v_run_id;

    UPDATE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
    SET FINISHED_AT = CURRENT_TIMESTAMP(),
        CONTRACT_COUNT = :v_count,
        TOTAL_WALL_TIME_SECS = DATEDIFF('second', STARTED_AT, CURRENT_TIMESTAMP())
    WHERE RUN_ID = :v_run_id;

    RETURN :v_run_id;
END;
$$;


-- ============================================================
-- SP 3: HYBRID method (AI_EXTRACT + AI_CLASSIFY)
-- Step 1: Extract clauses via AI_EXTRACT into temp table
-- Step 2: Classify risk + team via AI_CLASSIFY
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_EXPERIMENT_HYBRID()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
BEGIN
    USE DATABASE LEGAL_CONTRACT_DEMO;
    USE SCHEMA EXPERIMENTS;

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES)
    SELECT :v_run_id, 'hybrid', 'cortex-aisql', 0, 'SP-driven (AI_EXTRACT + AI_CLASSIFY)';

    CREATE OR REPLACE TEMPORARY TABLE _hybrid_extracted AS
    WITH categories AS (
        SELECT c.value::VARCHAR AS cat
        FROM TABLE(FLATTEN(input => ARRAY_CONSTRUCT(
            'Governing Law', 'Anti-Assignment', 'Change of Control',
            'Termination For Convenience', 'Non-Disparagement',
            'IP Ownership Assignment', 'License Grant', 'Non-Transferable License',
            'Revenue/Profit Sharing', 'Price Restrictions', 'Minimum Commitment',
            'Exclusivity', 'Non-Compete', 'Audit Rights',
            'Unlimited/All-You-Can-Eat-License', 'Irrevocable Or Perpetual License',
            'No-Solicit Of Customers', 'Warranty Duration',
            'Source Code Escrow', 'Post-Termination Services',
            'Most Favored Nation', 'Liquidated Damages',
            'Cap On Liability', 'Uncapped Liability',
            'Competitive Restriction Exception', 'Insurance',
            'Covenant Not To Sue', 'Volume Restriction', 'Joint IP Ownership',
            'No-Solicit Of Employees', 'Affiliate License-Licensee',
            'Rofr/Rofo/Rofn', 'Affiliate License-Licensor', 'Third Party Beneficiary'
        ))) c
    )
    SELECT
        ct.CONTRACT_ID,
        LENGTH(ct.FULL_TEXT) AS INPUT_CHARS,
        cat.cat AS CLAUSE_TYPE,
        AI_EXTRACT(
            text => SUBSTR(ct.FULL_TEXT, 1, 60000),
            responseFormat => {
                'schema': {
                    'type': 'object',
                    'properties': {
                        'clause_text': {
                            'description': 'Exact quote of the ' || cat.cat || ' clause, up to 800 chars. Return empty if not found.',
                            'type': 'string'
                        }
                    }
                }
            }
        ):response:clause_text::VARCHAR AS CLAUSE_TEXT
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT ct
    CROSS JOIN categories cat;

    DELETE FROM _hybrid_extracted WHERE CLAUSE_TEXT IS NULL OR LENGTH(CLAUSE_TEXT) <= 10;

    CREATE OR REPLACE TEMPORARY TABLE _hybrid_classified AS
    SELECT
        CONTRACT_ID, INPUT_CHARS, CLAUSE_TYPE, CLAUSE_TEXT,
        AI_CLASSIFY(
            CLAUSE_TEXT,
            [
                {'label': 'High', 'description': 'One-sided terms, uncapped liability, broad restrictions'},
                {'label': 'Medium', 'description': 'Notable terms needing review'},
                {'label': 'Low', 'description': 'Standard balanced terms'}
            ],
            {'task_description': 'Classify contract clause risk level'}
        ):labels[0]::VARCHAR AS RISK_LEVEL,
        AI_CLASSIFY(
            CLAUSE_TYPE || ': ' || SUBSTR(CLAUSE_TEXT, 1, 500),
            [
                {'label': 'Legal', 'description': 'Governing Law, Anti-Assignment, Change of Control, Termination, Non-Disparagement, Covenant Not To Sue, Third Party Beneficiary, Rofr/Rofo/Rofn'},
                {'label': 'Technical/Ops', 'description': 'IP Ownership, Joint IP, License Grant, Non-Transferable License, Source Code Escrow, Post-Termination Services, Warranty Duration, Insurance'},
                {'label': 'Sales', 'description': 'Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Volume Restriction, Exclusivity, Non-Compete, Audit Rights, Most Favored Nation, Liquidated Damages, Cap/Uncapped Liability'},
                {'label': 'Marketing', 'description': 'Unlimited License, Irrevocable/Perpetual License, No-Solicit of Customers/Employees, Competitive Restriction, Affiliate Licenses'}
            ],
            {
                'task_description': 'Route contract clause to responsible review team based on clause type',
                'examples': [
                    {'input': 'Governing Law: This Agreement shall be governed by the laws of the State of New York', 'labels': ['Legal'], 'explanation': 'Governing law is a Legal team clause'},
                    {'input': 'Revenue/Profit Sharing: Licensee shall pay 5% of net revenue quarterly', 'labels': ['Sales'], 'explanation': 'Revenue sharing is a Sales team clause'},
                    {'input': 'IP Ownership Assignment: All inventions made by Employee shall be assigned to Company', 'labels': ['Technical/Ops'], 'explanation': 'IP ownership is Technical/Ops'},
                    {'input': 'No-Solicit Of Customers: Party shall not solicit customers for 2 years', 'labels': ['Marketing'], 'explanation': 'No-solicit clauses route to Marketing'}
                ]
            }
        ):labels[0]::VARCHAR AS ASSIGNED_TEAM
    FROM _hybrid_extracted;

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
        (RUN_ID, CONTRACT_ID, STEP, INPUT_CHARS, OUTPUT_RAW, PARSED_OUTPUT, CLAUSE_COUNT)
    SELECT
        :v_run_id, CONTRACT_ID, 'clause_extraction',
        MAX(INPUT_CHARS),
        ARRAY_AGG(OBJECT_CONSTRUCT(
            'clause_type', CLAUSE_TYPE, 'clause_text', CLAUSE_TEXT,
            'risk_level', RISK_LEVEL, 'assigned_team', ASSIGNED_TEAM
        ))::VARCHAR,
        ARRAY_AGG(OBJECT_CONSTRUCT(
            'clause_type', CLAUSE_TYPE, 'clause_text', CLAUSE_TEXT,
            'risk_level', RISK_LEVEL, 'assigned_team', ASSIGNED_TEAM
        )),
        COUNT(*)
    FROM _hybrid_classified
    GROUP BY CONTRACT_ID;

    DROP TABLE IF EXISTS _hybrid_extracted;
    DROP TABLE IF EXISTS _hybrid_classified;

    SELECT COUNT(*) INTO :v_count
    FROM LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS WHERE RUN_ID = :v_run_id;

    UPDATE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
    SET FINISHED_AT = CURRENT_TIMESTAMP(),
        CONTRACT_COUNT = :v_count,
        TOTAL_WALL_TIME_SECS = DATEDIFF('second', STARTED_AT, CURRENT_TIMESTAMP())
    WHERE RUN_ID = :v_run_id;

    RETURN :v_run_id;
END;
$$;
