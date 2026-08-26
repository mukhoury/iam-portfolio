# Access Review, 2026 Q3

**Tenant:** Houry Identity Solutions (`hids1.onmicrosoft.com`) · **Reviewer:** Mukhtar Houry · **Date:** 2026-08-26
**Scope:** all 24 user accounts · **Workbook:** [`access-review-2026-Q3.xlsx`](access-review-2026-Q3.xlsx)

> All users are fictional and the tenant was built as a portfolio lab. The findings below are real output from it, pulled from Microsoft Graph: user attributes, group membership rules, actual group membership, license assignments, and directory role assignments.

## Result

| | |
|---|---|
| Accounts reviewed | **24** |
| Access retained | **14** |
| Actions required | **8** |
| Requires revalidation | **2** |

## Findings

### 1. A terminated identity is still enabled and holding two licenses · High

Robert Nguyen was terminated on 2026-08-04. The leaver workflow reported six of six tasks complete with zero failures. A scheduled joiner re-granted his access 8.5 hours later, also reporting zero failures.

He is enabled today, sits in the `Sales` group, and consumes two license seats.

**Action:** disable the account, remove the group membership, release both licenses.

### 2. Four users hold no access because their department value does not match the rule · High

The `HR` group rule reads `user.department -eq "HR"`. The `IT` rule reads `"IT"`.

Active Directory writes `Human Resources` and `Information Technology`. So four synced users match nothing:

| User | Department in AD | Rule expects | Groups held |
|---|---|---|---|
| Andre Bishop | Human Resources | HR | none |
| Natalie Cruz | Human Resources | HR | none |
| Angela Park | Information Technology | IT | none |
| Brian Sullivan | Information Technology | IT | none |

The `HR` group has two members and the `IT` group has two members. All four are cloud-only accounts whose department was typed directly into Entra. **Every user who arrived from Active Directory into those two departments is invisible to their own access group.**

Nobody reported it, because a missing entitlement produces no error. It only shows up if somebody compares the population to the membership.

**Action:** agree one department taxonomy across both directories, correct the values at source, confirm membership resolves.

### 3. Two users are in a department with no access group · Medium

Sean Delaney and Vanessa Hughes are in Operations. No Operations group exists.

Combined with finding 2, **six of twenty four users hold no department access at all.**

**Action:** create the group, or document that the department needs no shared access.

### 4. One Global Administrator, no break-glass account · High

Mukhtar Houry holds the only Global Administrator assignment in the tenant. There is no separate emergency access account excluded from Conditional Access.

A policy misconfiguration or a lost credential locks everybody out with no recovery path.

**Action:** create a dedicated break-glass account, exclude it from Conditional Access, store the credential offline, alert on its sign-ins.

### 5. An application entitlement with no documented justification · Medium

Priya Patel is the sole member of `Finance Reporting App Access`, an assigned group rather than a dynamic one. Assigned membership survives attribute changes and role moves, so it will not fall away on its own when she changes jobs.

**Action:** record the justification and an owner, or move it into an access package with approval and expiry.

### 6. A soft-matched account carrying stranded attributes · Low

Amanda Foster has no company name and no employee ID. Both were cleared when her cloud account was joined to an on-premises one. The fields are read-only in the cloud because the object is now synced, and empty on-premises because they were never set there.

**Action:** populate the values in Active Directory and confirm they flow up.

### 7. Six of twenty four users hold no license · Medium

The same six users with no group access also hold no license.

Licensing in this tenant is assigned **directly to each user** rather than through a group, so every assignment is a manual step somebody has to remember. Eighteen of twenty five seats are consumed, two of them by the terminated account in finding 1.

**Action:** move to group-based licensing so entitlement and licensing follow the same rule.

## What this review is actually testing

Access reviews are usually described as a way to catch people who have **too much** access. Two of the three highest-risk findings here are the opposite: people who have **none**, silently, because a string in a rule did not match a string in a directory.

Both failures are invisible from the Entra admin center on a per-user basis. A user with no groups looks the same as a user who has not been assigned any yet. You only see it by comparing the whole population against what each person should have.
