{% docs net_revenue %}
**Net revenue (BRL)**: the price of the items in orders that became a sale.

- Counted: `item_price` of every item whose order is NOT `canceled` or `unavailable`.
- Not counted: freight (`freight_value`), which is passed on to the carrier.
- Defined once, in the macro `is_revenue_order` and the variable
  `non_revenue_order_statuses`, and stored as a column so that every tool
  reports the same number.
{% enddocs %}
