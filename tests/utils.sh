
function assert_EQ() {
	if [[ ! $2 == $1 ]]; then
		echo "expected ${1} == ${2}"
		exit 1
	fi
}

function assert_OK() {
	if [[ $? -ne 0 ]]; then
		echo ${1:-"expected assert_OK"}
		exit 1
	fi
	return $?
}

function assert_FAIL() {
	if [[ $? -eq 0 ]]; then
		echo ${1:-"expected assert_FAIL"}
		exit 1
	fi
	return 1
}


