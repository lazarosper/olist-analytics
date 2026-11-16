"""Apply infra/snowflake/01_account_setup.sql to the Snowflake account.

Usage:
    python infra/apply_setup.py

Connects with key-pair auth (no password) using the same environment variables
as dbt: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PRIVATE_KEY_PATH.
After the script it grants the functional roles to the connecting user (its
real, possibly case-sensitive name is read from Snowflake) and one role to each
service user that exists.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import snowflake.connector

SETUP_SQL = Path(__file__).parent / "snowflake" / "01_account_setup.sql"
FUNCTIONAL_ROLES = ("LOADER", "TRANSFORMER", "REPORTER", "PII_READER")
# service identity -> the single role it gets (least privilege)
SERVICE_USER_ROLES = {"SVC_DBT_CI": "TRANSFORMER", "SVC_POWERBI": "REPORTER"}


def split_statements(sql: str) -> list[str]:
    """Split a SQL script on ';' after stripping '--' comments."""
    lines = [line.split("--", 1)[0] for line in sql.splitlines()]
    statements = " ".join(lines).split(";")
    return [s.strip() for s in statements if s.strip()]


def main() -> int:
    user = os.environ["SNOWFLAKE_USER"]
    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=user,
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        role=os.environ.get("SNOWFLAKE_SETUP_ROLE", "ACCOUNTADMIN"),
    )
    cur = conn.cursor()
    try:
        for statement in split_statements(SETUP_SQL.read_text(encoding="utf-8")):
            cur.execute(statement)
            print(f"ok   {statement[:90]}")
        # The real user name can be case-sensitive (it differs from the login
        # name), so ask Snowflake for it and quote it.
        cur.execute("select current_user()")
        user_name = cur.fetchone()[0]
        cur.execute("use role securityadmin")
        for role in FUNCTIONAL_ROLES:
            cur.execute(f'grant role {role} to user "{user_name}"')
            print(f"ok   grant role {role} to user {user_name}")
        # Service users (created once by an administrator, see README).
        for service_user, role in SERVICE_USER_ROLES.items():
            cur.execute(f"show users like '{service_user}'")
            if cur.fetchone():
                cur.execute(f"grant role {role} to user {service_user}")
                print(f"ok   grant role {role} to user {service_user}")
    finally:
        cur.close()
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
