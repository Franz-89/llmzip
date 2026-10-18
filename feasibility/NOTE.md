# Phase 0 — Feasibility note (draft)

Oct 17, 2026 · status: savings measured, comprehension pilot not run · **proposed decision: no-go for single-document Direct mode**

## What was measured

- **Corpus:** 20 Markdown docs from `test_docs/`, four types (api_reference ×2, readme ×5, guide ×8, design ×5), plus two multi-document bundles: the 10 ADRs (`adr-bundle`) and all 20 pilot docs concatenated (`pilot-bundle`). Selection and eligibility criteria are in `corpus.json` and were fixed before any measurement.
- **Estimator:** `estimate.py`. It runs greedy substitution of repeated word-aligned phrases and picks the sigil per document from symbols absent from the text. Gain is `k·(t_s − t_r) − (t_s + t_d)`. The cheapest IDs go to the most frequent entries, and round-trip expansion is asserted for every output.
- **Tokenizers:** o200k_base, cl100k_base, Qwen2.5 (HF).
- **Variants:** opaque IDs (`§0`), mnemonic aliases (`§AuthSvc`), and opaque with code protection turned off.
- **Cost:** the envelope always counts instruction (55 tokens) + legend + payload.

Run: `.venv/bin/python feasibility/estimate.py` → `results/estimate.md`, `results/estimate.json`.

## Results

Single documents, savings = 1 − envelope / original:

| Profile | Variant | Median | p10 | p90 | Docs ≥ 10% |
| --- | --- | --- | --- | --- | --- |
| o200k | opaque | −2.0% | −11.1% | −0.7% | 0/20 |
| o200k | mnemonic | −2.0% | −11.3% | −0.8% | 0/20 |
| o200k | opaque, unprotected | −1.0% | −11.8% | +1.3% | 0/20 |
| cl100k | opaque | −2.0% | −11.1% | −0.7% | 0/20 |
| Qwen2.5 | opaque | −2.0% | −10.4% | −0.8% | 0/20 |

With the 5% threshold every document becomes passthrough, so effective savings are 0% everywhere.

**Upper bound.** A relaxed run on the five largest docs (o200k) allowed multi-line candidates up to 120 units, turned code protection off and excluded the instruction cost. It still reached only +0.2% to +4.8%. A tuned optimizer will not rescue single-document savings on this corpus. The repetition simply isn't there: the top entries are fragments like `.\n- *`, `the NUC` and `.php\``.

Bundles:

| Bundle | Profile | Total (opaque) | Payload only (legend + instruction free, e.g. cached/shared) |
| --- | --- | --- | --- |
| adr-bundle (10 ADRs) | o200k | +6.7% | +18.6% |
| adr-bundle | Qwen2.5 | +9.5% | +24.2% |
| pilot-bundle (20 docs) | o200k | +0.3% | +2.6% |
| pilot-bundle, unprotected | o200k | +1.6% | +9.3% |

**Notation.** On cost alone, opaque is better. Mnemonic aliases tie on single docs (both near zero), but on the ADR bundle they keep only about a third of the payload savings (7.0% vs 18.6%). The comprehension side of this comparison has not been measured.

## Gate G0

| Criterion | Threshold | Measured | Verdict |
| --- | --- | --- | --- |
| Median savings | ≥ 10% go, 5–10% revise, < 5% no-go | −2.0% (all profiles) | **No-go** |
| Accuracy drop | ≤ 5 points | not run | — |

The savings criterion alone triggers no-go, so the comprehension pilot cannot change the outcome for single-document Direct mode. It was also blocked in practice: there are no model API keys in this environment.

## Proposed decision

Per the plan's firm decision 4, change direction before writing the codec. The plan's fallback is **shared multi-document dictionaries**. The only positive signal here supports it: templated document families (ADRs) give 19–24% payload savings once the legend is shared and cached, but the heterogeneous pilot bundle gives only ~3%. Suggested next steps:

1. Measure shared dictionaries with a train/held-out split. Build the dictionary on one part of a doc family, apply it to unseen docs, and count the legend once per bundle, amortized.
2. Find corpora with families of templated docs (ADRs, per-endpoint API pages, runbooks, generated references such as `ui/template-map.md`). This corpus is mostly one-off prose design docs, which is close to the worst case.
3. Run the comprehension pilot (100–150 questions, 2 model families) on the shared-dictionary setup instead of single-doc Direct. This needs API keys.

**Caveat:** all 20 docs come from one project and one writing style. The no-go is solid for this kind of corpus, but it is not proof for every kind of documentation.
