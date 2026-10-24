# ADR-Led Synthesis of Independent Full-Repository Architecture Proposals

**Project:** Volley World: Battle Lines  
**Phase:** Comparative adjudication and specification assembly, NOT implementation  
**Prerequisite:** Independently completed and quarantined reconstruction packages for a frozen source commit.

## 0. Mission and non-negotiable boundaries

Produce the most defensible **globally coherent** reconstruction and proposed architecture by comparing multiple independently reasoned attempts. Treat **their Architectural Decision Records, design premises, evidence and justifications** as the primary comparative inputs; use full specifications, source and tests as independent checks.

This is **not majority voting**, averaging, document concatenation, picking the longest output, adopting the most familiar pattern, or forcing a compromise. A minority perspective may prevail on stronger reasoning; no revision or rejection is required unless evidence or coherence warrants it.

Do not begin until the execution-protocol acceptance gate verifies independent inputs, identical frozen source/evidence, artifact manifests and no mutual visibility during candidate preparation. If the gate fails, record the contamination and do not represent outputs as genuinely independent. If the source changed mid-run, do not silently combine conclusions based on different commits.

The goal is to select a model in which the human explanation, semantic definitions, equations, causal stages, authoritative states, code responsibility map and future implementation rules agree. Do not implement or refactor the game in this phase.

## 1. Validate and normalize evidence before opinions

Inventory all candidate outputs, run manifests, commit hashes, source coverage, test executions, scope gaps and ADR references. Record whether any candidate was incomplete or contaminated. Do not silently weight an unevaluated claim equally with a verified one.

Reconcile factual claims using the same evidence states:
- DOC (documented intent), SRC (source-supported behavior), VER (actually test-verified);
- INF (inferred interpretation), PROP (proposed change), OPEN (uncertain/conflicted).

When a design document disagrees with code, separate what is intended, what is implemented, what is observed, and what requires designer approval. Verify pivotal claims against the frozen source snapshot rather than accepting candidate prose as authority. If access is insufficient, record unresolved evidence limitations.

## 2. Normalize by design problem and causal responsibility, not by vocabulary

Candidates may propose different ontologies, subsystem boundaries, ADR numbering, naming, or ways to express the same mechanics. Before deciding between them:

1. Recover the underlying **player-facing rule or engineering concern** addressed.
2. Identify its required behavior, causal responsibilities, invariants, and state writers.
3. Compare the candidate design premises and their evidence; challenge faulty premises.
4. Map semantically equivalent concepts even if named differently, **without** silently treating superficially similar terms as identical.
5. Distinguish substantive alternative models from presentational or naming differences.
6. Compare architecture owners only after agreeing on the actual responsibilities being owned.
7. Preserve genuinely different decompositions for evaluation rather than squeezing them into a predetermined taxonomy.

This normalization procedure does **not** declare one candidate's ontology as canonical in advance. Build a neutral crosswalk; select final vocabulary only after evaluating underlying meaning. Allow a superior novel decomposition to emerge in synthesis and treat it as a new proposal requiring justification.

## 3. Compare ADR reasoning systematically

For each consequential decision/problem, produce a cross-run comparative entry with:
- Normalized design question and stakes.
- Linked original run and ADR identifiers.
- Each candidate's claimed premise, evidence, logic, proposed representation and plausible alternatives.
- What each model preserves or compromises in game causality and behavioral fidelity.
- Semantic clarity: terms, units/frames, intention/prediction/state/outcome distinction, permissible transformations.
- Ownership, execution/event order, dependencies and lifecycle.
- Future extensions: predictability, isolation, genuine new concepts, interactions and performance implications.
- Coupling, boilerplate, duplicate rules, exception pressure, cognitive cost and maintainability.
- Strongest counterexample and practical validation for each viable alternative.
- Disposition and comparative explanation.

Use proportional justification (factual trace, reasoned defense, or deep comparative adjudication). Rationale quality and factual premises are more important than agreement counts. If candidates agree but for bad reasons, revise the justification. If candidates disagree because they reconstructed incompatible game rules, resolve evidence before architecture. Do not fabricate adversaries where the evidence strongly selects one option.

Permitted dispositions: adopt, revise, combine when truly compatible, reject for documented reasons, defer pending test/designer input, or unresolved. Explicitly preserve uncertainty without falsely forcing completion.

## 4. Construct a coherent whole, then challenge it

Choose mutually compatible semantic concepts, game rules, execution models and technical boundaries. Test the combined result for:
- Terminological and meaning continuity down to important individual variables.
- Same causal direction from player intent through execution and actual result.
- Single clear authority for consequential state and legal cross-domain dependencies.
- Consistent event order, lifecycle, effect conflict policy and serialization.
- Compatible component interfaces, extension contracts and conventions.
- No novel unapproved gameplay changes disguised as architecture cleanup.
- Whole-system complexity (not merely local module simplicity).

A set of strong isolated ADR decisions is not necessarily a strong global architecture. Where decisions conflict, revise them with reasons, prefer a coherent runner-up when justified, or leave the dependency explicitly unresolved. Record *newly synthesized* decisions as new ADRs with evidence and counterexamples, not as established truths.

## 5. Falsification and future-change simulation

Use actual repo-grounded mechanics, unusual cross-system interactions, failure/lifecycle edges and plausible hypothetical expansions chosen for their ability to distinguish candidate models—not to satisfy a fixed template. Consider player action physics and contacts, conditional traits, progression rewards, rally legality, content variations and scoring only insofar as actual code or authorized design makes them relevant.

For each probe, demand a plain-language outcome, authoritative rule, semantic and variable contracts, causal pipeline, proposed change procedure, impacted versus untouched responsibilities, edge cases and tests. Compare alternatives against the **same** probe when meaningful.

Where useful, prescribe a future **independent implementation-plan convergence trial**: give the unified constitution to separate agents and the same new mechanic, then compare ownership, concept definitions, causal stages, and tests. Allow coding style differences; detect conceptual contradictions. Do not assert this trial happened unless it was actually conducted.

## 6. Development governance and migration

Integrate a rigorous Development Constitution from the selected architecture. Define game-specific rules for feature intake, vocabulary and variable semantics, code ownership, authoritative writers, extension procedures, effect interaction, exceptions, test maintenance, ADR updates, documentation, and safe deprecations.

Separate:
- Established game behavior and current implementation.
- Chosen **target** architecture and approved semantic interpretations.
- Proposed unapproved gameplay changes.
- Migration/compatibility steps to reach the target.

Design a staged migration blueprint with dependency grouping, behavior baselines, tests, safe cutovers, rollback and approval gates. Do not change gameplay or automatically implement the proposal.

## 7. Complete synthesis outputs

Deliver all outcomes below with stable cross-references (file layout may differ):
1. Executive decision map and selected architecture overview.
2. Neutral concept/causal-responsibility crosswalk across candidates.
3. ADR comparison matrix with premise/evidence/arguments and provenance.
4. Synthesis ADRs for accepted, modified, combined, rejected, deferred and newly derived decisions.
5. Unified Game Design Specification plus discrepancies requiring designer input.
6. Conceptual Reference Manual.
7. Canonical Semantic Ontology and Variable Registry.
8. Causal Execution Models, rules, formulas and pseudocode.
9. Coherent proposed Technical Architecture and abstraction analysis.
10. Development Constitution and detailed extension contracts.
11. Bidirectional Design–Code Atlas showing existing and target owners separately.
12. Behavioral invariants, adversarial validation and future-change stress plan/results.
13. Migration/implementation blueprint only, with rollback and approvals.
14. Source coverage, provenance, uncertainty, confidence and contamination report.

Explain significant adjudications by **why this model survives better scrutiny**, cite original candidate ADRs, and specify what evidence would reopen the choice. Do not artificially generate changes, conflict, consensus or novel abstractions.

**Completion condition:** A skilled programmer and the designer can trace each important game concept from explanation to formal rule, causal calculation, authoritative responsibility, future extension procedure and test. Any irreducible ambiguity is named and placed behind a clear decision gate.
