# Copilot Chat Prompts for Template Adoption

This file contains ready-to-use prompts for GitHub Copilot Chat to help you analyze and adopt template features into an existing repository.

## Prerequisites

- You have an existing repository where you want to adopt template features
- You have access to GitHub Copilot Chat
- You have read through [GETTING_STARTED_EXISTING_REPO.md](GETTING_STARTED_EXISTING_REPO.md) to understand what the template provides

## Model Recommendation

**Use Claude Opus 4.5 or better for these prompts.**

These prompts require the model to:

- Read and synthesize multiple large documentation files
- Cross-reference configurations across two repositories
- Produce detailed, structured output with file-level specificity

Claude Opus 4.5 handles these tasks reliably. Other models may produce incomplete or less accurate results.

To select your model in GitHub Copilot Chat, click the model name in the chat interface and choose from the available options.

## Usage

Run these prompts in sequence in GitHub Copilot Chat. Replace `OWNER/REPO` with your actual organization/username and repository name.

---

### Adding Repositories to Copilot Chat Context

> Go to [GitHub Copilot Chat](https://github.com/copilot), then click `Add repositories, files, and spaces` > `Repositories...`. Search for `franklesniak/copilot-repo-template` and check its checkbox. Then, search for your destination repository (`OWNER/REPO`) and check its checkbox. Click outside the dialog (or press Escape) to return to the prompt input box.

---

## Prompt 1: Gap Analysis

Use this prompt to analyze your repository against the template and identify what's missing or incomplete.

```markdown
I want to implement `franklesniak/copilot-repo-template` in the existing repository `OWNER/REPO`.

Please review the following files in `franklesniak/copilot-repo-template`:

- `GETTING_STARTED_EXISTING_REPO.md` (required configurations)
- `OPTIONAL_CONFIGURATIONS.md` (optional configurations)

Then review the current state of `OWNER/REPO` and produce a gap analysis that:

1. Lists every required configuration item and its completion status
2. Lists every optional configuration item and whether it's been customized or uses defaults
3. Identifies any gaps, errors, or incomplete implementations

For each gap, indicate whether it's required or optional, and provide the specific file(s) and line(s) affected.
```

---

## Prompt 2: Actionable Checklist

After reviewing the gap analysis from Prompt 1, use this prompt to generate a prioritized list of actions.

```markdown
Based on the gap analysis, produce a prioritized checklist of configuration items I need to address or consider addressing.

For each item, include:

- Priority level (Required / Recommended / Optional)
- File(s) affected
- Current state
- Recommended change (with code snippets where helpful)
- Impact/rationale for making the change

Group items by priority level.
```

---

## Tips

- **Review the gap analysis before proceeding to Prompt 2.** You may have questions or context to add.
- **Provide context in follow-up prompts.** The more specific you are about your project's constraints (private vs. public repo, team size, languages used, etc.), the better the recommendations.
- **You don't need to address every optional item.** The template defaults are sensible for most projects. Focus on required items first, then consider optional items based on your team's needs.
