<#
    Install the Active Directory Domain Services role and its management tools.

    RUN THIS FIRST, and restart the server before running it. A freshly created
    Azure VM carries a pending reboot from first-boot servicing; installing a
    role through it produces a failure that only surfaces later during promotion.

    This installs the software only. It does NOT create a domain or make the
    machine a domain controller. That is 2-promote-dc.ps1.

    DNS Server is deliberately NOT installed here. Install-ADDSForest installs
    and configures it against the new domain. Installing it first means wiring it
    up by hand and is a common route to a domain controller pointing at the wrong
    resolver.
#>

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Equivalent to checking "Active Directory Domain Services" in Add Roles and
# Features and accepting the dependency prompt. -IncludeManagementTools pulls in
# Group Policy Management, the AD DS snap-ins and command-line tools, the Active
# Directory Administrative Center, and the Active Directory module for Windows
# PowerShell.

Get-WindowsFeature -Name AD-Domain-Services | Format-List Name, InstallState
