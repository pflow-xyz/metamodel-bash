#!/usr/bin/env bash

. ./tests/tictactoe.model.sh
. ./tests/utils.sh

function before_all() {
	m=$(Metamodel octoe_v1)
	${m}.init # load the model

	echo transitions: $(${m}.transitions)
	echo places: $(${m}.places)
}

function move() {
	local action=$1
	local multiple="${2:-1}"
	local vout
	local assert="${3:-assert_OK}"
	vout=$(${m}.transform $state $action $multiple)
	$assert "txn failed ${action} => ${vout}"
	if [[ $? -eq 0 ]]; then
		state=$vout
	fi
}

function valid_moves() {
	if [[ $((${#board[@]} % 2)) -eq 0 ]]; then
		${m}.live_transitions $state PlayerX 1
	else
		${m}.live_transitions $state PlayerO 1
	fi
}

function test_invariants() {
	assert_EQ $(${m}.schema) octoe_v1
	assert_EQ $(${m}.empty_vector) 0,0,0,0,0,0,0,0,0,0,0
	assert_EQ $(${m}.capacity_vector) 1,1,1,1,1,1,1,1,1,1,1
	assert_EQ $(${m}.initial_vector) 1,0,1,1,1,1,1,1,1,1,1
	assert_EQ $(${m}.cell_offset p11) 6
	assert_EQ $(${m}.cell_initial p11) 1
	assert_EQ $(${m}.cell_capacity p11) 1
	assert_EQ $(${m}.fn_offset X11) 7
	assert_EQ $(${m}.fn_role X11) PlayerX
	${m}.to_json
}

# The board datastructure is a dual representation of the state vector.
# we can use it as a convenient way to test for win conditions
function is_winner() {
	winset="${1},${1},${1}"

	if [[ "${board[p00]},${board[p11]},${board[p22]}" == "${winset}" || \
		"${board[p02]},${board[p11]},${board[p20]}" == "${winset}" || \
		"${board[p00]},${board[p01]},${board[p02]}" == "${winset}" || \
		"${board[p10]},${board[p11]},${board[p12]}" == "${winset}" || \
		"${board[p20]},${board[p21]},${board[p22]}" == "${winset}" || \
		"${board[p00]},${board[p10]},${board[p20]}" == "${winset}" || \
		"${board[p01]},${board[p11]},${board[p21]}" == "${winset}" || \
		"${board[p02]},${board[p12]},${board[p22]}" == "${winset}" ]]; then
		return 0
	else
		return 1
	fi
}

function game_is_over() {
	if [[ ${#board[@]} < 5 ]]; then
		return 1
	fi
	if [[ $((${#board[@]} % 2)) -eq 0 ]]; then
		is_winner O
		if [[ $? -eq 0 ]]; then
			stats[O]=$((${stats[O]} + 1))
			echo O Wins
			return 0
		fi
	else
		is_winner X
		if [[ $? -eq 0 ]]; then
			stats[X]=$((${stats[X]} + 1))
			echo X Wins
			return 0
		fi
	fi
	return 1
}

# The "little language" formed from the petri-net labels
# serves as a coding for game-state
#
# Formal verification of this program is possible
# by observing the correspondence between model and code.
function play() {
	local action=$1
	move $action 1 assert_OK
	board["p${action:1:2}"]=${action:0:1} # X11 becomes p11=X
}

function play_random_game() {
	state=$(${m}.initial_vector)
	echo "new_game => ${state}"
	board=()

	local role
	local live=($(valid_moves))
	while [[ ${#live[@]} -gt 0 ]]; do
		local i=$(($RANDOM % ${#live[@]}))
		local action=${live[$i]} # choose random action
		play $action
		echo "     ${action} => ${state}"
		live=($(valid_moves))
		game_is_over && return
	done
	echo "Draw"
}

declare -A stats
declare -A board
before_all
test_invariants

while true; do
	play_random_game
	game=$(($game + 1))
	echo
	echo "wins after ${game} game(s)"
	echo "-------------------"
	echo X: ${stats[X]} O: ${stats[O]}
	break # Just play one
done
