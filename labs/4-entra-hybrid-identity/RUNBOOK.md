# Rebuild Runbook — Hybrid Identity Lab

Reproducible build sheet for the hybrid identity environment: a Windows Server
domain controller in Azure acting as the on-premises directory, synchronized to
a Microsoft Entra ID tenant.

This is the *how to rebuild it* document. `BUILD-LOG.md` is the *what went wrong
and why these choices were made* document. Read this one to reproduce; read that
one to explain.

---

## 1. Parameters

Every value that changes between builds lives here. Nothing below this table
should need thinking about a second time.

| Parameter | This build | Arden Industries build |
|---|---|---|
| Org short name | `hids` | `arden` |
| Entra tenant | `hids1.onmicrosoft.com` | *(to be created)* |
| Azure subscription | Azure subscription 1 | *(TBD)* |
| Resource group | `rg-hybrid-identity-lab` | `rg-arden-hybrid-identity` |
| Region | `westus2` | *(keep close to the operator)* |
| VM name | `dc1` | `dc1` |
| VM size | `Standard_D2s_v3` | same |
| Image | Windows Server 2025 Datacenter x64 Gen2 | same |
| Image URN (CLI) | `MicrosoftWindowsServer:WindowsServer:2025-datacenter-g2:latest` | same |
| Local admin | `azureadmin` | same |
| OS disk | `StandardSSD_LRS`, image default 127 GiB, delete with VM | same |
| Virtual network | `vnet-westus2-1` | same pattern |
| Subnet | `snet-westus2-1`, `172.16.0.0/24` | same |
| DC private IP | `172.16.0.4`, **Static** | same |
| Network security group | `dc1-nsg` | same |
| RDP source | operator public `/32` only | same |
| Auto-shutdown | 23:00 Pacific, email notification | same |
| Tags | `project`, `environment` | same keys |
| AD forest root | `hids.local` | `arden.local` |
| NetBIOS name | `HIDS` | `ARDEN` |
| Alternative UPN suffix | `hids1.onmicrosoft.com` | `<tenant>.onmicrosoft.com` |
| OU structure | `OU=HIDS` → Employees / Service Accounts / Disabled Users | same |
| Employee roster | 12 users, 6 departments | reuse, rename per company |
| Forest / domain functional level | Windows Server 2025 | same |

**Naming constraint:** the VM name becomes the NetBIOS computer name, which caps
at 15 characters. Keep it short.

**`.local` is deliberate.** See BUILD-LOG.md. It reproduces the non-routable
namespace that creates the UPN suffix problem, which is the core teaching point
of the sync phase. Do not "fix" it by choosing a routable name; the lesson
disappears.

---

## 2. Order of operations

Build in this order. Two of these are ordering-sensitive and are marked.

1. Confirm an Azure subscription exists and the operator is Owner
2. Create the VM (resource group is created inline)
3. **Scope the RDP rule to the operator's IP** — do this immediately, the VM is
   created with 3389 open to the entire internet
4. **Pin the private IP to Static** — do this before promotion, AD DS requires it
5. Install a remote desktop client and connect
6. Restart the VM before installing any role (clears first-boot pending reboot)
7. Install the Active Directory Domain Services role
8. Promote to domain controller, creating a new forest
9. *(subsequent phases appended as the lab proceeds)*

---

## 3. Portal build, condensed

Only the values that differ from the portal defaults are listed. Anything not
mentioned stays as the wizard sets it.

**Basics**
- Resource group: create new, per parameter table
- VM name, Region per table
- Availability options: `No infrastructure redundancy required`
- Security type: `Standard`
- Image: set this **before** touching Size; changing the image re-prices and can
  reset the size field
- Size: `Standard_D2s_v3`
- Azure Spot discount: **unchecked**
- Username per table, password stored in a password manager
- Public inbound ports: `Allow selected ports` → `RDP (3389)`
- Existing Windows Server license: unchecked

**Disks**
- OS disk type: `Standard SSD` under **Locally Redundant Storage**. The dropdown
  lists Standard SSD twice; the other one is Zone-Redundant and costs ~50% more
- Delete with VM: checked (default)

**Networking**
- Defaults for virtual network, subnet, public IP
- NIC network security group: `Basic`
- **Delete public IP and NIC when VM is deleted: check this.** Unchecked by
  default, and it strands billing resources when the VM is later deleted

**Management**
- **Login with Microsoft Entra ID: leave unchecked.** Unsupported on a domain
  controller and its agent conflicts with promotion
- Enable auto-shutdown: checked, 23:00, Pacific, notification email set

**Monitoring**
- Boot diagnostics: on, managed storage account. Promotion forces a reboot; if
  the machine does not return, the boot screenshot is the only diagnostic
  available on a host that cannot be reached over the network

**Advanced** — nothing.

**Tags** — `project` and `environment`, applied to all resources.

---

## 4. Post-deployment hardening

**Scope RDP.** Portal → `dc1-nsg` → Inbound security rules → `RDP` → Source
`IP Addresses` → operator public address as `/32` → Save. The warning icon on the
rule clears when this is correct.

**Pin the private IP.** Portal → `dc1-nsg` → Network interfaces → the NIC →
IP configurations → `ipconfig1` → Allocation `Static`, keep the pre-filled
address → Save.

> Do **not** set a static address inside Windows. Azure delivers addresses by
> DHCP and cannot be turned off; hard-coding inside the guest makes it disagree
> with the fabric and typically ends in an unreachable machine. Static is
> enforced at the Azure network interface; the guest stays on DHCP and simply
> receives the same address every time.

---

## 5. Connect

macOS: **Windows App** from the Mac App Store (formerly Microsoft Remote
Desktop). Devices → `+` → **Add PC** → PC name is the VM's public IP.

The certificate warning on first connect is expected. Azure VMs present a
self-signed certificate with no chain to a trusted root.

---

## 6. Domain controller build

**Restart first.** A freshly created VM carries a pending reboot from first-boot
servicing. Installing a role through it produces a failure that surfaces later
during promotion with a misleading error.

**Install the role.** Server Manager → Manage → Add Roles and Features →
Role-based installation → select the server → check **Active Directory Domain
Services** → Add Features when prompted.

- Do **not** also check DNS Server. Promotion installs and configures it against
  the new domain. Installing it first means configuring it by hand.
- Leave *Restart the destination server automatically* unchecked so reboot timing
  stays under operator control.

Installing pulls in six components: the role, Group Policy Management, and four
management tools including the Active Directory module for Windows PowerShell.

**Promote.** The wizard's own **View script** button on the Review Options page
exports the promotion as PowerShell with every parameter filled in. That export
is the basis of `scripts/2-promote-dc.ps1`, so the scripted path is the GUI's
own parameters rather than a reconstruction.

Scripted rebuild, in order, restarting the server first:

```powershell
.\1-install-adds-role.ps1
# restart
.\2-promote-dc.ps1 -DomainName "arden.local" -NetbiosName "ARDEN"
```

The promotion command as the wizard exported it:

```powershell
Import-Module ADDSDeployment
Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "Win2025" `
    -DomainName "hids.local" `
    -DomainNetbiosName "HIDS" `
    -ForestMode "Win2025" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true
```

**One thing the export leaves out:** there is no
`-SafeModeAdministratorPassword`. Run the export verbatim and it prompts for the
DSRM password interactively. `scripts/2-promote-dc.ps1` collects it with
`Read-Host -AsSecureString` instead, deliberately, so the credential is never
written into a file that ends up in a repository.

**Paths, and why they matter beyond the wizard.** `C:\Windows\NTDS` holds
`ntds.dit`, the directory database containing every user, group, computer and
password hash in the domain. It is the highest-value file on a Windows network
and the target behind every "dumped NTDS.dit" line in a breach report.
`C:\Windows\SYSVOL` is replicated to every domain controller and holds Group
Policy objects and logon scripts, which every domain-joined machine reads and
executes. Production separates both onto a dedicated disk; lab defaults are fine.


---

## 7. Time

Leave the guest clock on **UTC** and leave *Set time automatically* **on**.

Kerberos rejects tickets when two machines' clocks differ by more than five
minutes, so time synchronization is load-bearing on a domain controller. The time
zone itself is display-only, but UTC means Windows Event Viewer entries compare
directly against Entra ID logs with no conversion step.

---

## 8. Cost control

| Item | Rate | Bills when stopped? |
|---|---|---|
| Compute + Windows license | ~$0.188/hr | No |
| OS disk (Standard SSD 128 GiB) | ~$9.60/mo | **Yes** |
| Public IP | ~$3.65/mo | **Yes** |
| Boot diagnostics storage | pennies | Yes |

- **Stop the VM from the Azure portal**, not by shutting down inside Windows.
  An in-guest shutdown leaves the machine allocated and still billing.
- Auto-shutdown is a backstop for forgotten sessions, not a substitute.
- When the lab is finished, **delete the whole resource group** in one action.
  Tags make its spend easy to isolate in Cost Management beforehand.

---

## 9. Known traps

- The create-VM wizard does not survive a session timeout, and on return it
  presents **different defaults** than the previous session. Rebuild from this
  document, never from memory.
- The Windows Server license is roughly half the monthly VM cost and only appears
  in the size dropdown *after* the image is chosen. Sizing off the Linux price
  understates it by about half.
- Anyone holding Contributor on the VM can reset the local administrator password
  through the Azure agent, without the old password and without a reboot. Once
  this machine is a domain controller, that is equivalent to Domain Admin over
  the forest. Control-plane access is guest access.
