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
	cell p1 1 10

	fn incP0 default 1,0
	fn decP0 default -1,0

	fn incP1 default 0,1
	fn decP1 default 0,-1
}

m=$(Metamodel counter_v1)
${m}.init

state=$(${m}.initial_vector)

assert_OK "failed to build initial vector"
assert_EQ $state 1,0 # FIXME: order is not guaranteed in maps
assert_EQ $(${m}.empty_vector) 0,0
assert_EQ $(${m}.capacity_vector) 10,10

function tx() {
	local action=$1
	local vout=$($(${m}.transform $state $action))
	if [[ $? -eq 0 ]]; then
		state=$vout
	fi
}

echo state:${state}
tx incP0
echo state:${state}
tx incP0
echo state:${state}
tx incP1
echo state:${state}
tx incP0
echo state:${state}
