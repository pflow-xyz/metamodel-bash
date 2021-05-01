#!/usr/bin/env bash
for t in  ./tests/*.test.sh ; do
	echo $t
	echo ------------------------------
	$t
	echo
done
