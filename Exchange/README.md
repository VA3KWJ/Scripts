# Exchange Scripts

Utilities for Exchange Online and on‑premises environments.

## ConvertIMCEAEXtoX500.ps1
Converts an IMCEAEX bounce address to an X.500 alias. If the `-IMCEAEX` parameter is omitted the script prompts for the string and shows a sample `Set-Mailbox` command.

## getActive.ps1
Queries every user mailbox (Exchange Online or on‑premises) and flags each as **Active** or **Inactive**. A mailbox is Active only if it has **sent** mail within the last 7 days; the newest received date is reported for reference (14‑day look‑back) but does not affect status. Results are grouped by SMTP domain with active users sorted to the top of each group and exported to CSV.

`-Environment Online|OnPremises` (default `Online`), `-ReceivedWithinDays 14`, `-SentWithinDays 7`, `-Path <csv>`. Uses mailbox folder statistics rather than message trace, so it is not limited by the 10‑day trace window.

