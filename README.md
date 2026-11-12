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
</span>
<p>This Active Directory tool offers an interactive user/computer OU lookup that compares results using fuzzy Levenshtein matching to determine if the computer is in an OU that matches the user's OU. ADSearch works by looking up a user and a computer in Active Directory, then compares their OU paths to estimate whether they belong to the same location. ADSearch installs and uses the ActiveDirectory module to find the username (SamAccountName) and computer name (hostname), using the Get-ADUser and Get-ADComputer cmdlets to the retreive the CanonicalNames for matching. It is strongly encouraged to tune this tool to your Active Directory enviroment before deploying.</p>
<br />

<ins><h3>Matching</h3></ins>
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
<ins><h3>Tuning</h3></ins>

- If you need to edit the matching to tune it to your environment, the color can be edited in <ins>lines 201-204</ins>.

- If you need to edit the score range, it can be changed in <ins>lines 133-137</ins>. 


<br /><br /><br />

<ins>PreDomainRebuild.ps1</ins>
- Set the variable for $LocalAdmin to the local admin account you plan on using (line 5)
- Configure your VPN install for the domain join (lines 25 & 26)

<ins>DomainRebuild.ps1</ins>
- Set the variable for $LocalAdmin to the local admin account you plan on using (line 5)
- Set the variable for domain and OU location you plan on domain joining the computer to (lines 8-11)

<ins>PostDomainRebuild.ps1</ins>
- Configure the installs for your tech stack (lines 28-30)
- Place the files for your installs (.msi/.exe/etc) and configurations in the folder: ~\Domain Rebuild\Resources
- Configure the install for your user-facing VPN (lines 32-35)
<br />

><h3>Important things to know</h3>
>
>- System Drive and Desktop paths are variables and can be used with desktop re-direction/different system drive paths.
>- The ‘Domain Rebuild’ folder must be placed on Desktop of specified local admin unaltered or it will break the script.
>- DO NOT close any of the PowerShell windows that open, doing so will halt the script. Re-login to the specified local admin to restart that phase of the domain rebuild.
>- It is very important that you wait for at least ~4min after logging into local admin post domain join, so you can let domain policies update and apply (depending on your environment). This may cause the computer to become slow and unresponsive after login and it is best to let group policy updates finish before proceeding. Re-login to the specified local admin login if necessary to restart that phase of the domain rebuild.
>- The domain credentials are stored as a AES secure string in "$env:ProgramData\DomainRebuild", that folder is then deleted as part of the final step of Phase 3.
>- Task Scheduler tasks are deleted as the script proceeds to the next phase, each task is named after the script that created it (ex. the PreDomainRebuild task starts DomainRebuild.ps1 after the 1st reboot).
>- Task Scheduler tasks will only start at the login of the specified local admin account, even if the computer is on batteries and tasks are set to the highest run level.
