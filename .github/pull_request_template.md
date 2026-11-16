## What and why

<!-- One or two sentences: what changes, and which business question or problem it serves. -->

## Type of change

- [ ] New model / column
- [ ] Change to existing logic (metric definition, grain, filter)
- [ ] Tests or documentation only
- [ ] Infrastructure / CI

## Checklist

- [ ] `dbt build --select state:modified+` passes locally in my dev schema
- [ ] New models have a description, a primary-key test (`unique` + `not_null`) and a stated grain
- [ ] No secrets, keys or raw data in the diff
- [ ] Columns with personal data are hashed or masked, and tagged `contains_pii` in YAML
- [ ] If an incremental model changed shape: noted below whether a `--full-refresh` is needed

## Impact on production

<!-- Does a table change shape? Does a number in the dashboard change? Is a full refresh needed after merge? -->
