# IAM Portfolio: Mukhtar Houry

Hands-on **Identity & Access Management (IAM)** lab work, documented as case studies.

I have 10+ years of real-world IAM experience (identity lifecycle management, RBAC
design, and access governance across enterprise retail, consulting, and financial
services). This repo is where I demonstrate that experience in modern, hands-on tooling,
one reproducible lab at a time, each written up the way I'd talk through it in an interview.

**Certifications:** CompTIA Security+ · ISC2 Certified in Cybersecurity (CC)
**Currently building toward:** Microsoft SC-300 (Identity & Access Administrator)

---

## Labs

| # | Lab | Focus | Tools |
|---|-----|-------|-------|
| 1 | [Entra ID Dynamic Groups & Conditional Access](labs/1-entra-dynamic-groups-conditional-access/) | ABAC · dynamic groups · Zero Trust · Conditional Access | Microsoft Entra ID (Premium P2) |
| 2 | [Entra ID Identity Governance](labs/2-entra-identity-governance/) | Access packages · access reviews · PIM · Lifecycle Workflows | Microsoft Entra ID (P2 + ID Governance) |
| 3 | [Identity Automation with Microsoft Graph PowerShell](labs/3-entra-graph-powershell/) | Graph API · offboarding detection controls · scope-aware scripting | Microsoft Graph PowerShell SDK |

*Labs 2 and 3 are being written up. Application Identity (app registrations, SSO/SAML/OIDC)
is next.*

---

## How to read these

Each lab is a self-contained case study with the same structure:

- **Problem:** the access-control challenge being solved
- **Solution:** the design decision and why
- **Steps:** what I actually did, reproducibly
- **Security outcome:** the control that was achieved and how it maps to real IAM job functions
- **Artifacts:** screenshots and evidence (sanitized)

**Ground rule for everything here:** if I can't explain it, it isn't in this repo.
