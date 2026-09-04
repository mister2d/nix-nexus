{
  # TPM-sealed keys. The private key cannot leave the chip.
  # Each host needs its own key.
  # Keys use P-256. Petunia's TPM fails to sign P-384 with TPM_RC_SIZE.
  tpmPersonal = [
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNFB6pgRk5PE1xMS3TlfOaJe61nDIk+yuJmuxkrtGMLZYVXBqqYnr/IKRLfX6DLIGeEOCTUJbGxXvFhoYUAmC7E= sony (TPM)"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNXL5V23wci0ARBKtji+yLad2Mg0pxIflmq2clUoNVQabpYQbwhIgDHcui1CBqZnA0FdDuVtnsrWzI0XMi3GvQI= ddukes@sweet16 personal (TPM)"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBwldrZh2sFdX5Z3IyizIlgYBGKLz31t90zokoU/XLcsHGLfZW8RbDwz4c1hGGdjCDlV5eaTMipeqF8a59qiN30= ddukes@petunia personal (TPM)"
  ];
}
