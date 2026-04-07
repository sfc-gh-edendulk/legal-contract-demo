import os
from snowflake.snowpark import Session

_session = None

def get_session():
    global _session
    if _session is not None:
        try:
            _session.sql("SELECT 1").collect()
            return _session
        except Exception:
            _session = None

    if os.path.exists("/snowflake/session/token"):
        _session = Session.builder.configs({
            "host": os.environ.get("SNOWFLAKE_HOST", ""),
            "account": os.environ.get("SNOWFLAKE_ACCOUNT", ""),
            "authenticator": "oauth",
            "token": open("/snowflake/session/token").read().strip(),
            "database": os.environ.get("DATA_DB", "LEGAL_CONTRACT_DEMO"),
            "schema": os.environ.get("DATA_SCHEMA", "APP"),
            "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
        }).create()
    else:
        conn_name = os.environ.get("SNOWFLAKE_CONNECTION_NAME", "CURSOR-AZURE_NETHERLANDS")
        _session = Session.builder.config("connection_name", conn_name).create()
        _session.sql("USE DATABASE LEGAL_CONTRACT_DEMO").collect()

    return _session
