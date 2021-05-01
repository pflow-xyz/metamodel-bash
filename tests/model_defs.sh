#!/usr/bin/env bash

. ./lib/metamodel.sh

function assert_OK() {
	if [[ $? -ne 0 ]]; then
		echo $1
		exit 1
	fi
}

function assert_EQ() {
	if [[ ! $1 =~ $2 ]]; then
		echo "expected ${1} =~ ${2}"
		exit 1
	fi
}

function counter_v1() {
	role default

	cell p0 0 10
	cell p1 1 11

	fn incP0 default
	fn decP0 default

	fn incP1 default
	fn decP1 default

	tx incP0 p0 1
	tx p0 decP0 1

	tx incP1 p1 1
	tx p1 decP1 1
}

m=$(Metamodel counter_v1)
${m}.init

assert_EQ $(${m}.type) "counter_v1"
assert_EQ $(${m}.empty_vector) 0,0
assert_EQ $(${m}.capacity_vector) 10,11

state=$(${m}.initial_vector)
assert_OK "failed to build initial vector"
assert_EQ $state 0,1


function txn() {
	local action=$1
	local multiple="${2:-1}"
	local vout=$(${m}.transform $state $action $multiple)
	if [[ $? -eq 0 ]]; then
		state=$vout
	fi
}

echo state:${state}
txn incP0 3
echo state:${state}
txn incP0 3
echo state:${state}
txn decP0
echo state:${state}
txn incP1
echo state:${state}
txn incP0
echo state:${state}
