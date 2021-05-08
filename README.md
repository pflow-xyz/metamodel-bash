petriflowsh
-----------

Petri-nets in pure bash.


## Usage


```bash
# include the lib
. ./lib/metamodel.sh

# write a Petri-net using the provided dsl
function counter_v0() {
	role default

	# store count w/ max 10
	cell p0 0 10

	# count up
	fn incP0 default
	tx incP0 p0 1

	# count down
	fn decP0 default
	tx p0 decP0 1
}

# 1. load it
m=$(Metamodel counter_v0)
${m}.init

# 2. use it to compute transformations
local state
local action=incP0
local multiple=1

# 3. profit
state=$(${m}.initial_vector)
state=$(${m}.transform $state $action $multiple)
```
