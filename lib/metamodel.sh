#!/usr/bin/env bash

#set -u

# changed to a random id for each model 'instance'
__petriflow__model_dsl_prefix="0000_"

# metamodel data structures
declare -A __petriflow__models
declare -A __petriflow__roles
declare -A __petriflow__places
declare -A __petriflow__places_attribs
declare -A __petriflow__transitions
declare -A __petriflow__transitions_attribs

# constructor
function Metamodel() {
	echo "__Metamodel__ $RANDOM ${1} "
}

function __Metamodel__() {
	local id="$1" # randomid
	local model=$2
	local attrib="$3"
	local state="${4:-}"
	local action="${5:-}"

	case "$attrib" in
	'.init')
		__petriflow__model_dsl_prefix="${id}_" # set instance prefix
		__petriflow__models[model]=$id         # record that model was loaded
		$model                                 # build the model
		__petriflow__model_dsl_prefix="0000_"  # set back to default
		;;
	'.empty_vector')
		__petriflow__vector "${id}_" 0
		;;
	'.initial_vector')
		__petriflow__vector "${id}_" initial
		;;
	'.capacity_vector')
		__petriflow__vector "${id}_" capacity
		;;
	'.transform')
		echo "__petriflow__transform ${id}_ $state $action"
		;;
	*)
		echo "UNDEFINED: ${attrib}"
		exit -1
		;;
	esac
}

# join arrays on a single char
function __petriflow__join_by { local IFS="$1"; shift; echo "$*"; }

# accepts name of attribute to collect into a csv/vector
function __petriflow__vector() {
	local prefix=$1
	local attrib=$2
	declare -a local vout

	for label in "${!__petriflow__places[@]}"; do
		# REVIEW: does order == offset here ?
		if [[ $label =~ $prefix ]]; then
			local i=${__petriflow__places_attribs[${label}_offset]}
			if [[ "${attrib}x" == "0x" ]]; then
				vout[$i]=0
			else
				vout[$i]=${__petriflow__places_attribs[${label}_${attrib}]}
			fi
		fi
	done

	echo $(__petriflow__join_by ',' ${vout[@]})

}

# add two vectors
# returns -1 if any part of the result is negative
function __petriflow__vadd() {
	local arr1
	local arr2

	IFS=, read -a arr1 <<<$1
	IFS=, read -a arr2 <<<$2

	out=""
	for k in ${!arr1[@]}; do
		out=$out$((${arr1[$k]} + ${arr2[$k]})),
	done

	echo -n "${out%?}" # strip last comma

	# check for negative numbers
	if [[ ! $out =~ '-' ]]; then
		return 0
	else
		return -1
	fi
}

function __petriflow__transform() {
	local prefix=$1
	local state=$2
	local action=$3
	echo $(__petriflow__vadd $state ${__petriflow__transitions_attribs[${prefix}${action}_delta]})
}

function __petriflow__assert_modeling() {
	if [[ __petriflow__model_dsl_prefix == "0000_" ]]; then
		echo "models must be loaded by Metamodel constructor"
		exit -2
	fi
}

################ DSL ################

# define an actor
function role() {
	__petriflow__assert_modeling
	__petriflow__roles[${__petriflow__model_dsl_prefix}${1}_role]=$1
}

# declare a place to store tokens
function cell() {
	__petriflow__assert_modeling
	__petriflow__places_attribs[${__petriflow__model_dsl_prefix}${1}_offset]=${#__petriflow__places[@]} # FIXME strict mode fails here
	__petriflow__places_attribs[${__petriflow__model_dsl_prefix}${1}_cell]=$1
	__petriflow__places_attribs[${__petriflow__model_dsl_prefix}${1}_initial]=$2
	__petriflow__places_attribs[${__petriflow__model_dsl_prefix}${1}_capacity]=$3
	__petriflow__places[${__petriflow__model_dsl_prefix}${1}]=${1}
}

# declare a transition to move tokens between cells
function fn() {
	__petriflow__assert_modeling
	__petriflow__transitions_attribs[$__petriflow__model_dsl_prefix${1}_offset]=${#__petriflow__transitions[@]}
	__petriflow__transitions_attribs[$__petriflow__model_dsl_prefix${1}_fn]=$1
	__petriflow__transitions_attribs[$__petriflow__model_dsl_prefix${1}_role]=$2
	__petriflow__transitions_attribs[$__petriflow__model_dsl_prefix${1}_delta]=$3
	__petriflow__transitions[${__petriflow__model_dsl_prefix}${1}]=${1}
}
