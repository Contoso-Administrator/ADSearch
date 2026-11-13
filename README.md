
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

# ADSearch
<p>This Active Directory toolkit offers user/computer OU comparisons using fuzzy Levenshtein matching to determine if the computer is in an OU that matches the user's OU (for IT audits and continual asset management). ADSearch and ADSearch_Excel works by looking up a user and a computer in Active Directory, then compares their OU paths to estimate whether they belong to the same location. Each tool installs and uses the ActiveDirectory module to find the username (SamAccountName) and computer name (hostname), using the Get-ADUser and Get-ADComputer cmdlets to the retrieve the CanonicalNames for matching. It is strongly encouraged to tune this tool to your Active Directory environment before deploying (depending on your domain's OU structure and depth, it is designed for a ~/State/Site/Facility structured domain).</p>
<br />

>[!NOTE]
>ADSearch defaults to the parent domain of the user and is not intended for multi-domain environments (ADSearch_Excel can be used for multi-domain environments). 

<br />

<h3>Matching</h3>
The script compares the two location names without regard to case. Identical names score 100%. Otherwise, it calculates the Levenshtein distance and turns it into a similarity percentage, then rates the result:
<br /><br />

| Score | Result | Color |
|  :---:          |     :---:      |           :---:  |
| 100%	| Exact Location Match |	Green |
| 80–99%	| Likely Same Location |	Green |
| 50–79%	| Possibly Related Location |	Yellow |
| 1–49% |	Weak Match |	Red |
| 0% | No Match |	Red |

<br />

<h3>Tuning ADSearch.ps1</h3>
The variables used for color matching and score ranges can edited by changing the variables below:
<br /><br />

- If you need to change the color matching to tune it to your environment, it can be edited in <ins>lines 201-204</ins>.
- If you need to change the score range, it can be edited in <ins>lines 133-137</ins> (depending on complexity of the user/computer OU structure).
<br />

# ADSearch_Excel

<p>ADSearch_Excel is the Excel version of the ADSearch lookup tool and can be an effective tool for auditing computer locations within Active Directory. It works by opening a workbook, finding each user listed in the 'Last Login' column (by searching the workbook for that header), and looks up the computer in that row's 'Hostname' column. The script then compares the computer and user OUs to estimate matching results in a new column. It is recommended to tune the matching of this tool and apply it to your environment(s) and workflow.
  
>[!NOTE]
>ADSearch_Excel is setup by default to work with ServiceNow CMDB (.xlsx) exports.
<br />

ADSearch_Excel works by placing the script in the same directory as the Excel workbook you are needing to add ADSearch results in and can be ran by starting the script with a domain account that can read user and computer objects in Active Directory. The script will fail if more than one Excel workbook is in the same directory as the script. ADSearch_Excel will import/install all required dependencies (Install-Module and ImportExcel) at start. The script will then add the columns 'OU Match Percentage', 'OU Match Reason', and 'AD_Name' to each row of the workbook for easy auditing. After the script is done, it will then add a worksheet called 'ADSearch_ErrorLog' with verbose logs of the results.
<br /><br />

<ins>OU Match Percentage</ins><br />
Returns the results of the fuzzy Levenshteinin matching in a percentage.

<ins>OU Match Reason</ins><br />
Returns match result along with the user and computer location or the  error result for that lookup (ex. ERROR: Computer Lookup)

<ins>AD_Name</ins><br />
Returns the username (SamAccountName) or error result for that lookup (ex. ERROR: Disabled).

<br />

>[!CAUTION]
>The variable <ins>$DomainSuffix</ins> must be set to the suffix of your domain in <ins>line 7</ins> of ADSearch_Excel.ps1. This is because this portion of the tool is designed to be able to work with multi-domain environments.
<br />

<h3>Tuning ADSearch_Excel.ps1</h3>
The headers used for matching can edited by changing the variables below, along with the score range:
<br /><br />

- Set the <ins>$FullNameHeader</ins> variable for the workbook header that has full user names (ex. John Doe) <ins>line 2</ins>.
- Set the <ins>$HostnameHeader</ins> variable for the workbook header that has the computer hostname (ex. DESKTOP-1234) <ins>line 3</ins>.
- Set the <ins>$DomainSuffix</ins> variable to the suffix of your domain <ins>line 7</ins>.
- If you need to change the score range, it can be edited in <ins>lines 109-112</ins> (depending on complexity of the user/computer OU structure).
<br />

><h3>Requirements</h3>
>
>- A domain account that can read user and computer objects.
>- For ADSearch_Excel.ps1 to work, the $DomainSuffix variable needs to be edited to your domain <ins>line 7</ins>.
>- A domain-joined Windows machine with the 'RSAT: Active Directory module' installed.
>- Access to the PowerShell Gallery, the script replies on Install-Module and ImportExcel as a dependency.
>- An Excel workbook (.xlsx) with 'Last Login' and 'Hostname' headers (if variables are left unconfigured) in row 1. 'Last Login' should contain users full names (John Doe). 'Hostname'.
>- Windows PowerShell 5.1 or later.
