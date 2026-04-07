-- Legal Contract Review Demo - SPCS Setup
-- Run with role: SS_ADMIN_ROLE

USE ROLE SS_ADMIN_ROLE;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE LEGAL_CONTRACT_DEMO;

-- Create dedicated compute pool
CREATE COMPUTE POOL IF NOT EXISTS LEGAL_DEMO_CP
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_S
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 3600;

-- Grant usage on warehouse to the role for the service
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SS_ADMIN_ROLE;

-- Upload the service spec to stage
-- PUT file://deploy/contract_review.yaml @LEGAL_CONTRACT_DEMO.APP.SERVICE_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Create the service
-- CREATE SERVICE LEGAL_CONTRACT_DEMO.APP.CONTRACT_REVIEW_SERVICE
--   IN COMPUTE POOL LEGAL_DEMO_CP
--   FROM @LEGAL_CONTRACT_DEMO.APP.SERVICE_STAGE
--   SPECIFICATION_FILE = 'contract_review.yaml'
--   EXTERNAL_ACCESS_INTEGRATIONS = ()
--   MIN_INSTANCES = 1
--   MAX_INSTANCES = 1;

-- Check service status
-- SELECT
--   v.value:containerName::varchar container_name,
--   v.value:status::varchar status,
--   v.value:message::varchar message
-- FROM (SELECT parse_json(system$get_service_status('LEGAL_CONTRACT_DEMO.APP.CONTRACT_REVIEW_SERVICE'))) t,
-- LATERAL FLATTEN(input => t.$1) v;

-- Get public endpoint
-- SHOW ENDPOINTS IN SERVICE LEGAL_CONTRACT_DEMO.APP.CONTRACT_REVIEW_SERVICE;
