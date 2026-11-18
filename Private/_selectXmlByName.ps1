function _selectXmlByName {
	# Namespace-agnostic child (or descendant with -Deep) element lookup
	param($Node, [string]$Name, [switch]$Deep)

	$axis = if ($Deep) { './/' } else { './' }
	$Node.SelectNodes("$axis*[local-name()='$Name']")
}
