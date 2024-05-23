# Parse the output of llvm-dwarfdump to extract unique file names.

/DW_AT_(call|decl)_file/ {
	if ($2 ~ /<built-in>/) next;
	if (!seen[$2]++) print substr($2, 3, length($2)-4)
}
