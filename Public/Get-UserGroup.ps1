function Get-UserGroup {
	param([string]$username = $env:username)

	(New-Object System.DirectoryServices.DirectorySearcher("(&(objectCategory=User)(samAccountName=$($username)))")).FindOne().GetDirectoryEntry().memberOf
}