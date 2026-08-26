# LAB2-CHG-001 — Termination, Robert Nguyen

**Type:** Leaver · **Status:** Reported successful, reversed 8.5 hours later · **Executed by:** Entra ID Lifecycle Workflows
**Recorded:** 2026-08-04 to 2026-08-06 · **Environment:** `hids1.onmicrosoft.com`

> Lab record. `LAB2-CHG-001` is a reference for this portfolio, not a ticket from a production service desk. The user is fictional. Every count, timestamp, and status below is real output from the lab tenant.

## Subject

| Field | Value |
|---|---|
| User | Robert Nguyen |
| User principal name | `robert.nguyen@hids1.onmicrosoft.com` |
| Object ID | `0a05ef8d-7bec-47a4-8b0d-6bf4f6748678` |
| Role | Sales Manager, Sales department |
| Employee hire date | 2026-08-10 (future dated) |

Onboarded 4:00 PM, terminated 4:41 PM the same day. A full employee lifecycle in forty-one minutes.

## Baseline, captured before the termination

| Field | Value |
|---|---|
| Account status | Enabled |
| Group memberships | **2** |
| `New Hire Baseline Access` | Membership type: **Assigned** |
| `Sales` | Membership type: **Dynamic** |
| `employeeLeaveDateTime` | Unset |

## Step 1 — Leaver workflow, 2026-08-04 16:41

Seven-task termination workflow, run on demand.

**Result reported: `Completed`. 6 tasks. 0 failed.**

| Attribute | Before | After |
|---|---|---|
| Account status | Enabled | **Disabled** |
| Group memberships | 2 | **1** |
| Surviving membership | — | **`Sales`, Membership type: Dynamic** |

### Why the group survived

`Remove user from all groups` cannot remove a dynamic membership. Dynamic membership is computed from attributes, so no process can manually remove a member. Robert's `department` still read `Sales`, so Entra kept re-adding him.

### The notification that reported success and never sent

Task 6, *"Send email on user's last day,"* reported success. No email was delivered. `employeeLeaveDateTime` was unset, so the task had no last day to reference. It ran, so it logged green. There was nothing to send.

**Two of the six tasks did not achieve their intent, and the execution record shows zero failures.**

## Step 2 — Scheduled joiner, 2026-08-05 01:13, unattended

The joiner workflow fired on its own schedule against the same terminated, disabled account.

| Field | Value |
|---|---|
| Execution type | Scheduled |
| Task | `Grant New Hire Baseline Access` |
| Result | **Completed** |
| Time | 2026-08-05 01:13, **8.5 hours after termination** |
| Group memberships after | **2 again** |

Trigger: `Days from event: 5 · Before · employeeHireDate`. Hire date August 10 minus 5 days is August 5. The workflow did exactly what it was configured to do, against an identity a termination never removed from its scope.

**Entra granted group membership to a disabled account without complaint. Disabled is not a scope filter.** Lifecycle Workflows never checks account state before provisioning.

Group membership across the three events: **2 → 1 → 2**. Both workflows reported zero failures. Neither knows the other exists.

## Step 3 — Remediation and re-test

Added task `Clear lifecycle attributes on termination` at position 3, clearing the attributes that feed the dynamic membership rule.

**Result: `Completed`. 7 tasks. 0 failed. Group memberships: 0.**

The dynamic group released the account for the first time. Every previous run stopped at one. The termination notification also sent for the first time, stamped `14:01:15 UTC`.

## Control verification

| # | Control | Result | Evidence |
|---|---|---|---|
| 1 | Account disabled on termination | **Pass** | Status Disabled after run |
| 2 | Sign-in blocked | **Pass** | Account disabled |
| 3 | Assigned group memberships removed | **Pass** | `New Hire Baseline Access` removed |
| 4 | Dynamic group membership removed | **Fail** | `Sales` survived; membership is computed, not assigned |
| 5 | Termination notification delivered | **Fail** | Task green, no email sent, `employeeLeaveDateTime` unset |
| 6 | Execution record reflects actual outcome | **Fail** | 6 tasks, 0 failed, while 2 tasks missed their intent |
| 7 | Terminated identity removed from future provisioning scope | **Fail** | Scheduled joiner re-granted access 8.5 hours later |
| 8 | Account state checked before provisioning | **Fail** | Access granted to a disabled account |
| 9 | Leaver and joiner aware of each other | **Fail** | Independent workflows, no shared state |
| 10 | Dashboard counts accurate | **Fail** | "3 users processed" was 1 user across 3 runs |
| 11 | Corrected workflow removes all entitlement | **Pass** | 7 tasks, 0 failed, 0 group memberships |

**4 pass, 7 fail.**

## Finding

A termination reported six of six tasks complete and zero failures while leaving the user in a group, sending no notification, and recording neither problem. An operator closing the ticket on that result would be wrong. An auditor sampling the run history would see nothing.

Eight and a half hours later, a scheduled onboarding workflow re-granted access to that same terminated, disabled account and also reported zero failures.

The residual entitlement was dormant while the account stayed disabled, but it was intact. Re-enable the account for any reason, a rehire, an error correction, a contractor returning, and the access comes back with nobody re-approving it.

## Recommended remediation

1. **Clear the attributes that drive membership, don't remove the membership.** Removing a computed membership treats the symptom. The rule puts it back.
2. **Terminated identities must fall out of provisioning scope.** Account status is not a scope filter, so the scope rule itself has to exclude them.
3. **Do not trust task completion as evidence of outcome.** Verify against the directory. Two green tasks here achieved nothing.
4. **Alert on group membership events**, the adds and removes individually. The 01:13 re-grant is only visible as an event, not in any status page.
5. **Treat lifecycle dashboard counts as unreliable.** Runs are being counted as users.
