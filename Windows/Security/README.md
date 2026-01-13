Collection of security auditing scripts. None of these scripts should actually modify any data and therefore should be safe to use. But as always, use caution!

YOU & YOU ALONE ARE RESPONSIBLE FOR YOUR OWN ACTIONS. I take no responsibility for what you do with these scripts.

## simAttack.ps1
This is to simulate a ransomware attack, but does not encrypt or modify any data. It will download the EICAR file which should trigger your anti-virus. It then proceeds to rename all files in the defined directory with .LOCK then drop a note into every directory. Use with simOSv2. While it does not intentionally modify any data I still don't suggest running it against any live or important data. I take no responsibility for your use of this script.
YOU ARE RESPONSIBLE FOR YOUR OWN ACTIONS!

## simDecrypt.ps1
This is the "decryption" tool for the attack script. It will remove the .LOCK extension on all files and remote the "note" left in each directory. Once again I do not advise running this script against live or important data and take no responsibility for your action.
YOU ARE RESPONSIBLE FOR YOUR OWN ACTIONS!
