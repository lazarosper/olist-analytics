"""Load one extract batch into the Snowflake RAW (bronze) layer.

    python ingestion/load_raw.py --batch 1      # initial load
    python ingestion/load_raw.py --batch 2      # later extract (new + changed rows)
    python ingestion/load_raw.py --batch 1 --reset   # start over (replay the demo)

Pattern: PUT local files to an internal stage, then COPY INTO append-only raw
tables.  Raw tables keep every source column as VARCHAR (nothing can fail on a
type error at load time; casting is dbt's job) plus four audit columns:

    _source_file       which file the row came from
    _file_row_number   row position inside that file
    _batch_id          logical extract the row belongs to
    _loaded_at         when the row landed in Snowflake (drives incrementals)

The load is idempotent: COPY INTO remembers which files it has already loaded
(load metadata, 64 days), so re-running a batch loads nothing twice.

Auth: key-pair, via SNOWFLAKE_ACCOUNT / SNOWFLAKE_USER / SNOWFLAKE_PRIVATE_KEY_PATH.
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import snowflake.connector

REPO_ROOT = Path(__file__).resolve().parent.parent
LANDING = REPO_ROOT / "data" / "landing"

DATABASE = "RAW"
SCHEMA = "OLIST"
STAGE = "LANDING"
FILE_FORMAT = "CSV_STRICT"

# table -> source columns, in file order
TABLES: dict[str, list[str]] = {
    "orders": [
        "order_id", "customer_id", "order_status", "order_purchase_timestamp", "order_approved_at",
        "order_delivered_carrier_date", "order_delivered_customer_date", "order_estimated_delivery_date",
    ],
    "order_items": [
        "order_id", "order_item_id", "product_id", "seller_id", "shipping_limit_date", "price", "freight_value",
    ],
    "order_payments": [
        "order_id", "payment_sequential", "payment_type", "payment_installments", "payment_value",
    ],
    "order_reviews": [
        "review_id", "order_id", "review_score", "review_comment_title", "review_comment_message",
        "review_creation_date", "review_answer_timestamp",
    ],
    "customers": [
        "customer_id", "customer_unique_id", "customer_zip_code_prefix", "customer_city", "customer_state",
    ],
    "products": [
        "product_id", "product_category_name", "product_name_lenght", "product_description_lenght",
        "product_photos_qty", "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm",
    ],
    "sellers": ["seller_id", "seller_zip_code_prefix", "seller_city", "seller_state"],
}


def connect() -> snowflake.connector.SnowflakeConnection:
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        role="LOADER",
        warehouse="LOADING_WH",
        database=DATABASE,
        schema=SCHEMA,
    )


def ensure_objects(cur) -> None:
    cur.execute(
        f"""
        create file format if not exists {FILE_FORMAT}
            type = csv
            skip_header = 1
            field_optionally_enclosed_by = '"'
            null_if = ('')
            empty_field_as_null = true
            error_on_column_count_mismatch = true
            encoding = 'UTF8'
        """
    )
    cur.execute(f"create stage if not exists {STAGE} file_format = {FILE_FORMAT}")
    for table, columns in TABLES.items():
        column_ddl = ",\n            ".join(f"{c} varchar" for c in columns)
        cur.execute(
            f"""
            create table if not exists {table} (
            {column_ddl},
            _source_file varchar,
            _file_row_number number,
            _batch_id varchar,
            _loaded_at timestamp_ntz
            )
            """
        )


def load_table(cur, table: str, batch: int) -> tuple[int, str]:
    local_file = LANDING / f"batch_{batch}" / f"{table}.csv"
    if not local_file.exists():
        raise FileNotFoundError(f"{local_file} not found. Run ingestion/split_batches.py first.")

    stage_path = f"@{STAGE}/batch_{batch}/{table}/"
    # PUT compresses with gzip on the client and skips files already staged.
    cur.execute(f"put 'file://{local_file.as_posix()}' {stage_path} auto_compress = true overwrite = false")

    columns = TABLES[table]
    select_list = ", ".join(f"${i}" for i in range(1, len(columns) + 1))
    cur.execute(
        f"""
        copy into {table} ({", ".join(columns)}, _source_file, _file_row_number, _batch_id, _loaded_at)
        from (
            select
                {select_list},
                metadata$filename,
                metadata$file_row_number,
                'batch_{batch}',
                convert_timezone('UTC', current_timestamp())::timestamp_ntz
            from {stage_path}
        )
        file_format = (format_name = {FILE_FORMAT})
        on_error = abort_statement
        """
    )
    row = cur.fetchone()
    # A skipped file returns a single-column status row instead of load counts.
    if len(row) < 4:
        return 0, str(row[0])
    return int(row[3]), str(row[1])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--batch", type=int, required=True, choices=(1, 2))
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Empty the raw tables and the stage first (only with --batch 1). Used to replay the demo.",
    )
    args = parser.parse_args()
    if args.reset and args.batch != 1:
        parser.error("--reset is only allowed together with --batch 1")

    conn = connect()
    cur = conn.cursor()
    try:
        ensure_objects(cur)
        if args.reset:
            for table in TABLES:
                cur.execute(f"truncate table {table}")
            cur.execute(f"remove @{STAGE}")
            print(f"Reset: emptied {len(TABLES)} raw tables and stage @{STAGE}")
        print(f"Loading batch_{args.batch} into {DATABASE}.{SCHEMA}")
        for table in TABLES:
            rows, status = load_table(cur, table, args.batch)
            cur.execute(f"select count(*) from {table}")
            total = cur.fetchone()[0]
            print(f"  {table:<16} +{rows:>7,} rows  ({status:<24}) table total {total:>8,}")
    finally:
        cur.close()
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
