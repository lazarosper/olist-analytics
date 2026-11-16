"""Turn the static Olist dump into two extract batches.

The public Olist dataset is a single frozen export, but a real pipeline receives
data over time and rows change after they first arrive (an order is shipped,
then delivered).  To be able to demonstrate incremental loading honestly, this
script simulates two extracts from the source system:

  batch_1  the state of the system as of the cutoff (default 2018-07-01):
           - only orders purchased before the cutoff
           - orders that were still in flight at the cutoff show the status and
             timestamps they had back then (e.g. 'shipped', not yet delivered)
           - only reviews written before the cutoff, for orders in this batch

  batch_2  a later extract:
           - orders purchased on/after the cutoff (new rows)
           - the final version of every in-flight order from batch_1 (updates)
           - reviews written on/after the cutoff
           - products and sellers first seen after the cutoff

Nothing is invented: every value comes from the original files.  The only
transformation is hiding events that had not happened yet at the cutoff.

Usage:
    python ingestion/split_batches.py --source "C:/path/to/olist/csvs"
Output:
    data/landing/batch_1/<table>.csv and data/landing/batch_2/<table>.csv
"""
from __future__ import annotations

import argparse
from pathlib import Path

import duckdb

REPO_ROOT = Path(__file__).resolve().parent.parent
LANDING = REPO_ROOT / "data" / "landing"

SOURCE_FILES = {
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "customers": "olist_customers_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--source", required=True, help="Folder with the original Olist CSV files")
    parser.add_argument("--cutoff", default="2018-07-01", help="Extract date of batch_1 (YYYY-MM-DD)")
    args = parser.parse_args()

    source = Path(args.source)
    con = duckdb.connect()
    con.execute(f"set variable cutoff = timestamp '{args.cutoff} 00:00:00'")

    # all_varchar keeps every value exactly as it is in the file (zip codes keep
    # their leading zeros, timestamps keep their format).  Typing happens in dbt.
    for table, filename in SOURCE_FILES.items():
        path = (source / filename).as_posix()
        con.execute(
            f"create view src_{table} as select * from read_csv('{path}', header = true, all_varchar = true)"
        )

    # --- orders -------------------------------------------------------------
    con.execute(
        """
        create table orders_tagged as
        select
            *,
            cast(order_purchase_timestamp as timestamp) >= getvariable('cutoff') as is_new,
            -- coalesce: a missing timestamp compares to NULL, which must count as "no"
            coalesce(
                cast(order_purchase_timestamp as timestamp) < getvariable('cutoff')
                and order_status in ('delivered', 'shipped')
                and (
                    cast(order_approved_at as timestamp) >= getvariable('cutoff')
                    or cast(order_delivered_carrier_date as timestamp) >= getvariable('cutoff')
                    or cast(order_delivered_customer_date as timestamp) >= getvariable('cutoff')
                ),
                false
            ) as is_in_flight
        from src_orders
        """
    )

    order_columns = """
        order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at,
        order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date
    """

    # batch 1: old orders; in-flight ones are rolled back to their state at the cutoff
    con.execute(
        f"""
        create table orders_b1 as
        select
            order_id,
            customer_id,
            case
                when not is_in_flight then order_status
                when cast(order_approved_at as timestamp) >= getvariable('cutoff') then 'created'
                when order_delivered_carrier_date is null
                    or cast(order_delivered_carrier_date as timestamp) >= getvariable('cutoff') then 'processing'
                else 'shipped'
            end as order_status,
            order_purchase_timestamp,
            case when cast(order_approved_at as timestamp) < getvariable('cutoff')
                then order_approved_at end as order_approved_at,
            case when cast(order_delivered_carrier_date as timestamp) < getvariable('cutoff')
                then order_delivered_carrier_date end as order_delivered_carrier_date,
            case when cast(order_delivered_customer_date as timestamp) < getvariable('cutoff')
                then order_delivered_customer_date end as order_delivered_customer_date,
            order_estimated_delivery_date
        from orders_tagged
        where not is_new
        """
    )
    # batch 2: new orders + final version of the in-flight ones
    con.execute(f"create table orders_b2 as select {order_columns} from orders_tagged where is_new or is_in_flight")

    # --- order children follow their order ----------------------------------
    for table in ("order_items", "order_payments", "customers"):
        key = "customer_id" if table == "customers" else "order_id"
        for batch, is_new in (("b1", "false"), ("b2", "true")):
            con.execute(
                f"""
                create table {table}_{batch} as
                select s.* from src_{table} s
                where s.{key} in (select {key} from orders_tagged where is_new = {is_new})
                """
            )

    # --- reviews arrive when they are written --------------------------------
    # A review is in batch 1 only if it was written before the cutoff AND its
    # order is already known in batch 1 (a child never arrives before its parent).
    con.execute(
        """
        create table order_reviews_tagged as
        select
            *,
            cast(review_creation_date as timestamp) < getvariable('cutoff')
                and order_id in (select order_id from orders_tagged where not is_new) as is_batch_1
        from src_order_reviews
        """
    )
    con.execute("create table order_reviews_b1 as select * exclude (is_batch_1) from order_reviews_tagged where is_batch_1")
    con.execute("create table order_reviews_b2 as select * exclude (is_batch_1) from order_reviews_tagged where not is_batch_1")

    # --- products / sellers: batch 2 holds the ones first sold after the cutoff
    for table, key in (("products", "product_id"), ("sellers", "seller_id")):
        con.execute(
            f"""
            create table {table}_b2 as
            select s.* from src_{table} s
            where s.{key} in (select {key} from order_items_b2)
              and s.{key} not in (select {key} from order_items_b1)
            """
        )
        con.execute(
            f"create table {table}_b1 as select s.* from src_{table} s "
            f"where s.{key} not in (select {key} from {table}_b2)"
        )

    # --- write files ---------------------------------------------------------
    print(f"cutoff = {args.cutoff}")
    print(f"{'table':<16}{'batch_1':>10}{'batch_2':>10}{'source':>10}")
    for table in SOURCE_FILES:
        counts = []
        for batch_no, suffix in ((1, "b1"), (2, "b2")):
            out_dir = LANDING / f"batch_{batch_no}"
            out_dir.mkdir(parents=True, exist_ok=True)
            out_file = (out_dir / f"{table}.csv").as_posix()
            con.execute(f"copy {table}_{suffix} to '{out_file}' (format csv, header true, quote '\"', escape '\"')")
            counts.append(con.execute(f"select count(*) from {table}_{suffix}").fetchone()[0])
        total = con.execute(f"select count(*) from src_{table}").fetchone()[0]
        print(f"{table:<16}{counts[0]:>10,}{counts[1]:>10,}{total:>10,}")


if __name__ == "__main__":
    main()
