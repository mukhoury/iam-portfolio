# Lab 3 Friction Log - Identity Automation with Microsoft Graph PowerShell

Running log of every mistake, surprise, and dead end. Written down as it happens so the
video narration sounds like someone who actually did the work, not someone reading a script.

## Phase checklist

- [x] Phase 1 - Environment and auth
- [x] Phase 2 - Read what the portal hides
- [x] Phase 3 - Collision detector
- [ ] Phase 4 - True lifecycle metrics
- [ ] Phase 5 - Bootstrap the scheduled leaver (only phase needing write scopes)
- [ ] Phase 6 - Write-up

Phases 1 through 4 are read-only. Write access is requested once, at Phase 5, and that
sequencing is deliberate.

---

## Phase 1 - Environment and auth

### The documented install command does not exist anymore
**2026-08-07.** Microsoft's macOS install docs, and basically every blog post, say to run
`brew install --cask powershell`. That cask has been removed. Homebrew errors with
"Cask 'powershell' is unavailable" and then helpfully suggests `powershell@preview`, which
would put you on a 7.7.0 preview build without you really noticing.

The stable build moved from a cask to a formula. The correct command is now:

    brew install powershell

That installed PowerShell 7.6.4 and pulled dotnet as a dependency. Formula installs go to
the user prefix, so unlike the old cask it needs no admin password.

**Why it matters beyond this lab:** anyone standing up a Graph automation workstation from
the official docs today either fails or silently ends up on a preview runtime. Worth knowing
if a team ever asks you to document a build process.

---

## Phase 2 prep - restoring Robert, and a sharper version of the Lab 2 finding

### The Properties blade lists employeeHireDate but not employeeLeaveDateTime
**2026-08-07.** Restored Robert Nguyen to parity with the other 12 users after the Lab 2
termination: re-enabled the account and set Department back to Sales, which puts him back in
the Sales dynamic group automatically.

With that done, his Properties tab shows Job Information containing Job title, Company name,
Department, Employee ID, Employee type, **Employee hire date**, Employee org data, Office
location, Manager, and Sponsors.

**There is no Employee leave date field anywhere on the blade.** Not on Properties, not on any
tab, not behind Manage view. The portal renders four of the five `employee*` lifecycle
attributes and omits the one that marks a person as terminated. The joiner attribute is
visible, the leaver attribute is not.

That is a more precise statement of the Lab 2 finding than "write-only from the portal's
perspective." Robert currently looks completely normal and completely clean on screen while
still carrying a termination timestamp on the object underneath. An administrator reviewing
this user in the portal has no way to know.

### Token revocation survives reinstatement
Re-enabling the account did not clear "Sign in sessions valid from date time: Aug 6, 2026 at
7:00 AM", the stamp left by the leaver workflow's token revocation task. Harmless in effect,
since it only invalidates tokens issued before that moment, but it is a permanent forensic
trace of the termination that persists after the user is brought back.

### Group-based licensing gives you no way to tell "converging" from "failed"
**2026-08-07.** Assigned Microsoft Entra ID P2 and the Entra ID Governance Add-on to the six
department groups (Engineering, Finance, HR, IT, Marketing, Sales). Deliberately excluded the
two Lab 2 groups, `Finance Reporting App Access` and `New Hire Baseline Access`, on the
reasoning that licensing should follow employment status rather than access grants. Licensing
off an access-package group would mean requesting a package hands someone a license, which is
backwards.

P2 reached 13 of 25 almost immediately. Governance sat at **5 of 25** for several minutes, and
the five that worked clustered perfectly by group: both Sales users, both Finance users, and
the admin. Engineering, HR, IT, and Marketing had nothing.

Three wrong diagnoses along the way, worth keeping because the reasoning is the lesson:
1. **Prerequisite dependency.** Governance is an add-on for P2, so assigning it before P2
   should fail for users lacking the base SKU. Ruled out: a dependency failure would scatter
   by user, not land cleanly on four entire groups.
2. **The four groups were never submitted.** Ruled out by the Licenses tab, which listed all
   six groups as assigned.
3. **A silent failure like Lab 2.** Ruled out: it resolved on its own within minutes.

**The actual finding:** it was asynchronous processing, and nothing in the interface says so.
Errors and Issues reported "Licensing errors (0)" and "Members without licenses (0)" while
eight members of assigned groups genuinely held no license. Both statements were true at once,
because that tab only reports failures among completed assignments. The per-group "Assigned
licenses" column stays blank whether a group succeeded or not, so it carries no signal either.

The only feedback is a summary count that is silently wrong until it isn't, with no
in-progress state. An administrator who checked once and walked away would reasonably conclude
eight assignments had broken.

---

## Phase 2 - THE FINDING: Graph returns employeeLeaveDateTime as empty, not denied

**2026-08-07.** Connected to Microsoft Graph read-only with `User.Read.All`,
`Group.Read.All`, `LifecycleWorkflows.Read.All`, `Organization.Read.All`, then queried Robert
Nguyen for the full set of `employee*` lifecycle attributes.

**Result: `EmployeeLeaveDateTime` came back BLANK. No error. No warning. No indication that
anything had been withheld.**

Reconnected with one additional read-only permission, `User-LifeCycleInfo.Read.All`, and ran
the identical command against the identical user minutes later:

    EmployeeLeaveDateTime : 8/6/2026 12:00:00 AM

**Why this is worse than the portal behavior.** The Entra portal at least omits the field from
the Properties blade entirely, so an administrator can see that the field is not being shown.
Graph returns the property present and empty. There is no way to distinguish "this user was
never terminated" from "you do not have permission to know."

An administrator auditing terminations tenant-wide while holding `User.Read.All` would get a
complete-looking result set with every leave date blank, and would reasonably report the tenant
clean. Reading full user profiles is not enough. Microsoft carves lifecycle data into its own
consent scope, and the consent screen says so in its own words: "Allows the app to read the
lifecycle information like employeeLeaveDateTime of users in your organization."

**Practical takeaway:** any script that audits offboarding must assert its own scopes before
trusting its results. A null lifecycle attribute is not evidence of anything unless
`User-LifeCycleInfo.Read.All` is confirmed present in the session.

### Second finding: employeeLeaveDateTime silently discards the time component
The corrected leaver workflow ran at **7:00 AM on 8/6** and set this attribute to `system.now`.
The stored value renders as **8/6/2026 12:00:00 AM**, midnight. The time was dropped despite
the attribute being named `...DateTime`.

This is the mechanism behind the Lab 2 observation that offboarding lag can never be measured.
It is not only that the workflow stamps its own run time rather than the actual termination
moment. Even a correctly stamped value could not express lag under 24 hours, because the field
holds day-level precision. Any offboarding SLA measured in hours cannot be evidenced from this
attribute.

**Verified against the raw Graph REST response**, so this is storage, not SDK formatting:

    GET https://graph.microsoft.com/v1.0/users/robert.nguyen@hids1.onmicrosoft.com
        ?$select=displayName,employeeLeaveDateTime

    {
      "employeeLeaveDateTime": "2026-08-06T00:00:00Z",
      "displayName": "Robert Nguyen"
    }

The workflow executed at 7:00 AM Pacific, which is 14:00 UTC. The directory stored
`00:00:00Z`. Entra keeps the date and discards the time on write.

---

## Phase 3 - building the detector, and why the obvious rule fails

**2026-08-07.**

### Rule 1 (naive): terminated but still enabled
    employeeLeaveDateTime is not null
    AND employeeLeaveDateTime < now
    AND accountEnabled = true

Returns Robert Nguyen. Looks correct.

**It would have missed the actual Lab 2 incident.** On Aug 4 the leaver ran, Robert was
*disabled*, and he still held a dynamic group membership. `accountEnabled = true` was false,
so this rule returns zero rows and reports the tenant clean while a terminated identity is
still entitled.

Disabling an account is not removing its access. A disabled account keeps group memberships,
licenses, and access package assignments. Anything that re-enables it, including a scheduled
joiner workflow, restores all of it instantly.

### Rule 2 (correct): terminated but still entitled
Drop the `accountEnabled` condition entirely and count group memberships instead. The question
is not "can they sign in," it is "do they still hold access."

### The current-state problem
Graph returns **current state only**. There is no "as of" parameter. The directory does not
remember that Robert went 2 groups, then 1, then 2, then 0, then 1.

Running the detector today returns Groups = 1 and looks unremarkable. The 1:13 AM
re-provisioning of a terminated account on Aug 5 left **no trace whatsoever on the user
object**. It was only caught because someone happened to be looking that week.

Two consequences:
1. **Detection must run continuously, not retrospectively.** A nightly scheduled run would
   have caught the reversal on the morning of Aug 5. Running it now catches nothing.
2. **Point-in-time questions need a different source.** "What access did this person hold on
   their termination date" cannot be answered from the user object. It requires Entra audit
   logs (30 days retention on P2, 7 on free) or snapshots captured in advance. Past that
   window the answer simply does not exist.

**An offboarding failure that self-heals leaves no evidence.**

### Reinstatement restores only the access nobody approved
Restored Robert by setting `department` back to Sales and re-enabling the account. Verified
his memberships afterward:

    Get-MgUserMemberOf -UserId robert.nguyen@hids1.onmicrosoft.com | ForEach-Object { $_.AdditionalProperties.displayName }
    Sales

Before termination he held **two** groups: `Sales` (dynamic, driven by `department`) and
`New Hire Baseline Access` (assigned by a joiner workflow task).

Only Sales came back, and it came back **automatically, with no human decision, the instant the
department attribute was set**. `New Hire Baseline Access` stayed revoked because an explicit
grant put it there and nothing has re-granted it. An access package assignment would behave the
same way, requiring a fresh request and approval.

**The asymmetry is the finding: attribute-driven access self-restores on reinstatement, while
approved access stays revoked. The entitlements that return for free are precisely the ones
that never passed an approval gate.**

### Tenant is cloud only
On-premises sync enabled reads No, which is why the hybrid limitation on `Update user
attributes` is documented from Microsoft's constraints rather than tested here.
