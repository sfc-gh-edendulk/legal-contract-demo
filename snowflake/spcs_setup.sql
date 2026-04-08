-- Legal Contract Review Demo - SPCS Setup
-- Requires ACCOUNTADMIN role (compute pool creation requires it)
-- TODO: Replace COMPUTE_WH with your warehouse name if different
-- Run AFTER setup.sql and after pushing the Docker image to the image registry

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE LEGAL_CONTRACT_DEMO;

-- Create dedicated compute pool
CREATE COMPUTE POOL IF NOT EXISTS LEGAL_DEMO_CP
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_S
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 3600;

-- Grant usage on warehouse to SYSADMIN so the service can query data
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SYSADMIN;

-- Upload the service spec to stage
-- Run this from your terminal (replace <conn> with your connection name):
--   snow sql --connection <conn> -q "PUT file://deploy/contract_review.yaml @LEGAL_CONTRACT_DEMO.APP.SERVICE_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
-- Or use SnowSQL:
--   PUT file://deploy/contract_review.yaml @LEGAL_CONTRACT_DEMO.APP.SERVICE_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Create the service
-- TODO: Verify the image path matches your registry.
--   Run: SHOW IMAGE REPOSITORIES IN SCHEMA LEGAL_CONTRACT_DEMO.APP;
--   The image path format is: /<db>/<schema>/<repo>/<image>:<tag>
CREATE SERVICE IF NOT EXISTS LEGAL_CONTRACT_DEMO.APP.CONTRACT_REVIEW_SERVICE
  IN COMPUTE POOL LEGAL_DEMO_CP
  FROM @LEGAL_CONTRACT_DEMO.APP.SERVICE_STAGE
  SPECIFICATION_FILE = 'contract_review.yaml'
  MIN_INSTANCES = 1
  MAX_INSTANCES = 1;

-- Check service status (run after ~1-2 minutes)
SELECT
  v.value:containerName::varchar container_name,
  v.value:status::varchar status,
  v.value:message::varchar message
FROM (SELECT parse_json(system$get_service_status('LEGAL_CONTRACT_DEMO.APP.CONTRACT_REVIEW_SERVICE'))) t,
LATERAL FLATTEN(input => t.$1) v;

-- Get public endpoint URL
SHOW ENDPOINTS IN SERVICE LEGAL_CONTRACT_DEMO.APP.CONTRACT_REVIEW_SERVICE;
