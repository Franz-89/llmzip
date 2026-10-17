# LLMZip Project — Development Plan v0.2

Oct 17, 2026 · @Francesco

## What changes from v0.1

Version 0.2 addresses the main risk upfront: before building the codec, a one-week Phase 0 checks that savings and comprehension are real. The remaining changes simplify the format and make the objectives measurable.

| Area | v0.1 | v0.2 | Why |
| --- | --- | --- | --- |
| Work sequence | LLM testing in week 7 | Phase 0 feasibility study with a go/no-go gate | If models cannot use references effectively, phases 1–4 serve no purpose |
| Baselines | None | Expanded, Expanded + prompt caching, LLMLingua | Value must be demonstrated against existing alternatives |
| Format | Binary first, text later | A single canonical text format | The LLM only reads text; two encodings double the specification |
| Sigil | Fixed `~`, with escaping | Chosen per document from symbols absent from the text | Almost always eliminates escaping (`~/` in paths, `~~` in Markdown) |
| Framing | `!end` terminator | Header with entry count, payload extending to end of file | An `!end` in the original document makes the archive ambiguous |
| Candidates | Substrings of at least 4 bytes | Sequences aligned with word boundaries | Fewer candidates, stable tokenization, more readable text |
| Gain | Retokenization of the entire document for each candidate | Local estimate, exact verification of the best candidates | Full retokenization is too slow beyond a few KB |
| Tokenizer | tiktoken | Interchangeable profiles for each model family | Target models are not limited to OpenAI |
| Identifiers | `~0`, `~1`, … in order | Cheapest IDs assigned to the most frequent entries | A reference such as `~12` can cost 2–3 tokens |
| Code blocks | Compressed like everything else | Protected by default | An LLM that copies code containing references produces broken code |
| Threshold | Output no worse than the original | Configurable minimum gain (default 5%) | Every reference has a comprehension cost |
| Evaluation | ≤2 percentage points, undefined sample | Non-inferiority test with a calculated sample size | 2 points require approximately 1,500 questions per model |
| MVP scope | Includes binary content | UTF-8 text only | Fewer edge cases in the first release |
| Name | LLMZip | Check for naming conflicts | A 2023 academic paper on compression using LLMs is already called LLMZip |

## Objectives and value proposition

LLMZip is worthwhile only if it fits more documentation into the same context than the alternatives, without degrading answers. The fundamental property remains unchanged:

```latex
D(C(x)) = x
```

C is the compressor, D the decompressor, and x the original byte sequence. Reversibility is guaranteed by the software, never by the LLM's interpretation.

| Objective | Target | Measurement |
| --- | --- | --- |
| Fidelity | 100%, byte for byte | Byte comparison and SHA-256 |
| Token savings | ≥ 20% median on eligible corpora | Eligibility criteria set before measurement; p10 and p90 also reported across the entire corpus |
| Comprehension | Non-inferior to the original within a declared margin | Paired test; see Verification strategy |
| Architecture | Offline | No LLM required for compression or decompression |

**Two distinct benefits.** Context savings (more documents within the window) are the primary benefit. Cost savings are secondary: for static documentation reused frequently, providers' prompt caching already greatly reduces input token prices, without any comprehension risk.

**Required baselines.** Every result is compared against:

1. Expanded: the original document, without compression.
2. Expanded + prompt caching: for cost comparisons.
3. [LLMLingua](https://github.com/microsoft/LLMLingua): lossy prompt compression, as a savings benchmark.
4. Simple deduplication: identical blocks replaced with natural-language references.
5. [In-context dictionary encoding](https://www.alphaxiv.org/abs/2604.13066): the closest published method to Direct mode, reimplemented if the code is unavailable.

**Input envelope.** Token counts always include the format instruction, legend, and payload. The technical header (version, checksum) is not sent to the model.

**Positioning.** The idea has direct precedents: LLMZip is not the first lossless approach using a dictionary readable by an LLM. The defensible novelty is an open, specified format, optimized for tokenizers, with protected code and shared dictionaries, evaluated on technical documentation without fine-tuning.

| Work | What it does | Difference from LLMZip |
| --- | --- | --- |
| [LTSC, meta-token (AWS, 2025)](https://arxiv.org/abs/2506.00307v1) | LZ77-style subsequence replacement, prepended dictionary; −27% and −18% tokens on the two tasks | Requires fine-tuning; does not define a file format |
| [In-context dictionary encoding (arXiv 2604.13066, 2026)](https://www.alphaxiv.org/abs/2604.13066) | Dictionary in the system prompt, no fine-tuning, criterion accounting for dictionary overhead | Repetitive data such as logs, rather than documentation; no specified format |
| [CompactPrompt (2025)](https://arxiv.org/pdf/2510.18043) | Reversible abbreviation of frequent n-grams in attached documents | One stage within a largely lossy pipeline |
| [Headroom](https://github.com/aicatalyst-team/headroom), [Claw Compactor](https://github.com/open-compress/claw-compactor/wiki) | Compression for agents; originals cached and retrieved on request | Reversibility through external storage: the model does not see the complete information |
| [LLMLingua](https://github.com/microsoft/LLMLingua), [llm-min.txt](https://www.sourcepulse.org/projects/2482450) | Content removal or distillation | Lossy |
| [TOON](https://github.com/toon-format/spec) | Compact format for structured data | Does not address prose and documentation |

To verify: whether LTSC and the 2026 work have public code that can be used as a baseline.

## Phase 0 — Feasibility (new, week 1)

Over one week, measure the maximum achievable savings and run an initial comprehension test using throwaway code. The reason: BPE tokenizers already compress frequent words, so only long, repeated phrases pay for their own legend entry (see the formula in the algorithm section). The 2026 work on in-context dictionary encoding already indicates that models interpret the dictionary well on logs: Phase 0 replicates its protocol on documentation.

**Activities**

1. Pilot corpus of 20 real documents, covering at least three types (API references, READMEs, configuration guides), selected before measurement.
2. Estimation script: greedy substitutions of repeated phrases, counts using 3 tokenizers, including the instruction and legend. It does not need to be lossless yet.
3. Pilot comprehension test: 100–150 questions, 2 models from different families, Direct versus Expanded, 3 runs.
4. Notation comparison: opaque IDs (`§3`) versus mnemonic aliases (`AuthSvc`) at similar token costs.

**Gate G0 — go/no-go**

| Outcome | Pilot condition | Decision |
| --- | --- | --- |
| Go | Median savings ≥ 10% and accuracy drop ≤ 5 points | Proceed with the specification |
| Revise | Savings of 5–10% or errors concentrated in one question type | Narrow the scope (e.g. prose only, multi-document only) |
| No-go | Savings < 5% or drop > 5 points | Switch to shared multi-document dictionaries, where repetition is greater |

The pilot sample is small: the gate is a signal for deciding where to invest, not final proof.

**Deliverable:** feasibility note with measurements, chosen notation, and a documented decision.

## System architecture

&#91;embedded content: architecture · offline compression and two reading modes\]

Four components are added compared with v0.1: the segmenter protects code, the tokenizer profile makes the optimizer independent of the model, the verifier checks every archive before saving it, and the prompt builder constructs the envelope for Direct mode. The prompt builder removes the technical header, which costs tokens and is of no use to the model.

## .llmz format (LLMZ/1)

There is only one canonical format, in text: it is what the LLM reads, so there is one grammar, one parser, and one set of test vectors. The binary encoding from v0.1 is removed.

```
LLMZ/1 sigil=§ entries=3 sha256=9f2c…e1 profile=o200k
§0=AuthenticationService
§1=access token
§2=HTTP 401 Unauthorized
---
# Authentication

§0 validates the §1.
If the §1 is expired, returns §2.
```

**Rules**

1. **Single-line header:** version, sigil, entry count, SHA-256 of the original, profile used.
2. **Dynamic sigil:** the encoder chooses a symbol from the profile that is absent from the document and cheap in tokens. Only if none is available are literal occurrences doubled.
3. **Framing without terminators:** the parser reads exactly `entries` entries, then the `---` line. The payload extends to the end of the file, preserving trailing newlines, CRLF, and BOM without ambiguity.
4. **Dictionary entries:** one per line; only three escapes in values (`\n`, `\r`, `\\`). Values are literal, never interpreted recursively.
5. **Reference boundary:** the ID is the longest sequence of ID characters after the sigil. The encoder does not replace an occurrence followed by an ID character: `§1` followed by `0` would be read as `§10`.
6. **Determinism:** the same input, profile, and version produce the same bytes. Ties follow documented rules; this also supports prompt caching.
7. **Valid UTF-8 only:** other inputs are rejected in V1.
8. **Decoder limits:** entry count, value length, and maximum expanded size, to guard against malicious archives.
9. **Errors:** the decoder rejects undefined IDs, malformed headers, excess entries, and incorrect checksums.

**Deliverable:** `format-v1.md` with an ABNF grammar and a directory of valid and invalid test vectors, versioned alongside the format.

## Compression algorithm

An entry is worthwhile only if its occurrences pay for its definition. For a string s with k occurrences:

```latex
G(s) = k \cdot (t_s - t_r) - (t_s + t_d)
```

t\_s is the string's token count, t\_r the reference's token count, and t\_d the legend row overhead. With t\_s = 6, t\_r = 2, and t\_d = 3, at least 3 occurrences are needed. A 2-token string, such as “access token”, is never worthwhile: the v0.1 example should be revised to use longer phrases.

**A — Candidates**

- Suffix array over the text, considering only sequences that start and end at a word or punctuation boundary.
- Protected regions excluded by default: code blocks and inline code (configurable).
- Pruning using the upper bound k · t\_s before any precise calculation.

**B — Gain estimation**

- Local retokenization of windows around each occurrence: with BPE pre-tokenization, effects remain local.
- Exact verification over the entire envelope only for the best N candidates in each iteration.
- The final archive cost is always measured exactly.

**C — Selection**

1. Priority queue ordered by estimated gain.
2. Apply the best candidate with positive gain; recalculate only overlapping candidates.
3. Resolve overlapping occurrences from left to right, deterministically.
4. Once selection is complete, assign the cheapest IDs in tokens to the entries with the most occurrences.

**D — Threshold and fallback.** If total savings fall below the threshold (default 5%), the output is passthrough: an archive with an empty dictionary.

**E — Verification during compression.** Before writing the file, the encoder decodes the result and compares its SHA-256 with the original.

**After the MVP:** beam search, and integer linear programming on small documents as an oracle, to determine how far greedy selection is from the optimum.

## Tokenizers and profiles

Gain depends on the tokenizer, so every archive is optimized for a profile declared in its header.

| Model family | Counting | Offline |
| --- | --- | --- |
| OpenAI (o200k\_base, cl100k\_base) | [tiktoken](https://github.com/openai/tiktoken) | Yes |
| Open models (Llama, Mistral, Qwen) | Hugging Face tokenizers | Yes |
| Claude | Anthropic token counting API | No |
| Gemini | Google countTokens API | No |

A profile contains: tokenizer, candidate sigils, ID cost table, and minimum threshold. The `multi` profile optimizes the worst case across multiple tokenizers.

For families without a local tokenizer, optimization uses a similar offline tokenizer, and measurements use the API only in benchmarks. This keeps compression offline, as required by the core principle.

## Repository organization

Python 3.12+ remains the right choice for the prototype. Additions compared with v0.1 are the specification with test vectors, profiles, segmenter, prompt builder, and baselines.

```
llmzip/
├── spec/
│   ├── format-v1.md          # ABNF grammar
│   └── vectors/              # new: valid and invalid archives
├── src/llmzip/
│   ├── segmenter.py          # new: protected regions
│   ├── candidates.py         # suffix array, word boundaries
│   ├── optimizer.py          # greedy with local estimation
│   ├── profiles.py           # new: tokenizers, sigils, ID costs
│   ├── encoder.py
│   ├── decoder.py
│   ├── format.py             # LLMZ/1 parser and writer
│   ├── verifier.py
│   ├── render.py             # new: Direct prompt builder
│   └── cli.py
├── tests/
│   ├── test_vectors.py       # new
│   ├── test_properties.py    # Hypothesis
│   ├── test_determinism.py   # new
│   └── fuzz/                 # new: decoder fuzzing
├── feasibility/              # new: Phase 0 notebooks
└── benchmarks/
    ├── corpus/
    ├── questions/            # new: questions by type, expected answers
    ├── baselines/            # new: Expanded, caching, LLMLingua
    └── evaluate.py
```

The v0.1 constraint remains: the encoder and decoder have no knowledge of the model. Only `profiles.py`, the optimizer, and the benchmarks use tokenizers.

## Revised roadmap

&#91;embedded content: roadmap · 7 phases, 5 gates, 9 weeks\]

Phase 0 adds one week, but may prevent eight weeks spent on a flawed assumption. Corpus and question preparation run in parallel from week 2, because annotation is the slowest task. Estimates still assume a single experienced Python developer working primarily on the project.

## Verification strategy

Reversibility is tested through property-based testing and fuzzing; comprehension through a non-inferiority test with sample size calculated before data collection.

**A — Reversibility (required)**

- Property-based tests with Hypothesis: random Unicode, text full of sigils, mixed CRLF, BOM, no final newline, text imitating a header.
- Decoder fuzzing on malformed archives in nightly CI.
- Determinism: compressing the same input twice must produce identical bytes.
- Versioned test vectors: every new version decodes all archives from previous versions.

**B — Comprehension (experimental)**

| Question type | Example | Why it matters |
| --- | --- | --- |
| Fact lookup | What error is returned for an expired token? | Basic case |
| Verbatim extraction | Copy the method signature | Highest risk: unexpanded references in the answer |
| Multi-hop | Combine two distant sections | Tests use of the legend across distances |
| Practical use | Write a correct API call | Measures the effect on generated code |
| Unanswerable | The document does not say | Measures hallucinations caused by expansion |

- Paired comparison: same question, same model, Direct versus Expanded, temperature 0 or multiple runs.
- At least 3 models, one per tokenizer family.
- Automated evaluation where possible; an LLM judge used only in a blinded setup, with human spot checks.
- Analysis using McNemar's test or paired bootstrap.

**Sample size.** Assuming 10% discordant pairs, 80% power, and a one-sided alpha of 5%:

| Non-inferiority margin | Questions per model (approx.) | When |
| --- | --- | --- |
| 5 percentage points | 250 | MVP |
| 2 percentage points | 1,500 | v1.0 |

**Metrics**

| Metric | Target |
| --- | --- |
| Byte-for-byte round trip | 100% |
| Deterministic output | 100% |
| Malformed archives accepted | 0, no decoder crashes after 24 hours of fuzzing |
| Token reduction | ≥ 20% median on eligible corpora, full distribution reported |
| Accuracy regression | Non-inferiority: 5 points for the MVP, 2 points for v1.0 |
| References leaked into answers | ≤ 1% of answers |
| Cost and latency per answer | Reported against Expanded and Expanded + caching |
| Stability across tokenizers | Separate report for each profile |

**Operating modes.** Direct sends the instruction, legend, and payload, leaving protected code literal. Expanded decompresses before sending: guaranteed fidelity, no savings. Direct is the innovation to measure; Expanded remains the automatic fallback if a model fails to meet the threshold.

## Shared dictionaries (v0.2)

Shared dictionaries are where repetition is greatest, and a stable legend at the start of the prompt works well with prompt caching. They remain scheduled after the MVP, but become the first alternative if Phase 0 yields a negative result.

| Level | Scope | Example | Identification |
| --- | --- | --- | --- |
| Local | Single document | Repeated phrases in `auth.md` | Within the archive |
| Package | Group of documents | Common API terms | Content hash + version |
| Global | Entire project | Service names and conventions | Content hash + version |

- **Immutable:** a new entry creates a new version; archives reference the hash of the dictionary used.
- **Separate ID namespaces:** distinct prefixes for each level prevent collisions within a bundle.
- **Stable IDs:** append-only dictionaries avoid invalidating existing caches and archives.
- **Tradeoff to measure:** within the context bundle, the full package legend is stable and therefore cacheable; including only the entries used costs fewer tokens but changes with every request.

Savings are always calculated over the complete bundle sent to the model.

## Risks and countermeasures

The greatest risk is that actual savings are small: this is why Phase 0 comes before everything else. Risks added since v0.1 appear first.

| Risk | Countermeasure |
| --- | --- |
| Actual savings too low because BPE already compresses frequent words | Phase 0 with a go/no-go gate; fallback to multi-document dictionaries |
| Prompt caching makes cost savings marginal | Position around context savings; caching baseline in every report |
| The LLM includes unexpanded references in answers or code | Code protected by default; reference leakage metric; explicit prompt instruction |
| Compressed text evades security scanners and human review | Always scan decompressed text for injections and secrets |
| A reference followed by a digit changes meaning | Longest-sequence rule; encoder skips that occurrence |
| LLMZip naming conflict | Check PyPI and GitHub before release; alternative name if needed |
| A reference is misinterpreted by the LLM | Notation chosen in Phase 0; benchmarks by question type |
| The legend consumes too many tokens | Gain formula includes definition cost; minimum threshold |
| A substitution alters the document | Unambiguous grammar, SHA-256 verification during compression and decompression |
| Differences between tokenizers | Separate profiles; multi profile for the worst case |
| Malicious archives with excessive expansion | Limits on entries, value length, and expanded size |
| Documents with little repetition | Passthrough below the threshold |
| Documentation containing hostile instructions | Treated as untrusted data in both modes |
| More inference work required to read the notation | Measure latency, output tokens, and total cost per answer |

## MVP, future development, and firm decisions

The first milestone is now the feasibility note at the end of week 1; a CLI operating on a Markdown file remains the Phase 4 goal.

**MVP checklist**

Feasibility

- [ ] Pilot corpus of 20 documents, with eligibility criteria set before measurement
- [ ] Maximum savings estimate across 3 tokenizers, including overhead
- [ ] Pilot comprehension test and notation selection
- [ ] Documented go/no-go decision

Foundations

- [ ] Text-based LLMZ/1 specification with grammar and test vectors
- [ ] Deterministic encoder and decoder, UTF-8 only
- [ ] Property-based tests and decoder fuzzing
- [ ] SHA-256, limits, and archive validation

Compression

- [ ] Candidates at word boundaries, with protected regions
- [ ] Token-aware greedy selection with local estimation and exact verification
- [ ] Interchangeable tokenizer profiles
- [ ] Minimum threshold and passthrough

Usability

- [ ] CLI compress / decompress / verify / stats
- [ ] Prompt builder for Direct mode
- [ ] Token report for each profile

Validation

- [ ] Corpus of at least 50 documents, questions by type with expected answers
- [ ] Expanded, Expanded + caching, and LLMLingua baselines
- [ ] Non-inferiority test on 3 models
- [ ] Automated results report

**Development after the MVP**

| Version | Contents |
| --- | --- |
| v0.2 | Shared dictionaries, cacheable context bundles |
| v0.3 | Beam search, ILP oracle, multi-tokenizer optimization, incremental compression |
| v1.0 | SDK, MCP tools, RAG integration, on-demand decompression, 2-point margin |

**Firm decisions**

1. No LLM is required for compression or decompression.
2. No substitution depends on semantic inference.
3. No result is published without comparison against the baselines.
4. If Phase 0 yields a no-go, change direction before writing the codec.
