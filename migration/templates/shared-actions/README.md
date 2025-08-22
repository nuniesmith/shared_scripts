# fks-shared-actions (Template)

Composite GitHub Actions for FKS ecosystem.

## Usage
```yaml
jobs:
  lint_py:
    steps:
      - uses: actions/checkout@v4
      - uses: yourorg/fks-shared-actions/lint-python@v1
```
