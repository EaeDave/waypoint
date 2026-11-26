# Evidence behind the rules

Status: November 2026. Read this when a user challenges a rule or asks why.
Many sources are preprints with small N; treat magnitudes as indicative.

## Context files (AGENTS.md)

- No general gain in task success; +20% inference cost. Instructions are
  followed and help for non-standard practices. Gloaguen et al.,
  arXiv:2602.11988.
- Correctness effect bounded to at most 10-15pp; agents fail on
  implementation skill, not missing repo knowledge. Khatri, arXiv:2607.27250.
- With source readable, compact docs do not beat the issue alone.
  Arman & Molybog, arXiv:2609.31587.
- Curated, non-redundant AGENTS.md: runtime -28.6%, output tokens -16.6%.
  Lulla et al., arXiv:2601.20404.
- Instruction-following degrades past ~150-200 instructions.
  arXiv:2507.11538. The ~100-line cap is practitioner consensus.

## Checks over prose

- Executable checks: 88.3% constraint compliance vs 67.0% prompt-only and
  50.3% with LLM self-reflection. ContextCov, arXiv:2603.00822.
- Layering violations kept landing after AGENTS.md stated the rule. Naming
  forbidden module paths in context dropped one model from 90% to 62%
  compliance. GYROCOMPASS, GroundLM 2026 (aclanthology 2026.groundlm-1.76).

## Code quality

- Clean vs messy minimal pairs: same pass rate, 7-8% fewer tokens, 34% fewer
  file revisits. arXiv:2605.20049.
- Code health correlates negatively with input tokens. arXiv:2608.18645.
- Iterative work: structural erosion rises in 77% and verbosity in 75.5% of
  trajectories; prompt guidance lowers the start level, not the rate.
  SlopCodeBench, arXiv:2603.24755.
- Agents resolve up to 13.1% fewer tasks on agent-written code; the signal is
  changed validation and error handling. arXiv:2606.21804.
- Typed contracts recover most of the gap for weaker models.
  arXiv:2608.21747.

## Locality and vertical slices

- 65% on SWE-bench Verified vs 21% on multi-file evolution. SWE-EVO,
  arXiv:2512.18470.
- One-sided edits of cross-file contracts are a top drift family.
  GYROCOMPASS.
- No controlled study compares slices with layers for agents. The slice rule
  is inferred from locality and working-set evidence. Expect lower cost and
  more predictable edits, not higher correctness.

## Unit size

- Successful trajectories cluster at 20-30k tokens; at 64k the resolve rate
  falls to 0-7% even with perfect retrieval. arXiv:2602.16069.
- Length alone costs 13.9-85% accuracy within the window. Du et al.,
  EMNLP 2025 findings.1264.
- Splitting at raw function boundaries costs 3.57-5.64pp EM.
  arXiv:2605.04763.
- Defect density per line is higher in small modules. Koru et al., IEEE TSE
  2009; Basili & Perricone 1984. The 200-line optimum is a binning artifact
  (Jones, 2023). Java methods up to ~24 SLOC: Chowdhury et al., MSR 2022.

## Verification

- Prescribed test-first ritual: regressions 6.08% to 9.94%. Targeted test
  context: -70%. TDAD, arXiv:2603.17973.
- Human tests as spec: 94.3% vs 68% with self-generated. TDFlow, EACL 2026.
- Pre/post-conditions before test generation: +9.8pp bug detection.
  arXiv:2608.17177.
- Refactors tangled into fixes lower compilability, no correctness gain.
  arXiv:2605.22526.
