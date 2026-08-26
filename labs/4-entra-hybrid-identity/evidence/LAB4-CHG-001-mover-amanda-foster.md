# LAB4-CHG-001 — Role change, Amanda Foster

**Type:** Mover · **Status:** Completed · **Source of change:** On-premises Active Directory
**Recorded:** 2026-08-24 · **Environment:** `hids.local` synchronized to `hids1.onmicrosoft.com`

> Lab record. `LAB4-CHG-001` is a reference for this portfolio, not a ticket from a production service desk. The user is fictional. Every identifier, timestamp, and correlation ID below is real output from the lab tenant.

## Subject

| Field | Value |
|---|---|
| User | Amanda Foster |
| User principal name | `amanda.foster@hids1.onmicrosoft.com` |
| Object ID | `d8defa0f-611b-4fd3-b18b-6f3c43080db3` |
| Source of authority | On-premises Active Directory (synchronized object) |

## Change requested

One attribute edited on-premises: `Department`, from blank to `Finance`.

Nothing else was touched. `Job Title` and `Company name` were deliberately left unchanged as controls.

## Access change decision

| Before | After |
|---|---|
| **Sales** `f319da40-c4f7-4181-b504-10f497fe930e` | **Finance** `380ecbeb-b249-42ef-b358-4833874b2af2` |

Both groups are dynamic security groups with membership computed from `user.department`. Neither membership was assigned or removed by a person.

## Approval trail

**None.** No request was raised, no approver was consulted, and no workflow ran.

The audit log attributes both membership events to an application:

| Field | Value |
|---|---|
| Actor type | Application |
| Display name | `Microsoft Approval Management` |
| Service principal | `ef0ebe67-e792-422c-ab93-a234e9083a44` |
| Application ID | `65d91a3d-ab74-42e6-8a2f-0add61688c74` |
| User agent | *(empty)* |

The actor's display name contains the word "Approval." Nothing was approved. That name is the service principal Entra runs dynamic membership processing under.

## Timeline

| Time (local) | Event | Actor |
|---|---|---|
| 17:16:30 | `Update user`, department arrives from on-premises | Connect Sync |
| 17:16:52 | `Remove member from group` — Sales | Microsoft Approval Management |
| 17:16:52 | `Add member to group` — Finance | Microsoft Approval Management |

Both membership events carry the same correlation ID, **`7240862c-d74d-486b-a7fb-7751fdf063e4`**, which is what proves they were one operation rather than two events that happened to land in the same second.

## Control verification

| Control | Result | Evidence |
|---|---|---|
| Change is attributable to a source | **Pass** | Connect Sync export, 17:16:30 |
| Old access removed before new access granted | **Pass** | Single operation, shared correlation ID |
| Change was approved before it took effect | **Fail** | No request, no approver, no workflow |
| Change is detectable by membership count | **Fail** | Count read 1 before and 1 after |
| Change is detectable by membership events | **Pass** | One add and one remove, individually logged |
| Audit record identifies the group as rule-driven | **Fail** | `Group Type: unknownFutureValue` on both events |
| Unrelated attributes preserved | **Fail** | `Company name` cleared in the same pass, not requested |

## Finding

A person's entire entitlement set was replaced by one operation that nobody requested, nobody approved, and no monitor built on membership totals could detect. The count stayed at 1 because a total is invariant under substitution, and substitution is exactly what attribute-driven groups do.

The only reliable detection is alerting on membership **events** individually and correlating them by correlation ID, because that is the only representation where both halves of the swap exist as separate facts tied to one cause.
