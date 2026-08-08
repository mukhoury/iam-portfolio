# Lab 2: Identity Governance Build Log

**Tenant:** Houry Identity Solutions (`hids1.onmicrosoft.com`) · Entra ID Premium P2
**Operator:** Mukhtar Houry (Global Administrator)
**Build date:** 2026-07-27
**SC-300 coverage:** Domain 4, Plan and implement identity governance

This is the working record of what was built, in the order it was built, with the
reasoning behind each choice. It exists so the lab can be (a) rebuilt from scratch,
(b) narrated on video without guessing, and (c) defended in an interview.

---

## Phase 1: Entitlement Management ✅ COMPLETE & VERIFIED

### What problem this solves

Onboarding by hand doesn't scale and leaves no evidence. Someone joins Finance, an
admin grants six things from memory, nobody records who approved it or why, and the
access never gets removed. Entitlement management turns that into a requestable,
approvable, expiring package with a permanent audit trail.

### Step 1: Catalog

- **Created:** `HIDS Onboarding Catalog`
- Description: "Access Packages for departmental onboarding."
- Enabled: **Yes** · Enabled for external users: **No**
- Object ID: `71744b90-c218-4d53-a0cd-455b2379951c`
- **Why:** A catalog is the container that holds access packages and the resources
  they're allowed to hand out. External users off because this lab is internal-only,
  B2B guest governance requires a linked Azure subscription (portal banner confirmed it).
- Screenshots: `01-catalog-created.png`, `02-catalog-overview-no-resources.png`

### Step 2: The resource group (and the gotcha)

- **Created group:** `Finance Reporting App Access`
- Type: **Security** · **Membership type: Assigned** · Entra roles assignable: **No**
- Description: "Requestable access to finance reporting resources - granted via access package"
- **The gotcha:** a **dynamic** group cannot be used inside an access package. Dynamic
  membership is rule-computed and owned by Entra, so the package can't add or remove
  people from it. All six Lab 1 groups are dynamic, so a new **Assigned** group had to
  be created specifically as the thing the package grants.
- **Why "Entra roles can be assigned = No":** that switch makes it a *role-assignable*
  group (used with PIM for groups). It is **permanent and cannot be changed after
  creation**. This group hands out app access, not admin rights.
- Screenshot: `03-static-group-assigned-membership.png`

### Step 3: Onboard the resource to the catalog

- Added `Finance Reporting App Access` to the catalog → Type: Group and Team,
  Sub Type: Security, **Onboarded: Yes**
- **Note:** you cannot create a group from inside the catalog. It must exist first.
- Catalog resource types available: Groups and Teams · Apps · SharePoint Online sites ·
  Microsoft Entra role · OAuthApplication
- Screenshot: `04-group-onboarded-as-catalog-resource.png`

### Step 4: Access package

**Basics**
- Name: `Finance Reporting Access`
- Description: "Time-limited, approved access to finance reporting resources. Expires after 90 days."
- Object ID: `6319a917-e4ec-47df-9d96-48b23a92f968`

**Resource roles**
- `Finance Reporting App Access` → role **Member** (not Owner, Owner would let the
  requestor manage the group itself)

**Requests, who can get it**
- For users, service principals, and agent identities in your directory
- Scope: **Specific users and groups** → the **Finance** dynamic group from Lab 1
- **Why this matters:** this is the chain-link between Lab 1 and Lab 2. Attribute-based
  membership decides *eligibility to request*. A Finance user sees the package;
  an IT user sees nothing. Attribute-based access control feeding entitlement management.

**Requests, who can request**
- **Self** ✔ · **Admin** ✔ (locked on, admins can always direct-assign) · Manager ✘
- **Why Manager is off:** on-behalf-of requests require a separate Microsoft Entra ID
  Governance license. Premium P2 does not include it.

**Approval**
- Require approval: **Yes** · Stages: **1**
- First approver: **Choose specific approvers** → Mukhtar Houry
  - *Manager as approver* was rejected because no lab user has the `manager` attribute
    populated, which would force the fallback approver on every single request.
  - *Sponsors as approvers* is greyed out, needs the ID Governance license and a
    connected organization (B2B).
- Decision deadline: **14 days** (Entra's hard maximum, requests cannot sit forever)
- Require **approver** justification: **Yes** ← the audit-critical field
- Assignment emails: enabled

**Requestor information**
- One question: "What business justification do you have for accessing finance reporting?"
- Answer format: **Long text** · **Required**
- *Revision made mid-build:* `Require requestor justification` was originally Yes, which
  produced **two** justification boxes on the request form. Turned it to **No**.
  **Finding:** that toggle controls whether the built-in "Business justification" field is
  *required*, not whether it *appears*, Entra always renders it. The custom question is
  the one that carries specific wording.

**Lifecycle**
- Assignments expire: **Number of days → 90** (default was 365)
- Users can request specific timeline: **No**, policy governs the window, not the requestor
- Allow users to extend access: **No** → *Require approval to grant extension* greys out
- Require access reviews: **No** (built separately in phase 2)
- **Why 90 days:** this is the privilege-creep cure. Access dies on its own unless
  re-requested and re-approved.

- Screenshots: `05`-`12`

### Step 5: End-to-end verification (the part that matters)

Tested as a real end user, not by admin assignment.

1. Signed in as `priya.patel@hids1.onmicrosoft.com` (Financial Analyst, Finance dept)
   in a private window.
   - **Conditional Access CA001 fired:** forced MFA registration via Combined Security
     Information Registration before she could reach anything. Lab 1's policy enforcing
     itself on a real user.
   - **Note:** bulk-CSV-created users were NOT flagged for forced password change; all 13
     sit on a shared known password. In production that's a finding.
2. Hitting `entra.microsoft.com` as Priya returned **401 / No access**, she holds no
   admin role. Least privilege, demonstrated. (`15-standard-user-denied-admin-center-401.png`)
3. My Access portal showed **Available (1)**, only `Finance Reporting Access`, because
   of the Finance-group scoping. An IT user would see zero.
4. Requested with justification: "Need access to the finance reporting resources to run
   quarterly close analysis and variance reporting for Q3. Requested per my role as
   Financial Analyst."
5. Status: **Pending approval**, submitted Jul 27 2026 4:18 PM PDT, due Aug 10 2026.
6. As approver (My Access → Approvals, *not* the admin center, approvers are usually
   business managers with no admin rights), reviewed her justification and **Approved**
   with rationale: "Priya Patel is a Financial Analyst on the Q3 close team; access is
   limited to finance reporting resources and expires in 90 days."
7. **Result:** `Finance Reporting App Access` went from 0 members to 1, Priya Patel,
   provisioned by Entra. Group membership was never touched by hand.

- Screenshots: `13`-`24`

### Phase 1 narration hooks (for the video)

- "The group was empty at 3:11. I never added anyone to it. The approval did that."
- "She sees one package. An IT user sees none. That's her department attribute deciding
  what she's even allowed to ask for."
- "Fourteen days is Entra's ceiling on an approval decision, you can go lower, not higher."
- "Ninety days, no self-extension. This access removes itself."
- "The requestor states the need. The approver states the decision rationale. Six months
  from now, an auditor asks why she has this, and the answer is a record, not a memory."

---

---

## Friction log: what actually went wrong (keep this; it's the honest part)

Everything below cost real time during the build. This is the section that makes the
video worth watching, because it's what a viewer will hit too.

1. **Dynamic groups can't go in an access package.** Built six beautiful dynamic groups in
   Lab 1, went to add one as the package resource, and none of them work. Entra owns
   rule-based membership, so a package can't add or remove people from it. Had to stop and
   create a brand-new **Assigned** group. Expect this, it isn't documented where you'd
   look for it.
2. **You can't create a group from inside the catalog.** "Add resources" only picks from
   groups that already exist. Wasted a round trip.
3. **Two justification boxes on the request form.** Set "Require requestor justification =
   Yes" *and* wrote a custom question, so end users got asked the same thing twice. Turning
   the toggle off did **not** remove the second box, it only made it optional. Entra always
   renders "Business justification"; the toggle just controls the asterisk. Learned that the
   hard way, mid-flow, with a real request half-submitted.
4. **The custom question DOES support long text.** Initial assumption was Short text or
   Multiple choice only. Wrong, there's a **Long text** option in the dropdown. Check the
   dropdown before believing anyone (including a doc) about what's available.
5. **Bulk-CSV users had no forced password change.** Expected a reset prompt on first
   sign-in; there wasn't one. All 13 lab accounts sit on the same known password. In a real
   tenant, that's an audit finding.
6. **MFA registration blocked the test.** Signing in as a test user triggered Combined
   Security Information Registration because CA001 requires MFA. Needed a phone and about
   ten minutes. Plan for it, you can't test end-user flows in an MFA-enforced tenant
   without enrolling the test user.
7. **Landed on `entra.microsoft.com` as a standard user → 401 No access.** Momentarily read
   as a broken account. It wasn't: standard users have no admin roles and the admin center
   correctly refuses them. The end-user destination is `myaccess.microsoft.com`. Confusing
   the two costs a minute and a small heart attack.
8. **The approver works in My Access, not the admin center.** Approvals don't appear in the
   Entra admin console, which is the point. Approvers are business managers, not admins.

---

## Phase 2: Access Reviews ✅ COMPLETE & VERIFIED

### What problem this solves

Entitlement management controls how access is GRANTED. Access reviews control whether
it's still justified later. The failure they fix: someone transfers from Finance to
Marketing, keeps the finance access because nobody remembers to remove it, and two years
later holds permissions from four different roles. That's privilege creep, and a
recurring review is the control that catches it.

### Configuration

- **Name:** `Quarterly Access Review - Finance Reporting App Access`
- **Description:** "Recurring quarterly certification of membership in Finance Reporting
  App Access. Unreviewed access is removed automatically."
- **Template:** Resource review (not Catalog review, Catalog reviews cover a user's
  access across every resource type in a catalog at once; overkill for one group)
- **Review type:** Teams + Groups → Select Teams + groups → `Finance Reporting App Access`
- **Scope:** All users · Inactive users only: unchecked
- **Multi-stage:** off (one stage)
- **Reviewer:** Selected user(s) or group(s) → Mukhtar Houry
- **Duration:** 7 days · **Recurrence:** Quarterly · **Start:** 2026-07-27 · **End:** Never
- **Auto apply results to resource:** Enabled
- **If reviewers don't respond:** **Remove access** ← fail-closed
- **Decision helpers:** "No sign-in within 30 days" on · "User-to-Group Affiliation" off
- **Justification required / Email notifications / Reminders:** all on
- **Status after create:** Not started (Entra activates the first instance on its own
  schedule from the start date)

### Design decisions worth defending in an interview

- **Fail closed.** Setting no-response to "Remove access" with auto-apply enabled makes
  silence revoke access instead of preserving it. Entra shows an explicit amber warning
  that this "could potentially lead to all access to this resource being revoked if the
  reviewers fail to respond", that's the point. The most common failure of review
  programs is reviewers ignoring the email; with "No change" you get the audit artifact
  without the control. Real mitigation is multiple reviewers, not weakening the setting.
- **Quarterly / 7 days.** Quarterly is the cadence most compliance frameworks land on for
  sensitive access; 7 days survives a reviewer being on vacation without letting the
  review drift into the next quarter.
- **Named reviewer, not group owner or manager.** In a production tenant the right answer
  is group owners or managers, closest to the resource, or actually knows the person's
  job. Both were unusable here (see friction #11).

### Phase 2 narration hooks

- "Silence removes access. That's deliberate, the most common way review programs fail
  is reviewers ignoring the email."
- "Microsoft warns you when you configure it this way. The warning is the feature."
- "Two of the four reviewer options were dead in my tenant, and that's the real lesson:
  governance features are only as good as the directory data underneath them."

---

## Friction log: phase 2

9. **New template picker.** The wizard now opens with a Resource review / Catalog review
   card chooser. Older walkthroughs and Microsoft Learn screenshots drop straight into
   the config, if you follow a 2024-era guide you're looking for a screen that no longer
   exists.
10. **"All users" is greyed out at first.** Scope and Review scope are coupled: while
    Review scope is "All Microsoft 365 groups with guest users," Scope is forced to
    "Guest users only." Click "Select Teams + groups" FIRST and the option unlocks.
    Trying it in the other order reads like a broken portal.
11. **Two of four reviewer types unusable.** "Managers of users" fails because no lab user
    has the `manager` attribute populated; "Group owner(s)" fails because the group has
    zero owners. Same root cause that killed "Manager as approver" in phase 1. Populate
    manager and owner fields or half of Entra's governance surface can't be used.
12. **Review sits at "Not started" after creation.** There's no start button. Entra
    activates the first instance on its own schedule from the start date, so the reviewer
    task doesn't appear in My Access immediately. Budget a wait before you can demo the
    reviewer experience.

---

## Phase 2: reviewer experience (2026-07-28)

The review instance went **Active** sometime in the ~21 hours between creation
(2026-07-27, afternoon) and the next check (2026-07-28, 1:09 PM). The exact activation
time was not observed, 21 hours is an upper bound, not a measurement.

**Where the decision actually happens:** `myaccess.microsoft.com`, not the Entra admin
center. Admins *build* reviews in the admin center; reviewers *do* them in My Access.
A real reviewer (a group owner or a people manager) never touches the admin portal.

Reviewer view showed: due **2026-08-03** (7 days from start), progress "In progress
(0 of 1 pending)", one user in scope, Priya Patel.

**Decision: Approve, overriding the system recommendation.** Justification recorded:

> Override of system recommendation. Helper flagged user as inactive (no sign-in in 30
> days); this is stale telemetry. User signed in and completed MFA registration on
> 7/27/26 and was provisioned to this group via an approved access package request the
> same day. Role (Financial Analyst) requires continued access to Finance Reporting App.

### Friction log: phase 2 (continued)

13. **The decision helper produced a false positive.** Entra recommended **Deny** and
    tagged Priya as an **"Inactive user", "has not signed into this tenant in last 30
    days."** She had signed in the previous day: interactive sign-in, forced through
    CA001 MFA registration, submitted an access package request, got provisioned. The
    recommendation was flatly wrong. Cause is reporting lag, last-sign-in telemetry can
    take up to ~24 hours to surface, and the recommendation for this instance was
    computed at instance start before her sign-in had propagated. Not a bug; a
    stale-data artifact. **The lesson is the "Accept recommendations" button sitting
    right there in the toolbar:** one click accepts every recommendation at once. With
    auto-apply enabled and no-response set to Remove access, clicking it would have
    revoked a legitimate analyst's access with no second prompt. This is exactly how
    review programs fail in production, reviewers rubber-stamp the machine because it's
    faster than thinking. Rejecting the recommendation and documenting *why* is the
    entire job.

### Phase 2 narration hooks (continued)

- "Entra told me to deny a user who had signed in the day before. I know why, the
  sign-in data hadn't propagated yet, and that's the whole argument against the
  'Accept recommendations' button."
- "The reviewer never sees the admin center. Different portal, different person,
  different mental model. If you build a review your reviewers can't understand in
  thirty seconds, they'll click whatever the machine suggests."

### Closing the loop: decision → enforcement (2026-07-28)

Recording a decision is not enforcing it. The admin **Results** blade showed
`Outcome: Approved` / `Recommended action: Deny` / `Reviewed by: Mukhtar Houry on
7/28/2026` with the **Apply result column empty**, decided, not yet executed. Auto-apply
fires when the instance ends, so the instance was stopped early from Results
(**Stop → "Do you want to stop the review? Reviewers will no longer be able to give
responses." → Yes**) to force it.

Observed sequence after stopping:

1. Overview donut heading changed **"Current" → "Previous"**; the whole **Current** nav
   group (Results / Reviewers / Settings / Audit logs) greyed out.
2. Essentials unchanged: `Review status: Active`, `Recurrence type: Quarterly`,
   `Access review period: 7/27/2026 - No end date`.
3. **Series → Review history:** showed the instance at `Status: Applying`, then
   `Status: Result applied` on refresh (~3 minutes).
4. Group `Finance Reporting App Access` → Members: **1 group member found, Priya Patel.**
   Decision enforced against the resource, membership intact.

The history record kept **End Date 8/3/2026**, the originally scheduled end, rather than
rewriting it to the early-stop date.

**Question answered (was open from 2026-07-27):** stopping a recurring review ends only the
current *instance*, not the *series*. The series stays Active and spawns the next quarterly
instance on schedule.

### Friction log: phase 2 (continued)

14. **The entire "Current" nav group greys out between instances.** After stopping the
    instance, Results / Reviewers / Settings / Audit logs under **Current** all go
    unclickable. It reads like a permissions failure or a broken portal; it is neither.
    There is simply no instance running, the first ended, the next hasn't started.
    Completed instances move to **Series → Review history**, which is where results live
    from that point on. Anyone demoing this live will look lost for thirty seconds if they
    don't know this.
15. **Signing the user in does not refresh a recommendation.** Two successful interactive
    sign-ins as Priya (visible in her audit log as `B2C / Validate user authentication /
    Token is valid`, 3:12 and 3:13 PM) left the "Inactive user / Deny" recommendation
    unchanged. Confirms the recommendation is computed at instance start and frozen for the
    life of that instance, it is not re-evaluated live. The only way to get a different
    recommendation is a new instance.

### Evidence chain (audit log, Priya Patel)

One log view contains the whole governance story, oldest last:

- `7/27 4:18 PM`, access package request submitted (from Priya's Request history)
- `7/27 4:26:42 PM`, `Entitlement Management` / Fulfill access package resource assignment
- `7/27 4:26:42 PM`, `Core Directory` / **Add member to group** / target `priya.patel@` /
  **Initiated by: Azure AD Identity Governance** ← a service principal, not an admin
- `7/27 4:26:45-46 PM`, `Entitlement Management` / Fulfill access package assignment
- `7/28 3:08:01 PM`, `Access Reviews` / **Approve decision** / Initiated by: Mukhtar Houry

**~8 minutes from request submission to automated provisioning.** The actor column is the
point: the membership was created by the governance engine on the strength of an approved
request, not by hand.

---

## Phase 3: Privileged Identity Management (PIM) 🟡 IN PROGRESS

**Design:** Marcus Chen (IT) becomes **eligible** for **User Administrator** instead of
holding it. Sarah Mitchell (IT) is the **approver**. Two-person control on a role that can
create users and reset non-admin passwords.

**Deliberately NOT done:** converting the tenant's only Global Administrator (Mukhtar) to
eligible. With no second break-glass account that is how a tenant becomes unrecoverable.
Documented as a design decision, not demonstrated destructively.

### Before state (2026-07-28)

- **Eligible assignments: none.** Zero just-in-time access existed in the tenant.
- **Active assignments: 1:** `Global Administrator / Mukhtar Houry / Direct / Assigned /
  End time: Permanent`.
- **Finding:** exactly one Global Administrator and no dedicated break-glass emergency
  access account. Microsoft guidance is at least two, cloud-only, excluded from
  Conditional Access and MFA, credentials held offline. Named as a gap rather than
  silently carried.

### Step 1-2: eligible assignment created

`Add assignments` → Role **User Administrator**, Scope type **Directory**, member
**Marcus Chen** → Setting tab: **Eligible** (Entra's own default, safe by default here),
**Permanently eligible** checked → Assign.

Result: `Eligible assignments` = `User Administrator / Marcus Chen / Direct /
7/28/2026 6:15:05 PM / Permanent`. **Marcus holds no privilege at all** until he activates.

**Two clocks, commonly confused:**
- *Eligibility duration*, how long he may request the role. Permanent here (full-time
  employee). Bounded eligibility is the contractor pattern.
- *Activation duration*, how long privilege stays on once granted. 4 hours here.

### Step 3: role settings hardened

**Defaults found (screenshot 62), two real gaps:**

1. **`Require approval to activate: No` / `Approvers: None`.** Out of the box, an eligible
   user self-activates. MFA and justification are required, so activation is *attributable*,
   but nobody authorizes it. PIM ships with accountability, not authorization. Those are
   different controls and get conflated constantly.
2. **`Allow permanent active assignment: Yes`.** PIM by default still permits exactly the
   standing privilege it exists to remove. Nothing stops an admin handing out a permanent
   active assignment.

Also default: activation max duration **8 hours** (a full workday of privilege).

**Changes applied:**

| Setting | Before | After |
| --- | --- | --- |
| Activation maximum duration | 8 hours | **4 hours** |
| On activation, require | Azure MFA | Azure MFA (unchanged) |
| Require justification on activation | Yes | Yes (unchanged) |
| Require approval to activate | **No** | **Yes** |
| Approvers | **None** | **Sarah Mitchell** |
| Allow permanent active assignment | **Yes** | **No** |
| Expire active assignments after | - | **1 month** |
| Require MFA on active assignment | **No** | **Yes** |

Notification settings left at defaults, three streams (assigned-eligible,
assigned-active, activated) each notifying Admin, Assignee/Requestor and Approver.
Detection layered on prevention.

### Design decisions worth defending in an interview

- **Approval routed to a named individual, not a group.** The member picker offers groups,
  and best practice *is* a group so one person's vacation doesn't block every activation,
  but the obvious candidate here, the **IT** group, contains Marcus himself. Selecting it
  would let him approve his own privilege escalation: a **segregation of duties** failure
  that passes a config review and fails an audit. Production answer is a dedicated
  "IAM Approvers" group that deliberately excludes the people it approves for.
- **Silent default approver.** The UI warns: *"If no specific approvers are selected,
  privileged role administrators/global administrators will become the default approvers."*
  Ticking "require approval" without naming anyone does not disable the control, it
  quietly routes every request to Global Admins, who may not be watching for them.
- **Scope left at Directory.** The alternative, **Administrative unit**, limits the same
  role to a subset of users. PIM constrains privilege in *time*; administrative units
  constrain it in *scope*. Real deployments use both.
- **Conditional Access authentication context not used.** The third "On activation,
  require" option ties activation to a CA policy, compliant device, trusted location,
  phishing-resistant MFA, instead of plain MFA. Stronger, and it would chain into CA001
  from Lab 1. Left out so the demo stays legible; named as the ceiling.

### Friction log: phase 3

16. **Naming drift in the portal.** The UI still says **"Azure MFA"** and **"Azure
    Multi-Factor Authentication"** although the product is now Microsoft Entra multifactor
    authentication. SC-300 uses current names; the portal you are clicking uses old ones.
    Expect the mismatch on exam day.
17. **The two "permanent" toggles look identical and aren't.** `Allow permanent eligible
    assignment` governs how long someone may *request* a role; `Allow permanent active
    assignment` governs whether they may *hold* it outright. Turning off the wrong one
    fights an assignment you just created.
18. **`Expire ... after` is a fixed dropdown, not a free-text day count.** Options are
    preset durations (15 days / 1 month / … / 1 year). "Set it to 30 days" isn't literally
    possible, 1 month is the nearest.

### Step 4 pre-flight: the eligible user seen from the admin side (2026-07-30)

Before operating the activation, Marcus Chen's user Overview blade was read as an auditor
would read it (screenshot 71).

| Field | Value |
| --- | --- |
| Account status | Enabled |
| **Assigned roles** | **0** |
| Group memberships | 1 (IT) |
| Applications / Assigned licenses | 0 / 0 |
| Last interactive sign-in | Jul 28, 2026 6:49 PM |
| MFA status | Capable with 2 authentication methods |

**The finding: `Assigned roles: 0` on a user who is eligible for User Administrator.**

Eligible assignments do not appear on the user object at all, they exist only inside PIM.
An auditor walking this tenant user blade by user blade would conclude there is exactly one
privileged account (the Global Administrator) and would be wrong. **Eligibility is latent
privilege, and it is invisible on the surface most people check.**

This is the honest answer to "eligible vs active": not the definition, but the observation
that *an eligible user's object is indistinguishable from an unprivileged one until the
moment he activates*. It is an argument for auditing PIM assignments as a separate control,
not folding privileged-access review into a user-attribute review.

**Two things confirmed off the same screen:**

- The 6:49 PM sign-in is **34 minutes after** the eligible assignment was created
  (6:15:05 PM). Marcus had already been through the front door.
- `Capable with 2 authentication methods`, **CA001 already fired on Marcus and he
  completed MFA registration.** The gate Priya was forced through is behind him, so the
  "expect CA001 to interrupt" step is a no-op for this account. It also means he can
  satisfy the *require MFA on activation* setting.

**Password decision.** Reset password was deliberately not used. The current Entra admin
center generates a random temporary password that cannot be chosen, which would break the
"all lab accounts on one shared password" convention. Trying the live password first,
resetting only on failure.

### Callout targets for video editing (Kite)

Rows that are invisible in a wall of table text and need an on-screen highlight:

- `Require approval to activate: No` and `Allow permanent active assignment: Yes` on the
  role-settings defaults screen, the whole argument of Phase 3
- `Outcome: Approved` next to `Recommended action: Deny` in the Phase 2 results blade
- The **Accept recommendations** button in the reviewer toolbar
- `Initiated by: Azure AD Identity Governance` in Priya's audit log
- **`Assigned roles: 0`** on Marcus's Overview blade while he is eligible for User
  Administrator, the invisibility of latent privilege, in one number

## Phase 3: operating the activation (2026-08-02)

### Marcus reaches PIM: the 401 question, answered

Signed in as `marcus.chen@hids1.onmicrosoft.com` (eligible-only, zero active roles) and
**PIM → My roles loaded fine. No 401.** This is the opposite of Priya in phase 1.

**Why the difference:** My roles is a *self-service* surface scoped to the signed-in
user's own assignments. It answers "what am I eligible for?" and nothing else. The blades
Priya hit were directory-wide reads that need real directory permissions.

**Better observation off the same screen: nav visibility is not authorization.** Marcus's
left nav renders Entra ID, ID Protection, ID Governance, Lifecycle workflows, Global
Secure Access, all of it. The admin center draws the menu client-side for everyone; the
401 only fires when the blade actually requests data. Seeing the menu item and being
allowed to use it are unrelated. Screenshot `72`.

**Row detail worth naming:** `End time: Permanent` on the eligible assignment means
*permanently eligible*, not permanent access. He is permanently allowed to **ask**. He
holds nothing until he activates, and activation is capped at 4 hours. "Permanently
eligible" and "permanent access" sound identical and mean opposite things.

### Activation (screenshots 73-76)

- **Duration slider maxed at 4 hours:** not Microsoft's default 8, Tuesday's hardening
  holding on the requestor's own screen. `73`
- Justification submitted as free text. **Finding:** the approver grid has dedicated
  `Ticket number` and `Ticket system` columns that stay empty, PIM has structured fields
  for ticket references and free-text Reason is the wrong place to put one. `77`
- After submitting, **My roles still shows `Activate`** on the row and Active assignments
  stays empty. The role was not granted. `74`
- **The trap: the toast says "Your activation request is scheduled" with a green
  checkmark.** It reads like success. He got nothing. `75`
- Real state lives at **PIM → My requests**: `Request status: Pending approval`. `76`
- **Clock oddity:** `Request time 8:20:37 AM` but `Start time 8:17:27 AM`, the start
  timestamp is when the activation blade was opened, three minutes *before* the request
  was actually submitted.

### Approver side

Signed in as Sarah Mitchell → **PIM → Approve requests** → the request is sitting in
`Requests for role activations` with Marcus as requestor. Approve/Deny greyed until the
row is checked. `77`

### Approval and the grant (screenshots 102-107)

Sarah approved at ~1:30 PM with a written justification. Result: `State: Activated`,
`End time: 5:30:26 PM`. `104`

**Finding, the activation clock restarts at approval, not at request.** The approver
blade showed `Start 8:17 AM / End 12:17 PM`, a window that had already elapsed while the
request sat pending for five hours. PIM discarded it and recalculated four hours from the
approval. Correct behavior, but the approver screen actively suggests otherwise.

**Finding, you cannot deactivate immediately.** `Deactivate role failed, The Active
duration is too short. Minimum Required is 5 minutes.` `106` Activated 1:30:27, attempted
1:33. The floor stops privilege from flickering on and off in sub-minute bursts, which
would let someone hold admin repeatedly while barely registering in any monitoring window.

After waiting out the 5 minutes, Deactivate succeeded and the row returned to
**Eligible assignments only**, `Action: Activate`, `End time: Permanent`. `107`

**Screenshots `72` and `107` are the JIT story in two images**, before any activation and
after a complete grant-and-release cycle, the user object is identical. The privilege
existed for 25 minutes and left no trace on the surface, only in the audit log.

**Manual deactivation does not populate Expired assignments.** The tab stayed empty after
the manual drop. A second activation was therefore run at 2:08 PM at the **minimum
duration the slider allows, 0.5 hours** `108` `109`, approved by Sarah at 2:09 `110` `111`,
and left to expire naturally at ~2:39 while Muk was out. Open question until verified:
does Expired assignments log only timed-out grants?

### Phase 3 access review: privileged role certification (screenshots 112-119)

Built in **PIM → Microsoft Entra roles → Access reviews**, which is a different surface
from the ID Governance access reviews used in phase 2. Phase 2 certified *group
membership*; this certifies *who is allowed to hold admin*.

- Name: `Q3 2026 - Privileged Role Review: User Administrator`
- Frequency **Quarterly**, duration **3 days**, start 8/2/2026, series end 11/3/2026
- **`Assignment type: All active and eligible assignments`:** the single most important
  setting on the blade, and the direct answer to the 7/30 `Assigned roles: 0` finding. A
  review covering only *active* assignments would certify Marcus as unprivileged.
- **`Inactive users only: False`:** deliberate. Phase 2 proved Entra's inactivity signal
  was wrong about Priya; a privileged role gets certified regardless of activity.
- Reviewer: **Sarah Mitchell**

**UI finding:** `Duration (in days)` is greyed out while `Frequency` is **One time**, it
only unlocks for a recurring frequency. `115`

**Reviewer options and why the other two fail here:** the dropdown offers *Selected
user(s) or group(s)*, *Members (self)*, and *Manager*. `114` **Manager** would fall through
to the backup reviewer on every request, no lab user has the `manager` attribute
populated, the same gap that killed manager-as-approver in phase 1. **Members (self)** is
self-attestation: the holder of User Administrator decides whether they should keep User
Administrator, which is the weakest possible control on a privileged role.

**Two more unsafe defaults closed** `117` → `118`:

- `Auto apply results to resource` shipped **Disable** → set **Enable**. A review that
  records decisions without enforcing them is paperwork.
- `If reviewers don't respond` shipped **No change** → set **Remove access**. Silence
  should revoke privilege, not preserve it. This is how standing admin accumulates.

Left on: Show recommendations (to see whether it repeats phase 2's stale-telemetry
mistake on a privileged role), Require reason on approval, mail notifications, reminders.

**Lockout check performed before enabling auto-apply + remove-on-silence:** the review
scopes only User Administrator, held solely by Marcus. Muk holds Global Administrator,
which is out of scope. No path to self-revocation.

Created successfully, **Status: `Not started`** `119`, same deferred activation seen with
the phase 2 instance. Compare `112` (empty) → `119`.

### Closing phase 3 (2026-08-03, screenshots 120-138)

**Expired assignments never populates, and the reason is better than the question.**
Empty under the default `Assignment type: Eligible` filter `121`, and still empty after
switching to `Active` `122` `123`. Two wrong theories died here (manual-vs-natural expiry,
then a filter default). The actual explanation: **Expired assignments tracks *assignment*
lifecycle, not *activation* sessions.** Marcus's eligible assignment is Permanent, so
nothing of his has ever expired. His activations were never assignments at all.

**Consequence, a completed JIT activation leaves no trace in any assignment view.** Not
on the user blade, not in Active, not in Expired. Same theme as `Assigned roles: 0`, one
layer deeper: the assignment surfaces show *current state only*. The entire history of who
held admin and when lives exclusively in the audit log.

**`PIM → My audit` is where it all is** `124`, 13 rows spanning 7/28 to 8/2:

- The **failed deactivation is logged with a red ✗** (`1:33:25 PM, Process role removal
  request`). The 5-minute-minimum rejection is a permanent record, not just a toast.
  Attempts are audited alongside successes, which is what makes the trail trustworthy.
- The final row's requestor is **`Azure AD PIM`, not a person**, the system revoked the
  privilege and signed its own name to it. Exact parallel to phase 1's
  `Azure AD Identity Governance` provisioning Priya. **Both times the actor is a service.**
- **Expiry precise to the second:** activation completed `2:13:10`, expired `2:43:11` on a
  0.5-hour grant.
- Two complete cycles, with Sarah appearing as a distinct actor from Marcus at each
  approval, segregation of duties demonstrated rather than described.

### The access review, operated

Instance found **Active at 10:21 AM 8/3**, created 2:27 PM 8/2. `125` **Bound only:**
activation is deferred, observed Active within ~20h here and ~21h in phase 2, with no
measurement of actual latency in either case, nobody watched the interval.

**The recommendation was correct this time:** `Approve, Last signed in less than 30 days
ago (8/2/2026)`. `127` This does **not** contradict phase 2. The sharper version of the
finding: the engine isn't reliably *wrong*, it's reliably *stale*. Whether staleness
produces a wrong answer depends on the gap between the user's activity and when the
instance computed its recommendation. Priya had ~1 day and the lag ate it; Marcus had ~20
hours and it caught up. **That is worse than being consistently wrong, you cannot
calibrate how much to trust it.**

**Marcus appeared in the review at all** because of `All active and eligible assignments`.
His active assignment expired 8/2 at 2:43 PM. A review scoped to active holders only would
have listed nobody and certified that the tenant has no User Administrators.

**Approve greyed, Deny live** `127`, `Require reason on approval: true` in action, and note
the asymmetry: you must justify *keeping* privilege, but may revoke without typing
anything. Friction sits on the riskier action.

**Third distinct 401 of the lab** `128`: Sarah, the designated reviewer, is denied the
**Audit Details** behind the recommendation she's being asked to act on. The portal renders
the `View` link for her anyway, the same "affordance the permissions don't back" pattern
as Marcus's left nav. **This is why real access reviews get rubber-stamped: the reviewer
isn't lazy, they're blind, so accepting the recommendation is the only available action.**

The 401 triad, same error code, three unrelated causes:
1. **Priya:** no role. Authorization.
2. **Lifecycle workflows:** tenant didn't own the SKU. Licensing.
3. **Sarah:** legitimate reviewer, denied the supporting evidence. Permission scope.

**Decision vs enforcement, made visible.** At 100% complete with every decision recorded,
`Apply result` was still **blank** `132`. Decision and enforcement are separate steps.
Stopping the instance drove `Applying` `136` and moved it to Review history as
**`Complete`** `135`. The instance's `Object Id` (`bbbf041e…`) differs from the series'
(`ea76e364…`), instance and series are distinct objects at the data layer, not two views
of one thing. Post-stop, the **Current nav group greys out** `134`, matching phase 2.

**Final finding, an Approve has nothing to enforce.** `Applied by: N/A`,
`Applied Date: N/A`, `Apply result` blank, still unchanged **4h20m later** at 3:00 PM `138`.
Phase 2 produced `Result applied` because a Deny actually removed Priya from a group; here
the reviewer affirmed existing access and the resource was never touched.

**Why that matters for audit:** evidencing "the review ran" by looking at Applied Date
makes an all-approve review look like it never happened. The proof the control operated is
the decision record, the reviewer attribution (`Sarah Mitchell on 8/3/2026`), and the
instance status, not the apply result. **A review that changes nothing is still a control.**

## Phase 3: ✅ COMPLETE (2026-08-03)


## Phase 4: Lifecycle Workflows 🟡 UNBLOCKED 2026-08-02

### The licensing wall (screenshots 78-94)

Phase 4 stopped before it started. **Lifecycle workflows returned a 401.**

**This is the single best teaching artifact in the lab so far:** it is the *same error
code Priya got*, for a completely unrelated reason. Hers was authorization, she held no
role. This one was **licensing**, the tenant didn't own the SKU. The error surface is
identical and tells you nothing about which. Anyone would burn an hour auditing role
assignments before thinking to check Billing.

**How it was actually diagnosed:**

- `Billing → Licenses → All products`, only **Microsoft Entra ID P2**, 25 licenses. `78`
- `License usage`, **`ID Governance: 0`**. That's the number that named the problem. `79`
- Lifecycle workflows → `You don't have access`, `Error code 401`. `80`

**The trap in the trials flow.** The Entra `Trials` blade advertises **Entra Suite, 25
licenses, 90 days free**, and Entra ID Governance at 30 days. `81` Clicking either
Activate lands on `signup.microsoft.com`, which says something different: **"One month
free with payment details,"** card required, **auto-converts to a 1-year paid
subscription**. `82` `83` The 90 days does not survive contact with checkout.

**Getting into the right tenant.** Entering `mukhtar@hids1.onmicrosoft.com` (the work
account, not either personal `@outlook.com` MSA) made the flow recognize an existing
tenant and redirect to the M365 admin center to complete the order. `84` `85` This is
what avoided repeating the 2026-07-08 failure, where the same checkout **spun up a brand
new tenant** instead of licensing the existing one and 12 users + 6 groups were lost.

**Plan selection.** The marketplace lists six SKUs. `86` `87` With P2 already owned, the
right pick is **`Entra ID Governance Add-on for Entra ID P2 (Trial)`**, same features as
the standalone trial, but converts at **$4.80** rather than **$8.40** per license/month.

**The buried default.** Checkout showed `Total due: $0.00` and *"To keep these services
active, renew your subscription before your trial expires"*, which reads like it lapses
harmlessly. `88` It does not. A secondary **Trial renewal settings** panel does the real
work, and it **defaults to a 1-year subscription** (Sep 2 2026 → Sep 2 2027). `89`
Changed to **1 month / pay monthly / quantity 1** → $4.80 on Sep 2, month-to-month. `90`

- Order confirmed; trial expires **September 1, 2026**. `91`
- Cancellation requires turning off recurring billing **at least 2 days before** the
  billing date → **real deadline Aug 31**. Calendar reminders set for Aug 7 (P2 converts
  Aug 9) and Aug 29 (kill Governance).
- After: `ID Governance: 25`, Entra home lists **Standalone products: Entra ID
  Governance**, and Lifecycle workflows loads. `92` `93` `94`
- **Before/after pair for the video: `79` → `93`.** Zero to 25, one number.

### Tenant defaults noted on arrival

- **`Workflow schedule: Every 3 hours`:** workflows do not fire on the attribute change.
  They fire on a tenant-wide 3-hour tick unless run on demand. Anything time-sensitive in
  a demo has to be run on demand or it looks broken.
- Schedule enabled: 0 · Deleted workflows: 0 · no alerts, clean slate.
- Banner: since Jan 15 2026 a **linked Azure subscription** is required for ID Governance
  features **on guest users**. Internal-only lab is unaffected, but it's the third time
  this lab has hit a "needs a linked subscription" boundary.

### Building the joiner workflow (2026-08-04, screenshots 139-182)

**Subject:** Robert Nguyen, Sales Manager, Sales dept, no phase 1-3 evidence attached to
him, so he's safe to use.

**Attribute prep.** `Employee hire date` and `Manager` were both empty `139`. Set hire date
to **Aug 10** and manager to **Sarah Mitchell** `140`.

**Finding, the leaver half can't be built in the portal.** The Job Information editor
states *"This view only contains properties that can be updated"* and lists 9 fields.
**`employeeLeaveDateTime` is not among them.** So scheduled joiner workflows are fully
portal-configurable but scheduled leaver workflows require Microsoft Graph. That is the
cleanest argument in this whole lab for why an IAM analyst needs scripting, and the
natural hook into a Graph/PowerShell lab 3. (Partial workaround: the **Real-time employee
termination** template carries an **On-demand** tag, so a leaver can be demoed against a
chosen user without the attribute.)

**Also noticed:** the **Sponsors** field is now live on the user record, it was greyed out
in phase 1 when sponsors-as-approvers needed the ID Governance license. Loose end for phase 5.

**Template gallery, 14 templates: 3 Joiner, 3 Mover, 7 Leaver, 1 extensibility preview**
`142` `143` `144`. **Microsoft ships more than twice as many offboarding templates as
onboarding ones.** That's not an accident, it's where the risk and the audit findings are.
Same lesson as Verizon: provisioning happens because someone is waiting on it;
deprovisioning only happens if a process forces it.

**Trigger model** (`146`) is exactly three options: *Time based attribute* (a date field,
predictable lifecycle events), *Attribute changes* (mover scenarios, department or title
changes and access follows), *Group membership changes* (access-driven rather than
HR-driven).

#### Wrong turn #1: the trigger date had already passed

Template default: **7 days before `employeeHireDate`** `145`. Robert's hire date is Aug 10,
so 7 days before is **Aug 3, yesterday**. A scheduled run would never have fired for him.
Changed to **5 days**, putting the trigger at Aug 5. Caught before creation, not after.

#### Wrong turn #2: the template ships scoped to a department that doesn't exist here

**Default scope rule: `department equal Marketing`** `148`. Robert is in **Sales**. Accept
the default and you get a workflow that looks fully configured, reports no errors, and
**silently never runs**. Same species as the PIM defaults but sneakier, there's no security
warning attached, so nothing prompts you to look. Changed to `Sales` `151`.

**Scope mechanics worth knowing:** operators are limited to four, `equal`, `notEqual`,
`in`, `startsWith` `150`. No contains, no wildcards, no date comparison. And **scope and
trigger are two independent filters that must both pass**, scope says *who is eligible*,
trigger says *when*. Robert was the only user with a hire date set, so he was the only
possible match regardless of how many people are in Sales.

**Rule syntax** `152`: `(department eq 'Sales')`, OData filter syntax, labeled internally
as a **State evaluation rule**. Worth contrasting with lab 1's dynamic groups, which use
Entra's *dynamic membership* syntax (`user.department -eq "Sales"`). **Same logical filter,
two different rule languages inside the same product, not interchangeable.**

#### Task 1: Generate TAP and Send Email

TAP = **Temporary Access Pass**, a time-limited passcode letting a brand-new employee
register their first authentication method with no password. It solves the bootstrap
problem: how does someone with no credential prove who they are in order to set up MFA?
It's sent to the **manager**, because a pre-hire has no mailbox yet, which is why setting
Sarah as Robert's manager mattered.

**Two more unsafe defaults closed** `154` → `155`:
- `One-time use: No` → **Yes**. A multi-use TAP is redeemable repeatedly for its whole
  window, so a forwarded or compromised manager mailbox keeps working. The trade-off is
  real and worth naming: one-time-use means a fumbled registration burns the pass and
  someone reissues it. Security teams accept that cost; helpdesks resent it.
- `Activation duration: 1 hour` → **8 hours**. Note the panel text: *"The user's employee
  hire date used as the start time"*, the pass is valid from the hire date, not from when
  the workflow ran 5 days early. Good design, but one hour is tight for a first day.

#### Wrong turn #3: dynamic groups blocked, for the third time in this lab

Added **Add user to groups** as task 2 `156` `157`, and the group picker greyed out all six
lab 1 groups with the reason stated inline: **"Dynamic groups are not allowed."** `158`
Only `Finance Reporting App Access`, the Assigned group created in phase 1 for exactly this
reason, was selectable.

**This is the third time the same constraint has bitten, and the first time Microsoft
explains it inline.** Phase 1 just greyed things out silently.

Resolution took about two minutes: created **`New Hire Baseline Access`**, Security,
**Assigned**, roles-assignable No, **no members**, owner **Mukhtar Houry** `159` `160`.
Deliberately did *not* reuse `Finance Reporting App Access`, because that group holds
exactly one member (Priya) as phase 2 evidence and dropping a Sales user into it would
corrupt a captured artifact.

**Setting an owner closes half an open question** carried since phase 1, `manager` and
group `owner` were both unpopulated tenant-wide. An ownerless group is a real governance
finding: nobody is accountable for it and nobody gets asked at review time whether it should
still exist. **Members left empty on purpose**, pre-adding Robert would make the workflow's
group-add a no-op and destroy the proof that it did anything.

Renamed the task **Grant New Hire Baseline Access** with a real description `163`, the
default "Add user to groups" gives no indication *which* group in execution history.

#### Wrong turn #4: the workflow would have been created inert

**`Enable schedule` is unchecked by default** on the Review + create step `166`. Create it
as-is and you get a workflow that looks complete and never fires, which is why the earlier
Overview read `Schedule enabled: 0`. Checked it, plus **Run What if after creation** `167`.

**What-if returned no users in scope** `168` and **Simulate Workflow Execution was greyed
out**. Most likely because What-if evaluates the trigger as well as the scope, and Robert
isn't due until Aug 5, but that wasn't confirmed, so it stays a hypothesis. **The trap
worth logging: a What-if returning zero users does not necessarily mean the scope rule is
broken. It can mean nobody is due today.** Plenty of people would go rewrite a perfectly
good rule chasing that.

Workflow created 3:13 PM, `Schedule: Yes`, `Enabled: Yes` `171`.

#### The on-demand run: failed, and the failure was worth more than a success

Run on demand **bypasses the schedule and execution conditions** `174`, which is how a
workflow triggered for Aug 5 can be tested on Aug 4.

Result: **`Status: Failed`**, 1 user processed, 0 successful, **1 of 2 tasks failed** `177`.

**Reporting inconsistency worth flagging:** the **Tasks** tab showed both tasks
`In progress` with every counter at zero `178` while the **Users** tab already showed
`Failed`. The three tabs update on different schedules, so an operator checking the wrong
one gets a wrong answer about whether onboarding succeeded.

Drilling into each task gave the real diagnosis:

- **`Generate TAP and Send Email` → Failed:** *"the mail attribute was missing for all of
  the provided email recipients"* `180`. Sarah has no `mail` value because no lab user holds
  a license or mailbox. The pass itself likely generated; **delivery** is what died.
- **`Grant New Hire Baseline Access` → Canceled** `179`. Not failed, *canceled*. That's
  `Continue workflow execution on error` being unchecked on task 1, working exactly as
  designed. Fail-fast halted the run before the group add.

**The design question this surfaces, should a notification failure block access
provisioning?** Arguably not. A new hire's group membership is independent of whether their
manager received an email. As shipped, a mail problem silently prevents onboarding access
for every new hire, and the run just reports "failed" without making clear which half broke.

**Resolution.** Two changes: set Sarah's `mail` attribute, **it turned out to be editable
in the portal** `181` `182`, contrary to the expectation that `mail` is Exchange-owned, and
checked **Continue workflow execution on error** on task 1. Used a real external address so
the TAP email could actually be received and captured rather than sent into a mailbox that
doesn't exist; noted as a lab accommodation, since in production the manager's real mailbox
is the recipient.

#### Resolution verified: the same user, both outcomes, in one screenshot

Re-ran on demand at 4:00 PM. **`Completed`, 0 of 2 tasks failed** `183`. Workflow history
now shows both runs side by side: **3:45 PM Failed, 4:00 PM Completed.** One frame,
before and after.

**The TAP email actually arrived** `184`, and it validates three separate hardening changes
at once:

- **Sender is `lifecycleworkflows-noreply@hids1.onmicrosoft.com`:** not `@microsoft.com`,
  the custom email domain set in Workflow settings took effect.
- **The Houry Identity Solutions logo renders in the email body:** lab 1's tenant branding
  carried into a lab 2 workflow notification. Two labs visibly connected.
- **The 8-hour TAP window is stated in the body**: valid `10 August 07:00 UTC`, expires
  `10 August 15:00 UTC`, anchored to Robert's hire date, not to the run time.

**Security finding, the TAP is delivered in plaintext.** The pass (an 8-character string,
redacted here and in the screenshot) sits in the
email body, with instructions to forward it to the new hire. A credential, however
temporary, transmitted in cleartext to a mailbox. If the manager's mailbox is compromised
or the mail is forwarded to the wrong person, an attacker bootstraps that identity and
registers **their own** MFA method on it, full account takeover before the employee's
first day. **The one-time-use setting enabled earlier is the mitigation that matters**: a
stolen pass is burned on first redemption, so the theft becomes detectable rather than silent.

**And read the footer:** *"Microsoft Corporation facilitated sending this email but did not
validate the sender or the message."* An email containing a credential, from a noreply
address, carrying a disclaimer that nobody verified it, **structurally indistinguishable
from a phishing email**, and new hires are trained to trust it on day one. Kite callout.

**Group membership confirmed** `185`: `1 group member found`, Robert Nguyen, Object Id
`0a05ef8d-7bec-47a4-8b0d-6bf4f6748678`, **matching the User ID in the workflow history
exactly**. Complete evidence chain: empty group created 2:56 PM → workflow run 4:00 PM →
membership verified 4:04 PM, with matching object IDs tying execution record to resulting
state. Nobody touched that group by hand.

**Joiner workflow: ✅ COMPLETE AND VERIFIED.**

## Phase 4b: The leaver workflow (screenshots 186-194)

Subject: **Robert again**, deliberate choice. The joiner evidence is already captured in
`183`-`185`, and "the same employee's full lifecycle in ninety minutes" is a far stronger
narrative than two unrelated demos. The point of lifecycle workflows *is* the lifecycle.

**Structural differences from the joiner** `186`:
- **`Trigger type: On-demand`, locked and greyed.** No date attribute, no days-from-event.
  Correct for termination, you don't schedule it five days out, you execute at the moment
  it happens.
- **The wizard replaces *Configure scope* with *Select users*.** On-demand workflows drop
  rule-based scoping entirely in favor of explicit selection, because a termination targets
  a named individual, not a population.

### The biggest finding in phase 4: the termination template deletes the account

Default tasks shipped by **Real-time employee termination** `187`:

1. Remove user from all groups
2. Remove user from all Teams
3. **Delete User Account**

**Microsoft's real-time termination template deletes the account outright, and never
disables it or revokes its sessions first.** That is backwards, for three reasons:

- **Deleting destroys evidence.** In a termination for cause, data theft, policy violation,
  anything under investigation, the account *is* the evidence: sign-in logs, mailbox, group
  history. HR and Legal routinely need it preserved, and a 30-day recycle bin is not a legal
  hold.
- **Disabling alone does not end active sessions.** A disabled account can keep working
  through an existing refresh token until it expires. Revoking tokens is what actually ejects
  someone *right now*, which is the entire premise of "real-time" termination.
- **Deletion is irreversible after 30 days, and terminations get reversed.** Wrong person,
  wrong name, HR error, rehire.

**Compounding default:** the Select users step defaults to **"Select users now and run
workflow after you create it"** `188`, so the out-of-box path is create *and immediately
execute*, with account deletion as task 3. **One click from a wizard to a deleted user.**
Switched to *create the workflow and select users later* so the destructive run is a
separate, deliberate action rather than a side effect of finishing a wizard.

### The fix

Removed **Delete User Account** `189` `190`. Opened the task catalog `191` `192` and found
**`Revoke all refresh tokens for user`**, *"Revoke all refresh and browser session tokens
for user"*, **available in the catalog but deliberately absent from the termination
template**, while account deletion was included. Given that refresh tokens are what let a
signed-in session keep renewing itself, that is the single most important task in a
real-time termination, and it has to be added by hand.

Added three tasks `193`: **Disable User Account**, **Revoke all refresh tokens for user**,
**Remove all licenses for user** (license reclamation is both an access control and a cost
control, and it is the step that gets forgotten for months).

**Final task order** `194`:

1. **Disable User Account:** stop new authentication
2. **Revoke all refresh tokens:** invalidate anything already authenticated
3. **Remove user from all groups:** strip access
4. **Remove user from all Teams**
5. **Remove all licenses for user:** reclaim cost

**The sequencing logic, stated for the video script:** kill the ability to authenticate
first, then invalidate what is already authenticated, then remove what they could reach,
then reclaim spend. Running the template's original order means stripping group memberships
from someone who can still sign in, cleanup performed on a live session. **And no deletion
at any point**: the identity is preserved for investigation, legal hold, and rehire, and
deletion becomes a separate decision made later on purpose.

### Adding the offboarding notification (screenshot 201)

Added **Send email on user's last day** as task 6, deliberately **last**, the notification
should tell the manager what was done, not fire before the work happens. Recipient is the
**manager**, not the departing employee, so it resolves to Sarah, whose `mail` now points at
a real inbox.

### The offboarding run: and the finding it exposed

Before state captured `198` `199`: **Account status `Enabled`**, **`Group memberships: 2`**,
and the Groups blade shows the two side by side with the **Membership Type** column visible:

| Group | Membership type |
|---|---|
| `New Hire Baseline Access` | **Assigned** |
| `Sales` | **Dynamic** |

Run started 4:41 PM `202`. Result: **`Completed`, 6 tasks, 0 failed** `203`.

After state `204`: **Account status `Disabled`** ✅ and **`Group memberships: 1`**.

#### The best security finding in phase 4: a "successful" offboarding that left access behind

**`Remove user from all groups` cannot remove dynamic group memberships.** `205` confirms
the survivor is **`Sales`, Membership type: Dynamic**. The assigned group was removed; the
dynamic one was not, because dynamic membership is *computed from attributes* and no
process can manually remove a member. Robert's `department` still reads Sales, so Entra
keeps putting him back.

**The workflow reported 6 tasks, 0 failed, a clean, fully successful offboarding, while
leaving the user in a group.** Nothing in the execution record flags it. An operator
closing the ticket on that result would be wrong, and an auditor sampling the run history
would see nothing.

**Why it matters beyond the lab:** the account is disabled, so the residual entitlement is
dormant rather than live, but it is *intact*. Re-enable the account for any reason (rehire,
error correction, a contractor returning) and the access comes straight back without anyone
re-approving it. In a tenant where dynamic groups grant licenses, application access, or
Conditional Access exclusions, that is standing entitlement surviving a termination.

**The actual fix is to change what drives membership, not the membership itself**, which is
precisely why **`Update user attributes`** exists in the leaver task catalog `192`. A correct
offboarding workflow clears or rewrites `department` (and any other attribute feeding a
dynamic rule) so the user falls out of the group by evaluation. Removing the membership is
treating the symptom.

**This is the fourth appearance of the dynamic-group constraint in this lab**, it blocked an
access package in phase 1, blocked the group picker in phase 4a, was the reason
`New Hire Baseline Access` had to be created at all, and now silently defeats offboarding.
One architectural property, four different failure modes, only one of which Microsoft
explains inline.

#### And the email that reported success but never arrived

**Task 6 reported success. No email was delivered.** Most likely because
**`employeeLeaveDateTime` is unset**, the attribute the portal does not expose (see the
phase 4a finding), so *"Send email on user's **last day**"* has no last day to reference.
The task ran, so it is recorded green; there was simply nothing to send.

That is the sharpest version of the Graph limitation: it doesn't only block *scheduled*
leaver workflows, it silently hollows out an *on-demand* task while reporting success.
**Two of the six tasks in this run did not achieve their intent, and the execution record
shows 0 failures.**

### Remaining in phase 4

- Confirm whether the joiner's scheduled run fires unattended on Aug 5
- Optional: add `Update user attributes` to the leaver and re-run to show the dynamic group
  actually dropping, the "correct" version of the workflow

## Phase 4: ✅ COMPLETE (2026-08-04)

Both workflows built, hardened, run, and verified. Robert Nguyen was onboarded at 4:00 PM
and offboarded at 4:41 PM, **a full employee lifecycle in forty-one minutes**, with the
evidence chain captured at every step.

## Phase 5: Case study write-up + video ⬜
