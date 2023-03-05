#!/usr/bin/env bash

. ./tests/tictactoe.model.sh
. ./tests/utils.sh

function before_all() {
	m=$(Metamodel octoe_v1)
	${m}.init # load the model

	#echo transitions: $(${m}.transitions)
	#echo places: $(${m}.places)
}

function test_json_output() {
	echo $(${m}.to_json)
}

before_all
test_json_output
