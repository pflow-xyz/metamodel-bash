#!/usr/bin/env bash

#  MIT License
#  Copyright (c) 2023 stackdump.com LLC
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#  The above copyright notice and this permission notice shall be included in all
#  copies or substantial portions of the Software.
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.

# Metamodel Constructor
# $1: model_declaration - a function name that is invoked to exec DSL code
# $2: (optional) model_id - defaults to $RANDOM

function Metamodel() {
	local model_declaration=$1
	local model_id=${2:-$RANDOM}
	echo "__mm__ $model_id $model_declaration "
}

declare -A __mm__model
declare -A __mm__role
declare -A __mm__place
declare -A __mm__place_attr
declare -A __mm__arc
declare -A __mm__arc_attr
declare -A __mm__txn
declare -A __mm__txn_attr
declare -A __mm__guard

# dispatch calls to attributes and methods
function __mm__() {
	local model_id=${1}
	local model_declaration=${2}
	local operation=${3}
	local state_or_arg=${4:-}
	local action_or_role=${5:-}
	local multiple=${6:-1}
	local label
	local prefix="${model_id}_"

	case "$operation" in
	'.init')
		__mm__prefix="${model_id}_"               # set instance prefix
		__mm__model[$model_id]=$model_declaration # index model by object-id
		$model_declaration                        # evaluate the DSL
		__mm__reindex                             # build the model
		;;                                        #
	'.prefix')
		echo $prefix # get attribute prefix used to distinguish multiple models
		;;
	'.schema')
		echo ${__mm__model[$model_id]} # return model name
		;;
	'.empty_vector')
		__mm__vector $prefix 0 # build empty vector of proper size
		;;
	'.initial_vector')
		__mm__vector $prefix initial # initial cell values
		;;
	'.capacity_vector')
		__mm__vector $prefix capacity # cell max capacity
		;;
	'.transform')
		__mm__transform $prefix $state_or_arg $action_or_role $multiple # apply a morphism
		;;
	'.transitions')
		for label in ${!__mm__txn[@]}; do
			if [[ ! $label =~ $prefix ]]; then
				continue
			fi
			echo ${__mm__txn_attr[${label}_fn]}
		done
		;;
	'.places')
		for label in ${!__mm__place[@]}; do
			if [[ ! $label =~ $prefix ]]; then
				continue
			fi
			echo ${__mm__place_attr[${label}_cell]}
		done
		;;
	'.live_transitions') # apply a morphism
		__mm__live_transitions $prefix $state_or_arg $action_or_role $multiple
		;;
	'.cell_offset')
		echo ${__mm__place_attr[${prefix}${state_or_arg}_offset]}
		;;
	'.cell_initial')
		echo ${__mm__place_attr[${prefix}${state_or_arg}_initial]}
		;;
	'.cell_capacity')
		echo ${__mm__place_attr[${prefix}${state_or_arg}_capacity]}
		;;
	'.fn_offset')
		echo ${__mm__txn_attr[${prefix}${state_or_arg}_offset]}
		;;
	'.fn_role')
		echo ${__mm__txn_attr[${prefix}${state_or_arg}_role]}
		;;
	'.to_json')
		__mm__to_json $prefix $model_id
		;;
	*)
		echo "UNDEFINED: ${operation}"
		exit 101
		;;
	esac
}

# assert label is not already in use
function __mm__assert_not_exists() {
	local prefix=${1}
	local label=${2}

	__mm__is_place ${prefix}${label}
	if [[ $? -eq 0 ]]; then
		echo ${label} place already defined
		exit 102
	fi
	__mm__is_transition ${prefix}${label}
	if [[ $? -eq 0 ]]; then
		echo ${label} transition already defined
		exit 103
	fi
}

# assert source and target are different elements
function __mm__assert_good_arc() {
	local prefix=${1}
	local source=${2}
	local target=${3}

	__mm__is_place ${prefix}${source}
	if [[ $? -eq 0 ]]; then
		__mm__is_transition ${prefix}${target}
		if [[ $? -ne 0 ]]; then
			echo "${source} -> ${target} : expect place -> transition"
			exit 104
		fi
		return 0
	fi
	__mm__is_transition ${prefix}${source}
	if [[ $? -eq 0 ]]; then
		__mm__is_place ${prefix}${target}
		if [[ $? -ne 0 ]]; then
			echo "${source} -> ${target} : expect transition -> place"
			exit 105
		fi
		return 0
	fi
	echo "bad arc"
	exit 106
}

# look for matching place by label
function __mm__is_place() {
	if [[ -z ${__mm__place[$1]} ]]; then
		return -1
	else
		return 0
	fi
}

# look for matching transition by label
function __mm__is_transition() {
	if [[ -z ${__mm__txn[$1]} ]]; then
		return -1
	else
		return 0
	fi
}

# set vector transformation
function __mm__set_delta() {
	local prefix=${1}
	local place=${2}
	local transition=${3}
	local weight=${4}

	local label="${prefix}${transition}_delta"
	local delta=${__mm__txn_attr[$label]}
	local offset=${__mm__place_attr[${prefix}${place}_offset]}
	local vector

	IFS=, read -a vector <<<$delta

	vector[$offset]=$weight

	__mm__txn_attr[$label]=$(__mm__join_by ',' ${vector[@]})
}

# declare a guard/arc that inhibits a transition
function __mm__set_guard() {
	local arc_id=${1}
	local place=${2}
	local transition=${3}
	local weight=${4}
	local vector

	__mm__is_place ${prefix}${transition}
	if [[ $? -eq 0 ]]; then
		echo "bad guard - target must be transition"
		exit 107
	fi
	__mm__is_transition ${prefix}${place}
	if [[ $? -eq 0 ]]; then
		echo "bad guard - source must be place"
		exit 107
	fi

	local label="${__mm__prefix}${transition}_${arc_id}_guard"
	local offset=${__mm__place_attr[${prefix}${place}_offset]}

	IFS=, read -a vector <<<$(__mm__vector $__mm__prefix 0)
	vector[$offset]=$weight
	__mm__guard[$label]=$(__mm__join_by ',' ${vector[@]})
}

# build model from declaration
function __mm__reindex() {
	local empty_vector=$(__mm__vector $__mm__prefix 0)
	local prefix=$__mm__prefix
	local label

	for label in ${!__mm__txn[@]}; do
		if [[ ! $label =~ $prefix ]]; then
			continue
		fi
		__mm__txn_attr[${label}_delta]=$empty_vector
	done

	for label in ${!__mm__arc[@]}; do
		if [[ ! $label =~ $prefix ]]; then
			continue
		fi

		# inhibitor arc
		if [[ "${__mm__arc_attr[${label}_guard]}" -eq 1 ]]; then
			local place=${__mm__arc_attr[${label}_source]}
			local transition=${__mm__arc_attr[${label}_target]}
			local id=${__mm__arc_attr[${label}_id]}
			local weight=$((-1 * ${__mm__arc_attr[${label}_weight]}))
			__mm__set_guard $id $place $transition $weight
			continue
		fi

		# arc
		__mm__is_place ${prefix}${__mm__arc_attr[${label}_source]}
		if [[ $? -eq 0 ]]; then
			local transition=${__mm__arc_attr[${label}_target]}
			local place=${__mm__arc_attr[${label}_source]}
			local v=-1 # tokens leave the cell
		else
			local transition=${__mm__arc_attr[${label}_source]}
			local place=${__mm__arc_attr[${label}_target]}
			local v=1 # tokens added to cell
		fi
		local weight=$(($v * ${__mm__arc_attr[${label}_weight]}))
		__mm__set_delta $prefix $place $transition $weight
	done
}

# join arrays on a single char
function __mm__join_by {
	local IFS=${1}
	shift
	echo "$*"
}

# accepts name of attribute to return as a vector
function __mm__vector() {
	local prefix=$1
	local operation=$2
	declare -a local vector_out
	local label

	for label in ${!__mm__place[@]}; do
		if [[ ! $label =~ $prefix ]]; then
			continue
		fi

		local i=${__mm__place_attr[${label}_offset]}
		if [[ ${operation} == 0 ]]; then
			vector_out[$i]=0
		else
			vector_out[$i]=${__mm__place_attr[${label}_${operation}]}
		fi
	done

	echo $(__mm__join_by ',' ${vector_out[@]})
}

# performs vector1 * (vector2 * multiple)
# returns -1 if any part of the result is negative or exceeds capacity
function __mm__vector_add() {
	local vector1
	local vector2
	local multiple
	local capacity

	IFS=, read -a vector1 <<<${1}
	IFS=, read -a vector2 <<<${2}
	multiple=${3:-1}
	IFS=, read -a capacity <<<${4}

	local vector_out
	local scalar
	for label in ${!vector1[@]}; do
		local delta=$((${vector2[$label]} * ${multiple}))
		scalar=$((${vector1[$label]} + $delta))

		if [[ ${capacity[$label]} > 0 ]] && [[ ${capacity[$label]} < $scalar ]]; then
			# store negative overflow output
			scalar=$((${capacity[$label]} - ${scalar}))
		fi
		vector_out=${vector_out}${scalar},
	done

	echo -n "${vector_out%?}" # strip last comma

	# check for negative numbers
	if [[ $vector_out =~ '-' ]]; then
		return -1
	else
		return 0
	fi
}

# evaluate inhibitor arcs
function __mm__test_guards() {
	local state=${1}
	local prefix=${2}
	local action=${3}
	local vector_out
	local empty=$(__mm__vector $prefix 0)
	for label in ${!__mm__guard[@]}; do
		if [[ ! $label =~ "${prefix}${action}_" ]]; then
			continue
		fi
		vector_out=$(__mm__vector_add $state ${__mm__guard[$label]} 1 $empty)
		if [[ $? -eq 0 ]]; then
			echo $vector_out
			return 1
		fi
	done
	return 0
}

# state transformation
function __mm__transform() {
	local prefix=${1}
	local state=${2}
	local action=${3}
	local multiple="${4:-1}"
	local guard_out
	local capacity=$(__mm__vector $prefix capacity)

	guard_out=$(__mm__test_guards $state $prefix $action)
	if [[ $? -eq 0 ]]; then
		local delta=${__mm__txn_attr[${prefix}${action}_delta]}
		__mm__vector_add $state $delta $multiple $capacity
	else
		echo guard_fail: $guard_out
		return 1
	fi
}

# state transformation
function __mm__live_transitions() {
	local prefix=${1}
	local state=${2}
	local role=${3}
	local multiple="${4:-1}"
	local out

	for label in ${!__mm__txn[@]}; do
		if [[ ! $label =~ $prefix ]]; then
			continue
		fi
		if [[ $role == ${__mm__txn_attr[${label}_role]} ]]; then
			local action=${__mm__txn_attr[${label}_fn]}
			out=$(__mm__transform $prefix $state $action $multiple)
			if [[ $? -eq 0 ]]; then
				echo $action
			fi
		fi
	done

}

function __mm__to_json() {
	local prefix=${1}
	local places_out=""
	local transitions_out=""

	for label in ${!__mm__place[@]}; do
		if [[ ! $label =~ $prefix ]]; then
			continue
		fi
		local offset=${__mm__place_attr[${label}_offset]}
		local cell=${__mm__place_attr[${label}_cell]}
		local initial=${__mm__place_attr[${label}_initial]}
		local capacity=${__mm__place_attr[${label}_capacity]}
		places_out="${places_out}\"${cell}\": {\"label\": \"${cell}\", \"offset\": ${offset},  \"initial\": \"${initial}\", \"capacity\": \"${capacity}\" },"
	done

	for label in ${!__mm__txn[@]}; do
		if [[ ! $label =~ $prefix ]]; then
			continue
		fi
		local offset=${__mm__txn_attr[${label}_offset]}
		local fn=${__mm__txn_attr[${label}_fn]}
		local role=${__mm__txn_attr[${label}_role]}
		local action=${__mm__txn_attr[${label}_fn]}
		local delta=${__mm__txn_attr[${label}_delta]}
		local guards=$(__mm__guards_json $prefix $action)
		transitions_out="${transitions_out}\"${fn}\": { \"offset\": ${offset}, \"label\": \"${fn}\", \"role\": \"${role}\", \"delta\": [${delta}], \"guards\": [${guards}] },"
	done
	local schema=${__mm__model[$model_id]}
	echo "{ \"schema\": \"${schema}\", \"places\": {${places_out::-1}}, \"transition\": {${transitions_out::-1}} }"

}

# write guard json as vectors
function __mm__guards_json() {
	local prefix=${1}
	local action=${2}
	local guards_json=""
	for label in ${!__mm__guard[@]}; do
		if [[ ! $label =~ "${prefix}${action}_" ]]; then
			continue
		fi
		guards_json="${guards_json}[${__mm__guard[$label]}],"
	done

	if [[ -n $guards_json ]]; then
		echo "${guards_json::-1}"
	fi
	return 0
}

###################### Model DSL ######################

# define an actor
function role() {
	__mm__role[${__mm__prefix}${1}_role]=$1
}

# declare a place to store tokens
function cell() {
	__mm__assert_not_exists ${__mm__prefix} ${1}
	__mm__place_attr[${__mm__prefix}${1}_offset]=${#__mm__place[@]}
	__mm__place_attr[${__mm__prefix}${1}_cell]=$1
	__mm__place_attr[${__mm__prefix}${1}_initial]=$2
	__mm__place_attr[${__mm__prefix}${1}_capacity]=$3
	__mm__place[${__mm__prefix}${1}]=$1
}

# declare a transition to move tokens between cells
function fn() {
	__mm__assert_not_exists ${__mm__prefix} ${1}
	__mm__txn_attr[$__mm__prefix${1}_offset]=${#__mm__txn[@]}
	__mm__txn_attr[$__mm__prefix${1}_fn]=$1
	__mm__txn_attr[$__mm__prefix${1}_role]=$2
	__mm__txn[${__mm__prefix}${1}]=$1
}

# declare arcs/paths between places and transitions
function tx() {
	__mm__assert_good_arc $__mm__prefix $1 $2
	local arc_id=${#__mm__arc[@]}
	__mm__arc_attr[$__mm__prefix${arc_id}_id]=$arc_id
	__mm__arc_attr[$__mm__prefix${arc_id}_source]=$1
	__mm__arc_attr[$__mm__prefix${arc_id}_target]=$2
	__mm__arc_attr[$__mm__prefix${arc_id}_weight]=${3:-1} # default=1
	__mm__arc_attr[$__mm__prefix${arc_id}_guard]=${4:-0}  # 0=arc, 1=guard
	__mm__arc[$__mm__prefix${arc_id}]=$arc_id
}

# declare an inhibitor arc - provides conditional tx live-ness
function guard() {
	tx ${1} ${2} ${3:-1} 1
}
