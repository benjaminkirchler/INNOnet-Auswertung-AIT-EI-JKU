---
name: Theory Modeling
description: Develop, check, or write up economic theory models — reference-dependent preferences (Kőszegi–Rabin), threshold public goods / crowdfunding (Zubrickas), identity, and behavioral mechanisms. Use when writing model sections, propositions, proofs, or numerical verification code.
---

# Theory Modeling

## Notation conventions

- Kőszegi–Rabin models: η is the weight on gain–loss utility, λ > 1 is loss aversion. State the reference-point concept used (CPE, UPE, or lagged expectations) explicitly at the start of the model section.
- Define every symbol at first use; maintain one notation table in the paper's design/appendix folder.
- Keep notation consistent between the derivation/note file and the paper section. If one changes, update the other in the same session.

## Model development workflow

1. Write the economic environment first: players, actions, timing, information, payoffs.
2. State each result as a numbered Proposition with explicit assumptions.
3. Proof structure: claim → proof → one-paragraph economic intuition after the proof.
4. Verify every proposition and comparative static with a numerical example in R: a standalone, seeded script that checks the claimed inequality/sign over a parameter grid. Save these scripts alongside the theory files.
5. End the model section with testable predictions, each mapped to an empirical specification or treatment comparison.

## Writing style for theory

- Prose explains the economics; math states the results. No unexplained algebra walls — long derivations go to an appendix.
- Flag any assumption made purely for tractability and say what it rules out.

## Learning check

When introducing a modeling concept (e.g., personal equilibrium, reference dependence, threshold provision), briefly check that the user follows the logic and can restate the mechanism (see the `mentor-and-learning` skill). Teach the intuition before moving to algebra.
