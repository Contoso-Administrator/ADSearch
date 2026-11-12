# ADSearch
```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║      _    ____       ____  _____    _    ____   ____ _   _    ║
║     / \  |  _ \     / ___|| ____|  / \  |  _ \ / ___| | | |   ║
║    / _ \ | | | |    \___ \|  _|   / _ \ | |_) | |   | |_| |   ║
║   / ___ \| |_| |     ___) | |___ / ___ \|  _ <| |___|  _  |   ║
║  /_/   \_\____/     |____/|_____/_/   \_\_| \_\\____|_| |_|   ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║                User / Computer OU Lookup Tool                 ║
╚═══════════════════════════════════════════════════════════════╝
```

<p>This Active Directory tool offers an interactive user/computer OU lookup that compares results using fuzzy Levenshtein matching to determine if the computer is in an OU that matches the user's OU. ADSearch works by looking up a user and a computer in Active Directory, then compares their OU paths to estimate whether they belong to the same location. ADSearch installs and uses the ActiveDirectory module to find the username (SamAccountName) and computer name (hostname), using the Get-ADUser and Get-ADComputer cmdlets to the retreive the CanonicalNames for matching. It is strongly encouraged to tune this tool to your Active Directory enviroment before deploying.</p>
<br />

<h3>Matching</h3>
The script compares the two location names without regard to case. Identical names score 100%. Otherwise, it calculates the Levenshtein distance and turns it into a similarity percentage, then rates the result:
<br /><br />

| Score | Result | Color |
| :---         |     :---:      |          ---: |
|100%	Exact Location Match |	Green |
| 80–99%	| Likely Same Location |	Green |
| 50–79%	| Possibly Related Location |	Yellow |
| 1–49% |	Weak Match |	Red |
| 0% | No Match |	Red |

<br />
<h3>Tuning</h3>

- If you need to change the color matching to tune it to your environment, it can be edited in <ins>lines 201-204</ins>.

- If you need to change the score range, it can be edited in <ins>lines 133-137</ins>. 


# ADExcelSearch

<p>ADExcelSearch is the Excel version of the ADSearch lookup tool and can be an effective tool for auditing computer locations within Active Directory. It works by opening a workbook, finding each user listed in the 'Last Login' column, and looks up the computer in that row's 'Hostname' column. It then compares the computer and user OUs to estimate matching results. It is recommended to tune this tool (tuned by default to work with ServiceNow CMDB exports).

ADExcelSearch works 

</p>

<ins>PreDomainRebuild.ps1</ins>

><h3>Requirements</h3>
>
>- A domain account that can read user and computer objects.
>- A domain-joined Windows machine with the 'RSAT: Active Directory module' installed.
>- Access to the PowerShell Gallery, the script replies on Install-Module and ImportExcel as a dependency.
>- A Excek workbook with 'Last Login' and 'Hostname' headers in row 1. Last Login should contain users' full names, such as John Doe.
>- Windows PowerShell 5.1 or later.
