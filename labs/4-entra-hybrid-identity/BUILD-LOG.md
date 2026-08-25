# Build Log — Lab 4: Hybrid Identity with Entra Connect Sync

Running friction log. Every mistake, dead end, surprising default, greyed-out
control, and licensing wall gets recorded here as it happens, with what was
expected versus what actually happened.

---

## Environment constraint (recorded before any build work)

**Expected:** install Entra Connect Sync locally and sync a local Active
Directory domain.

**What happened:** Entra Connect Sync is a Windows-only application and must run
on a Windows Server that can reach an Active Directory Domain Services domain.
The build machine is an Apple Silicon Mac. Microsoft does not publish a Windows
Server ARM64 ISO for general download, so a local virtual machine is not a
viable path. Windows 11 ARM runs fine under virtualization but a client edition
cannot be promoted to a domain controller.

**Resolution:** stand up a Windows Server virtual machine in Azure to act as the
on-premises domain controller. This is disclosed in the case study rather than
presented as a physical on-premises environment.

---

## Phase log

<!-- entries appended as the build proceeds -->

### Phase 1 — Windows Server 2022 is no longer in the marketplace shortlist

**Expected:** select Windows Server 2022 Datacenter as planned.

**What happened:** the Create a virtual machine image dropdown offers only 2025
builds in its "Marketplace images to get started" shortlist: Datacenter Azure
Edition, Datacenter, Datacenter Server Core, plus Windows 11 Pro. 2022 is still
reachable through "See all images" but is no longer a default suggestion.

**Decision:** use **Windows Server 2025 Datacenter - x64 Gen2**. Entra Connect
Sync supports Server 2016 and later, so 2025 is valid, and building on the
current server release is the more defensible choice for a portfolio piece than
deliberately reaching back for an older one.

**Rejected alternatives:** *Azure Edition* pairs hotpatching with an Azure-tuned
image and is a nonstandard base for a domain controller. *Server Core* has no
desktop, and the Entra Connect Sync configuration wizard needs a GUI.

### Phase 1 — the Windows license roughly doubles the compute bill

**Expected:** a 2 vcpu / 8 GiB virtual machine at about $70/month, the figure the
portal showed while the image field still held the default Ubuntu selection.

**What happened:** after switching the image to Windows Server 2025 Datacenter,
the identical Standard_D2s_v3 size re-priced from **$70.08/month to
$137.24/month**. The size did not change. The $67.16 difference is the Windows
Server license, billed per vcpu on top of compute.

**Why it matters:** the size dropdown is the only place this cost appears, and it
only appears *after* the image is chosen. Anyone sizing a Windows workload off
the Linux price is off by roughly half.

**Knock-on decision:** this also killed the plan to save money with a burstable
B-series size. B2ms is about $9/month cheaper than D2s_v3 on compute, but the
license is identical on both, so at lab usage the saving is around twenty cents
across the whole build. Burst-credit throttling on a domain controller also
running SQL Server Express is a worse trade than twenty cents. Stayed on
**Standard_D2s_v3**.

### Phase 1 — disk choice, and the two identically named options

**Decision:** OS disk set to **Standard SSD, Locally Redundant Storage**, 127 GiB
image default, Delete-with-VM enabled, platform-managed key, no data disks.

**Friction:** the OS disk type dropdown lists **Standard SSD twice**, once under
Locally Redundant Storage and again under Zone-Redundant Storage, with no price
shown against either. Picking the wrong one costs roughly 50% more for zone
resiliency a lab does not need.

**Cost reasoning:** the disk bills continuously whether the virtual machine is
running or deallocated, unlike compute and the Windows license which stop on
deallocation. That makes disk type the highest-leverage cost decision in the
wizard. Premium SSD 127 GiB is about $19.71/month against roughly $9.60 for
Standard SSD. Standard HDD is cheaper still but puts spinning-disk latency under
a domain controller that will also run the SQL Server Express instance Entra
Connect Sync installs.

**Azure's counter-recommendation, declined:** the portal warns that Premium SSD
is advised for high IOPS and that only Premium-backed virtual machines qualify
for the 99.9% single-instance connectivity SLA. Neither applies to a lab that can
be rebuilt on demand.

### Phase 1 — Azure's delete-with-VM defaults are inconsistent

**Observed:** on the Disks tab, "Delete with VM" is checked by default for the OS
disk. On the Networking tab, "Delete public IP and NIC when VM is deleted" is
**unchecked** by default.

**Consequence if left alone:** deleting the virtual machine later would destroy
the disk but strand the public IP address and network interface in the
subscription, still billing at roughly $3.65/month for the IP with nothing
attached to it. Orphaned public IPs and disks are among the most common causes of
unexplained Azure spend.

**Action:** checked the box so all three resources share the machine's lifecycle.

**Transferable point for the write-up:** a resource that bills continuously and
is not deleted with its parent is a governance problem, not just a cost problem.
The same reasoning applies to identity, where an entitlement that outlives the
account it was granted for is exactly the failure Lab 3 was built to detect.

### Phase 1 — Entra ID login is the one identity feature deliberately left off

**Setting:** Management tab, "Login with Microsoft Entra ID", left **unchecked**.

**Why it is worth calling out:** on an ordinary Azure server this is a good
control. It replaces local account sign-in with Entra ID accounts, which brings
Conditional Access and multifactor authentication to the machine login itself.
On a domain controller it is unsupported, and the extension it installs conflicts
with promotion to a domain controller.

**The point:** the server that becomes the authority for on-premises identity is
the one server that does not get handed over to cloud identity. Directly relevant
to the sign-in method decision coming in Phase 4, where the same question is
asked at the tenant level instead of the machine level.

### Phase 1 — auto-shutdown configured as the cost backstop

Enabled auto-shutdown at 11:00 PM Pacific with email notification 30 minutes
before. Deliberately late so it cannot terminate an active build session. This
is a backstop for forgotten deallocations, not a replacement for stopping the
machine at the end of each session, since a running virtual machine bills compute
plus the Windows Server license continuously.

### Phase 1 — wizard state is not preserved across a sign-out

**What happened:** the Create-VM wizard was left open overnight with every tab
configured but not yet submitted. The Azure session expired, and on return the
wizard had reset to factory defaults with nothing retained.

**Worse than a plain reset:** the defaults it came back with were *different* from
the ones seen the day before. Region defaulted to East US instead of West US 2,
Availability options defaulted to Availability zone with Zone 1 selected rather
than no redundancy, and Security type defaulted to Trusted launch rather than
Standard. Re-running from muscle memory would have produced a differently
configured machine.

**Takeaway:** nothing in the wizard exists until Create is clicked, and portal
defaults are not stable enough to rely on. The full intended configuration was
re-issued as an explicit checklist rather than reconstructed from memory.

**Confirmation of the licensing finding:** on the rebuild, the Estimated monthly
costs panel itemized the split directly. Image (Windows Server 2025 Datacenter)
$67.16, Size (Standard_D2s_v3) $70.08, total $137.24. The Windows license is just
under half the monthly cost of the virtual machine.

### Phase 1 — tabs that looked skippable, and the one that was not

**Monitoring:** boot diagnostics left on with a managed storage account. Chosen
deliberately rather than skipped: promoting this server to a domain controller
forces a reboot, and if the machine fails to come back, the boot screenshot is
the only diagnostic available on a host that can no longer be reached over the
network. Correction to an earlier note in this log: it is not free. Azure charges
a nominal amount on storage reads and writes, which for a screenshot and a serial
log is pennies per month, but it is not zero.

**Advanced:** skipped entirely. The custom data field could have installed Active
Directory automatically at first boot, which is how this is done at scale and
exactly the wrong choice for a lab whose purpose is understanding each promotion
step.

**Tags:** applied `project=lab4-hybrid-identity` and `environment=lab` to all
resources. This is the mechanism Azure cost reporting groups by, so the lab's
spend can later be isolated from anything else in the subscription instead of
being reconstructed by hand.

### Phase 1 — review page ambiguity, resolved by watching the deployment

The Review + create summary listed **NIC Network security group** as a dash,
which read as though no security group would be created despite Basic having been
selected on the Networking tab. Rather than assume, this was left as an open
question and checked against the live deployment, where `dc1-nsg` appeared with
type Network security group and status Created. The dash was a display artifact
for a resource that did not exist yet, not a missing control.

**Confirmed price at creation:** 0.1880 USD/hr for Standard_D2s_v3 with the
Windows Server license included.

## Phase 1 complete — deployment and immediate hardening

`dc1` deployed successfully into `rg-hybrid-identity-lab`. Resources created:
virtual network, subnet, public IP `dc1-ip`, network security group `dc1-nsg`,
network interface, OS disk, boot diagnostics storage account, auto-shutdown
schedule.

### Closing the RDP exposure the wizard opened

The virtual machine was created with its RDP rule (priority 300, TCP 3389) set to
Source `Any`, meaning reachable from every address on the internet. Azure marked
the rule with a warning icon in the inbound rules list.

Scoped Source to a single `/32` covering only the workstation's public address.
The warning icon cleared on save, and the rule now sits above the default
`DenyAllInBound` at priority 65500, which catches every other source.

**Deliberate sequencing:** the machine was created with the port open rather than
with inbound ports set to None, then closed immediately afterward. This produced
a documented before-and-after on a real control instead of a configuration that
was simply never wrong.

**Known operational caveat:** the source address is a residential one and will
change when the internet provider reassigns it. A future failure to connect over
RDP with no other change points at this rule first.

### Private IP pinned to Static

Active Directory Domain Services requires a domain controller to hold a fixed
address, since every domain-joined machine locates it by that address. In Azure
the correct place to enforce this is the network interface's IP configuration,
not the operating system. Setting a fixed address inside Windows makes the guest
disagree with the Azure fabric and typically ends in a machine that can no longer
be reached. Windows stays on DHCP; Azure is configured to hand it the same
address every time.

Done before the first remote session so any connectivity blip had nothing to
interrupt.

## Phase 2 — Active Directory Domain Services

### Blocked before the first checkbox: pending restart

Opening Add Roles and Features and reaching Select server roles surfaced a
warning banner: *"The destination server has a pending restart. We recommend that
you restart the destination server before either installing or removing roles."*

The machine had been running roughly two hours with no manual restart. The
pending reboot is left over from first-boot servicing plus the VMAccess extension
that reset the local administrator password earlier in the session.

**Decision: cancel the wizard and restart before installing anything.** Installing
Active Directory Domain Services on a server with a queued reboot is a documented
source of failures that surface later during promotion, where the error text
points at the directory rather than at the real cause. A two minute restart is
cheaper than debugging a half-finished forest.

### Phase 2 — one checkbox, six components

Checking Active Directory Domain Services on the Select server roles page
triggered a dependency prompt and expanded to six installed components:
the AD DS role itself, Group Policy Management, and four management pieces under
Remote Server Administration Tools (AD DS Snap-Ins and Command-Line Tools, the
Active Directory Administrative Center, and the Active Directory module for
Windows PowerShell).

**DNS Server deliberately not selected.** A domain controller requires DNS, and
the instinct is to check it here. The promotion step installs and configures DNS
itself, wired to the new domain. Installing it first means configuring it by hand
and is a common route to a domain controller pointing at the wrong resolver.

**"Restart the destination server automatically if required" left unchecked.**
Installing the role does not require a reboot; promotion does. Leaving the
wizard unable to reboot on its own keeps that timing under operator control
rather than dropping a remote session without warning.

**Continuity note for the write-up:** the Active Directory module for Windows
PowerShell installed here is the on-premises counterpart to the Microsoft Graph
PowerShell SDK used in Lab 3. Same pattern, two directories.

### Phase 2 — installation succeeded, and the machine is still not a domain controller

The results pane reported *"Configuration required. Installation succeeded on
dc1"* and, under Active Directory Domain Services, *"Additional steps are
required to make this machine a domain controller."* `AD DS` appeared in the
Server Manager navigation and the role count moved from 1 to 2.

This is the install-versus-promote distinction stated by the product itself. The
binaries and management tools are present. There is no forest, no directory
database, and nothing authenticates against the machine. Promotion is a separate
operation.

### Phase 2 — time zone deliberately left on UTC

The guest clock reads UTC and was left there. **Set time automatically** is on and
had synced successfully, which is the setting that actually matters: Kerberos
rejects tickets when two machines' clocks differ by more than five minutes by
default, so a domain controller with a drifting clock stops authenticating.

The time *zone* is only a display preference and would not have broken Kerberos
either way. It stays on UTC so that Windows Event Viewer entries on this machine
can be compared against Entra ID sync results without converting between zones
first. This is the same lesson as Lab 3, finding 10: a timestamp without a stated
timezone is not evidence.

### Phase 2 — domain name chosen to reproduce the common real-world failure

**Chosen: `hids.local`, NetBIOS `HIDS`.**

This is deliberately contrary to current Microsoft guidance. A `.local` namespace
is not publicly routable, cannot be registered or verified by anyone, and
collides with the mDNS protocol used by Bonjour.

**Why it was chosen anyway:** a large share of enterprises still run on `.local`
forests built years ago, because renaming a forest is disruptive enough that most
organizations never do it. That single fact produces the most common problem in
hybrid identity. On-premises users carry sign-in names ending in `@hids.local`,
and a cloud tenant will only accept sign-in names on a domain it has verified. It
can never verify `.local`. Synchronizing without addressing this leaves every user
in the cloud with a sign-in name that does not work.

Building the problem deliberately, then documenting the alternative UPN suffix
that resolves it, demonstrates more than picking a clean name and never meeting
the issue. The choice is recorded here so it reads as intent rather than as an
error.

### Phase 2 — the `.local` choice produces its first symptom immediately

The DNS Options page of the promotion wizard raised: *"A delegation for this DNS
server cannot be created because the authoritative parent zone cannot be found."*
The **Create DNS delegation** checkbox was unavailable.

A DNS delegation is a parent zone pointing down at a child, the way `.com` points
at a registered second-level domain. `.local` has no authoritative parent
anywhere, because it is not a real top-level domain and cannot be registered by
anyone. There is nothing to delegate from, so the wizard correctly refuses.

Harmless in an isolated forest, and worth recording as the first visible
consequence of the naming decision rather than as an error.

### Phase 2 — promotion settings

- Deployment operation: **Add a new forest**
- Root domain: `hids.local`
- Forest functional level: Windows Server 2025
- Domain functional level: Windows Server 2025
- DNS server: enabled (installed by promotion, not preinstalled)
- Global Catalog: enabled, greyed — mandatory on the first domain controller
- Read-only domain controller: unavailable — an RODC cannot be the first domain
  controller in a forest, since there is no writable partner to replicate from
- DSRM password set and stored

**On DSRM:** the Directory Services Restore Mode password is a local credential,
unrelated to `azureadmin` and to any domain account. Its only purpose is booting
the machine with Active Directory offline to repair a corrupt directory. It is
needed precisely when domain authentication is unavailable, which is why an
unrecorded DSRM password is discovered as a problem at the worst possible moment.

### Phase 2 — the wizard writes its own automation, and almost nobody notices

The Review Options page carries a **View script** button that exports the entire
promotion as PowerShell with every parameter already populated. Ten screens of
clicking reduce to one `Install-ADDSForest` call.

Captured and turned into `scripts/2-promote-dc.ps1`, parameterized on domain and
NetBIOS name. Because it came from the wizard's own export rather than from
documentation, the scripted path is guaranteed to match what the GUI would have
done.

**One deliberate deviation from the export:** the exported script contains no
`-SafeModeAdministratorPassword`, so running it verbatim prompts interactively.
The saved version collects it with `Read-Host -AsSecureString` rather than
accepting a literal, so a DSRM password can never be committed to a repository.

### Phase 2 — prerequisites check: two warnings, both predicted, both correct to ignore

All checks passed. Two warnings raised.

**1. Static IP.** *"This computer has at least one physical network adapter that
does not have static IP address(es) assigned to its IP Properties."*

Correct about what it observes and wrong about the consequence. Windows sees a
DHCP-configured adapter because Azure delivers addresses by DHCP and that cannot
be disabled. The address is pinned at the Azure network interface instead, so it
never changes. Assigning a literal address inside the guest is the documented way
to make the guest disagree with the fabric and lose network connectivity on a
machine reachable only over the network.

This warning was anticipated before the wizard was ever opened, which is why the
Phase 1 static assignment was done at the correct layer.

**2. DNS delegation.** The `.local` parent-zone warning, repeated from the DNS
Options page.

**Also noted:** *"If you click Install, the server automatically reboots at the
end of the promotion operation."*

### Phase 2 — the sign-in identity changes at promotion

After promotion the machine has no local account database. It is a domain
controller, and the local administrator account created at VM provisioning
becomes a **domain** account.

Reconnecting over RDP therefore requires `HIDS\azureadmin` rather than
`azureadmin`. The password is unchanged. A bare username fails with an error that
does not explain the cause.

Worth a checkpoint in any student-facing version: this is a guaranteed
stopping point, and the failure gives no hint about the fix.

## Phase 2 complete — forest built and verified

Promotion succeeded and the server rebooted into its new role. Verified from an
elevated PowerShell session rather than by trusting the wizard's success message:

```
Get-ADDomain   -> DNSRoot hids.local | NetBIOSName HIDS
                  DomainMode Windows2025Domain
                  DistinguishedName DC=hids,DC=local
Get-ADForest   -> Name hids.local | ForestMode Windows2025Forest
                  GlobalCatalogs {dc1.hids.local}
Get-Service    -> ADWS Running | DNS Running | NTDS Running
```

**DNS appeared without being installed by hand.** Server Manager went from two
roles to three and DNS joined the navigation on its own, confirming the decision
not to check DNS Server on the roles page. `Install-ADDSForest -InstallDns:$true`
handled it and wired it to the new domain.

**Why verify in PowerShell rather than accept the wizard's word.** The wizard
reports on its own operation. `Get-ADDomain` asks the directory to describe
itself, and it can only answer if the directory exists, the database mounted, and
Active Directory Web Services is running to serve the query. Three independent
facts, one command. This is the same discipline as Lab 3, where a task reported
six of six steps complete while the underlying state was wrong.

**Checkpoint for the student version:** these three commands are the pass/fail
gate for this phase. A student who cannot produce this output should not proceed,
and the output itself tells them which piece is missing.

### Phase 2 aftermath — the auto-shutdown control was tested for real, and it held

The virtual machine was left running at the end of the session. At 10:30 PM Pacific
Azure emailed a 30-minute warning offering **Postpone 1 hour**, **Postpone 2
hours**, or **Skip this instance**. No action was taken, and the machine shut
down on schedule at 11:00 PM.

Verified afterward from the command line rather than trusting the notification:

```
az vm get-instance-view -g rg-hybrid-identity-lab -n dc1 \
  --query "instanceView.statuses[?starts_with(code,'PowerState')].displayStatus" -o tsv
-> VM deallocated
```

**"Deallocated" is the word that matters.** A machine reported as *Stopped* has
released nothing and still bills full compute plus the Windows Server license.
*Stopped (deallocated)* has released the underlying hardware and bills only for
storage. The distinction is not made obvious in the portal, and it is the single
most common reason people are surprised by an Azure bill for a machine they
believe is off.

Roughly 12.5 hours of runtime, about $2.35 in compute.

**Design point worth carrying into the student version of this lab:** the control
was configured in Phase 1 before it was ever needed, and it worked without the
operator being awake. A cost guardrail that depends on remembering is not a
guardrail. This one is mandatory in the student guide, not optional.

### Tooling — Azure CLI installed

`brew install azure-cli` (2.89.1), authenticated against the
`hids1.onmicrosoft.com` tenant. Enables state verification, start/stop from the
command line, and a scripted rebuild path for the Arden Industries port.

Resource group inventory at end of Phase 2, seven resources:
`dc1`, `dc1_OsDisk_*`, `dc1416` (NIC), `dc1-ip`, `dc1-nsg`, `vnet-westus2-1`,
`shutdown-computevm-dc1`.

## Phase 3 — alternative UPN suffix and directory seeding

### The problem, restated

Every account in `hids.local` receives a user principal name ending in
`@hids.local`. Microsoft Entra ID only accepts sign-in names on a domain the
tenant has **verified**, and verification requires publishing a DNS record on
that domain. `.local` is not a real top-level domain, cannot be registered, and
has no DNS to publish to, so it can never be verified.

Synchronizing without addressing this does not fail loudly. Entra ID replaces the
unverifiable suffix with the tenant's default routing domain, and every user
arrives in the cloud with a sign-in name nobody was told to use.

**Fix:** an alternative UPN suffix. Active Directory Domains and Trusts,
right-click the top-level *forest* node (not the domain beneath it), Properties,
UPN Suffixes, add `hids1.onmicrosoft.com`. The forest keeps its `hids.local`
identity; the humans get sign-in names the cloud will accept.

Microsoft's own wording in that dialog frames it as convenience: *"Adding
alternative domain names provides additional logon security and simplifies user
logon names."* In hybrid identity it is not convenience, it is a prerequisite.

### Containers are not organizational units

Expanding `hids.local` shows Builtin, Computers, ForeignSecurityPrincipals,
Managed Service Accounts and Users, all typed **Container**. Only *Domain
Controllers* is typed **Organizational Unit**.

Group Policy cannot be linked to a container. Microsoft made exactly one default
location a real organizational unit, the one holding domain controllers, because
that one needs policy applied to it. This is the concrete reason every real
environment builds its own OU structure instead of leaving accounts where Windows
puts them.

### Structure built

```
OU=HIDS
├── OU=Employees          12 users, UPN on hids1.onmicrosoft.com
├── OU=Service Accounts    2 users, UPN deliberately left on hids.local
└── OU=Disabled Users      empty, reserved for the Phase 6 off-boarding test
```

Every account carries both `employeeID` and `mail`, populated at creation. A
blank `mail` hard-failed a Lifecycle Workflow task in Lab 2; it is not an
attribute to backfill later.

The Service Accounts container exists to be **excluded** from synchronization in
Phase 4. A filtering lesson with nothing deliberately out of scope is a checkbox,
not a control.

Verified split: 12 accounts on `hids1.onmicrosoft.com`, 2 on `hids.local`.

### FINDING — Azure Contributor is Domain Admin, demonstrated rather than asserted

RDP clipboard redirection did not carry the seeding script into the guest. Rather
than chase the setting, the script was delivered with:

```
az vm run-command invoke -g rg-hybrid-identity-lab -n dc1 \
  --command-id RunPowerShellScript --scripts @scripts/3-seed-directory.ps1
```

**Twelve user accounts were created in the domain from a macOS laptop with no
domain credentials, no RDP session, no Windows password, and a non-functioning
clipboard.** The only privilege held was Contributor on the Azure resource. The
platform passed the script to the in-guest agent, which executed it as
`NT AUTHORITY\SYSTEM` on a domain controller.

**Why this matters beyond convenience.** The earlier password-reset observation
(Phase 1) established this as a claim. This is the proof. Directory permissions
never entered the path: the code did not authenticate to Active Directory, it ran
underneath it. No Active Directory ACL, no PIM assignment, and no tiered
administration model constrains an operation delivered this way.

The control that governs it is the Azure RBAC assignment on the resource, which
lives in an entirely different system from the one most Active Directory
administrators are watching. On a domain controller, **Contributor on the
resource is effectively Domain Admin over the forest.**

Practical consequences worth stating in the write-up:
- Domain controllers hosted as cloud virtual machines inherit their cloud
  role assignments as a privilege escalation path into the directory.
- Reviewing Domain Admins membership while ignoring who holds Contributor on the
  hosting subscription audits half the problem.
- The same reasoning that puts PIM in front of directory roles argues for
  just-in-time elevation on the resource itself.

### Design decision — the on-premises workforce is deliberately a different cast

The tenant already contains 13 cloud-only users from Labs 1 to 3 (Sarah Mitchell,
David Kim, Marcus Chen, Priya Patel, Amanda Foster, Elena Rodriguez, James
O'Brien, Kevin Walsh, Lisa Anderson, Michelle Torres, Robert Nguyen, Thomas
Brooks, plus the tenant administrator).

The on-premises roster was built as twelve **different** people, on purpose.

**Why not reuse the same names.** Entra Connect performs **soft matching**: an
on-premises user arriving with the same userPrincipalName or primary SMTP address
as an existing cloud-only user is linked to it rather than duplicated, and the
cloud object is converted to a synced object. Source of authority moves to Active
Directory permanently, most attributes become read-only in the cloud, and the
change cannot be reversed without deleting the object.

Those twelve cloud users are the subjects of three published case studies, one of
which walks through PIM activation for Marcus Chen. Reusing the names would have
silently rewritten the environment those write-ups describe.

**Why this is not a compromise.** A real hybrid organization has both cloud-only
and on-premises-mastered identities. Presenting the environment that way is more
accurate than pretending every account originates in one directory.

**Deferred to Phase 6, deliberately:** recreate **two** of the existing cloud
users on-premises and let the soft match happen on purpose, to demonstrate the
conversion and the source-of-authority shift with a blast radius of two accounts
rather than twelve.

### Naming constraint nobody documents: the roster has to be sayable

The first roster contained Tobias Lindqvist, Grace Adeyemi and Beatrice Nkemelu.
All fine on paper, all awkward to narrate on a recorded walkthrough.

Three more were changed for a subtler reason: Priya Raman, Marcus Webb and Elena
Duarte shared **first names** with Priya Patel, Marcus Chen and Elena Rodriguez in
the cloud tenant. Saying "Marcus" aloud would have been ambiguous between the
on-premises and cloud casts, which defeats the point of keeping them distinct.

Final roster keeps Daniel Okafor, Hana Sato, Victor Ramos, Naomi Farrow, Omar
Haddad and Sean Delaney, and replaces the other six with Karen Whitfield, Andre
Bishop, Natalie Cruz, Brian Sullivan, Angela Park and Vanessa Hughes.

**Transferable rule for any lab that will be narrated or taught:** pick names you
can pronounce without hesitating, and never reuse a first name that already
belongs to someone else in the same story.

## Phase 4 — Entra Connect Sync

### The installer is no longer on the Microsoft Download Center

`go.microsoft.com/fwlink/?LinkId=615771`, the link in most published Azure AD
Connect guides, no longer serves the MSI. It redirects to a download page that
returns 403 to automated requests. A scripted download produced a 0.1 MB HTML
stub instead of the ~180 MB installer.

New versions are published **only inside the Microsoft Entra admin center**,
behind tenant authentication: Entra ID → Entra Connect → Get started → Manage →
Download Connect Sync Agent → Accept terms & download.

**Worth noting for the student version:** a large share of the tutorials online
still point at the old Download Center link, and a student following them will
hit a dead end with no explanation. Also worth noting the design intent, which is
reasonable: the tool that connects a directory to a tenant can now only be
obtained by someone already authenticated to that tenant.

Live retirement notice on that page: **Connect Sync versions earlier than
2.5.79.0 retire on 2026-09-30.** Version currency on this tool is an operational
responsibility, not housekeeping.

### Cloud Sync versus Connect Sync, decided rather than defaulted

**Chose Connect Sync.** Microsoft's own framing on the Manage tab: Cloud Sync
suits multi-national organizations consolidating disconnected forests or pursuing
a cloud-first strategy; Connect Sync suits "complex topologies and organizations
that rely on their on-premises infrastructure."

Reasons for Connect Sync here:
1. It is the tool named in the job postings that drove this lab.
2. It exposes the two decisions the phase exists to teach, sign-in method and
   organizational unit filtering. Cloud Sync makes the first decision for you
   (password hash sync only, no pass-through authentication and no federation)
   and simplifies the second.
3. It is what most enterprises are currently running.

Cloud Sync is the better tool for a greenfield deployment. Being able to say both
of those in one breath is the answer that lands in an interview.

### The `.local` decision pays off, in Microsoft's own words

The Express Settings page displayed, unprompted:

> *"hids.local is not a routable domain. It is recommended to use custom settings
> to configure user sign-in options."*

The non-routable domain was chosen deliberately in Phase 2, the consequence was
predicted before the installer was ever downloaded, and the alternative UPN suffix
was added in Phase 3 to pre-empt it. The installer then flagged exactly that
condition on its own.

**Express Settings was declined.** Its stated behaviour: sync the entire forest,
**synchronize all attributes**, select password hash synchronization without
asking, start an initial sync, and enable auto-upgrade. No filtering step and no
sign-in method choice are ever presented.

For a small single-forest production environment Express is genuinely the correct
answer, and saying so demonstrates judgement rather than reflexive complexity.
Here it would have skipped both teaching points and pushed the service accounts
straight into the cloud directory.

### Phase 4 — the server's own hardening blocks the installer's sign-in

Clicking Next on **Connect to Microsoft Entra ID** produced:

> *"Content within this application coming from the website listed below is being
> blocked by Internet Explorer Enhanced Security Configuration."*
> `https://login.microsoftonline.com`

**Cause.** Internet Explorer Enhanced Security Configuration (IE ESC) is on by
default on Windows Server. It blocks essentially all web content, on the sound
reasoning that nobody should be browsing casually on a server. The Entra Connect
wizard authenticates through an embedded browser control, so the hardening blocks
the installer's own sign-in.

**Options.**
1. Add each URL to Trusted Sites as prompted. The sign-in redirects through
   several hosts (`login.microsoftonline.com`, `aadcdn.msftauth.net`,
   `msauth.net`, `msftauth.net`), so the dialog reappears three or four times.
2. Disable IE ESC, which is what Microsoft's own Entra Connect prerequisites
   direct you to do.

**Chosen:** disabled IE ESC by setting `IsInstalled = 0` on both the
administrator and user Active Setup components. In production the correct
handling is the URL allowlist, with ESC left enabled.

**Why this belongs in the student guide.** It is a hard stop, the error names a
Windows feature rather than anything to do with identity, and nothing in the
wizard suggests the fix. A student without a pointer here either quits or spends
an hour searching. It is also a tidy illustration of a real tension: a hardening
control doing exactly its job and breaking a legitimate administrative task, and
the correct answer being a narrow exception rather than switching the control off
permanently.

### FINDING — the sign-in configuration table reports the tenant's own primary domain as "Not Added"

**Microsoft Entra sign-in configuration** listed both on-premises UPN suffixes
against the tenant's domains:

```
Active Directory UPN Suffix    Microsoft Entra ID Domain
hids.local                     Not Added
hids1.onmicrosoft.com          Not Added
```

`hids.local` is expected and permanent. `hids1.onmicrosoft.com` is not: it is the
tenant's **initial and primary domain**, confirmed independently on the Entra
admin center home page (`Primary domain: hids1.onmicrosoft.com`). It is verified
by construction and cannot fail verification.

**Ruled out by testing rather than assumption:**
- *Stale table.* Clicking the in-page refresh control changed nothing.
- *Stale authentication token.* A separate Microsoft Graph call from an
  unrelated session was rejected at the same time with
  `TokenIssuedBeforeRevocationTimestamp`, suggesting tokens had been invalidated.
  Navigating back to **Connect to Microsoft Entra ID** and re-authenticating
  produced the identical result, so this was not the cause.
- *Insufficient permission.* The account is Global Administrator.

**Cause: not established.** The plausible candidate is that this check enumerates
tenant domains through a deprecated provisioning interface and renders an empty
result as "Not Added" for every row. That is a hypothesis, not a verified
explanation, and it is recorded here as one.

**Decision:** proceed by selecting *Continue without matching all UPN suffixes to
verified domains*, on the following reasoning. The failure this control guards
against applies to unverifiable **custom** domains. `hids1.onmicrosoft.com` is the
tenant routing domain, so sign-in names on it are valid with no verification step
that could fail. All twelve employees carry that suffix; the only accounts on
`hids.local` are the two service accounts, which are excluded from scope anyway.

**Verification deferred to Phase 5, deliberately.** The resulting cloud
userPrincipalName of every synced user will be read from the directory and
compared against the on-premises value. If they match, the table was cosmetic. If
any were rewritten, that is the more valuable outcome.

**This is the lab's recurring pattern for the third time:** the tool's summary is
a claim, and the directory is the evidence. Lab 3 found a workflow reporting six
of six tasks complete while the underlying state was wrong. Phase 2 here verified
promotion with `Get-ADDomain` rather than trusting the wizard's success message.
Same discipline, same reason.

### Phase 4 — configuration as submitted

| Setting | Choice | Reasoning |
|---|---|---|
| Tool | Connect Sync, not Cloud Sync | named in the job postings; exposes sign-in method and OU filtering as explicit choices |
| Install path | Customize, not Express | Express syncs the whole forest with all attributes and never presents either decision |
| Sign-in method | Password hash synchronization | authentication survives an on-premises outage; PTA and federation put the datacenter in the path of every login, permanently |
| Seamless SSO | Enabled | standard pairing with PHS; creates the `AZUREADSSOACC` account |
| AD connector account | Create new (`MSOL_*`) | dedicated least-privileged account rather than pointing sync at an existing domain admin |
| UPN suffix matching | Continue without matching | see the "Not Added" finding above; verified by outcome in Phase 5 |
| Scope | `OU=Employees,OU=HIDS` only | Service Accounts and Disabled Users deliberately excluded |
| Group filtering | Off | OU filter already scopes to twelve users; group filtering is a pilot mechanism |
| Identity across directories | Represented once | single forest |
| Source anchor | Azure-managed (`mS-DS-ConsistencyGuid`) | survives a forest migration, unlike `objectGUID` which is regenerated and orphans the cloud object |
| Password writeback | Enabled | self-service password reset writes back to AD; grants the `MSOL_` account Reset Password rights |
| Group / device writeback | Off | not needed; group writeback is flagged as deprecated in the UI |
| Staging mode | Off | this server is the active one |
| Export deletion threshold | 500 (default) | left on |

### Permissions this wizard grants without stating it plainly

**Two accounts are created during a ten-minute installation, and both are
high-value targets.**

**`MSOL_*` (Active Directory).** Because password hash synchronization was
selected, this account is granted **Replicating Directory Changes** and
**Replicating Directory Changes All**. Those are precisely the rights a **DCSync**
attack requires: they allow an attacker to ask a domain controller for the
password hashes of any account in the domain, including `krbtgt`. Enabling
password writeback adds **Reset Password** over synced users on top.

**`AZUREADSSOACC` (Active Directory computer account).** Holds the Kerberos
decryption key underpinning Seamless SSO. Compromise of that key permits forging
tokens for any user in the tenant. **Microsoft recommends rotating it every 30
days; in practice it is created during a deployment project and never touched
again.**

Neither of these is presented as a security decision in the wizard. Both are
consequences of checkboxes. Monitoring for use of the replication rights, and
scheduling the SSO key rotation, are the two follow-ups a real deployment needs
and rarely gets.

### The export deletion threshold, and why it exists

The summary listed **Enable Microsoft Entra ID Export Deletion Threshold (500)**,
enabled by default and never presented as a choice.

If a single export would delete more than 500 cloud objects, it halts and waits
for manual approval. It exists because OU-scoped filtering makes mass deletion a
plausible accident: moving users out of a synced organizational unit does not
merely stop synchronizing them, it tells Entra Connect they no longer exist, and
the cloud accounts are soft-deleted along with licenses and group memberships.

500 is a guess Microsoft made without knowing the size of the organization. For a
200-person company it will never fire. For a 50,000-person company, 500
unintended deletions is already an incident.

## Phase 4 complete, and Phase 5 verification

### Configuration completed, with three post-install advisories

The wizard reported success and raised three notices:

1. **`mS-DS-ConsistencyGuid` confirmed as source anchor** (green). Verifies the
   correction made earlier in this log: the Azure-managed anchor is not
   `objectGUID`.
2. **"The Active Directory Recycle Bin is not enabled for your forest."** Worth
   acting on. Without it, deleting a directory object strips most attributes
   immediately and recovery requires an authoritative restore from backup. Given
   that the failure mode of OU-scoped filtering is mass deletion, relying on the
   cloud-side export deletion threshold while leaving the on-premises safety net
   off is lopsided.
3. **"We strongly recommend you configure Trusted Platform Module (TPM)."**

### The TPM warning is a direct consequence of a Phase 1 decision

Security type was set to **Standard** rather than **Trusted launch** during VM
creation, chosen to keep that wizard simple. Trusted launch is what provides a
virtual TPM. The absence of one is why Entra Connect raised this notice eight
phases later, and what it protects is the encryption key the sync engine uses for
stored credentials.

Not lab-breaking, and the same call is defensible for a throwaway environment.
Recorded because it is a clean example of an early convenience decision surfacing
much later somewhere unrelated, which is worth narrating.

### FINDING RESOLVED — the "Not Added" table was cosmetic

Verified directly against Microsoft Graph after the initial sync:

```
synced from on-prem : 12
cloud-only          : 13
total               : 25
```

**All twelve arrived carrying exactly their on-premises userPrincipalName**, e.g.
`daniel.okafor@hids1.onmicrosoft.com`. None were rewritten. Department and
`onPremisesSamAccountName` populated correctly.

The Microsoft Entra sign-in configuration table reporting the tenant's own
primary domain as "Not Added" had no bearing on the outcome. The decision to
proceed on reasoning and defer the verdict to the directory was correct, and it
produced better evidence than a clean run would have.

### The organizational unit filter held

Zero service accounts reached the cloud. `svc-backup` and `svc-monitoring` remain
on-premises only, as does everything in `Builtin`, `Computers`, `Users`, and the
`MSOL_` account itself. Had the ambiguous parent checkbox meant "sync everything,"
the connector account and a domain controller object would now be in the cloud
directory. They are not.

The thirteen cloud-only users from Labs 1 to 3 are untouched, which was the entire
reason for using a separate on-premises roster.

### Artifacts created by the install, both high-value

```
AZUREADSSOACC        created 2026-08-21 20:18:07 UTC, PasswordLastSet identical
MSOL_4895979ee08c    enabled
```

`PasswordLastSet` on the Seamless SSO account is the clock on the Kerberos key
Microsoft recommends rotating every 30 days. In most environments this field still
reads the installation date years afterward.

Microsoft's own description on the `MSOL_` account states it plainly: *"This
account must have directory replication permissions in the local Active Directory
and write permission on certain attributes to enable Hybrid Deployment."*

### The ADSync cmdlets are gated by local groups, and that is the control working

`Get-ADSyncConnector` and `Get-ADSyncScheduler` returned empty when executed via
`az vm run-command`, which runs as `NT AUTHORITY\SYSTEM`. These cmdlets are
restricted to members of the `ADSyncAdmins` local group, created during
installation and offered for customization on the Required Components screen.

**Worth stating as a counterpoint to the earlier Contributor finding.** Azure
control-plane access grants code execution as SYSTEM inside the guest, and that
was enough to write to Active Directory. It is *not* automatically enough to
administer the sync engine, because that is protected by a separate local group
membership. Layered controls behave differently, and the honest version of the
earlier finding is "extremely powerful," not "unlimited."

Run interactively as `azureadmin`:

```
SyncCycleEnabled         : True
AllowedSyncCycleInterval : 00:30:00
StagingModeEnabled       : False
```

## Phase 5 complete — source of authority, demonstrated by accident

### How it came up

Reviewing the user list in the Entra admin center, the 13 cloud-only users showed
`Company name: Houry Identity Solutions` and the 12 synced users showed blank.
The obvious fix was to edit them in the portal.

**The portal reported the edit succeeded.** No error, no warning, no greyed-out
field, no note that the object is synced.

Checked against Microsoft Graph immediately afterward:

```
synced users WITH company set    : 0
synced users WITHOUT company     : 12
```

**Nothing was written.** Every one of the twelve was still blank.

### FINDING — a success message with no write behind it

`companyName` is one of the attributes whose source of authority moves to Active
Directory once an object is synchronized. The Entra portal accepts the input,
returns a success notification, and discards the value.

This is a worse failure mode than a refusal. A disabled field teaches the rule the
first time an administrator meets it. **A success message that silently does
nothing means the administrator leaves believing the change was made**, and the
discrepancy surfaces later through a report, an audit, or a downstream system
reading the wrong value.

Third occurrence of this pattern in this lab, after the "Not Added" domain table
and the promotion wizard's own success summary, and it is the same pattern Lab 3
was built around: **the tool's message is a claim, the directory is the
evidence.**

### The fix, and the proof of direction

On the domain controller:

```powershell
Get-ADUser -SearchBase "OU=Employees,OU=HIDS,DC=hids,DC=local" -Filter * |
    Set-ADUser -Company "Houry Identity Solutions"

Start-ADSyncSyncCycle -PolicyType Delta
```

Verified in the cloud within a minute:

```
synced users with company set: 12 of 12
onPremisesLastSyncDateTime: 20:21:41Z -> 21:18:53Z
```

Written on-premises, carried up by one delta cycle. Authority runs one way.

**Attribute naming note:** the field is `company` in Active Directory and
`companyName` in Entra ID. Same value, two names, which is one reason attribute
mapping conversations go sideways.

**PowerShell gotcha worth keeping:** `Get-ADUser` returns only a small default
attribute set. `Company` is not in it, so `-Properties Company` is required or the
value reads as empty and the write appears to have failed when it did not.

### Sync cadence is a floor, not a setting

`AllowedSyncCycleInterval : 00:30:00` is returned by the Entra ID service, not
chosen locally. `CustomizedSyncCycleInterval` can be set longer but not shorter;
the service rejects anything below the allowed interval. Frequency has no billing
consequence, since the virtual machine is charged for uptime rather than activity.

**Operational consequence worth stating in an interview:** synchronization is
eventually consistent, not immediate. A termination processed on-premises at 9:06
can leave the cloud account enabled until 9:35. Organizations that care put an
explicit `Start-ADSyncSyncCycle -PolicyType Delta` at the end of the termination
process rather than waiting for the scheduler.

**Delta vs Initial:** Delta processes only what changed and is correct almost
always. Initial re-imports everything and re-evaluates every sync rule, and is
required after a *configuration* change such as editing OU filtering. Running
Delta after a config change appears to succeed while changing nothing, which is
its own quiet failure.

---

## Phase 6A — the deliberate soft match

Two cloud-only users were reserved in Phase 3 for this: Amanda Foster and Kevin Walsh, both
chosen because they appear in none of the published Lab 1 to 3 write-ups. Amanda was converted.
Kevin remains available.

### Setup

`amanda.foster@hids1.onmicrosoft.com` existed in the cloud since 14 July 2026, object ID
`d8defa0f-611b-4fd3-b18b-6f3c43080db3`, department `Sales`, company `Houry Identity Solutions`,
member of exactly one group. A matching account was created in `OU=Employees` with the identical
userPrincipalName, a `sAMAccountName` of `afoster` to match the roster convention, and
**Department deliberately left blank**.

**Friction worth recording:** the New Object wizard copies the User logon name field down into the
pre-Windows 2000 field as you type, and the copy is one-directional. The only order that works is
top field first, bottom field second. Correcting them in the other order silently undoes the fix,
and nothing on screen says so.

### Sync 1 — the join

**Expected:** the blank Department would flow up, overwrite `Sales`, and the Lab 1 dynamic group
keyed on `user.department -eq "Sales"` would drop her.

**What happened:** the soft match worked exactly as designed. One Amanda Foster, not two. Object
ID unchanged. Creation date still 14 July, so demonstrably the same object rather than a
recreation. `On-premises sync enabled` flipped to Yes.

**And nothing else changed.** Department still read `Sales`. Company still read
`Houry Identity Solutions`. Both were verified as empty in Active Directory.

**Finding 1: the join does not reconcile.** A soft match converts the object and makes the synced
fields read-only in the portal, but it leaves pre-existing cloud values in place. Amanda was left
holding two attributes that could not be edited in Entra, because she was now synced, and did not
exist in Active Directory, because they were never set. Correct-looking, unmaintainable from
either side, and invisible to an access review.

### Sync 2 — one variable changed

Department was set to `Finance` in Active Directory. Job Title and Company were deliberately left
empty as controls, so a single run could test both whether populated values overwrite and whether
absent values survive.

**Finding 2: the next unrelated change wipes the strays.** Department became `Finance` as
expected. **Company name was cleared**, an attribute nobody touched, in the same pass. Its state
in Active Directory was identical across both syncs. The only difference is that the object had
been modified on-premises.

Recorded as an observation, not an explanation. The working hypothesis is that the join writes
only what it is given while a subsequent modification re-exports the full attribute set, but that
was not proven here. What matters operationally is the shape: a soft match can be validated,
signed off, and look correct, and then months later one unrelated edit to one person silently
clears every stranded attribute on that object, with nothing connecting the two events.

**Finding 3, and the important one: a membership count cannot detect an access change.**

Group memberships read `1` before the change and `1` after. The number never moved. Her actual
membership changed completely: the Sales dynamic group dropped her in the same pass the Finance
dynamic group picked her up. One in, one out, every entitlement replaced, net zero.

The instrument was wrong, and it was chosen deliberately in advance, which is what makes it worth
recording. A total is invariant under substitution, and substitution is precisely what
attribute-driven groups do. The correct control is alerting on membership **events**, the adds and
removes individually from the audit log, because that is the only place the two halves of the swap
exist as separate facts.

### What the whole chain looks like

One word typed into a text box on a Windows server, by someone who provisions accounts
on-premises and may never sign into Entra. It synced. One rule stopped matching, another started.
Access moved from one group to another with no approval, no notification, no human decision, and
no change in any number an administrator would think to watch.

### Still open in Phase 6

- Audit log read on Amanda Foster for the actor and timestamp of the group swap. This is the
  evidence half of Finding 3 and it is not done.
- Kevin Walsh has not been soft matched.
- Amanda's Job Title baseline in Entra was never captured before the test, so that control is
  unusable. Capture baselines for every attribute, not only the one under test.
- 6B, hunting what the organizational-unit filter silently excluded, and 6C, the off-boarding test.

---

## Phase 6A — the audit log read

Scope: Amanda Foster's per-user Audit logs blade, date filter `Last 1 month`. **13 events.**
Nine on 8/24, four on 8/7. Times below are local (Pacific); the raw values inside modified
properties are UTC and are noted as such where they matter.

### Getting there: the audit log deep link is dead

**Expected:** `entra.microsoft.com/#view/Microsoft_AAD_IAM/AuditLogsMenuBlade/~/Audit` to open
the tenant-wide audit log.

**What happened:** `Error displaying your content`. Error reason
`ErrorLoadingExtensionAndDefinition`, details `Failed to retrieve the blade definition for
'AuditLogsMenuBlade' from the server ... error code 404`. Microsoft has renamed or removed the
blade.

**Resolution:** navigate through the interface instead. Entra ID > Users > Amanda Foster >
Audit logs. The per-user blade turned out to be the better instrument anyway, because it
pre-scopes events to the object under study rather than requiring a target filter against the
whole tenant.

### FINDING — thirteen events, zero human actors

Every event on this user in a full month was initiated by a service. Three distinct ones:

- `ConnectSyncProvisioning_dc1_489597...` — 5 events
- `Microsoft Approval Management` — 2 events
- `CloudLicensingSystem` — 6 events

Not one `Type: User` actor in the set. The account was created, licensed, joined to
on-premises Active Directory, had its password replaced, had its sessions invalidated, and had
its entire group membership substituted, and no human being appears anywhere in the record of it.

### The sequence on 8/24

- **5:01:52 PM** `Update user`, sync service. The join.
- **5:03:30 PM** `Update PasswordProfile`, sync service.
- **5:03:31 PM** `Change user password`, sync service.
- **5:03:31 PM** `Update StsRefreshTokenValidFrom Timestamp`, sync service.
- **5:16:30 PM** `Update user`, sync service. `Department = Finance` arriving from on-premises.
- **5:16:52 PM** `Remove member from group`, Microsoft Approval Management.
- **5:16:52 PM** `Add member to group`, Microsoft Approval Management.
- **5:17:15 PM** `Update user`, CloudLicensingSystem.
- **5:17:15 PM** `Change user license`, CloudLicensingSystem.

### FINDING — the soft match moved credential authority and killed every session

Ninety seconds after the join, three events fired in the same second-and-a-half, all by the sync
service: `Update PasswordProfile`, `Change user password`, and
`Update StsRefreshTokenValidFrom Timestamp`.

The third one is the operational bite. Moving that timestamp forward invalidates every
outstanding refresh token on the account, which signs the user out of every session on every
device. A real person would have been ejected from everything mid-workday with no notification
and no stated cause.

Nothing in the Entra user interface surfaces this. The user blade shows a synced account that
looks correct. The only place the credential handover and the forced sign-out exist as facts is
the audit log, and only if someone thinks to look.

Recorded as observation. The reading that this is password hash synchronization taking authority
for the credential is consistent with the events but was not separately proven here.

### Finding 3, the evidence half

Both group events carry the **same Correlation ID**: `7240862c-d74d-486b-a7fb-7751fdf063e4`.

That is the fact the whole finding rests on. A shared correlation identifier means the removal
and the addition were emitted by one logical operation, not two operations that happened to land
in the same second. Without it the claim is "her access changed twice in one second," which a
reasonable skeptic can attribute to coincidence. With it the claim is "her access was
substituted," which is a different and much worse thing.

Modified properties, removal:

- `Group.DisplayName` — old `"Sales"`, new blank
- `Group.ObjectID` — old `"f319da40-c4f7-4181-b504-10f497fe930e"`, new blank

Modified properties, addition:

- `Group.DisplayName` — old blank, new `"Finance"`
- `Group.ObjectID` — old blank, new `"380ecbeb-b249-42ef-b358-4833874b2af2"`

Two different group object identifiers, so these are two distinct groups rather than one group
renamed. Same actor on both sides.

Note the shape of the record. Entra does not log an event that says "removed from Sales." It logs
a property that used to hold a value and now holds nothing. To learn what someone lost, you read
the **old value** column, and nothing in the row indicates the loss mattered.

Target on both events includes `Type: User`, `Id: d8defa0f-611b-4fd3-b18b-6f3c43080db3`. That is
the same object identifier read off the user blade in Sync 1, now independently confirmed by the
audit subsystem's own target field. The soft match produced one object, not two, and that is no
longer a single-source claim.

### FINDING — the audit record cannot identify a dynamic group as dynamic

On the Target(s) tab of both events, the group target reports:

- `Display Name:` **blank**
- `Group Type:` **`unknownFutureValue`**

`unknownFutureValue` is the placeholder the Graph API returns for an enumeration value the
consuming schema has no name for. In practice it means the audit record does not tell you what
kind of group this was.

This is the most consequential instrumentation gap in the phase. An investigator working this
incident from the audit log alone would have a removal, an addition, a correlation identifier
tying them together, and an actor. They would have no indication anywhere in the record that a
membership rule caused it, that no approval existed because none was possible, or that the same
thing will happen again to anyone whose department attribute changes. To learn any of that they
must already suspect the group is dynamic and go read its rule somewhere else entirely.

Both groups reported `unknownFutureValue`, on both events. It is not an artifact of one record.

### The data an investigator needs is present but not where they would look

Three separate cases in a single event:

- **Display Name** is blank on both targets. The group's name exists in the record, but only on
  the Modified Properties tab. Anyone who opens the event and stops at Target(s) gets two
  globally unique identifiers and an email address.
- **App ID** is blank on the Activity tab. The application identifier
  `65d91a3d-ab74-42e6-8a2f-0add61688c74` is present, on Modified Properties, under
  `ActorId.ServicePrincipalNames` and `SPN`, alongside
  `https://approvalmanagement.activedirectory.windowsazure.com`.
- **User Agent** is blank on both group events, but populated as
  `MCAPICommercialProductLicensing` on the licensing event 23 seconds later.

The consequence is that no single consistent review method works across the log. Which tab holds
the fact you need depends on which event type you are reading.

### FINDING — the actor is named "Microsoft Approval Management" and nothing was approved

`Type: Application`. Service principal object identifier in this tenant:
`ef0ebe67-e792-422c-ab93-a234e9083a44`.

Dynamic membership processing executes under a first-party service principal whose display name
is Microsoft Approval Management. No request existed. No approver saw anything. No workflow ran.
The audit column that an auditor reads to answer "who did this and under what authority" returns
a string that implies an authority that was never exercised.

Combined with the previous finding, the record reads: something called Approval Management
changed this person's group membership, and the record cannot tell you the group was
rule-driven. Both halves point an investigator away from the truth.

### FINDING — an event titled "Change user license" where no license changed

**Expected:** the group substitution cascaded into licensing through group-based licensing, and
this event would show a license SKU moving.

**What happened:** nothing changed. `LicenseAssignmentDetail` holds the same two SKU identifiers
before and after:

- `00ed1723-1992-4384-b7ce-1c3bf01eedc7`
- `84a661c4-e949-4bd2-a560-ed7766fcaf2b`

The array is reordered and the `StatusUpdateTimestamp` on both entries refreshes from
`2026-08-07T19:34:09.6675686Z` to `2026-08-25T00:17:15.5164014Z`. That is the entire diff. She
gained nothing and lost nothing.

The timestamps cross-check cleanly. `2026-08-25T00:17:15Z` is 8/24 5:17:15 PM Pacific, this
event. `2026-08-07T19:34:09Z` is 8/7 12:34:09 PM Pacific, which is a row still visible further
down the same list. Her licenses were genuinely last changed on August 7 and this event did not
touch them.

**There is also no cascade.** The licensing event carries Correlation ID
`030d609d-26d1-42da-bd93-0c985501ef5e`, which does not match the group swap's
`7240862c-d74d-486b-a7fb-7751fdf063e4`. Its Target(s) tab lists only the user, with no group
target at all. Entra does not connect the two events, and neither should the write-up. Actor is
`CloudLicensingSystem`, service principal `acf6fd49-d00e-4a3e-985d-732d5e0b8d21`, application
`de247707-4ea4-47d6-89fd-3c632f870b34` / `https://cloudlicensing.microsoft.com`.

### FINDING — the two instruments fail in opposite directions, 23 seconds apart

This is the finding the phase is actually for.

**At 5:16:52**, every entitlement Amanda had was replaced with a different set in a single
operation, and the metric a reasonable administrator would monitor, her group membership count,
read `1` before and `1` after. **A real access change that produced no signal.**

**At 5:17:15**, an event fired titled `Change user license`, initiated by a service principal,
carrying a full before-and-after diff, and her entitlements were identical on both sides of it.
**A non-change that produced a loud signal.**

Same user. Same minute. A monitor built on membership counts misses a total access substitution.
A monitor built on `Change user license` events chases a re-stamp. Neither instrument reported
the state of her access correctly, and they were wrong in opposite directions inside the same
23 seconds.

The correct control remains the one identified in Sync 2: alert on membership **events**, the
adds and removes individually, and correlate them by Correlation ID. That is the only
representation in which both halves of a substitution exist as separate facts and can be tied
back to one cause.

### Screenshots

`124` through `131`. Audit log list with three non-human actors, both group events across all
three detail tabs, and the licensing event across all three.

### Still open in Phase 6, after 6A

- The two license SKU identifiers are unresolved. Look them up in the Licenses blade so the
  case study can name the products rather than print GUIDs.
- Kevin Walsh has not been soft matched.
- 6B, hunting what the organizational-unit filter silently excluded. Service Accounts and the two
  `hids.local` users never arrived.
- 6C, the off-boarding test using the `Disabled Users` container.
- Still unexplained from Sync 2: why the join left cloud-only attributes intact while the next
  delta sync cleared Company name. Hypothesis only, not proven.

### Environment note recorded during 6B — Connect Sync retirement deadline

The Microsoft Entra Connect blade carries a standing banner: **Microsoft will retire Microsoft
Entra Connect versions earlier than 2.5.79.0 on September 30, 2026.** Recorded 2026-08-25, so
roughly five weeks of runway.

The version installed on `dc1` has not been checked against that floor. If it is below 2.5.79.0
the lab environment stops synchronizing on a fixed date, which would take the hybrid half of this
portfolio piece offline. Verify the installed version and upgrade if required.

Unrelated to the 6B question, recorded because it was on screen and it has a deadline.

---

## Phase 6B — hunting the silence

**The question.** Twelve users were synchronized and the `Service Accounts` container was
excluded by the organizational-unit filter in Phase 4. That much was known, because it was built
that way. The question worth asking is different: **does any instrument on the Entra side
represent the absence at all?**

Framed operationally: an auditor holds Global Reader in this tenant and has no access to the
Windows server. Can they determine that accounts exist on-premises which were excluded from
synchronization?

### The Entra-side picture

`Entra ID > Users`, unfiltered: **25 users**. With `On-premises sync enabled == Yes`:
**13 users**.

Thirteen rather than twelve, because Amanda Foster was recreated on-premises during Phase 6A and
became a thirteenth synced object. The baseline moved mid-phase, which is worth recording on its
own: a reconciliation target that changes while you are reconciling against it is the normal
condition, not an edge case.

### FINDING — there is no query for absence

The filter vocabulary offered under `on-premises` is:

- On-premises SAM account name
- On-premises immutable ID
- On-premises last sync date time
- On-premises provisioning errors
- On-premises sync enabled

Every one is a **property of an object that already exists in Entra**. A filter evaluates rows.
The excluded service accounts have no row, no attribute to compare, and no possible query that
returns them. The vocabulary is entirely about what the directory already holds.

Alongside that, Entra reports 13 synchronized and offers no denominator anywhere. Thirteen out of
what is unanswerable from the cloud.

### FINDING — the error control works correctly and is blind by design

`On-premises provisioning errors` is the one filter that sounds like it would catch a sync gap.
It is fully usable: selecting Attribute `Category` fills Operator with `==` and turns Value into
a bounded dropdown, and `Apply` enables. The dropdown holds exactly **one** category,
`PropertyConflict`. Selecting it returns **0 users found**, which also proves the list is a
static enumeration rather than a reflection of errors present in the tenant.

So a competent administrator, with no prior knowledge, can complete that dialog in fifteen
seconds and get a clean result.

The instrument is not broken, and that is the finding. Every category it offers describes an
**error**. An organizational-unit exclusion is a successful configuration that has executed
correctly on every sync since Phase 4. Nothing failed, so nothing is reported, and nothing reads
as all clear. **The exclusion is invisible precisely because it succeeded.**

### FINDING — the sync status blade reports the engine, not the payload

`Microsoft Entra Connect > Connect Sync` reports `Sync status: Enabled`, a last-sync time,
`Password Hash Sync: Enabled`, and sign-in method counts for Federation, Seamless single sign-on,
and Pass-through authentication.

It reports **no object count of any kind**. Not synchronized, not in scope, not excluded. It
makes **no mention of scope, filtering, or organizational units** anywhere on the page. The blade
would render identically whether the filter passed 13 objects or 13,000, and identically whether
one container was excluded or nine.

Two incidental findings from the same page:

**The Version field does not show a version.** It renders a link reading
`Download the latest Entra Connect Sync Version`. The same console carries a standing banner
warning that versions earlier than 2.5.79.0 retire on September 30, 2026. An administrator
cannot assess compliance with that deadline from the page that announces it.

**`Password Hash Sync: Enabled` confirms Phase 6A.** The password and token-invalidation events
observed after the soft match were recorded there as consistent with password hash
synchronization but not separately proven. The configuration is now observed. That finding is
upgraded from inference to confirmed.

### FINDING — "Enabled" describes intent, not activity

At the moment the blade reported `Sync status: Enabled` with no warning of any kind, `Last sync`
read **14.00 hours ago** and the domain controller `dc1` was `Stopped (deallocated)` in Azure.

Connect Sync's default cycle is 30 minutes, so roughly **28 consecutive cycles did not run**, and
the tenant's only synchronization status page presented that as normal in plain text. No amber,
no advisory, no degraded state.

In this lab the machine was deallocated deliberately to control Azure spend, so 14 hours is
expected and harmless. Nobody deallocates a production domain controller. In a real environment
that identical screen would mean something had failed overnight, and it would still read
`Enabled`. The page cannot distinguish a deliberate shutdown from an outage because it is not
reporting on either. It reports how synchronization is **configured**.

Answering that question also required leaving the Entra admin center for the Azure portal,
because virtual machine power state is not an identity object. **The sync engine's health depends
on infrastructure the identity console cannot see.**

### Ground truth from the domain controller

Read directly from `hids.local` with `Get-ADUser`, scoped per container with `-SearchBase`:

- `OU=Employees` — **13 users**, every UPN on `@hids1.onmicrosoft.com`
- `OU=Service Accounts` — **2 users**, `svc-backup@hids.local` and `svc-monitoring@hids.local`
- `OU=Disabled Users` — **0 users**, verified rather than assumed

**15 accounts exist on-premises. 13 reached the cloud. 2 are invisible.**

The 13 in `OU=Employees` match the 13 Entra reports as synchronized **name for name, with zero
discrepancy**. That rules out sync failure as an explanation for anything missing. The engine is
doing its job perfectly. Whatever is absent is absent by design.

### FINDING — the invisible accounts are the privileged ones

`svc-backup` and `svc-monitoring`. A backup identity needs to read everything. A monitoring
identity needs to see everything. The two accounts excluded from every cloud control in the
tenant are, by function, among the broadest-reaching identities in the directory.

This is not an artifact of how the lab was seeded. It is the normal shape of the problem, because
service accounts are exactly what administrators exclude from synchronization. The consequence is
that the identities least covered by Conditional Access, cloud access reviews, risk detection,
and Privileged Identity Management are the ones that would matter most in an incident.

### FINDING — removing the filter would not fix it

Both service accounts carry `@hids.local` user principal names.

`.local` is not a routable internet domain and cannot be verified in Entra, because nobody can
prove ownership of it. So these accounts have **two independent reasons** they cannot appear in
the tenant: the organizational-unit filter, and an unverifiable UPN suffix.

An administrator who discovers the gap and reaches for the obvious remedy will widen the filter,
run a sync, see nothing arrive, and have to diagnose a second cause they did not know existed.
Worth stating plainly in the case study, because "just remove the exclusion" is the intuitive fix
and it is wrong.

### 6B.4 — the control that would actually catch this

No cloud-side control can. Every instrument in Entra describes objects Entra holds, and the
problem is defined by objects it does not hold. The control has to compare two sources.

1. **Scheduled reconciliation, and it is the only real answer.** Query Active Directory for every
   in-scope object, query Microsoft Graph for every synchronized object, diff the two sets, alert
   on the delta. That produces the denominator the cloud cannot. It is also the only control that
   would have surfaced this in under a minute. Natural extension of the Graph PowerShell work in
   Lab 3.
2. **Treat sync scope as an access control, because it is one.** The organizational-unit filter
   is a security decision whose only evidence lives in a configuration wizard on a server the
   auditor cannot reach. It needs a documented owner, a recorded justification, and a review
   date, exactly like a firewall rule or a group membership.
3. **Compensating controls for the excluded identities.** Anything deliberately kept out of the
   cloud is deliberately kept out of Conditional Access, access reviews, and risk detection. That
   is a defensible decision only if on-premises controls cover the gap: tiered administration,
   group managed service accounts where the application supports them, credential vaulting, and
   privileged access monitoring that does not depend on the cloud.

### Screenshots

`132` through `149`.

### Microsoft Entra Connect Health — checked, and it does not close the gap either

**On the original 6B question: no.** Connect Health reports server status, alert history, and
sync errors. It shows **no object counts, no scope, and no mention of filtering or organizational
units** anywhere. All four tenant-side instruments are now checked and the conclusion stands
without caveat: nothing in Entra can tell you 13 out of 15.

What it did surface is a set of findings about the instruments themselves.

### FINDING — two consoles, opposite verdicts, and neither was reporting on what it appeared to

At roughly the same moment, `Microsoft Entra Connect > Connect Sync` read `Sync status: Enabled`
with no warning of any kind, while Connect Health showed `Status: Error` with 1 active alert
against the same server.

The alert is **`Health service data is not up to date`**, scoped to `dc1`. That is the health
agent failing to report telemetry, **not the sync engine failing**. Nothing on the page draws
that distinction. An administrator who opens Connect Health, sees `Error` beside their only
Connect server, and escalates would be escalating a monitoring gap while believing they had a
synchronization outage.

### FINDING — the overview page contradicts itself

Three signals render simultaneously on `hids1.onmicrosoft.com`:

- `dc1` — **Error**, red
- Sync Error — **0 total errors**, green, `Data freshness status` green
- `Last Export to Microsoft Entra ID: 8/25/2026, 12:59:47 PM`, recent and successful

A red server, a green zero-error panel, and a successful export twenty minutes prior, with
nothing on the page reconciling them for the reader.

### FINDING — the alert was stale by more than half an hour

Alert history on `dc1`:

- Created **1:13:55 AM**, resolved **3:52:49 AM**
- Recreated **3:52:49 AM**, the same second the previous one resolved, last updated
  **11:48:59 AM**, still **Active**

The virtual machine returned around 12:57 PM and exported successfully at 12:59:47 PM. The alert
had not been re-evaluated since 11:48 AM, over an hour before the condition cleared, and was
still presenting as active thirty minutes after the problem ended.

### FINDING — the status page does not auto-refresh, and gives no cue that it is stale

The Connect Sync blade showed `Last sync: 14.00 hours ago` at 1:13 PM while Connect Health
recorded a successful export at 12:59:47 PM, fourteen **minutes** earlier. Clicking `Refresh`
changed the field to `Less than 1 hour ago`.

So the value was fetched when the page first loaded at 12:50 PM, when 14 hours was accurate, and
never updated. **A tab left open reports synchronization state frozen at the moment it was
opened, with nothing on the page indicating the number is old.** This was tested rather than
assumed; the alternative hypothesis, that two consoles genuinely disagreed, was checked and
disproved.

Note also the precision. The same field renders as `14.00 hours ago`, two decimal places, and as
`Less than 1 hour ago`, a sixty-minute bucket. Connect Health gives the same fact to the second.
During an incident, "less than 1 hour ago" is close to useless.

### FINDING — the instruments fail in opposite directions, again

This is the second time in Lab 4, on an unrelated subsystem.

**Phase 6A:** a membership count stayed flat through a total entitlement substitution, while a
`Change user license` event fired loudly over a change that never occurred.

**Phase 6B:** the Connect Sync blade reported `Enabled` with no warning while the server was
powered off and roughly 28 sync cycles had not run, while Connect Health reported `Error` on a
server that was synchronizing correctly and had exported successfully twenty minutes earlier.

One instrument silent while something real happened. Another loud while nothing happened. Twice,
on different subsystems, in the same lab.

The operational conclusion is not that these particular pages are poorly built. It is that
**the state of the instrument and the state of the system are independent variables**, and any
control worth relying on has to be validated against ground truth rather than trusted because it
is green. In this phase, ground truth required domain-administrator access to a server the cloud
console cannot see.

### Environment note RESOLVED — version checked, and the rename hid it

Installed version on `dc1`, read from the registry uninstall keys:

- **Microsoft Entra Connect Sync — 2.6.84.0**
- Microsoft Azure AD Connect Agent Updater — 1.5.4899.0
- Microsoft Entra Connect Health Agent — 4.5.2614.0
- Microsoft Entra Connect synchronization services — 2.6.84.0

The retirement floor is 2.5.79.0, so **2.6.84.0 is compliant and the September 30, 2026 banner
does not apply to this environment.** No upgrade required, which is the correct outcome, because
an upgrade re-runs configuration and the organizational-unit filter is the subject of Phase 6B.

**Worth recording: the first version query returned the wrong answer because of the rename.**
Filtering the uninstall keys on `*AD Connect*` returned only the Agent Updater, because the sync
engine registers as "Microsoft **Entra** Connect Sync" and that string does not contain
"AD Connect". Broadening to `*Connect*`, the fragment that survived the rename, returned all four.

Note the branding on one machine: three components carry Entra, one still carries Azure AD, and
the desktop shortcut reads "Azure AD Connect". Microsoft's own installer is internally
inconsistent, which is a concrete answer to why job postings and documentation still say Azure AD
in 2026. Any search of a system for a renamed product should anchor on the unchanged fragment,
because a brand-name assumption baked into a filter fails silently and looks like a clean result.

---

## Phase 6C — the off-boarding test

**The scenario.** The standard on-premises off-boarding move is two actions performed together:
disable the account, then move it to a Disabled Users container. Done by a help desk technician
working a termination ticket who has never thought about what the cloud does in response.

**The design.** Doing both at once teaches nothing, because the outcome cannot be attributed. So
they were separated, with a delta sync and an observation between them.

**Subject:** Victor Ramos, `872f6b90-2858-416b-8413-94862b442c84`, `sAMAccountName vramos`.
**Control:** Hana Sato, `78f0bb1f-c5c2-452f-b53e-fd5ce0769538`. Same department, same dynamic
group, untouched throughout. Without her, "he left the group" and "the group broke" are
indistinguishable.

### 6C.1 — baseline, captured properly this time

Phase 6A burned a control by recording only the attribute under test. Not repeated.

**Cloud:** Account status `Enabled`, Object ID `872f6b90-2858-416b-8413-94862b442c84`, created
`Aug 21, 2026 at 1:21 PM`, group memberships **1**, assigned licenses **2**, assigned roles 0.
Job title `Sales Engineer`, Company `Houry Identity Solutions`, Department `Sales`, Employee ID
`EMP-1008`, Usage location `United States`, On-premises sync enabled `Yes`.

**Group:** `Sales`, `f319da40-c4f7-4181-b504-10f497fe930e`, Security, **Dynamic**, Source
**Cloud**. The same group object Amanda Foster was removed from in Phase 6A, confirmed by GUID
rather than by name.

**Licenses:** `Microsoft Entra ID P2` (4/4 services) and `Microsoft Entra ID Governance Add-on`
(1/1). **Both assignment paths are `Direct`.**

**Source:** `Enabled True`, `Department Sales`, `Title Sales Engineer`,
`Company Houry Identity Solutions`, `EmployeeID EMP-1008`,
`DN CN=Victor Ramos,OU=Employees,OU=HIDS,DC=hids,DC=local`.

Two things fell out of the baseline for free:

**Victor's Company name is populated while Amanda's is blank.** Same tenant, same sync, same
attribute. An unplanned control that strengthens the Phase 6A finding: the Company wipe was
specific to the soft-match path, not a general failure of that attribute to synchronize.

**Both licenses are assigned Direct, not through a group.** This retroactively confirms the
Phase 6A correction. The group substitution could not have cascaded into licensing because
group-based licensing is not in use on this object at all. The false cascade is now disproved
twice, by correlation ID and by assignment model.

### 6C.2 — disable only

`Disable-ADAccount -Identity vramos` at 2:04 PM local, verified `Enabled : False` by read-back
rather than trusting a silent write. Delta sync at 2:06 PM, `Success`.

**Result in the cloud:** Account status `Disabled`. The flag synchronized correctly.

**And nothing else changed.**

- Still a member of `Sales`, **same group GUID**, no substitution
- Still holding **2 licenses**
- Still carrying `Department = Sales`, `Title = Sales Engineer`, `Company = Houry Identity
  Solutions`

### FINDING — disabling an account revokes authentication and nothing else

The rule is `user.department -eq "Sales"`. It tests **department**. It does not test whether the
account is enabled, and termination does not clear an attribute. So a disabled, terminated
employee continues to satisfy the membership rule and continues to hold the entitlement.

He cannot sign in. That is the entire effect of the action an administrator understands as
"revoking access."

The dangerous case is not today, it is the reversal. One `Enable-ADAccount` and one sync restores
a fully entitled identity instantly, with no approval, no review, and no record that anything was
granted. This is Lab 2's finding, where the joiner workflow silently reversed the leaver,
reproduced through an entirely different mechanism.

### FINDING — the disable produced no membership event, so there is nothing to alert on

The `Sales` group's own overview reported `Last membership change: 8/24/2026, 5:16 PM`, which is
Amanda from the previous day. Victor's disable, two minutes after the sync, generated **no
membership change at all**.

Correct behavior, and precisely the problem. Disabling a user is not a membership operation, so
no add or remove is emitted, and the control recommended in Phase 6A, alerting on membership
events, is blind to this entire class of stale access. `Dynamic rules processing status` read
`Succeeded` throughout.

### FINDING — the group members list cannot show an access reviewer the problem

Columns on `Sales > Members`: `Name`, `Type`, `Email`, `User type`, `Object Id`, `Device Id`.

**There is no account status column.** Nothing on that page indicates Victor had been disabled
four minutes earlier. An access review scoped to this group presents a terminated employee to a
reviewer as an ordinary current member, alongside active staff, rendered identically.

The control specifically designed to catch stale access is structurally unable to display the
most common form of it.

**Correction recorded.** The members list also contained Robert Nguyen, and he was initially
written up here as an undetected orphan from Lab 2. That was wrong. Robert was off-boarded in
Lab 2, the joiner workflow reversed it, and **that reversal was the Lab 2 finding**; he was
deliberately left in the restored state as preserved evidence. Known, intentional, documented.
He is excluded from the Phase 6C findings entirely. Logged in the corrections file as A7, because
calling deliberately seeded lab state a live security finding is the kind of error that does not
survive an interview.

### 6C.3 — the move

`Move-ADObject` to `OU=Disabled Users,OU=HIDS,DC=hids,DC=local` at 2:18 PM, verified by the
changed `DistinguishedName`. Delta sync at 2:20 PM, `Success`.

### FINDING — moving a user between folders deletes the cloud identity

Victor Ramos returned **`0 users found`** in the Entra user list. The tenant went from **25 users
to 24**.

He is not disabled in the cloud. He is not greyed out or flagged. The object no longer exists.
`Sales` dropped to **2 members**, Hana Sato and Robert Nguyen, with no removal event, because a
membership cannot be removed from a member that does not exist.

This is the behavior predicted in the Phase 4 write-up before the test was designed: leaving the
scoped organizational unit does not stop synchronization, it reports the object as absent and the
cloud account is soft-deleted along with its licenses and group memberships.

### The shape of the whole phase

**Step one, disable.** Blocked sign-in. Revoked no entitlement, released no license, produced no
event, left the account visible and indistinguishable on the page an auditor reviews.

**Step two, move to a folder.** Deleted the cloud identity, released the licenses, removed the
group membership, and delivered the actual security outcome.

The action an administrator understands as revoking access did almost nothing. The action they
understand as tidying up did everything, and it is destructive.

### FINDING — the deletion record does not say why, and the timestamps point at the wrong event

`Deleted users` shows Victor with `Deleted date time: Aug 25, 2026 at 2:20 PM` and
`Permanent deletion date time: Sep 24, 2026 at 2:20 PM`, a 30-day window.

**2:20 PM is when the sync ran. The administrative action happened at 2:18 PM, on a Windows
server that emits nothing into the cloud audit trail.** The record timestamps the mechanism, not
the cause. An investigator reading this six months from now sees a user deleted at 2:20 PM by the
synchronization service, with nothing anywhere indicating that a human moved an object between
containers two minutes earlier.

**The user principal name is also rewritten on delete.** The `User principal name` column shows
`872f6b90285...`, the object ID, while the real address is preserved separately under
`Original user principal name: victor.ramos@hids1.onmicrosoft.com`. Entra frees the address
immediately so it can be reassigned, which has two consequences worth knowing: a restore may need
the UPN repaired, and the freed address is available to a new account while the old one is still
recoverable.

### FINDING — the deletion threshold protects against the wrong mistake

The export deletion threshold is 500, the default, recorded in Phase 4. One deletion passed
straight through without a prompt, a warning, or a confirmation.

That threshold exists because organizational-unit filtering makes mass deletion a plausible
accident, and it does protect against deleting five hundred people. It offers nothing at all
against deleting **one** person, which is both far more likely and far less likely to be noticed.

### 6C.4 — the control that would actually work

1. **Do not treat disable as revocation.** Off-boarding must clear the attributes that drive
   entitlement, not only the sign-in flag. Lab 2 reached the same conclusion from the Lifecycle
   Workflows side: the corrected leaver clears the attributes feeding dynamic membership, because
   that is the only thing that works against rule-computed groups.
2. **Anything genuinely privileged should not be attribute-driven.** Access packages with
   approval and expiry survive a stale `department` value. A dynamic rule does not.
3. **Alerting on membership events is necessary and insufficient.** Phase 6A established it as
   the control for substitutions. Phase 6C shows it cannot see a disabled member retaining access,
   because no event is emitted. Both controls are required, and neither covers the other.
4. **Reconcile deletions against a cause.** A cloud deletion attributed to the sync service with
   no corresponding change record on-premises should be an alert, not a routine entry. The
   reconciliation control proposed in Phase 6B produces exactly this.
5. **Access reviews need account state in the reviewer's view.** As shipped, the members list
   cannot convey it, so a reviewer is being asked to make a decision without the single most
   relevant fact.

### State left behind, deliberately

Victor Ramos remains soft-deleted and is **permanently purged on September 24, 2026**. He is the
evidence for this phase and is being left in place, the same decision made about Amanda Foster's
blank Company name. If Phase 7 or the video needs him restored, it must happen before that date.

### Screenshots

`156` through `173`.
