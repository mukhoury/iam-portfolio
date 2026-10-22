<#
    Promote a Windows Server to the first domain controller in a new forest.

    Derived from the "View script" export of the Active Directory Domain Services
    Configuration Wizard, so these are the exact parameters the GUI would have
    used, not a reconstruction.

    RUN THIS SECOND. Run 1-install-adds-role.ps1 first, and restart the server
    before either one. A pending reboot causes failures that surface here with
    misleading errors.

    The machine reboots on completion. That is expected and required.
#>

param(
    [string]$DomainName     = "hids.local",
    [string]$NetbiosName    = "HIDS",
    [string]$Mode           = "Win2025"
)

Import-Module ADDSDeployment

# Prompted rather than hard-coded. The Directory Services Restore Mode password
# is a local credential used to boot with Active Directory offline and repair a
# corrupt directory. It is not a domain account and never belongs in a script.
$dsrm = Read-Host -AsSecureString `
    "Directory Services Restore Mode (DSRM) password - store this in a password manager"

Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode $Mode `
    -DomainName $DomainName `
    -DomainNetbiosName $NetbiosName `
    -ForestMode $Mode `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $dsrm `
    -Force:$true

# Arden Industries rebuild:
#   .\2-promote-dc.ps1 -DomainName "arden.local" -NetbiosName "ARDEN"
