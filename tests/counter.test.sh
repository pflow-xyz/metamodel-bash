#!/usr/bin/env bash

. ./lib/metamodel.sh
. ./tests/utils.sh

function counter_v1() {
	role admin
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

	# add a conditional to decrement p0
	cell flag 1 1
	fn clearFlag admin
	tx flag clearFlag
	guard flag decP0
}

# Test model declaration
m=$(Metamodel counter_v1)
${m}.init

assert_EQ $(${m}.schema) "counter_v1"
assert_EQ $(${m}.empty_vector) 0,0,0
assert_EQ $(${m}.capacity_vector) 10,11,1

state=$(${m}.initial_vector)
assert_EQ $state 0,1,1


# test internal functions
prefix=$(${m}.prefix)
__mm__is_transition "${prefix}flag"
assert_FAIL 'flag should not be a transition'

__mm__is_place "${prefix}flag"
assert_OK 'expected flag to be a place'

__mm__is_transition "${prefix}clearFlag"
assert_OK 'expected clearFlag to be a transition'

__mm__is_place "${prefix}clearFlag"
assert_FAIL 'clearFlag should not be a place'


# Test morphisms
function txn() {
	local action=$1
	local multiple="${2:-1}"
	local vout
	local assert="${3:-assert_OK}"
	vout=$(${m}.transform $state $action $multiple)
	$assert "txn failed ${action} => ${vout}"
	if [[ $? -eq 0 ]] ; then
		state=$vout
	fi
}

# bad output state p0 < 0
txn decP0 1 assert_FAIL

# increment
txn incP0
echo state:${state}

# guard inhibits action
txn decP0 1 assert_FAIL

# remove inhibition flag
txn clearFlag
echo state:${state}

# decrement
txn decP0
echo state:${state}

# trigger action with multiple
txn incP1 3
echo state:${state}

# try to exceed 11 capacity
txn incP1 5 assert_FAIL
