# Olist Analytics

An analytics engineering project on the public Olist Brazilian e-commerce dataset:
Snowflake as the warehouse, dbt Core for transformation, Power BI for reporting,
GitHub Actions for CI/CD.

**Business question:** how much net revenue does the marketplace make, where does it
come from, and what do late deliveries cost in customer satisfaction?

## Status

Work in progress. This first commit sets up the foundations:

- `infra/` Snowflake warehouses, databases, roles and grants as code
- `profiles.yml` three targets (dev, ci, prod), key-pair auth from environment variables
- `.github/workflows/` CI on pull requests, deployment to production on merge to `main`
- `.sqlfluff`, `.pre-commit-config.yaml` code-quality tooling

## Setup

```bash
python -m venv .venv
.venv/Scripts/activate
pip install -r requirements.txt
dbt deps
python infra/apply_setup.py
```
