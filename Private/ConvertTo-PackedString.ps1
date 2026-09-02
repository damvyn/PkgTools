function ConvertTo-PackedString {
	param ( [parameter(mandatory)][byte[]] $byteArray )

	[System.IO.MemoryStream] $out = new-object System.IO.MemoryStream
	$gzipStream = new-object System.IO.Compression.GzipStream $out, ([IO.Compression.CompressionMode]::Compress)
	$gzipStream.write($byteArray, 0, $byteArray.length)
	$gzipStream.close()
	$out.Close()
	return [convert]::toBase64String($out.toArray())
}