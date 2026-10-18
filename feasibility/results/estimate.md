# Phase 0 — savings estimate

Savings = 1 − envelope / original, where the envelope is instruction + legend + payload.
Effective savings apply the 5% passthrough threshold.

## Single documents (pilot corpus, n=20)

| Profile | Variant | Median | p10 | p90 | Median effective | Docs ≥ 10% |
| --- | --- | --- | --- | --- | --- | --- |
| o200k | opaque | -2.0% | -11.1% | -0.7% | 0.0% | 0/20 |
| o200k | mnemonic | -2.0% | -11.3% | -0.8% | 0.0% | 0/20 |
| o200k | opaque-unprotected | -1.0% | -11.8% | 1.3% | 0.0% | 0/20 |
| cl100k | opaque | -2.0% | -11.1% | -0.7% | 0.0% | 0/20 |
| cl100k | mnemonic | -2.1% | -11.3% | -0.7% | 0.0% | 0/20 |
| cl100k | opaque-unprotected | -1.1% | -11.8% | 1.4% | 0.0% | 0/20 |
| Qwen/Qwen2.5-7B-Instruct | opaque | -2.0% | -10.4% | -0.8% | 0.0% | 0/20 |
| Qwen/Qwen2.5-7B-Instruct | mnemonic | -2.1% | -10.9% | -0.8% | 0.0% | 0/20 |
| Qwen/Qwen2.5-7B-Instruct | opaque-unprotected | -2.5% | -11.7% | 0.8% | 0.0% | 0/20 |

## By document type (median savings, opaque notation)

| Type | o200k | cl100k | Qwen/Qwen2.5-7B-Instruct |
| --- | --- | --- | --- |
| api_reference | -1.2% | -1.2% | -1.2% |
| bundle | 3.5% | 3.7% | 4.8% |
| design | -1.2% | -1.1% | -1.6% |
| guide | -3.0% | -2.9% | -3.0% |
| readme | -9.1% | -9.1% | -9.0% |

## Per document (opaque notation)

| Document | Type | o200k | cl100k | Qwen/Qwen2.5-7B-Instruct | Entries (o200k) | Protected |
| --- | --- | --- | --- | --- | --- | --- |
| API_PUBLIC.md | api_reference | -1.0% | -1.0% | -0.9% | 12 | 36% |
| apis.md | api_reference | -1.5% | -1.5% | -1.5% | 1 | 32% |
| README.md | readme | -19.4% | -19.5% | -19.1% | 2 | 23% |
| project-overview.md | readme | -9.1% | -9.1% | -9.0% | 0 | 16% |
| iaapa/README.md | readme | -10.9% | -10.9% | -10.1% | 1 | 9% |
| design_handoff_orbit_homepage/README.md | readme | -1.2% | -1.3% | -1.4% | 12 | 11% |
| skills/README.md | readme | +0.9% | +0.9% | +0.9% | 9 | 19% |
| deployment.md | guide | -8.1% | -8.1% | -7.9% | 0 | 30% |
| DB_POOLING.md | guide | -1.9% | -1.9% | -1.8% | 5 | 29% |
| testing.md | guide | -13.1% | -13.1% | -12.9% | 0 | 27% |
| database.md | guide | -8.8% | -8.8% | -8.5% | 0 | 25% |
| MIGRATION_PLAYBOOK.md | guide | -0.8% | -0.8% | -0.8% | 10 | 46% |
| CODING_STANDARDS.md | guide | -2.1% | -2.1% | -2.1% | 1 | 65% |
| product-import-matching.md | guide | -3.4% | -3.4% | -3.4% | 1 | 17% |
| lco-revert-and-idempotency.md | guide | -2.6% | -2.4% | -2.6% | 12 | 29% |
| PERMISSIONS.md | design | +0.0% | +0.1% | -0.6% | 27 | 17% |
| EVENTS.md | design | -0.8% | -0.7% | -0.8% | 17 | 23% |
| DYNAMIC_PRICING.md | design | -1.2% | -1.1% | -1.6% | 17 | 16% |
| MAINTENANCE.md | design | -1.7% | -1.6% | -1.6% | 7 | 18% |
| architecture.md | design | -4.5% | -4.5% | -4.5% | 1 | 28% |
| adr-bundle | bundle | +6.7% | +7.1% | +9.5% | 22 | 12% |
| pilot-bundle | bundle | +0.3% | +0.4% | +0.2% | 180 | 27% |

## Envelope breakdown (o200k, opaque, totals over the 20 documents)

| Original | Instruction | Legend | Payload | Envelope |
| --- | --- | --- | --- | --- |
| 64151 | 1100 | 1107 | 63010 | 65237 |
