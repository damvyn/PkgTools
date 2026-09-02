function ConvertTo-UnPackedBytes {
	param ( [parameter(mandatory)][string] $packedString )

	$in = new-object System.IO.MemoryStream( , [convert]::fromBase64String($packedString))
	$out = new-object System.IO.MemoryStream
	$gzipStream = new-object System.IO.Compression.GzipStream $in, ([IO.Compression.CompressionMode]::Decompress)
	$gzipStream.copyTo($out)
	$gzipStream.close()
	$in.close()
	$out.close()
	return $out.toArray()
}