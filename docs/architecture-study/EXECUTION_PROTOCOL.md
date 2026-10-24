# Independent Reconstruction Execution Protocol

**Status:** Mandatory orchestration rules for the architectural study. These are operational independence requirements, not a proposed software architecture.

## Objective

Run six (or an explicitly revised number of) **genuinely isolated architectural reconstructions** from exactly the same frozen code and approved design materials. Only after all outputs are sealed should an independent synthesis agent compare them. This ensures differences are attributable as far as practicable to independently generated reasoning rather than exposure to prior candidates or silently changing evidence.

## Preparation: lock input conditions

1. Select a **source commit SHA**, not a moving branch name. Record any submodules, Git LFS pointers, generated dependencies and exact snapshot availability.
2. Build an **approved design-evidence manifest** listing relative path, content digest/version and authority notes for each supplied document. Specify treatment of historical notes, existing repo documentation and external information. If agents can inspect other repo documents, they all receive the same snapshot.
3. Freeze the **reconstruction prompt bytes** and digest. The entire prompt, including additions and clarifications, must be identical across runs. Do not coach later attempts with insights from earlier attempts.
4. Hold equivalent model family/version, reasoning or token budget, tools, read permissions, execution time budget and test permissions wherever practical. Record unavoidable differences rather than claiming perfect equivalence.
5. Decide output directory templates, run IDs and collection mechanism **without embedding target architectural opinions**. The run identifier is metadata, not an invitation for a specialized role.
6. Ensure analyses are **read-only with respect to the game source**. Running tests may produce isolated artifacts but must not mutate the frozen source or shared evidence.

## Isolation requirements

Each run must:
- Start in a new context/session with **no inherited discussion about the other runs**, interim feedback or prior candidate conclusions.
- See the same source SHA and same approved design evidence.
- Be unable to read, search, import, or infer prior/in-progress candidate reports, ADRs, summaries, instructions, scratchpads, agent messages, or output directories.
- Write only to its own isolated workspace; never write into a shared source tree that another reconstruction can subsequently read.
- Receive identical handoff instructions and comparable tool/environment permissions.
- Never run synthesis, consult a colleague run, or adjust its proposal toward anticipated consensus.

**An instruction to ignore neighboring directories is not isolation.** Use separate clones/worktrees with appropriate filesystem or sandbox permissions; if the platform cannot enforce isolation, hold candidate artifacts outside any accessible workspace until all runs finish. A different worktree alone is insufficient if agents have access to the parent filesystem. If no adequate quarantine is possible, document this limitation and treat independence claims as qualified.

Agents may independently select different abstractions, ontologies, subsystem maps, variables, pseudocode approaches and architectures. Reporting obligations are shared; conceptual conclusions are not predetermined.

## Suggested working layout (not an architectural model)

    architecture-study/
      protocol/
        RECONSTRUCTION_HANDOFF.md
        SYNTHESIS_HANDOFF.md
        EXECUTION_PROTOCOL.md
      runs/
        run-01/
        run-02/
        run-03/
        run-04/
        run-05/
        run-06/
      synthesis/
        evidence-crosswalk/
        decisions/
        final-specification/

**Important:** The example above describes eventual centralized archival layout, **not** an agent-visible working directory during reconstruction. Do not place other run outputs in a location readable by active agents. The prompts may live under docs/architecture-study in the repo, but an actual run should work against a frozen source snapshot and place reports outside any later agent's input scope. Avoid letting reports written to the repository during the study become part of the source snapshot for subsequent runs.

## Run manifest and acceptance evidence

Each sealed run must include:
- Run ID, model identity/version, agent/runtime settings, tool permissions and execution environment.
- Start/end timing and any interrupted/retried segments (retry policy must not feed other runs' findings).
- Source commit SHA, approved document manifest/digests, prompt digest, and test environment.
- Whether the run could access others' outputs; how isolation was enforced, and any contamination incident.
- Complete deliverable file manifest with content hashes, coverage declaration and observed test outcomes.
- Known omissions, tool errors, context-budget interruptions and deviations from protocol.

A machine-readable manifest is encouraged, but its schema must not force an architectural conclusion. Suggested fields: run_id, source_sha, prompt_sha256, design_manifest_sha256, environment, artifacts, coverage, executed_tests, isolation_verification, deviations.

## Sealing and synthesis gate

1. Complete each run independently and seal its outputs with digest-verified manifests. No cross-run feedback during execution.
2. Compare source SHA, design manifest digest, prompt digest, run permissions and isolation records across runs.
3. If any run used changing inputs, cross-run data, altered prompts or unverifiable isolation, **flag or exclude it from the independent cohort**; do not quietly normalize away the difference. Decide whether a clean rerun is needed.
4. Snapshot all accepted results and make them available together to the synthesis agent, along with frozen source/evidence and this protocol.
5. Invoke SYNTHESIS_HANDOFF.md **only after this gate**. Synthesis must first map equivalent game responsibilities across different vocabularies/decompositions, then compare ADR premises and justifications, then build and validate a compatible whole.
6. Designer review is required for unresolved game-intent disputes before promoting those claims to canon. **Synthesis completion does not authorize gameplay implementation.**

## Controls on arbitrariness

- Six is the planned sample, not a magical guarantee of quality; stopping or adding runs requires explicit recorded decision.
- No requirement that runs intentionally disagree, invent alternatives, follow one framework, or split responsibilities into prescribed categories.
- No success metric based on majority vote, number of abstractions, document size or the appearance of convergence.
- The only common constraints on proposals are evidence fidelity, complete coverage, readable defensible reasoning, semantic/causal accountability, testability and required output coverage.
- Convergence is a **later** property to test in independent *implementation plans* from the selected constitution, not a requirement placed on discovery runs.

## Acceptance checklist

- [ ] Frozen source commit and identical verified evidence manifest
- [ ] Identical reconstruction prompt digest
- [ ] Separate, restricted contexts and output storage
- [ ] Comparable model/tools/budgets and documented deviations
- [ ] Each candidate has a coverage report and justification-linked ADRs
- [ ] Each candidate sealed before any synthesis access
- [ ] Inputs and independence gate audited
- [ ] Only then: synthesis and adversarial validation
- [ ] No gameplay code changed by either discovery or synthesis phase
