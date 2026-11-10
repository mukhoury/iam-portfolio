<#
Creates joiners from a CSV with Microsoft Graph PowerShell.
Runs as a preview unless -Apply is used. Each user gets a random temporary password
that must be changed at first sign-in. Passwords are not saved or displayed.
Connect first:
Connect-MgGraph -TenantId "hids2.onmicrosoft.com" -Scopes "User.ReadWrite.All","User-LifeCycleInfo.ReadWrite.All" -NoWelcome
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CsvPath,
    [string]$ManagerUpn = 'mukhtar@hids2.onmicrosoft.com',
    [string]$ExpectedDomain = 'hids2.onmicrosoft.com',
    [switch]$Apply
)

$context = Get-MgContext
if (-not $context) { throw 'Not connected. Run Connect-MgGraph first.' }
if ($context.Account -notlike "*@$ExpectedDomain") { throw "Connected as $($context.Account), not $ExpectedDomain. Stopping." }

$rows = Import-Csv -Path $CsvPath
$duplicates = $rows | Group-Object EmployeeId | Where-Object Count -gt 1
if ($duplicates) { throw "Duplicate EmployeeId values: $($duplicates.Name -join ', ')" }

if (-not $Apply) {
    Write-Host "PREVIEW ONLY. Nothing was created. Add -Apply to create these $($rows.Count) users." -ForegroundColor Yellow
    $rows | Format-Table EmployeeId, DisplayName, JobTitle, Department -AutoSize
    return
}

$manager = Get-MgUser -UserId $ManagerUpn -Property id
foreach ($row in $rows) {
    $bytes = [byte[]]::new(24)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $password = 'Aa1!' + [Convert]::ToBase64String($bytes)
    try {
        $user = New-MgUser -AccountEnabled -DisplayName $row.DisplayName -GivenName $row.FirstName -Surname $row.LastName `
            -UserPrincipalName $row.UserPrincipalName -MailNickname ($row.UserPrincipalName -split '@')[0] `
            -JobTitle $row.JobTitle -Department $row.Department -CompanyName $row.CompanyName -EmployeeId $row.EmployeeId `
            -EmployeeType $row.EmployeeType -OfficeLocation $row.OfficeLocation -UsageLocation $row.UsageLocation `
            -PasswordProfile @{ Password = $password; ForceChangePasswordNextSignIn = $true } -ErrorAction Stop
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)" -Body @{ employeeHireDate = "$($row.HireDate)T00:00:00Z" }
        Set-MgUserManagerByRef -UserId $user.Id -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$($manager.Id)" }
        Write-Host "Created $($row.DisplayName) ($($row.Department))" -ForegroundColor Green
    } catch {
        Write-Host "FAILED $($row.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
    }
}
