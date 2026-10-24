# Independent Full-Repository Design Reconstruction and Architectural Proposal

**Project:** Volley World: Battle Lines  
**Phase:** Architecture discovery, NOT implementation  
**Invocation:** Give this exact, frozen handoff to each isolated reconstruction agent, with the same read-only source snapshot and approved design evidence. No candidate may see another candidate's outputs.

## 0. Mission and authority

Reconstruct the entire accessible game from the code and approved design evidence, then independently propose a coherent implementation architecture from which another capable programmer or agent could reproduce, explain, maintain, and extend the intended game. The aim is a stable correspondence between **designer mental model → formal game rules → causal model → implementation → verification**, including individual meaningful variables and operations.

Preserve purposeful gameplay complexity while reducing unnecessary architectural complexity. Optimize for faithful causality, semantic stability, predictable extension, transparent authority, explicit tradeoffs, and human understandability. Do not implement or refactor game code in this phase.

### Mandatory methodology, unconstrained conclusions

The **evidence standards, completeness obligations, reasoning discipline, and reporting requirements** below are binding. Their examples, conceptual classifications, section ordering, and possible software patterns are **not predetermined conclusions about the game**. Derive the actual ontology, domains, execution models, representation choices, and abstractions from evidence and defensible reasoning. Different architectures are permissible, including ones not anticipated by this handoff. You may reorganize your analysis when that improves fidelity, but all required outcomes must remain discoverable and traceable.

Do not create a domain, interface, pipeline, effect system, class, or abstraction merely because it appears in these instructions or because it is a conventional pattern. Do not omit a stronger approach because it falls outside the examples. The words "domain," "authority," "causal model," and "contract" describe questions to answer, not prescriptive module types.

The goal of this run is to discover and defend its strongest model, **not to converge with other runs**. Prefer well-supported results over novelty. If the evidence cannot resolve intent, record the ambiguity rather than inventing an answer.

## 1. Scope and evidence

Record the exact source commit SHA; supplied design-document inventory and versions; Godot settings/version; available tests; permissions; and meaningful limitations. Inspect the entire accessible repository, including runtime entry points, scripts, scenes, resources, data and content definitions, game rules, simulation, editor tools, export/build logic, persistence, tests/fixtures, and relevant design/history files. Follow real state writers, input/output paths, signals, event and physics ordering, lifecycle transitions, and cross-system effects. A file listing alone is not coverage.

Organize design findings by what the player experiences and what rules govern that experience, **not** by the current folder hierarchy. Technical infrastructure with no direct player-facing equivalent still belongs in the inventory and dependency graph. Report precisely what was and was not inspected, and do not pretend to have run unavailable tests.

Classify consequential claims:
- **DOC**: explicitly documented design intent, with source.
- **SRC**: directly supported by inspected implementation, with file/symbol/span.
- **VER**: actually verified through an executed test or observation, with method and result.
- **INF**: inferred interpretation, with its uncertainty.
- **PROP**: proposed architecture, semantics, convention, or new rule.
- **OPEN**: unresolved or conflicting claims.

Documentation is evidence of intent, not automatic proof of current runtime behavior. Current code is evidence of behavior, not automatic authority over intended game design. Distinguish historical notes from current instructions when possible. Do not invent absent formulas, design rationale, tests, or findings.

## 2. Reconstruct the game from the top down

For every identified code-governed element, recover: the player's intention and experienced result; game purpose; preconditions, eligibility, failure conditions, priority and edge cases; relevant state and lifecycle; constraints and rules; inputs and outputs; interaction with other mechanics; timing; formulas where established; test and source evidence; and unresolved deviations between observed implementation and documented intent.

Maintain stable **rule identifiers** and a discoverable cross-reference system. Explain behavior in human game language first, then precise logic, state transitions, and implementation-independent pseudocode. Include technical subsystems that shape authoring, operation or verification even if they do not directly appear as player mechanics.

Separate **intention, planning/prediction, authoritative execution, resolved outcome, and presentation** where these distinctions actually matter. Do not enforce those as universal stages on every mechanic. Inverse solvers, predictive models, visual approximations and optimizations are valid when correctly identified and kept semantically distinct from authoritative state transitions.

A reconstructed game rule is not a recommendation. Keep existing behavior, established intent, implementation accidents, ambiguous evidence and suggested changes separately labeled.

## 3. Discover semantics and causal reasoning

Derive a canonical vocabulary of significant game concepts, quantities, states, and transitions. For each important concept or variable, capture as applicable:
- Exact meaning, provenance, synonyms/aliases and disallowed ambiguities.
- Its role (e.g., command, prediction, authoritative state, derived measurement, presentation), **as discovered**, not as a forced classification.
- Types, units, coordinate/time frame, valid range and precision when relevant.
- Lifecycle, ownership, permitted readers/writers, dependencies and legal transformations.
- Its position in the actual rule/cause chain, edge cases and constraints.
- Mapping to existing symbols; tests; examples and counterexamples.
- What must be reviewed before its definition can change.

Do not merge similarly named concepts with different meanings; do not multiply synonymous concepts without a game-rule distinction. Specify the direction of computation for major interactions, distinguishing actual causality from convenience transforms and planning. Show how the designer's explanation maps into precise data and calculations without hidden change in meaning.

Construct human-readable causal workflows, state diagrams or tables, formulas and pseudocode at whatever granularity is necessary for independent implementation. Do not demand identical workflows where genuinely different domains require different execution models.

## 4. Independently derive the technical architecture

From the reconstructed game and semantic contracts, propose the clearest defensible target architecture. Evaluate meaningful grouping and separation through shared rules, state lifetimes, invariants, inputs/outputs, causality, extension behavior, and data authority—not file similarity or fashionable patterns.

For every major component or responsibility, specify:
- Purpose, owned and excluded responsibilities.
- Canonical state and legal mutation paths.
- Inputs, outputs, contracts, lifecycle, interaction/event/physics order.
- Dependencies, failure behavior, persistence/serialization where relevant.
- How game laws and variables map to code-level operations.
- Extension surface, conflict resolution, instrumentation and verification.

The examples of shared rules, composition, specialization, data-driven definitions, domain APIs and dedicated mechanisms are a **non-exhaustive possibility space**, not a menu that must be exhausted or selected from.

For every consequential generalization or specialization, ask whether the behaviors share real governing laws, what semantic information is preserved or lost, what complexity is moved rather than removed, whether new features have a predictable home, and which counterexample would challenge the boundary. Do not impose a universal modifier engine or uniformly special-case every feature. Demonstrate *whole-architecture compatibility*: local elegance is insufficient if neighboring models conflict.

## 5. Justification-led architectural decisions

Record consequential discretionary choices in centralized **Architectural Decision Records (ADRs)** with stable local IDs. Use three proportional depths:

- **L1 / Traceable:** factual reconstruction and uncontroversial mappings. Evidence and uncertainty suffice.
- **L2 / Reasoned:** substantive inferred meanings, transformations, conventions or extensions. Explain the selected view, basis, problem solved, consequences.
- **L3 / Comparative:** foundational, disputed, high-impact, hard-to-reverse choices. State the governing design premise, evidence, credible alternatives, comparison criteria, choice, lost benefits/tradeoffs, validation/counterexamples, and reconsideration trigger.

Apply the strongest scrutiny to semantic distinctions, computation direction, rule ownership, state authority, abstraction boundaries, integration assumptions, and development governance. **Do not invent alternatives solely to satisfy a quota.** Defend why the chosen model follows the game instead of asserting that the proposed organization is intuitively good.

ADRs must be useful to a later agent comparing independently derived models: include precise design question, candidate conclusion, underlying premise, references, consequences, limits and tests. Other deliverables reference ADR IDs rather than repeat their essays.

## 6. Development Constitution and semantic continuity

Produce operational, game-specific governance so future humans and coding agents follow the same conceptual model instead of inventing a new one at each feature. For each consequential rule, state scope, rationale, permitted and forbidden usage, procedure, verification, and revision/exception trigger.

Cover at least:
- Translating a design request into player-facing rules, acceptance cases and explicit uncertainty.
- Locating the conceptual home and authoritative owner before touching implementation.
- Naming and defining variables, units, frames, time bases, state categories, aliases and deprecations.
- Respecting the established causal direction and distinguishing prediction from resolution.
- State write permissions, event order, side effects, dependencies and lifecycle.
- How to extend behavior, compose interactions and resolve conflicting effects; how to recognize a genuinely new concept.
- Godot-specific scene/script/resource, data, physics loop, tooling, persistence, testing and diagnostics conventions justified by the real project.
- Change classification: content/configuration, behavior extension, cross-system rule, foundational change, breaking rewrite.
- Mandatory updates to rule, ontology, atlas, ADR, tests and documentation on changes.
- Exceptions, designer review, deprecation, migration and rollback.

No architecture can guarantee every future feature fits without revision. The contract must make **foreseeable changes predictable** and genuine architectural change **explicit and governed**, not disguise new concepts under generic adapters.

Supply detailed extension recipes and counterexamples from real current mechanics; hypothetical examples may be used if labeled. Different mechanics may legitimately have different extension protocols. Avoid rules that only express generic software taste.

## 7. Traceability, verification and future-change probes

Provide a bidirectional **Design–Code Atlas** from game laws and semantic entries to observed source ownership and proposed target ownership, with functions/variables/tests where inspectable. Keep current versus proposed placements visibly separate. Every meaningful state writer and rule evaluator should map to a game concept or be flagged.

Define behavioral invariants, regression and integration tests, semantic contract checks, source verification, and acceptance scenarios. Identify what was genuinely executed, what was inspected only, and what remains proposed.

Challenge your architecture against representative **repo-grounded** interactions and several plausible future changes. For each scenario show conceptual home, governing rule, variables and causal stages, precise extension path, changes required, unaffected systems, conflicting effects and verification plan. If examples such as novel swings, traits, Trinkets, Workout progression, contact legality, or alternative scoring are not supported by the inspected repo, label them hypothetical or choose better tests. No fixed count or mandatory example may substitute for selecting diagnostic cases.

Include adversarial probes targeting meaning drift, duplicate authority, ambiguous variable use, unexpected cross-system coupling, lifecycle edges, and performance/engine constraints. Do not claim a hypothetical implementation experiment actually ran.

## 8. Required independent output package

Supply a complete, independently usable package covering these **fourteen outcomes** (you may merge files or alter their presentation if every outcome is readily locatable):

1. Game Design Specification.
2. Conceptual Reference Manual.
3. Semantic Ontology and Variable Registry.
4. Causal Execution Models and pseudocode.
5. Proposed Technical Architecture.
6. Abstraction Analysis and competing models.
7. Development Constitution.
8. Extension Contracts and Procedures.
9. Bidirectional Design–Code Atlas.
10. Verification and Stress-Test Plan with actual execution statuses.
11. Discrepancy and Uncertainty Register.
12. Central ADR Register with proportional defenses.
13. Proposed Implementation/Migration Blueprint (planning only).
14. Coverage and Confidence Report.

The package must be self-contained, plainly navigable, and sufficiently detailed for a qualified outsider to recreate intended behaviors without re-reverse-engineering the code. Link related entries with stable IDs and explain why any significant requested artifact is unavailable.

Finish with:
- A concise map of the architecture you independently advocate.
- Its most consequential defended decisions and meaningful credible alternatives.
- Factual questions needing designer adjudication.
- What could falsify or materially improve your proposal.
- An evidence-backed coverage declaration.

**Prohibition:** No gameplay implementation, repository refactor, cherry-picking another attempt's result, claiming cross-run agreement, or automatic promotion of a proposal into design canon.
