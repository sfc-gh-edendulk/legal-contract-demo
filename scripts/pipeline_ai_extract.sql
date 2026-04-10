-- Method B: AI_EXTRACT for structured clause extraction
-- Extracts clauses as a list of objects from contract text in a single set-based query.
-- Usage: Run via experiment runner or standalone with snow sql -f

INSERT INTO LEGAL_CONTRACT_DEMO.ANALYTICS.CLAUSE_ANALYSIS
    (CONTRACT_ID, CLAUSE_TYPE, CLAUSE_TEXT, ASSIGNED_TEAM, RISK_LEVEL, RISK_EXPLANATION)
SELECT
    ct.CONTRACT_ID,
    f.value::VARCHAR AS CLAUSE_TYPE,
    AI_EXTRACT(
        text => SUBSTR(ct.FULL_TEXT, 1, 60000),
        responseFormat => {
            'schema': {
                'type': 'object',
                'properties': {
                    'clause_text': {
                        'description': 'Exact quote of the ' || f.value::VARCHAR || ' clause, up to 800 characters',
                        'type': 'string'
                    },
                    'assigned_team': {
                        'description': 'Which team should review: Legal, Technical/Ops, Sales, or Marketing',
                        'type': 'string'
                    },
                    'risk_level': {
                        'description': 'Risk level: High, Medium, or Low. High = one-sided/uncapped. Medium = notable. Low = standard.',
                        'type': 'string'
                    },
                    'risk_explanation': {
                        'description': 'One sentence explanation of the risk assessment',
                        'type': 'string'
                    }
                }
            }
        }
    ):response AS EXTRACTION,
    EXTRACTION:assigned_team::VARCHAR,
    EXTRACTION:risk_level::VARCHAR,
    EXTRACTION:risk_explanation::VARCHAR
FROM LEGAL_CONTRACT_DEMO.RAW.CONTRACT_TEXT ct,
LATERAL FLATTEN(input => ARRAY_CONSTRUCT(
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
)) f
WHERE EXTRACTION:clause_text::VARCHAR IS NOT NULL
  AND LENGTH(EXTRACTION:clause_text::VARCHAR) > 10;
