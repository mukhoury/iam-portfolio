# Lab 2: Microsoft Entra ID Identity Governance

**Tools:** Microsoft Entra ID Premium P2 · Microsoft Entra ID Governance · Entitlement Management · Access Reviews · Privileged Identity Management (PIM) · Lifecycle Workflows

**Domains:** Identity Governance and Administration (IGA) · Privileged Access Management · Joiner / Mover / Leaver automation · Microsoft SC-300 Domain 4

**Tenant:** `Houry Identity Solutions` (`hids1.onmicrosoft.com`), 13 users, 6 departments. Built on top of [Lab 1](../1-entra-dynamic-groups-conditional-access/).

> **Full build record:** [`BUILD-LOG.md`](BUILD-LOG.md) is the working log for this lab, written as it was built. It contains every configuration value, every design decision, and an unedited friction log of what went wrong. This README is the summary.

---

## Problem

Lab 1 solved provisioning. Attribute-based dynamic groups put people into the right security groups automatically, and a Conditional Access policy forced multifactor authentication on every sign-in.

That is a good foundation and it answers exactly one question: *did the right people get access?* It leaves four questions unanswered, and those four are where real audit findings come from.

1. **Was the access ever authorized?** Dynamic groups grant on an attribute. Nobody requested anything, nobody approved anything, and no business justification exists anywhere.
2. **Is it still justified six months later?** Nothing expires. A user who transfers from Finance to Marketing keeps accumulating entitlements, which is privilege creep, and it is invisible without a recurring certification.
3. **Why does anyone hold admin permanently?** The tenant had exactly one Global Administrator with a permanent, standing assignment. Standing privilege is the largest blast radius in any directory.
4. **What happens when someone leaves?** Nothing automatic. Offboarding depended entirely on a human remembering to do it, which is the single most common source of orphaned access.

## Solution

Four native Entra controls, one per gap, built and verified end to end as real users rather than by admin assignment.

- **Entitlement Management** turns access into something that is requested, approved with a recorded justification, and expires on its own after 90 days with no self-extension.
- **Access Reviews** recertify that access on a quarterly recurrence, configured **fail closed** so a reviewer ignoring the email revokes access instead of preserving it.
- **Privileged Identity Management** replaces standing admin with just-in-time activation: approval-gated, MFA-enforced, capped at 4 hours, with permanent active assignment turned off.
- **Lifecycle Workflows** automate the joiner and the leaver so onboarding and offboarding are executed by the platform and recorded, not performed from memory.

### The lifecycle this builds

```mermaid
flowchart TB
    subgraph J["JOINER: scheduled, 5 days before hire date"]
        j1["Generate Temporary Access Pass<br/>8 hr window · one-time use<br/>emailed to manager"]
        j2["Grant New Hire Baseline Access<br/>(Assigned group)"]
    end

    subgraph G["GRANT: Entitlement Management"]
        g1["User requests package<br/>(scoped to Finance dynamic group)"]
        g2["Approver decides<br/>+ recorded justification"]
        g3["Governance engine provisions<br/>90-day expiration"]
    end

    subgraph C["CERTIFY: Access Reviews"]
        c1["Quarterly recurrence<br/>7-day window"]
        c2["Fail closed:<br/>no response = remove access"]
    end

    subgraph P["PRIVILEGE: PIM"]
        p1["Eligible, not active"]
        p2["Activate: MFA + justification<br/>+ approval by a second person"]
        p3["Auto-expires at 4 hrs"]
    end

    subgraph L["LEAVER: on demand"]
        l1["1. Disable account"]
        l2["2. Revoke all refresh tokens"]
        l3["3. Clear lifecycle attributes<br/>(department, hire date)"]
        l4["4. Remove groups, Teams, licenses"]
    end

    J --> G --> C
    G -.-> P
    C --> L
    P --> L
```

**Read it as:** access is granted only after an approval that is recorded, recertified on a schedule that revokes on silence, held privileged only in short approved bursts, and torn down by a workflow that removes the *cause* of membership rather than just the membership.

---

## Steps

### Phase 1: Entitlement Management

Built `HIDS Onboarding Catalog`, onboarded an **Assigned** security group as a requestable resource, and published the `Finance Reporting Access` package with a single-stage approval, a required approver justification, a 14-day decision deadline, and a 90-day expiration with self-extension disabled.

Request scope was deliberately pointed at the **Finance dynamic group from Lab 1**. That is the link between the two labs: an attribute decides who is even *eligible to ask*. A Finance user sees one package; an IT user sees none.

Verified as a real end user. Signed in as Priya Patel in a private window, was forced through CA001 MFA registration, requested the package with a written business justification, approved it from `myaccess.microsoft.com` as the approver, and watched the group go from 0 members to 1. **Group membership was never touched by hand.**

### Phase 2: Access Reviews

Built `Quarterly Access Review - Finance Reporting App Access` as a resource review: quarterly recurrence, 7-day window, auto-apply enabled, and **"if reviewers don't respond" set to Remove access**.

Operated it from the reviewer side, then drove it through to enforcement and confirmed the result applied against the resource.

### Phase 3: Privileged Identity Management

Made Marcus Chen (IT) **eligible** for User Administrator rather than holding it, with Sarah Mitchell (IT) as the approver, creating two-person control over a role that can create users and reset passwords.

Hardened the role settings away from the shipped defaults: activation capped at **4 hours** instead of 8, **approval required** instead of self-service, **permanent active assignment disabled**, active assignments expiring after 1 month, and MFA required on active assignment.

Ran two complete activation cycles end to end: request, pending approval, approval by a second person, grant, and both manual deactivation and natural expiration. Then built a **separate privileged role access review** scoped to `All active and eligible assignments`, and operated that too.

Deliberately **not** done: converting the tenant's only Global Administrator to eligible. With no second break-glass account, that is how a tenant becomes unrecoverable. It is documented as a design decision rather than demonstrated destructively.

### Phase 4: Lifecycle Workflows

**Joiner**, scheduled 5 days before `employeeHireDate`, scoped to `(department eq 'Sales')`: generate a one-time-use Temporary Access Pass with an 8-hour window and email it to the manager, then grant baseline group access. Verified end to end, including a real failed run that was diagnosed and fixed.

**Leaver**, on demand, rebuilt from Microsoft's template into a defensible sequence:

1. **Disable User Account:** stops new authentication
2. **Revoke all refresh tokens:** invalidates what is already authenticated
3. **Clear lifecycle attributes** (`department`, `employeeHireDate`; stamp `employeeLeaveDateTime`)
4. **Remove from all groups**
5. **Remove from all Teams**
6. **Remove all licenses**
7. **Notify the manager**

Verified across three runs, ending with Robert Nguyen at **zero group memberships**, disabled, tokens revoked, licenses reclaimed, and no account deletion at any point.

---

## Security Outcome

- **Access is authorized, not just granted.** Every entitlement carries a requestor justification, an approver decision with recorded rationale, and a timestamped actor. Six months later the answer to "why does she have this?" is a record, not somebody's memory.
- **Access expires by default.** 90-day assignments with no self-extension mean privilege creep requires an act of renewal rather than an act of removal.
- **Silence revokes.** Both access reviews are configured so an unresponsive reviewer removes access. The most common failure mode of review programs is reviewers ignoring the email, and fail-closed converts that failure into a safe outcome.
- **No standing privilege.** User Administrator is held for minutes, under approval, with MFA, and released automatically. A complete grant-and-release cycle leaves the user object identical to before.
- **Segregation of duties is demonstrated, not described.** Marcus requests, Sarah approves, and both appear as distinct actors in the audit trail on every cycle.
- **Offboarding removes the cause of access, not just the symptom.** The corrected leaver clears the attributes that drive dynamic membership, which is the only thing that actually works against rule-computed groups.

---

## Findings

The configuration above is the easy half. These are the things that only show up when you operate the controls and read the results carefully, and they are the reason this lab took two weeks rather than two days.

### 1. A "successful" offboarding that left access behind

The leaver workflow reported **6 tasks, 0 failed**. Robert was still in the `Sales` group.

`Remove user from all groups` **cannot remove dynamic group memberships**, because dynamic membership is computed from attributes and no process can manually remove a computed member. His `department` still read Sales, so Entra kept putting him back. Nothing in the execution record flagged it. An operator closing the ticket on that result would be wrong, and an auditor sampling run history would see a clean run.

The account was disabled, so the residual entitlement was dormant rather than live. But it was intact. Re-enable for any reason (rehire, error correction, a returning contractor) and the access returns without anyone re-approving it.

**The fix is to change what drives membership, not the membership itself.** Adding `Update user attributes` to clear `department` is what finally produced zero groups.

### 2. The onboarding workflow silently reversed the offboarding

Robert was terminated and disabled on Aug 4 at 4:41 PM. At **1:13 AM on Aug 5**, the scheduled joiner fired unattended and re-granted `New Hire Baseline Access`, 8.5 hours after his termination.

His group count went 2, then 1, then **2 again**. Both workflows reported zero failures. **Neither knows the other exists.** The joiner was triggered on `employeeHireDate` minus 5 days, and a termination never removed him from its scope.

Two things fall out of this that generalize well beyond a lab:

- **Automation without a shared state model reverses itself.** Two workflows that are each individually correct produced a net wrong outcome, and both reported success.
- **Disabled is not a scope filter.** Entra granted group membership to a disabled account without complaint. Lifecycle Workflows never checks account state before provisioning.

### 3. Latent privilege is invisible on the surface everyone checks

Marcus Chen's user Overview blade read **`Assigned roles: 0`** while he was eligible for User Administrator. Eligible assignments do not appear on the user object at all; they exist only inside PIM.

An auditor walking this tenant user by user would conclude there is exactly one privileged account and would be wrong. This is the argument for auditing PIM assignments as a separate control rather than folding privileged access into a user-attribute review, and it is why the privileged role review in phase 3 is scoped to **`All active and eligible assignments`**. Scoped to active holders only, it would have listed nobody and certified that the tenant has no User Administrators.

### 4. PIM ships with accountability, not authorization

Out of the box, the role settings were **`Require approval to activate: No`** with **`Approvers: None`**, and **`Allow permanent active assignment: Yes`**.

MFA and justification are required by default, so activation is *attributable*. Nobody *authorizes* it. Those are different controls and they get conflated constantly. And the product built to eliminate standing privilege still permits standing privilege by default.

Related trap: the UI warns that if no approvers are named, Global Administrators silently become the default approvers. Enabling approval without naming anyone does not disable the control, it quietly routes every request to people who may not be watching for it.

### 5. Microsoft's real-time termination template deletes the account and never revokes tokens

The shipped **Real-time employee termination** template runs three tasks: remove from groups, remove from Teams, **Delete User Account**. `Revoke all refresh tokens for user` exists in the task catalog but is **deliberately absent from the template**.

That ordering is backwards on three counts. Deleting destroys the evidence that a for-cause termination depends on. Disabling alone does not end active sessions, because a refresh token keeps working until it expires, which makes token revocation the only thing that ejects someone *right now*. And deletion is irreversible after 30 days, while terminations get reversed routinely.

Compounding it: the wizard defaults to "select users now and run workflow after you create it." **One click from a wizard to a deleted user.**

### 6. The recommendation engine is reliably stale, not reliably wrong

In phase 2 the access review recommended **Deny** on Priya and tagged her as inactive with no sign-in in 30 days. She had signed in the previous day, completed MFA registration, submitted a request, and been provisioned. The recommendation is computed at instance start and frozen, and her sign-in had not propagated.

In phase 3 the same engine got Marcus **right**. That is worse than being consistently wrong, because you cannot calibrate how much to trust it.

The reason it matters is the **Accept recommendations** button sitting in the reviewer toolbar. One click accepts everything. With auto-apply on and no-response set to remove, that click would have revoked a legitimate analyst's access with no second prompt.

### 7. The reviewer is denied the evidence behind the decision

Sarah, the designated reviewer, received a **401** when clicking through to the Audit Details supporting the recommendation she was being asked to act on. The portal renders the link for her anyway.

**This is why real access reviews get rubber-stamped. The reviewer is not lazy, they are blind, so accepting the recommendation is the only available action.**

### 8. The same error code, three unrelated causes

A 401 appeared three times in this lab and meant something different every time:

- **Priya** on the admin center: she holds no role. **Authorization.**
- **Lifecycle Workflows**: the tenant did not own the SKU. **Licensing.**
- **Sarah** on audit details: a legitimate reviewer denied supporting evidence. **Permission scope.**

The error surface is identical and tells you nothing about which. Anyone would burn an hour auditing role assignments before thinking to check Billing.

### 9. The Temporary Access Pass is a credential mailed in plaintext

The TAP arrives in the manager's inbox as readable text, with instructions to forward it to the new hire, carrying a footer that reads *"Microsoft Corporation facilitated sending this email but did not validate the sender or the message."*

A credential, from a noreply address, with a disclaimer that nobody verified it. **Structurally indistinguishable from a phishing email**, and new hires are trained to trust it on day one. If that mailbox is compromised, an attacker bootstraps the identity and registers **their own** MFA method before the employee's first day.

The one-time-use setting enabled during hardening is the mitigation that matters: a stolen pass is burned on first redemption, so the theft becomes detectable rather than silent.

### 10. Task status cannot distinguish "delivered" from "silently did nothing"

The offboarding notification task reported **Completed** on a run where no email was sent, and **Completed** again on a run where one was. On the first run `employeeLeaveDateTime` was unset, so *"send email on user's last day"* had no last day to reference. The task ran, so it went green. There was simply nothing to send.

On the Aug 4 leaver run, **two of six tasks did not achieve their intent and the execution record showed 0 failures.**

### 11. You cannot bootstrap a scheduled leaver from the portal at all

`employeeLeaveDateTime` is available in the workflow task attribute picker but does not exist on the user Properties blade, which cannot even display it. A scheduled leaver triggers on that attribute, the only portal-native way to set it is a workflow task, and that task can only be run on demand.

`Update user attributes` is further restricted to directory extensions for on-premises synced users, so **this entire fix is unavailable in a hybrid tenant.**

That circular dependency is the cleanest argument in this lab for why an IAM analyst needs to script against Microsoft Graph, and it is what [Lab 3](../3-entra-graph-powershell/) is built on.

### 12. Dashboard counts are inflated

"Total processed: 3 users" was one user across three runs. The same flaw appeared on the leaver. Any onboarding-volume metric pulled off that dashboard overstates reality.

---

## Key Concepts Reinforced

- **Entitlement management** as the grant control: catalogs, access packages, request policies, approval workflows, and time-bound assignment.
- **Access reviews** as the recertification control, including fail-closed configuration and the difference between recording a decision and enforcing it.
- **Just-in-time privileged access** via PIM: eligible versus active, activation duration versus eligibility duration, approval gating, and privileged role certification as a distinct control from user access review.
- **Joiner / Mover / Leaver automation** with Lifecycle Workflows: scheduled versus on-demand triggers, scope rules versus trigger conditions, task ordering, and fail-fast versus continue-on-error.
- **Segregation of duties** enforced through configuration, including why the obvious approver group was rejected: it contained the person it would approve for.
- **Audit trail literacy.** The most important evidence in this lab is in the audit log, not the assignment views, because assignment surfaces show current state only.
- **Attribute-driven access has attribute-driven revocation.** Dynamic membership can only be removed by changing the attribute that computes it.

---

## Artifacts

235 screenshots covering the full build are in [`screenshots/`](screenshots/). The set below is the evidence for the findings above.

### Phase 1: Entitlement Management

| Screenshot | What it shows |
|---|---|
| ![Package scoped to Finance](screenshots/05-request-policy-scoped-to-finance-group.png) | Request policy scoped to the **Finance dynamic group from Lab 1**. An attribute decides who is eligible to ask. |
| ![90-day expiration](screenshots/09-lifecycle-90-day-expiration-no-extension.png) | 90-day expiration with self-extension disabled. Access removes itself. |
| ![End user view](screenshots/13-myaccess-end-user-view-available-package.png) | Priya's My Access view: **Available (1)**. An IT user sees zero. |
| ![Standard user 401](screenshots/15-standard-user-denied-admin-center-401.png) | 401 number one: a standard user on the admin center. Authorization. |
| ![Approval with justification](screenshots/21-approve-decision-with-justification.png) | Approver decision with recorded rationale, made in My Access, not the admin center. |
| ![Auto-provisioned](screenshots/24-priya-auto-provisioned-into-group.png) | Group goes 0 members to 1. Membership created by the governance engine. |
| ![Full audit chain](screenshots/46-priya-audit-log-full-governance-chain.png) | The whole chain in one view, including **`Initiated by: Azure AD Identity Governance`**, a service principal rather than an admin. |

### Phase 2: Access Reviews

| Screenshot | What it shows |
|---|---|
| ![Fail closed warning](screenshots/33-settings-fail-closed-remove-access-warning.png) | Entra's own amber warning on fail-closed configuration. The warning is the feature. |
| ![False positive](screenshots/39-decision-pane-deny-recommended-false-positive.png) | **Recommended: Deny, "inactive user."** She had signed in the previous day. Note the **Accept recommendations** button in the toolbar. |
| ![Override recorded](screenshots/45-admin-results-approved-vs-recommended-deny.png) | `Outcome: Approved` next to `Recommended action: Deny`, with the override justification recorded. |
| ![Result applied](screenshots/50-review-history-result-applied.png) | Decision enforced against the resource, not just recorded. |

### Phase 3: Privileged Identity Management

| Screenshot | What it shows |
|---|---|
| ![PIM defaults](screenshots/62-role-settings-defaults-before.png) | Shipped defaults: **`Require approval to activate: No`** and **`Allow permanent active assignment: Yes`**. The whole argument of this phase. |
| ![Hardened](screenshots/70-role-settings-after-hardened.png) | After hardening: 4-hour cap, approval required, named approver, no permanent active assignment. |
| ![Assigned roles zero](screenshots/71-marcus-chen-overview-before-activation.png) | **`Assigned roles: 0`** on a user eligible for User Administrator. Latent privilege, invisible. |
| ![Activation scheduled trap](screenshots/75-marcus-notification-activation-request-scheduled.png) | Green checkmark, "your activation request is scheduled." He got nothing. Real state is under My requests. |
| ![Deactivate floor](screenshots/106-deactivate-failed-minimum-5-minutes.png) | Deactivation refused: 5-minute minimum, so privilege cannot flicker below the monitoring window. |
| ![Full JIT audit chain](screenshots/124-marcus-pim-audit-history-full-jit-chain.png) | Two complete cycles. The failed deactivation is logged with a red mark, and the final revocation is signed **`Azure AD PIM`**, not a person. |
| ![Reviewer 401](screenshots/128-reviewer-401-on-audit-details.png) | 401 number three: the reviewer denied the evidence behind her own decision. |

### Phase 4: Lifecycle Workflows

| Screenshot | What it shows |
|---|---|
| ![ID Governance zero](screenshots/79-license-usage-id-governance-zero.png) | `ID Governance: 0`. The number that diagnosed 401 number two, which was licensing, not permissions. |
| ![Template deletes account](screenshots/187-leaver-default-tasks-includes-delete-account.png) | Microsoft's real-time termination template: **Delete User Account** included, token revocation absent. |
| ![Revoke tokens in catalog](screenshots/192-leaver-catalog-scrolled-revoke-refresh-tokens.png) | `Revoke all refresh tokens for user` sitting in the catalog, available but not in the template. |
| ![Corrected sequence](screenshots/194-leaver-tasks-reordered-correct-sequence.png) | The rebuilt sequence: disable, revoke, strip, reclaim. No deletion at any point. |
| ![Run reports success](screenshots/203-leaver-completed-all-6-tasks-zero-failed.png) | **Completed, 6 tasks, 0 failed.** |
| ![Dynamic group survives](screenshots/205-dynamic-group-survives-offboarding.png) | The same run: `Sales`, membership type **Dynamic**, still there. The finding, in two screenshots. |
| ![Joiner reverses it](screenshots/209-joiner-history-tasks-baseline-access-granted-aug5.png) | `Grant New Hire Baseline Access`, **Completed 8/5 1:13 AM**, 8.5 hours after termination, to a disabled account. |
| ![Access restored](screenshots/212-robert-groups-baseline-access-restored-after-offboarding.png) | Group memberships back to 2 on a terminated user. Both workflows reported success. |
| ![TAP in plaintext](screenshots/184-tap-onboarding-email-received.png) | The Temporary Access Pass, in plaintext, from a noreply address, with the "did not validate the sender" footer. |
| ![Zero groups](screenshots/230-robert-zero-groups-dynamic-membership-dropped.png) | The corrected leaver: **not a member of any groups.** Attribute cleared, dynamic membership dropped by evaluation. |

---

*This is a training tenant. The `hids1.onmicrosoft.com` domain, the Houry Identity Solutions display name, and all 13 users are non-production lab data. Object IDs shown belong to a temporary lab tenant.*
