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

That sequencing turned out to be unenforceable by itself. See the Phase 4 finding: asking for
read-only scopes does not produce a read-only session.

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

### Second finding: the workflow discards the time component, NOT the attribute
> **CORRECTED 2026-08-08 in Phase 5.** The original version of this entry claimed the attribute
> itself stores date-only precision. That was wrong. A Graph write preserves the time to the
> minute. The workflow task is what truncates. The observation below was accurate, the cause
> assigned to it was not. Corrected text follows, original reasoning kept so the mistake is
> visible.

The corrected leaver workflow ran at **7:00 AM on 8/6** and set this attribute to `system.now`.
The stored value renders as **8/6/2026 12:00:00 AM**, midnight. The time was dropped despite
the attribute being named `...DateTime`.

**Verified against the raw Graph REST response**, so this is not SDK formatting:

    GET https://graph.microsoft.com/v1.0/users/robert.nguyen@hids1.onmicrosoft.com
        ?$select=displayName,employeeLeaveDateTime

    {
      "employeeLeaveDateTime": "2026-08-06T00:00:00Z",
      "displayName": "Robert Nguyen"
    }

The workflow executed at 7:00 AM Pacific, which is 14:00 UTC. The directory stored `00:00:00Z`.

**What I concluded at the time, and got wrong:** that Entra keeps the date and discards the
time on every write, so offboarding lag under 24 hours is unmeasurable by design.

**What Phase 5 proved:** see "The truncation question, answered" below. Writing
`2026-08-08 14:30:00` through Graph stored `21:30Z` and read back intact. The attribute holds
full precision. **`Update user attributes` with `system.now` is what writes a date-only value.**

The practical conclusion narrows rather than disappears: offboarding lag is unmeasurable when
the timestamp is set by a Lifecycle Workflow, which is the only portal-native path. It is
perfectly measurable when set by Graph. That is a sharper argument for scripting than the
original claim, because it points at a specific broken component instead of a platform limit.

**The lesson worth keeping:** one observation supported two explanations, and I picked the
wrong one because I never tested the other write path. "Verified against raw REST" proved the
stored value, not the cause. Proving what a value IS is not the same as proving WHY.

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

---

## Phase 4 - Tooling, and THE FINDING: a read-only request is not a read-only session

### The PowerShell profile
Built `~/.config/powershell/Microsoft.PowerShell_profile.ps1` so the workflow is `pwsh`,
`Connect-Lab`, `Find-TerminatedWithAccess` instead of retyping a five-scope connect line and a
full script path every time.

It does four things: puts the lab scripts folder on `$env:PATH` (via `Join-Path $HOME ...`, not
a hardcoded `/Users/derek`, so the same profile works on the MacBook where home is `muk`),
defines `Connect-Lab` with read scopes, defines `Connect-LabWrite` with write scopes behind a
typed confirmation, and defines `Show-LabContext` to print the account, tenant, and every
granted scope with a READ-ONLY or READ-WRITE banner.

The banner was meant to be a convenience. It turned into the control that caught the finding.

### THE FINDING
Ran `Connect-Lab`, which requests exactly six read scopes. The session came back:

    Mode   : READ-WRITE
    Scopes : 10 granted
             ...
             User.ReadWrite.All

**`User.ReadWrite.All` was never requested.** Write access to every user object in the tenant,
in a session explicitly asked to be read-only.

### Root cause
`Connect-MgGraph -Scopes` is a **request, not a limit**. Entra issues a token containing every
delegated permission the application has already been consented for. Microsoft Graph Command
Line Tools is a shared Microsoft first-party app, and it had a standing tenant-wide admin
consent grant that included `User.ReadWrite.All` from an earlier write session.

Confirmed in Entra admin center at Enterprise applications > Microsoft Graph Command Line Tools
> Permissions > Admin consent: ten delegated permissions, every row reading
`Granted through: Admin consent`, `Granted by: An administrator`. That grant is a durable
directory object. It does not care what scopes you asked for today.
Screenshot `01-graph-cli-admin-consent-includes-user-readwrite-all.png`.

### Why it matters
Every piece of guidance says to connect with least privilege and step up only when needed. That
advice is unenforceable through the scope parameter alone. An admin who connects "read-only
first" out of caution is holding tenant-wide user write for the entire session, and nothing in
the default connect output tells them. The habit provides the feeling of least privilege without
the fact of it.

The `offline_access` row on the same blade is worth naming too: "maintain access to data you
have given it access to" is the refresh token, which is exactly what Lab 2's
`Revoke all refresh tokens for user` task destroys. The mechanism Lab 2 built a control against
is visible here from the requesting side.

### The fix, and it is the same principle as PIM
Revoked the standing `User.ReadWrite.All` grant from the application. Permission count went
10 to 9, all remaining entries read or sign-in scopes.
Screenshot `02-after-revoke-nine-permissions-read-only.png`.

Reconnected with `Disconnect-Lab; Connect-Lab`:

    Mode   : READ-ONLY
    Scopes : 9 granted

Screenshot `03-connect-lab-before-and-after-revoke.png` holds both states in one frame, same
command, same account, minutes apart.

**This converts a standing application privilege into a just-in-time one.** Write consent is now
granted at the moment Phase 5 needs it rather than sitting permanently on the service principal.
That is PIM's argument applied to an application identity instead of a human one, and the same
argument as the Lab 2 finding that eligible-but-not-active is the safe default.

### Two things this exposed that are still open
1. **Revocation timing was not measured.** The new token reflected the revoked grant immediately
   after `Disconnect-Lab`, so the MSAL cache was cleared rather than reused. Whether an
   already-issued token would have kept working until expiry was not tested. It almost certainly
   would have, which means revoking consent does not revoke access already in flight.
2. **`Find-TerminatedWithAccess.ps1` checks for missing scopes, not excess ones.** Under-permission
   produces a silently incomplete report, which the script already hard-stops on. Over-permission
   produces silent risk, which it does not notice at all. Worth adding a warning.

---

## Phase 5 - Bootstrapping the scheduled leaver

Subject: **Thomas Brooks, Engineering.** Chosen deliberately. Every other candidate carries
evidence from an earlier phase (Priya from entitlement management, Marcus from PIM, Sarah as
approver, Robert from lifecycle), and Engineering is the one department untouched by any prior
phase. Critically he is **not in Sales**, so the existing joiner workflow scoped to
`department eq 'Sales'` cannot fire on him and confuse the result.

### Tenant survey first, and it explains a lot of Lab 2
Listed all 13 users with their lifecycle attributes before touching anything:

**No user has an `employeeHireDate`. No user has an `employeeType`. Only Robert carries an
`employeeLeaveDateTime`.** Robert's hire date is now blank, which confirms the corrected
leaver's attribute-clearing task did what it claimed.

That emptiness is the root cause behind several Lab 2 dead ends that looked unrelated at the
time: manager-as-approver was unusable, group-owner-as-reviewer was unusable, and
manager-as-reviewer fell through to the backup on every request. **Half of Entra's governance
surface reads from attributes that nobody populates.** A governance feature is only as good as
the directory data underneath it, and most tenants have less of that data than they think.

### Just-in-time write access, proven
`Connect-LabWrite` **triggered a fresh Microsoft consent prompt.** Before the Phase 4 revoke it
would have connected silently against the standing grant. The session came back with 12 scopes
including `User-LifeCycleInfo.ReadWrite.All` and `LifecycleWorkflows.ReadWrite.All`, neither of
which had ever been consented on that application.

That is the Phase 4 remediation paying off: a standing application privilege became a
just-in-time one, granted by a human at the moment of need. Same argument as PIM, one layer
down, applied to an application identity instead of a person.

### THE TRUNCATION QUESTION, ANSWERED
The open question carried from Lab 2 was whether `employeeLeaveDateTime` discards time on every
write path, or only when a workflow task sets it with `system.now`.

Wrote an explicit non-midnight time through Graph:

    Update-MgUser -UserId thomas.brooks@hids1.onmicrosoft.com `
                  -EmployeeLeaveDateTime (Get-Date "2026-08-08 14:30:00")

Read straight back:

    Thomas Brooks   8/8/2026 9:30:00 PM

**The time survived.** 2:30 PM Pacific is 21:30 UTC, and 21:30 UTC is 9:30 PM. Stored to the
minute.

**Conclusion: the attribute holds full datetime precision. The Lifecycle Workflow task is the
thing that truncates.** This corrects the Phase 2 entry above, which blamed the attribute.

Why it matters: "the platform cannot measure offboarding lag" is a much weaker and less useful
statement than "the workflow task writes a date-only value, so lag is unmeasurable only on the
portal-native path." The first sounds like a limitation to accept. The second names a specific
component to work around, and the workaround is the script.

### Second finding: the SDK round-trips through UTC and prints UTC on read
Wrote `14:30`, read back `9:30 PM`. Nothing is wrong, that is the same instant expressed in
UTC, but the SDK does not convert back to local on read.

An administrator who writes an afternoon timestamp and sees a seven-hour difference come back
will reasonably assume the write was corrupted and go hunting a bug that does not exist. Any
report built on these values needs an explicit timezone conversion, or an explicit statement
that the column is UTC. A timestamp without a stated zone is not evidence.

### Third finding: the revoke does not stay revoked
Set `employeeType = Administrator` on the admin account, then ran `Disconnect-Lab; Connect-Lab`
to drop back to least privilege.

**It came back READ-WRITE with 12 scopes.**

Granting write consent during `Connect-LabWrite` recreated the standing tenant-wide grant. The
just-in-time property established by the Phase 4 revoke survived exactly until the first time
write was actually used. From that moment `Connect-Lab` hands back write again, because the
grant governs and the request does not.

**Revoking once is not a remediation, it is a reset.** Genuine just-in-time application
privilege requires one of:

1. Revoking the write grant after every write session, which nobody will do reliably by hand
   and which therefore needs to be scripted or scheduled.
2. A dedicated app registration holding only read permissions, used for all audit work, so the
   read tooling is structurally incapable of writing regardless of what the shared Graph CLI
   app has been consented for.

Option 2 is the real answer, and it is the same reasoning as using a separate break-glass
account instead of promising to be careful with the one you have. **Controls that depend on an
operator remembering to undo something are not controls.**

Worth noting the shape of the mistake: the Phase 4 write-up called the revoke a fix and
verified it against a single reconnect. That verification was real but it was taken before the
one action guaranteed to undo it. **Verifying a control immediately after applying it only
proves it applied, not that it holds.**
