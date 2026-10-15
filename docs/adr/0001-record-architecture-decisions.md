# 0001. Record architecture decisions
- Status: Accepted
- Date: 2026-10-14

## Context
The exam evaluates architectural reasoning, and the reviewers will not see the decisions made while building. The reasoning must live next to the code.

## Decision
Keep short ADRs in `docs/adr/`, one per significant decision, versioned with the code. The README links to them and summarizes only the outcome.

## Consequences
- Reviewers can read the "why" without a call; the live walkthrough can focus on discussion.
- Small overhead per decision; kept to about one page each.

## Alternatives considered
- Putting everything in the README: becomes long and mixes "how to run" with "why".
- Wiki or external doc: gets separated from the code and its history.
