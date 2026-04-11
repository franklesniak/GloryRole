# Post-Public TODO

Tasks to complete once the repository is made public.

## Security

- [ ] **Enable private vulnerability reporting** -- Go to **Settings** > **Security** > **Private vulnerability reporting** > **Enable**. This allows security researchers to report vulnerabilities directly through the GitHub Security tab.
- [ ] **Optionally update the security link in issue template config** -- After enabling private vulnerability reporting, you can update `.github/ISSUE_TEMPLATE/config.yml` to change the security URL from `/security` to `/security/advisories/new` for a more direct path to the reporting form.

## Verification

- [ ] **Verify security flow** -- From the repository's main page, click the **Security** tab. Confirm SECURITY.md is accessible and the "Report a vulnerability" button works.
- [ ] **Test issue templates** -- Open each issue type once and ensure required fields behave correctly. Click the Contributing Guide, Security Vulnerabilities, and Discussions links in the issue template chooser to verify they work.
- [ ] **Test PR template** -- Open a test PR with a trivial change, confirm the PR template renders correctly and the contributing guidelines link works, then close it.
- [ ] **Verify CI workflows** -- Push a change and confirm all GitHub Actions workflows (markdownlint, PowerShell CI, placeholder check) complete successfully.

## Repository Settings

- [ ] **Set up branch rulesets** -- Configure branch protection for `main` via **Settings** > **Rules** > **Rulesets**. See [GitHub's rulesets documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) for setup guidance.
- [ ] **Review repository description** -- Go to the repository's main page and click the gear icon next to "About" to add a description, website URL, and topics.
- [ ] **Review Discussions categories** -- Go to **Discussions** and configure the default categories to match the project's needs (e.g., Q&A, Ideas, General, Show and Tell).

## Cleanup

- [ ] **Delete this file** -- Once all tasks are complete, delete `TODO.md` from the repository.
