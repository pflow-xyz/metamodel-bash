#!/usr/bin/env bash

. ./lib/metamodel.sh

function assert_OK() {
	if [[ $? -ne 0 ]]; then
		echo $1
		exit 1
	fi
}

function assert_EQ() {
	if [[ ! $2 =~ $1 ]]; then
		echo "expected ${1} =~ ${2}"
		exit 1
	fi
}

function octoe_turns_x() {
	tx turnX "X${1}0" 1
	tx turnX "X${1}1" 1
	tx turnX "X${1}2" 1

	tx "X${1}0" turnO 1
	tx "X${1}1" turnO 1
	tx "X${1}2" turnO 1
}

function octoe_turns_o() {
	tx turnO "O${1}0" 1
	tx turnO "O${1}1" 1
	tx turnO "O${1}2" 1

	tx "O${1}0" turnX 1
	tx "O${1}1" turnX 1
	tx "O${1}2" turnX 1
}

function octoe_moves_x() {
	fn "X${1}0" PlayerX
	fn "X${1}1" PlayerX
	fn "X${1}2" PlayerX

	tx "p${1}0" "X${1}0"
	tx "p${1}1" "X${1}1"
	tx "p${1}2" "X${1}2"
}

function octoe_moves_o() {
	fn "O${1}0" PlayerO
	fn "O${1}1" PlayerO
	fn "O${1}2" PlayerO

	tx "p${1}0" "O${1}0"
	tx "p${1}1" "O${1}1"
	tx "p${1}2" "O${1}2"
}

# decare a row of the board
function octoe_row() {

	cell "p${1}0" 1 1
	cell "p${1}1" 1 1
	cell "p${1}2" 1 1

	octoe_moves_x $1
	octoe_moves_o $1

	octoe_turns_x $1
	octoe_turns_o $1
}


function octoe_v1() {
	role PlayerX
	role PlayerO

	cell turnX 1 1
	cell turnO 0 1

	octoe_row 0
	octoe_row 1
	octoe_row 2
}

m=$(Metamodel octoe_v1)
${m}.init

assert_EQ $(${m}.type) "octoe_v1"
assert_EQ $(${m}.empty_vector) 0,0,0,0,0,0,0,0,0,0,0 
assert_EQ $(${m}.capacity_vector) 1,1,1,1,1,1,1,1,1,1,1 

state=$(${m}.initial_vector)
assert_OK "failed to build initial vector"
assert_EQ $state 1,0,1,1,1,1,1,1,1,1,1 


function txn() {
	local action=$1
	local vout=$(${m}.transform $state $action)
	if [[ $? -eq 0 ]]; then
		state=$vout
	fi
}

echo state:${state}
txn X11
echo state:${state}
txn O10
echo state:${state}
txn X00
echo state:${state}
txn O12
echo state:${state}
txn X22
