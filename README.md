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

<p>This Active Directory toolkit offers an interactive user/computer OU comparisons using fuzzy Levenshtein matching to determine if the computer is in an OU that matches the user's OU. ADSearch and ADSearch_Excel works by looking up a user and a computer in Active Directory, then compares their OU paths to estimate whether they belong to the same location. Each tool installs and uses the ActiveDirectory module to find the username (SamAccountName) and computer name (hostname), using the Get-ADUser and Get-ADComputer cmdlets to the retreive the CanonicalNames for matching. It is strongly encouraged to tune this tool to your Active Directory enviroment before deploying.</p>
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

<h3>Tuning ADSearch.ps1</h3>

- If you need to change the color matching to tune it to your environment, it can be edited in <ins>lines 201-204</ins>.
- If you need to change the score range, it can be edited in <ins>lines 133-137</ins>. 

<br />

# ADSearch_Excel

<p>ADSearch_Excel is the Excel version of the ADSearch lookup tool and can be an effective tool for auditing computer locations within Active Directory. It works by opening a workbook, finding each user listed in the 'Last Login' column, and looks up the computer in that row's 'Hostname' column. The script then compares the computer and user OUs to estimate matching results in a new column. It is recommended to tune the matching of this tool and apply it to your environment(s) and workflow (ADSearch_Excel is setup by default to work with ServiceNow CMDB exports).

ADSearch_Excel works by placing the script in the same directory as the Excel workbook you are needing to add ADSearch results in and can be ran by starting the script with a domain account that can read user and computer objects in Active Directory. The script will fail if more than one Excel workbook is in the same directory as the script and will import/install all dependencies (Install-Module and ImportExcel). The script will then add the columns 'OU Match Percentage', 'OU Match Reason', and 'AD_Name' to each row of the workbook.
<br />

<ins>OU Match Percentage</ins><br />
Returns the results of the fuzzy Levenshteinin matching in a percentage.

<ins>OU Match Reason</ins><br />
Returns match result along with the user and computer location or the  error result for that lookup (ex. ERROR: Computer Lookup)

<ins>AD_Name</ins><br />
Returns the username (SamAccountName) or error result for that lookup (ex. ERROR: Disabled).


<br />
<h3>Tuning ADSearch_Excel.ps1</h3>
The headers used for matching can edited by changing the variables below, along with the score range. 
<br />

- Set the $DomainSuffix variable for the suffix of your domain <ins>line 7</ins>.
- Set the $FullNameHeader variable for the header that has full user names (ex. John Doe) <ins>line 2</ins>.
- Set the $$HostnameHeader variable for the header that has the computer hostname (ex. DESKTOP-1234) <ins>line 3</ins>.
- Set the $ADNameHeader variable for what header name for AD results are returned in <ins>line 4</ins>.
- Set the $PercentHeader variable for what header name your percentage results are returned in <ins>line 5</ins>.
- Set the $ReasonHeader variable for what header name your match reasons are returned in <ins>line 6</ins>.
- Set the $DomainSuffix variable to the suffix of your domain <ins>line 7</ins>.
- If you need to change the score range, it can be edited in <ins>lines 133-137</ins>.


><h3>Requirements</h3>
>
>- A domain account that can read user and computer objects.
>- A domain-joined Windows machine with the 'RSAT: Active Directory module' installed.
>- Access to the PowerShell Gallery, the script replies on Install-Module and ImportExcel as a dependency.
>- An Excel workbook (.xlsx) with 'Last Login' and 'Hostname' headers in row 1. Last Login should contain users' full names, such as John Doe.
>- Windows PowerShell 5.1 or later.
