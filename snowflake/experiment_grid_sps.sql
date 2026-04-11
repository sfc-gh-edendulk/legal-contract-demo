USE ROLE SS_ADMIN_ROLE;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE LEGAL_CONTRACT_DEMO;
USE SCHEMA EXPERIMENTS;

-- ============================================================
-- GRID EXPERIMENT 1: COMPLETE v3 (shorter quotes to avoid truncation)
-- Key change: 200 char quotes instead of 800, should parse 100%
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_GRID_COMPLETE_SHORT()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
    v_credits_before FLOAT;
BEGIN
    SELECT CREDITS_USED INTO :v_credits_before
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE SERVICE_TYPE = 'AI_SERVICES' AND USAGE_DATE = CURRENT_DATE();

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES, EXPERIMENT_TAG, AI_CREDITS_BEFORE)
    SELECT :v_run_id, 'complete', 'mistral-large2', 0,
           'Grid: short quotes (200 chars) to avoid truncation', 'grid_v3', :v_credits_before;

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
        (RUN_ID, CONTRACT_ID, STEP, INPUT_CHARS, OUTPUT_RAW)
    SELECT
        :v_run_id, CONTRACT_ID, 'clause_extraction', LENGTH(FULL_TEXT),
        SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large2',
            'Extract ALL relevant clauses from this contract as a JSON array. Each element must have: {"clause_type":"...", "clause_text":"exact quote up to 200 chars", "assigned_team":"Legal|Technical/Ops|Sales|Marketing", "risk_level":"High|Medium|Low", "risk_explanation":"1 sentence"}
Use ONLY these clause_type values:
Governing Law, Anti-Assignment, Change of Control, Termination For Convenience, Non-Disparagement, IP Ownership Assignment, License Grant, Non-Transferable License, Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Exclusivity, Non-Compete, Audit Rights, Unlimited/All-You-Can-Eat-License, Irrevocable Or Perpetual License, No-Solicit Of Customers, Warranty Duration, Source Code Escrow, Post-Termination Services, Most Favored Nation, Liquidated Damages, Cap On Liability, Uncapped Liability, Competitive Restriction Exception, Insurance, Covenant Not To Sue, Volume Restriction, Joint IP Ownership, No-Solicit Of Employees, Affiliate License-Licensee, Rofr/Rofo/Rofn, Affiliate License-Licensor, Third Party Beneficiary
Team rules: Legal=Governing Law/Anti-Assignment/Change of Control/Termination/Non-Disparagement/Rofr/Covenant Not To Sue/Third Party Beneficiary. Technical/Ops=IP Ownership/Joint IP/License Grant/Non-Transferable License/Source Code Escrow/Post-Termination Services/Warranty Duration/Insurance. Sales=Revenue Sharing/Price Restrictions/Minimum Commitment/Volume Restriction/Exclusivity/Non-Compete/Audit Rights/Most Favored Nation/Liquidated Damages/Cap On Liability/Uncapped Liability. Marketing=Unlimited License/Irrevocable Or Perpetual License/No-Solicit Of Customers/No-Solicit Of Employees/Competitive Restriction Exception/Affiliate Licenses.
Return ONLY a valid JSON array.
CONTRACT:
' || SUBSTR(FULL_TEXT, 1, 60000)
        )
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT;

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
-- GRID EXPERIMENT 7: COMPLETE with claude-3-7-sonnet model
-- Tests Anthropic Claude model; best F1 (0.626), fastest (67s)
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_GRID_COMPLETE_CLAUDE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
    v_credits_before FLOAT;
BEGIN
    SELECT CREDITS_USED INTO :v_credits_before
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE SERVICE_TYPE = 'AI_SERVICES' AND USAGE_DATE = CURRENT_DATE();

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES, EXPERIMENT_TAG, AI_CREDITS_BEFORE)
    SELECT :v_run_id, 'complete', 'claude-3-7-sonnet', 0,
           'Grid: claude-3-7-sonnet model, 200 char quotes', 'grid_v3', :v_credits_before;

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
        (RUN_ID, CONTRACT_ID, STEP, INPUT_CHARS, OUTPUT_RAW)
    SELECT
        :v_run_id, CONTRACT_ID, 'clause_extraction', LENGTH(FULL_TEXT),
        SNOWFLAKE.CORTEX.COMPLETE(
            'claude-3-7-sonnet',
            'Extract ALL relevant clauses from this contract as a JSON array. Each element must have: {"clause_type":"...", "clause_text":"exact quote up to 200 chars", "assigned_team":"Legal|Technical/Ops|Sales|Marketing", "risk_level":"High|Medium|Low", "risk_explanation":"1 sentence"}
Use ONLY these clause_type values:
Governing Law, Anti-Assignment, Change of Control, Termination For Convenience, Non-Disparagement, IP Ownership Assignment, License Grant, Non-Transferable License, Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Exclusivity, Non-Compete, Audit Rights, Unlimited/All-You-Can-Eat-License, Irrevocable Or Perpetual License, No-Solicit Of Customers, Warranty Duration, Source Code Escrow, Post-Termination Services, Most Favored Nation, Liquidated Damages, Cap On Liability, Uncapped Liability, Competitive Restriction Exception, Insurance, Covenant Not To Sue, Volume Restriction, Joint IP Ownership, No-Solicit Of Employees, Affiliate License-Licensee, Rofr/Rofo/Rofn, Affiliate License-Licensor, Third Party Beneficiary
Team rules: Legal=Governing Law/Anti-Assignment/Change of Control/Termination/Non-Disparagement/Rofr/Covenant Not To Sue/Third Party Beneficiary. Technical/Ops=IP Ownership/Joint IP/License Grant/Non-Transferable License/Source Code Escrow/Post-Termination Services/Warranty Duration/Insurance. Sales=Revenue Sharing/Price Restrictions/Minimum Commitment/Volume Restriction/Exclusivity/Non-Compete/Audit Rights/Most Favored Nation/Liquidated Damages/Cap On Liability/Uncapped Liability. Marketing=Unlimited License/Irrevocable Or Perpetual License/No-Solicit Of Customers/No-Solicit Of Employees/Competitive Restriction Exception/Affiliate Licenses.
Return ONLY a valid JSON array.
CONTRACT:
' || SUBSTR(FULL_TEXT, 1, 60000)
        )
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT;

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
-- GRID EXPERIMENT 2: COMPLETE with llama3.1-70b model
-- Tests whether a different LLM improves recall
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_GRID_COMPLETE_LLAMA()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
    v_credits_before FLOAT;
BEGIN
    SELECT CREDITS_USED INTO :v_credits_before
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE SERVICE_TYPE = 'AI_SERVICES' AND USAGE_DATE = CURRENT_DATE();

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES, EXPERIMENT_TAG, AI_CREDITS_BEFORE)
    SELECT :v_run_id, 'complete', 'llama3.1-70b', 0,
           'Grid: llama3.1-70b model, 200 char quotes', 'grid_v3', :v_credits_before;

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_RESULTS
        (RUN_ID, CONTRACT_ID, STEP, INPUT_CHARS, OUTPUT_RAW)
    SELECT
        :v_run_id, CONTRACT_ID, 'clause_extraction', LENGTH(FULL_TEXT),
        SNOWFLAKE.CORTEX.COMPLETE(
            'llama3.1-70b',
            'Extract ALL relevant clauses from this contract as a JSON array. Each element must have: {"clause_type":"...", "clause_text":"exact quote up to 200 chars", "assigned_team":"Legal|Technical/Ops|Sales|Marketing", "risk_level":"High|Medium|Low", "risk_explanation":"1 sentence"}
Use ONLY these clause_type values:
Governing Law, Anti-Assignment, Change of Control, Termination For Convenience, Non-Disparagement, IP Ownership Assignment, License Grant, Non-Transferable License, Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Exclusivity, Non-Compete, Audit Rights, Unlimited/All-You-Can-Eat-License, Irrevocable Or Perpetual License, No-Solicit Of Customers, Warranty Duration, Source Code Escrow, Post-Termination Services, Most Favored Nation, Liquidated Damages, Cap On Liability, Uncapped Liability, Competitive Restriction Exception, Insurance, Covenant Not To Sue, Volume Restriction, Joint IP Ownership, No-Solicit Of Employees, Affiliate License-Licensee, Rofr/Rofo/Rofn, Affiliate License-Licensor, Third Party Beneficiary
Team rules: Legal=Governing Law/Anti-Assignment/Change of Control/Termination/Non-Disparagement/Rofr/Covenant Not To Sue/Third Party Beneficiary. Technical/Ops=IP Ownership/Joint IP/License Grant/Non-Transferable License/Source Code Escrow/Post-Termination Services/Warranty Duration/Insurance. Sales=Revenue Sharing/Price Restrictions/Minimum Commitment/Volume Restriction/Exclusivity/Non-Compete/Audit Rights/Most Favored Nation/Liquidated Damages/Cap On Liability/Uncapped Liability. Marketing=Unlimited License/Irrevocable Or Perpetual License/No-Solicit Of Customers/No-Solicit Of Employees/Competitive Restriction Exception/Affiliate Licenses.
Return ONLY a valid JSON array.
CONTRACT:
' || SUBSTR(FULL_TEXT, 1, 60000)
        )
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT;

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
-- GRID EXPERIMENT 3: AI_EXTRACT_CLASSIFY baseline on 60 contracts
-- Same as v2 but on larger dataset
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_GRID_AI_EXTRACT_CLASSIFY()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
    v_credits_before FLOAT;
BEGIN
    USE DATABASE LEGAL_CONTRACT_DEMO;
    USE SCHEMA EXPERIMENTS;

    SELECT CREDITS_USED INTO :v_credits_before
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE SERVICE_TYPE = 'AI_SERVICES' AND USAGE_DATE = CURRENT_DATE();

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES, EXPERIMENT_TAG, AI_CREDITS_BEFORE)
    SELECT :v_run_id, 'ai_extract_classify', 'cortex-aisql', 0,
           'Grid: baseline ai_extract+classify on 60 contracts', 'grid_v3', :v_credits_before;

    CREATE OR REPLACE TEMPORARY TABLE _grid_aec_extracted AS
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

    DELETE FROM _grid_aec_extracted WHERE CLAUSE_TEXT IS NULL OR LENGTH(CLAUSE_TEXT) <= 10;

    CREATE OR REPLACE TEMPORARY TABLE _grid_aec_classified AS
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
    FROM _grid_aec_extracted;

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
    FROM _grid_aec_classified
    GROUP BY CONTRACT_ID;

    DROP TABLE IF EXISTS _grid_aec_extracted;
    DROP TABLE IF EXISTS _grid_aec_classified;

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
-- GRID EXPERIMENT 4: Multi-property AI_EXTRACT (grouped categories)
-- Extract 5-6 related categories per call for better context
-- Hypothesis: more context per call = better extraction
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_GRID_AI_EXTRACT_MULTI()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
    v_credits_before FLOAT;
BEGIN
    USE DATABASE LEGAL_CONTRACT_DEMO;
    USE SCHEMA EXPERIMENTS;

    SELECT CREDITS_USED INTO :v_credits_before
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE SERVICE_TYPE = 'AI_SERVICES' AND USAGE_DATE = CURRENT_DATE();

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES, EXPERIMENT_TAG, AI_CREDITS_BEFORE)
    SELECT :v_run_id, 'ai_extract_multi', 'cortex-aisql', 0,
           'Grid: multi-property extraction (grouped categories)', 'grid_v3', :v_credits_before;

    CREATE OR REPLACE TEMPORARY TABLE _grid_multi_group1 AS
    SELECT CONTRACT_ID, LENGTH(FULL_TEXT) AS INPUT_CHARS,
        AI_EXTRACT(
            text => SUBSTR(FULL_TEXT, 1, 60000),
            responseFormat => {
                'schema': {
                    'type': 'object',
                    'properties': {
                        'governing_law': {'description': 'Exact quote of the Governing Law clause. Empty if not found.', 'type': 'string'},
                        'anti_assignment': {'description': 'Exact quote of the Anti-Assignment clause. Empty if not found.', 'type': 'string'},
                        'change_of_control': {'description': 'Exact quote of the Change of Control clause. Empty if not found.', 'type': 'string'},
                        'termination_for_convenience': {'description': 'Exact quote of the Termination For Convenience clause. Empty if not found.', 'type': 'string'},
                        'non_disparagement': {'description': 'Exact quote of the Non-Disparagement clause. Empty if not found.', 'type': 'string'},
                        'covenant_not_to_sue': {'description': 'Exact quote of the Covenant Not To Sue clause. Empty if not found.', 'type': 'string'},
                        'third_party_beneficiary': {'description': 'Exact quote of the Third Party Beneficiary clause. Empty if not found.', 'type': 'string'},
                        'rofr_rofo_rofn': {'description': 'Exact quote of the Right of First Refusal/Right of First Offer/Right of First Negotiation clause. Empty if not found.', 'type': 'string'}
                    }
                }
            }
        ) AS extraction
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT;

    CREATE OR REPLACE TEMPORARY TABLE _grid_multi_group2 AS
    SELECT CONTRACT_ID, LENGTH(FULL_TEXT) AS INPUT_CHARS,
        AI_EXTRACT(
            text => SUBSTR(FULL_TEXT, 1, 60000),
            responseFormat => {
                'schema': {
                    'type': 'object',
                    'properties': {
                        'ip_ownership_assignment': {'description': 'Exact quote of the IP Ownership Assignment clause. Empty if not found.', 'type': 'string'},
                        'joint_ip_ownership': {'description': 'Exact quote of the Joint IP Ownership clause. Empty if not found.', 'type': 'string'},
                        'license_grant': {'description': 'Exact quote of the License Grant clause. Empty if not found.', 'type': 'string'},
                        'non_transferable_license': {'description': 'Exact quote of the Non-Transferable License clause. Empty if not found.', 'type': 'string'},
                        'source_code_escrow': {'description': 'Exact quote of the Source Code Escrow clause. Empty if not found.', 'type': 'string'},
                        'post_termination_services': {'description': 'Exact quote of the Post-Termination Services clause. Empty if not found.', 'type': 'string'},
                        'warranty_duration': {'description': 'Exact quote of the Warranty Duration clause. Empty if not found.', 'type': 'string'},
                        'insurance': {'description': 'Exact quote of the Insurance clause. Empty if not found.', 'type': 'string'}
                    }
                }
            }
        ) AS extraction
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT;

    CREATE OR REPLACE TEMPORARY TABLE _grid_multi_group3 AS
    SELECT CONTRACT_ID, LENGTH(FULL_TEXT) AS INPUT_CHARS,
        AI_EXTRACT(
            text => SUBSTR(FULL_TEXT, 1, 60000),
            responseFormat => {
                'schema': {
                    'type': 'object',
                    'properties': {
                        'revenue_profit_sharing': {'description': 'Exact quote of the Revenue/Profit Sharing clause. Empty if not found.', 'type': 'string'},
                        'price_restrictions': {'description': 'Exact quote of the Price Restrictions clause. Empty if not found.', 'type': 'string'},
                        'minimum_commitment': {'description': 'Exact quote of the Minimum Commitment clause. Empty if not found.', 'type': 'string'},
                        'volume_restriction': {'description': 'Exact quote of the Volume Restriction clause. Empty if not found.', 'type': 'string'},
                        'exclusivity': {'description': 'Exact quote of the Exclusivity clause. Empty if not found.', 'type': 'string'},
                        'non_compete': {'description': 'Exact quote of the Non-Compete clause. Empty if not found.', 'type': 'string'},
                        'audit_rights': {'description': 'Exact quote of the Audit Rights clause. Empty if not found.', 'type': 'string'},
                        'most_favored_nation': {'description': 'Exact quote of the Most Favored Nation clause. Empty if not found.', 'type': 'string'},
                        'liquidated_damages': {'description': 'Exact quote of the Liquidated Damages clause. Empty if not found.', 'type': 'string'},
                        'cap_on_liability': {'description': 'Exact quote of the Cap On Liability clause. Empty if not found.', 'type': 'string'},
                        'uncapped_liability': {'description': 'Exact quote of the Uncapped Liability clause. Empty if not found.', 'type': 'string'}
                    }
                }
            }
        ) AS extraction
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT;

    CREATE OR REPLACE TEMPORARY TABLE _grid_multi_group4 AS
    SELECT CONTRACT_ID, LENGTH(FULL_TEXT) AS INPUT_CHARS,
        AI_EXTRACT(
            text => SUBSTR(FULL_TEXT, 1, 60000),
            responseFormat => {
                'schema': {
                    'type': 'object',
                    'properties': {
                        'unlimited_license': {'description': 'Exact quote of the Unlimited/All-You-Can-Eat-License clause. Empty if not found.', 'type': 'string'},
                        'irrevocable_perpetual_license': {'description': 'Exact quote of the Irrevocable Or Perpetual License clause. Empty if not found.', 'type': 'string'},
                        'no_solicit_customers': {'description': 'Exact quote of the No-Solicit Of Customers clause. Empty if not found.', 'type': 'string'},
                        'no_solicit_employees': {'description': 'Exact quote of the No-Solicit Of Employees clause. Empty if not found.', 'type': 'string'},
                        'competitive_restriction_exception': {'description': 'Exact quote of the Competitive Restriction Exception clause. Empty if not found.', 'type': 'string'},
                        'affiliate_license_licensee': {'description': 'Exact quote of the Affiliate License-Licensee clause. Empty if not found.', 'type': 'string'},
                        'affiliate_license_licensor': {'description': 'Exact quote of the Affiliate License-Licensor clause. Empty if not found.', 'type': 'string'}
                    }
                }
            }
        ) AS extraction
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT;

    CREATE OR REPLACE TEMPORARY TABLE _grid_multi_unpivoted AS
    SELECT CONTRACT_ID, INPUT_CHARS, cat AS CLAUSE_TYPE, clause_text AS CLAUSE_TEXT
    FROM (
        SELECT CONTRACT_ID, INPUT_CHARS,
            extraction:response:governing_law::VARCHAR AS "Governing Law",
            extraction:response:anti_assignment::VARCHAR AS "Anti-Assignment",
            extraction:response:change_of_control::VARCHAR AS "Change of Control",
            extraction:response:termination_for_convenience::VARCHAR AS "Termination For Convenience",
            extraction:response:non_disparagement::VARCHAR AS "Non-Disparagement",
            extraction:response:covenant_not_to_sue::VARCHAR AS "Covenant Not To Sue",
            extraction:response:third_party_beneficiary::VARCHAR AS "Third Party Beneficiary",
            extraction:response:rofr_rofo_rofn::VARCHAR AS "Rofr/Rofo/Rofn"
        FROM _grid_multi_group1
    ) UNPIVOT(clause_text FOR cat IN (
        "Governing Law", "Anti-Assignment", "Change of Control",
        "Termination For Convenience", "Non-Disparagement",
        "Covenant Not To Sue", "Third Party Beneficiary", "Rofr/Rofo/Rofn"
    ))
    WHERE clause_text IS NOT NULL AND LENGTH(clause_text) > 10

    UNION ALL

    SELECT CONTRACT_ID, INPUT_CHARS, cat AS CLAUSE_TYPE, clause_text AS CLAUSE_TEXT
    FROM (
        SELECT CONTRACT_ID, INPUT_CHARS,
            extraction:response:ip_ownership_assignment::VARCHAR AS "IP Ownership Assignment",
            extraction:response:joint_ip_ownership::VARCHAR AS "Joint IP Ownership",
            extraction:response:license_grant::VARCHAR AS "License Grant",
            extraction:response:non_transferable_license::VARCHAR AS "Non-Transferable License",
            extraction:response:source_code_escrow::VARCHAR AS "Source Code Escrow",
            extraction:response:post_termination_services::VARCHAR AS "Post-Termination Services",
            extraction:response:warranty_duration::VARCHAR AS "Warranty Duration",
            extraction:response:insurance::VARCHAR AS "Insurance"
        FROM _grid_multi_group2
    ) UNPIVOT(clause_text FOR cat IN (
        "IP Ownership Assignment", "Joint IP Ownership", "License Grant",
        "Non-Transferable License", "Source Code Escrow",
        "Post-Termination Services", "Warranty Duration", "Insurance"
    ))
    WHERE clause_text IS NOT NULL AND LENGTH(clause_text) > 10

    UNION ALL

    SELECT CONTRACT_ID, INPUT_CHARS, cat AS CLAUSE_TYPE, clause_text AS CLAUSE_TEXT
    FROM (
        SELECT CONTRACT_ID, INPUT_CHARS,
            extraction:response:revenue_profit_sharing::VARCHAR AS "Revenue/Profit Sharing",
            extraction:response:price_restrictions::VARCHAR AS "Price Restrictions",
            extraction:response:minimum_commitment::VARCHAR AS "Minimum Commitment",
            extraction:response:volume_restriction::VARCHAR AS "Volume Restriction",
            extraction:response:exclusivity::VARCHAR AS "Exclusivity",
            extraction:response:non_compete::VARCHAR AS "Non-Compete",
            extraction:response:audit_rights::VARCHAR AS "Audit Rights",
            extraction:response:most_favored_nation::VARCHAR AS "Most Favored Nation",
            extraction:response:liquidated_damages::VARCHAR AS "Liquidated Damages",
            extraction:response:cap_on_liability::VARCHAR AS "Cap On Liability",
            extraction:response:uncapped_liability::VARCHAR AS "Uncapped Liability"
        FROM _grid_multi_group3
    ) UNPIVOT(clause_text FOR cat IN (
        "Revenue/Profit Sharing", "Price Restrictions", "Minimum Commitment",
        "Volume Restriction", "Exclusivity", "Non-Compete", "Audit Rights",
        "Most Favored Nation", "Liquidated Damages", "Cap On Liability", "Uncapped Liability"
    ))
    WHERE clause_text IS NOT NULL AND LENGTH(clause_text) > 10

    UNION ALL

    SELECT CONTRACT_ID, INPUT_CHARS, cat AS CLAUSE_TYPE, clause_text AS CLAUSE_TEXT
    FROM (
        SELECT CONTRACT_ID, INPUT_CHARS,
            extraction:response:unlimited_license::VARCHAR AS "Unlimited/All-You-Can-Eat-License",
            extraction:response:irrevocable_perpetual_license::VARCHAR AS "Irrevocable Or Perpetual License",
            extraction:response:no_solicit_customers::VARCHAR AS "No-Solicit Of Customers",
            extraction:response:no_solicit_employees::VARCHAR AS "No-Solicit Of Employees",
            extraction:response:competitive_restriction_exception::VARCHAR AS "Competitive Restriction Exception",
            extraction:response:affiliate_license_licensee::VARCHAR AS "Affiliate License-Licensee",
            extraction:response:affiliate_license_licensor::VARCHAR AS "Affiliate License-Licensor"
        FROM _grid_multi_group4
    ) UNPIVOT(clause_text FOR cat IN (
        "Unlimited/All-You-Can-Eat-License", "Irrevocable Or Perpetual License",
        "No-Solicit Of Customers", "No-Solicit Of Employees",
        "Competitive Restriction Exception", "Affiliate License-Licensee",
        "Affiliate License-Licensor"
    ))
    WHERE clause_text IS NOT NULL AND LENGTH(clause_text) > 10;

    CREATE OR REPLACE TEMPORARY TABLE _grid_multi_classified AS
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
    FROM _grid_multi_unpivoted;

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
    FROM _grid_multi_classified
    GROUP BY CONTRACT_ID;

    DROP TABLE IF EXISTS _grid_multi_group1;
    DROP TABLE IF EXISTS _grid_multi_group2;
    DROP TABLE IF EXISTS _grid_multi_group3;
    DROP TABLE IF EXISTS _grid_multi_group4;
    DROP TABLE IF EXISTS _grid_multi_unpivoted;
    DROP TABLE IF EXISTS _grid_multi_classified;

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
-- GRID EXPERIMENT 5: Two-pass (COMPLETE discovery + AI_EXTRACT validation)
-- Pass 1: COMPLETE discovers clause types present
-- Pass 2: AI_EXTRACT validates and extracts text for each discovered type
-- Hypothesis: COMPLETE's high recall + AI_EXTRACT's precision
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_GRID_TWO_PASS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
    v_credits_before FLOAT;
BEGIN
    USE DATABASE LEGAL_CONTRACT_DEMO;
    USE SCHEMA EXPERIMENTS;

    SELECT CREDITS_USED INTO :v_credits_before
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE SERVICE_TYPE = 'AI_SERVICES' AND USAGE_DATE = CURRENT_DATE();

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES, EXPERIMENT_TAG, AI_CREDITS_BEFORE)
    SELECT :v_run_id, 'two_pass', 'mistral-large2+cortex-aisql', 0,
           'Grid: COMPLETE discovery then AI_EXTRACT validation', 'grid_v3', :v_credits_before;

    CREATE OR REPLACE TEMPORARY TABLE _grid_tp_discovery AS
    SELECT
        CONTRACT_ID,
        LENGTH(FULL_TEXT) AS INPUT_CHARS,
        SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large2',
            'List ALL clause types present in this contract. Return ONLY a JSON array of strings (clause type names).
Use ONLY these clause_type values:
Governing Law, Anti-Assignment, Change of Control, Termination For Convenience, Non-Disparagement, IP Ownership Assignment, License Grant, Non-Transferable License, Revenue/Profit Sharing, Price Restrictions, Minimum Commitment, Exclusivity, Non-Compete, Audit Rights, Unlimited/All-You-Can-Eat-License, Irrevocable Or Perpetual License, No-Solicit Of Customers, Warranty Duration, Source Code Escrow, Post-Termination Services, Most Favored Nation, Liquidated Damages, Cap On Liability, Uncapped Liability, Competitive Restriction Exception, Insurance, Covenant Not To Sue, Volume Restriction, Joint IP Ownership, No-Solicit Of Employees, Affiliate License-Licensee, Rofr/Rofo/Rofn, Affiliate License-Licensor, Third Party Beneficiary
Return ONLY a JSON array of strings. Example: ["Governing Law", "License Grant", "Non-Compete"]
CONTRACT:
' || SUBSTR(FULL_TEXT, 1, 60000)
        ) AS discovered_raw
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT;

    CREATE OR REPLACE TEMPORARY TABLE _grid_tp_discovered_cats AS
    SELECT d.CONTRACT_ID, d.INPUT_CHARS, f.value::VARCHAR AS CLAUSE_TYPE
    FROM _grid_tp_discovery d,
         LATERAL FLATTEN(input => TRY_PARSE_JSON(
             REGEXP_SUBSTR(TRIM(d.discovered_raw), '\\[.*\\]', 1, 1, 's')
         )) f
    WHERE f.value::VARCHAR IN (
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
    );

    CREATE OR REPLACE TEMPORARY TABLE _grid_tp_extracted AS
    SELECT
        dc.CONTRACT_ID, dc.INPUT_CHARS, dc.CLAUSE_TYPE,
        AI_EXTRACT(
            text => SUBSTR(ct.FULL_TEXT, 1, 60000),
            responseFormat => {
                'schema': {
                    'type': 'object',
                    'properties': {
                        'clause_text': {
                            'description': 'Exact quote of the ' || dc.CLAUSE_TYPE || ' clause. Return empty string if not found.',
                            'type': 'string'
                        }
                    }
                }
            }
        ):response:clause_text::VARCHAR AS CLAUSE_TEXT
    FROM _grid_tp_discovered_cats dc
    JOIN LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT ct ON ct.CONTRACT_ID = dc.CONTRACT_ID;

    DELETE FROM _grid_tp_extracted WHERE CLAUSE_TEXT IS NULL OR LENGTH(CLAUSE_TEXT) <= 10;

    CREATE OR REPLACE TEMPORARY TABLE _grid_tp_classified AS
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
    FROM _grid_tp_extracted;

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
    FROM _grid_tp_classified
    GROUP BY CONTRACT_ID;

    DROP TABLE IF EXISTS _grid_tp_discovery;
    DROP TABLE IF EXISTS _grid_tp_discovered_cats;
    DROP TABLE IF EXISTS _grid_tp_extracted;
    DROP TABLE IF EXISTS _grid_tp_classified;

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
-- GRID EXPERIMENT 6: AI_EXTRACT with no text length limit
-- Tests whether removing "up to 800 chars" improves recall
-- ============================================================
CREATE OR REPLACE PROCEDURE LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_GRID_AI_EXTRACT_NOLIMIT()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id VARCHAR DEFAULT UUID_STRING();
    v_count INT;
    v_credits_before FLOAT;
BEGIN
    USE DATABASE LEGAL_CONTRACT_DEMO;
    USE SCHEMA EXPERIMENTS;

    SELECT CREDITS_USED INTO :v_credits_before
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE SERVICE_TYPE = 'AI_SERVICES' AND USAGE_DATE = CURRENT_DATE();

    INSERT INTO LEGAL_CONTRACT_DEMO.EXPERIMENTS.RUN_METADATA
        (RUN_ID, METHOD, MODEL, CONTRACT_COUNT, NOTES, EXPERIMENT_TAG, AI_CREDITS_BEFORE)
    SELECT :v_run_id, 'ai_extract_nolimit', 'cortex-aisql', 0,
           'Grid: AI_EXTRACT without text length limit + classify', 'grid_v3', :v_credits_before;

    CREATE OR REPLACE TEMPORARY TABLE _grid_nolimit_extracted AS
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
                            'description': 'Full exact quote of the ' || cat.cat || ' clause from the contract. Return empty string if this clause type is not present.',
                            'type': 'string'
                        }
                    }
                }
            }
        ):response:clause_text::VARCHAR AS CLAUSE_TEXT
    FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT ct
    CROSS JOIN categories cat;

    DELETE FROM _grid_nolimit_extracted WHERE CLAUSE_TEXT IS NULL OR LENGTH(CLAUSE_TEXT) <= 10;

    CREATE OR REPLACE TEMPORARY TABLE _grid_nolimit_classified AS
    SELECT
        CONTRACT_ID, INPUT_CHARS, CLAUSE_TYPE, CLAUSE_TEXT,
        AI_CLASSIFY(
            SUBSTR(CLAUSE_TEXT, 1, 2000),
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
    FROM _grid_nolimit_extracted;

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
    FROM _grid_nolimit_classified
    GROUP BY CONTRACT_ID;

    DROP TABLE IF EXISTS _grid_nolimit_extracted;
    DROP TABLE IF EXISTS _grid_nolimit_classified;

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
