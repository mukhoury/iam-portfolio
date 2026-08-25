<#
    Seed the directory: three organizational units, twelve employees, two
    service accounts.

    RUN THIS THIRD, from an elevated PowerShell session on the domain controller,
    after the alternative UPN suffix has been added in Active Directory Domains
    and Trusts.

    Design notes that matter later in the lab:

    * Employees get a UPN on the VERIFIED cloud domain, not on hids.local.
      hids.local can never be verified by a tenant, so Entra ID would silently
      rewrite those sign-in names during sync. This is the entire point of
      Phase 3.

    * Service accounts deliberately KEEP the hids.local suffix. They are not
      people, they must never appear in the cloud directory, and in Phase 4 the
      Service Accounts organizational unit is excluded from synchronization.
      Having a container that is deliberately out of scope is what makes the
      filtering lesson real rather than theoretical.

    * Every account gets BOTH an employeeID and a mail value. A blank mail
      attribute hard-failed a Lifecycle Workflow task in Lab 2. Populate it at
      creation, not afterward.

    * Disabled Users starts empty. It is where Phase 6 sends an account to see
      what synchronization does, or fails to do, on an off-boarding.
#>

Import-Module ActiveDirectory

$dom      = "DC=hids,DC=local"
$root     = "OU=HIDS,$dom"
$suffix   = "hids1.onmicrosoft.com"
$labPw    = ConvertTo-SecureString "LabPassw0rd!2026" -AsPlainText -Force

# ---------------------------------------------------------------- 1. sub-OUs
foreach ($ou in "Employees","Service Accounts","Disabled Users") {
    $exists = Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $root -ErrorAction SilentlyContinue
    if (-not $exists) {
        New-ADOrganizationalUnit -Name $ou -Path $root -ProtectedFromAccidentalDeletion $true
        Write-Host "OU created: $ou" -ForegroundColor Green
    } else {
        Write-Host "OU already exists: $ou" -ForegroundColor Yellow
    }
}

# -------------------------------------------------------------- 2. employees
$staff = @(
    @{ First="Daniel";   Last="Okafor";    Dept="Finance";                 Title="Financial Analyst";       Id="EMP-1001" }
    @{ First="Karen";    Last="Whitfield"; Dept="Finance";                 Title="Accounts Payable Lead";   Id="EMP-1002" }
    @{ First="Andre";    Last="Bishop";    Dept="Human Resources";         Title="HR Business Partner";     Id="EMP-1003" }
    @{ First="Natalie";  Last="Cruz";      Dept="Human Resources";         Title="Recruiting Coordinator";  Id="EMP-1004" }
    @{ First="Brian";    Last="Sullivan";  Dept="Information Technology";  Title="Systems Administrator";   Id="EMP-1005" }
    @{ First="Angela";   Last="Park";      Dept="Information Technology";  Title="Security Analyst";        Id="EMP-1006" }
    @{ First="Hana";     Last="Sato";      Dept="Sales";                   Title="Account Executive";       Id="EMP-1007" }
    @{ First="Victor";   Last="Ramos";     Dept="Sales";                   Title="Sales Engineer";          Id="EMP-1008" }
    @{ First="Naomi";    Last="Farrow";    Dept="Marketing";               Title="Content Strategist";      Id="EMP-1009" }
    @{ First="Omar";     Last="Haddad";    Dept="Marketing";               Title="Demand Generation Mgr";   Id="EMP-1010" }
    @{ First="Vanessa";  Last="Hughes";    Dept="Operations";              Title="Operations Analyst";      Id="EMP-1011" }
    @{ First="Sean";     Last="Delaney";   Dept="Operations";              Title="Facilities Coordinator";  Id="EMP-1012" }
)

$empOU = "OU=Employees,$root"

foreach ($p in $staff) {
    $sam  = ($p.First.Substring(0,1) + $p.Last).ToLower()
    $user = "$($p.First).$($p.Last)@$suffix".ToLower()

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Host "user already exists: $sam" -ForegroundColor Yellow
        continue
    }

    New-ADUser `
        -Name              "$($p.First) $($p.Last)" `
        -GivenName         $p.First `
        -Surname           $p.Last `
        -DisplayName       "$($p.First) $($p.Last)" `
        -SamAccountName    $sam `
        -UserPrincipalName $user `
        -EmailAddress      $user `
        -Department        $p.Dept `
        -Title             $p.Title `
        -Path              $empOU `
        -AccountPassword   $labPw `
        -Enabled           $true `
        -ChangePasswordAtLogon $false `
        -OtherAttributes   @{ employeeID = $p.Id }

    Write-Host "created: $user  [$($p.Id)]  $($p.Dept)" -ForegroundColor Green
}

# ------------------------------------------------------- 3. service accounts
# NOTE the suffix: these stay on hids.local on purpose. They are excluded from
# synchronization in Phase 4 and must never reach the cloud directory.
$svcOU = "OU=Service Accounts,$root"

$svcAccounts = @(
    @{ Name="svc-backup";     Desc="Nightly backup job";        Id="SVC-9001" }
    @{ Name="svc-monitoring"; Desc="Infrastructure monitoring"; Id="SVC-9002" }
)

foreach ($s in $svcAccounts) {
    if (Get-ADUser -Filter "SamAccountName -eq '$($s.Name)'" -ErrorAction SilentlyContinue) {
        Write-Host "service account already exists: $($s.Name)" -ForegroundColor Yellow
        continue
    }

    New-ADUser `
        -Name              $s.Name `
        -DisplayName       $s.Name `
        -SamAccountName    $s.Name `
        -UserPrincipalName "$($s.Name)@hids.local" `
        -EmailAddress      "$($s.Name)@hids.local" `
        -Description       $s.Desc `
        -Department        "Information Technology" `
        -Title             "Service Account" `
        -Path              $svcOU `
        -AccountPassword   $labPw `
        -Enabled           $true `
        -PasswordNeverExpires $true `
        -OtherAttributes   @{ employeeID = $s.Id }

    Write-Host "created service account: $($s.Name)@hids.local  [$($s.Id)]" -ForegroundColor Cyan
}

# ------------------------------------------------------------- 4. verify
Write-Host "`n--- Employees ---" -ForegroundColor White
Get-ADUser -SearchBase $empOU -Filter * -Properties UserPrincipalName, mail, employeeID, Department |
    Sort-Object employeeID |
    Format-Table Name, UserPrincipalName, mail, employeeID, Department -AutoSize

Write-Host "--- Service accounts (should NOT be on $suffix) ---" -ForegroundColor White
Get-ADUser -SearchBase $svcOU -Filter * -Properties UserPrincipalName, employeeID |
    Format-Table Name, UserPrincipalName, employeeID -AutoSize

Write-Host "--- Counts by UPN suffix ---" -ForegroundColor White
Get-ADUser -SearchBase $root -Filter * -Properties UserPrincipalName |
    Group-Object { ($_.UserPrincipalName -split '@')[1] } |
    Format-Table Name, Count -AutoSize
