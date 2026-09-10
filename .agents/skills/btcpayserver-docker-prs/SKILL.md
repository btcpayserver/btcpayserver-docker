---
name: btcpayserver-docker-prs
description: Prepare or update BTCPay Server Docker pull requests. Use when creating, opening, drafting, editing, or reviewing a PR in btcpayserver-docker, including gh pr create and gh pr edit requests.
---

# BTCPay Server Docker Pull Requests

Use this workflow for every pull request in this repository.

## Preparation

1. Read `AGENTS.md` and follow its repository-wide implementation and generated-file rules. Do not duplicate those rules here.
2. Inspect the worktree, staged changes, recent commits, remotes, tracking branch, and the complete diff from the target branch.
3. Review every commit included in the PR, not only the latest commit.
4. Run the checks appropriate to the change unless the user explicitly asks to skip them. Do not confuse running checks with documenting them in the PR body.
5. Use a dedicated branch and cohesive, imperative commit messages consistent with recent repository history.
6. Push only intended changes. Never include unrelated worktree changes.

## PR Description

Lead with why the change exists. Explain the operational, security, compatibility, or user problem before describing implementation details. Include links to advisories, issues, prior commits, or documentation when they materially explain the motivation.

Do not add a `Validation`, `Testing`, `Tests`, or equivalent section to the PR description. Checks should still be run and reported to the user outside the PR body when useful.

For a user-facing command or workflow:

1. Add a `Usage` section.
2. Run the implemented command and include its exact current help output. Do not reconstruct or paraphrase it from memory.
3. Include one short, realistic end-to-end example showing the command and its output.
4. Explain the practical use case, not only the command syntax.
5. Keep examples focused; do not turn the PR description into complete product documentation.

Finish with a concise `Implementation` section when technical context helps reviewers. Describe important behavior, persistence, migration, security boundaries, and rollback semantics without listing every changed file.

Use this default structure, omitting sections that do not apply:

```markdown
## Why

<Problem, history, and user impact.>

## Usage

<Exact help output and one simple example.>

## Implementation

<Concise technical notes for reviewers.>
```

## Publishing

1. Open the PR as a draft unless the user explicitly requests a ready-for-review PR.
2. Verify the title, base branch, head branch, draft state, body, and URL after creating or editing it.
3. Keep the PR description accurate when later commits change behavior or usage.
4. Return the PR URL and explicitly ask the user for review.
