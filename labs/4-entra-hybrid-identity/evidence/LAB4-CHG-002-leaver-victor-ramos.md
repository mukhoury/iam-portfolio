# LAB4-CHG-002 — Termination, Victor Ramos

**Type:** Leaver · **Status:** Completed with control failures · **Source of change:** On-premises Active Directory
**Recorded:** 2026-08-25 · **Environment:** `hids.local` synchronized to `hids1.onmicrosoft.com`

> Lab record. `LAB4-CHG-002` is a reference for this portfolio, not a ticket from a production service desk. The user is fictional. Every identifier, timestamp, and count below is real output from the lab tenant.

## Subject

| Field | Value |
|---|---|
| User | Victor Ramos |
| User principal name | `victor.ramos@hids1.onmicrosoft.com` |
| sAMAccountName | `vramos` |
| Object ID | `872f6b90-2858-416b-8413-94862b442c84` |
| Distinguished name | `CN=Victor Ramos,OU=Employees,OU=HIDS,DC=hids,DC=local` |
| Control user (untouched) | Hana Sato, `78f0bb1f-c5c2-452f-b53e-fd5ce0769538` |

## Baseline, captured before any change

| Field | Value |
|---|---|
| Account status | Enabled |
| Group memberships | 1 — **Sales** `f319da40-c4f7-4181-b504-10f497fe930e` (dynamic) |
| Licenses | 2 — Microsoft Entra ID P2, Microsoft Entra ID Governance Add-on. Both **Direct** |
| Department / Title / Company | Sales / Sales Engineer / Houry Identity Solutions |
| Employee ID | `EMP-1008` |

## Actions performed

The two steps a help desk performs on a termination ticket, run separately with a synchronization and an observation between them so each outcome could be attributed.

| Time (local) | Action |
|---|---|
| 14:04 | `Disable-ADAccount -Identity vramos`, verified `Enabled : False` by read-back |
| 14:06 | Delta synchronization |
| 14:18 | `Move-ADObject` to `OU=Disabled Users,OU=HIDS,DC=hids,DC=local` |
| 14:20 | Delta synchronization |

## Result of step one, disable

| Attribute | Before | After |
|---|---|---|
| Cloud account status | Enabled | **Disabled** |
| Group membership | Sales | **Sales, unchanged** |
| Licenses | 2 | **2, unchanged** |
| Department | Sales | Sales, unchanged |
| Group membership event emitted | — | **None** |

The Sales group's own overview still showed a last membership change dated the previous day.

## Result of step two, container move

| Attribute | Before | After |
|---|---|---|
| Cloud object | Present, disabled | **Deleted** |
| Tenant user count | 25 | **24** |
| Sales group members | 3 | **2** |
| Deleted date | — | 2026-08-25 14:20 |
| Permanent deletion date | — | 2026-09-24 14:20 |
| User principal name | `victor.ramos@…` | Rewritten to the object ID; original retained separately |

`OU=Disabled Users` sits outside the synchronization scope. Entra Connect read the object as absent and removed the cloud account along with its licenses and group membership.

## Control verification

| # | Control | Result | Evidence |
|---|---|---|---|
| 1 | Account disabled at the source | **Pass** | `Enabled : False`, verified by read-back |
| 2 | Cloud sign-in blocked | **Pass** | Account status Disabled after sync |
| 3 | Group entitlements revoked by the disable | **Fail** | Sales membership intact, same group object ID |
| 4 | Licenses released by the disable | **Fail** | Both licenses still assigned |
| 5 | A membership event was emitted for alerting | **Fail** | No membership change recorded on the group |
| 6 | Account state visible to an access reviewer | **Fail** | Group members list has no account status column |
| 7 | Cloud identity retained for audit after filing | **Fail** | Object deleted by the container move |
| 8 | Deletion recoverable | **Pass** | 30-day window, purges 2026-09-24 |
| 9 | Deletion record identifies the cause | **Fail** | Timestamped to the sync, not to the human action two minutes earlier |
| 10 | Deletion threshold prevented an unintended removal | **Fail** | Threshold is 500; one deletion passed without a prompt |
| 11 | Control user unaffected | **Pass** | Hana Sato unchanged throughout |

**4 pass, 7 fail.**

## Finding

The action an administrator understands as revoking access, disabling the account, blocked sign-in and revoked nothing else. The entitlement survived, the licenses survived, and no event fired that a monitor could catch.

The action they understand as filing the account away deleted the cloud identity outright, along with the audit trail anyone would later want, and did so without a prompt because the safety threshold is calibrated for mass deletion rather than for one.

Between those two steps, a terminated employee sat in a live entitlement group and looked identical to an active one on the page an access reviewer would open.

## Recommended remediation

1. Off-boarding must clear the attributes driving group membership, not only the sign-in flag.
2. Alert on membership add and remove events individually. Run history and account status both miss this.
3. Do not move terminated accounts out of synchronization scope. Disable in place, or accept that the cloud identity and its audit trail are destroyed.
4. Treat synchronization scope as an access control with a documented owner and a review date.
