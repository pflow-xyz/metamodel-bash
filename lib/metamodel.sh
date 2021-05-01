#!/usr/bin/env bash

#set -u # KLUDGE some issues with using strict mode

# changed to a random id for each model 'instance'
__petriflow__model_dsl_prefix="0000_"

# metamodel data structures
declare -A __petriflow__models
declare -A __petriflow__roles
declare -A __petriflow__places
declare -A __petriflow__places_attribs
declare -A __petriflow__transitions
declare -A __petriflow__transitions_attribs
declare -A __petriflow__arcs
declare -A __petriflow__arcs_attribs

# constructor
function Metamodel() {
	echo "__Metamodel__ $RANDOM ${1} "
}

function __Metamodel__() {
	local id="$1" # object-id
	local model=$2
	local attrib="$3"
	local state="${4:-}"
	local action="${5:-}"
	local multiple="${6:-1}"

	case "$attrib" in
	'.init')
		__petriflow__model_dsl_prefix="${id}_" # set instance prefix
		__petriflow__models[$id]=$model        # record which model was loaded by object-id
		$model                                 # evaluate the DSL
		__petriflow__reindex                   # build the model
		__petriflow__model_dsl_prefix="0000_"  # set back to default
		;;
	'.type')
		echo ${__petriflow__models[$id]}
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
		__petriflow__transform ${id}_ $state $action $multiple
		;;
	*)
		echo "UNDEFINED: ${attrib}"
		exit -1
		;;
	esac
}

function __petriflow__is_place() {
	if [[ "${__petriflow__places[$1]}x" == "x" ]]; then
		return -1
	else
		return 0
	fi
}

function __petriflow__is_transition() {
	if [[ "${__petriflow__transitions[$1]}x" == "x" ]]; then
		return -1
	else
		return 0
	fi
}

function __petriflow__set_delta() {
	local prefix=$1
	local place=$2
	local transition=$3
	local weight=$4

	local k="${prefix}${transition}_delta"
	local d=${__petriflow__transitions_attribs[$k]}
	local o=${__petriflow__places_attribs[${prefix}${place}_offset]}

	IFS=, read -a arr1 <<<$d

	arr1[$o]=$weight

	__petriflow__transitions_attribs[$k]=$(__petriflow__join_by ',' ${arr1[@]})
}

function __petriflow__reindex() {

	local empty_vector=$(__petriflow__vector $__petriflow__model_dsl_prefix 0)

	for label in "${!__petriflow__transitions[@]}"; do
		__petriflow__transitions_attribs[${label}_delta]=$empty_vector
	done

	for label in "${!__petriflow__arcs[@]}"; do
		if [[ $label =~ $__petriflow__model_dsl_prefix ]]; then
			__petriflow__is_place ${__petriflow__model_dsl_prefix}${__petriflow__arcs_attribs[${label}_source]}
			if [[ $? -eq 0 ]]; then
				local t=${__petriflow__arcs_attribs[${label}_target]}
				local p=${__petriflow__arcs_attribs[${label}_source]}
				local w=-1
			else
				local t=${__petriflow__arcs_attribs[${label}_source]}
				local p=${__petriflow__arcs_attribs[${label}_target]}
				local w=1
			fi
			__petriflow__set_delta $__petriflow__model_dsl_prefix $p $t $w
		fi
	done
}

# join arrays on a single char
function __petriflow__join_by {
	local IFS="$1"
	shift
	echo "$*"
}

# accepts name of attribute to collect into a csv/vector
function __petriflow__vector() {
	local prefix=$1
	local attrib=$2
	declare -a local vout

	for label in "${!__petriflow__places[@]}"; do
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

	local multiple=${3:-1}

	local out=""
	for k in ${!arr1[@]}; do
		local delta=$((${arr2[$k]} * ${multiple}))
		out=$out$((${arr1[$k]} + $delta)),
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
	local multiple="${4:-1}"
	echo $(__petriflow__vadd $state ${__petriflow__transitions_attribs[${prefix}${action}_delta]} ${multiple})
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
	__petriflow__transitions[${__petriflow__model_dsl_prefix}${1}]=${1}
}

function tx() {
	arc_id=${#__petriflow__arcs[@]}
	__petriflow__arcs_attribs[$__petriflow__model_dsl_prefix${arc_id}_id]=${arc_id}
	__petriflow__arcs_attribs[$__petriflow__model_dsl_prefix${arc_id}_source]=$1
	__petriflow__arcs_attribs[$__petriflow__model_dsl_prefix${arc_id}_target]=$2
	__petriflow__arcs_attribs[$__petriflow__model_dsl_prefix${arc_id}_weight]=${3:-1}
	__petriflow__arcs[$__petriflow__model_dsl_prefix${arc_id}]=${arc_id}
}

function guard() {
	# FIXME: add inhibitor arcs
	#__petriflow__arcs_attribs[$__petriflow__model_dsl_prefix${arc_id}_inhibit]=${1}
	return
}
