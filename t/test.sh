#!/usr/bin/env bash
set -ex


output=$(prove -ve bait ./bait.t :: -C 2>&1) || true
[[ $output == *'Failed 2/14 subtests'* ]]

[[ $output == *"
=========================================
Failed Test_3 - A simple test case that fails
--- Failed asserts ---------------------
--- Captured stdout --------------------
# This will fail
--- Captured stderr --------------------
----------------------------------------
"* ]]

assert () { : a failing assert; false; }

[[ $output == *"
=========================================
Failed Test_5 - A test case with a few checks
--- Failed asserts ---------------------
$(declare -f assert)

+ assert
+ : a failing assert
+ false
+ return_code=1

--- Captured stdout --------------------
--- Captured stderr --------------------
hello
----------------------------------------
"* ]]

# Test option -i
output=$(
    prove -ve bait ./bait.t :: -i '*dummy*' 2>&1 \
      | grep -v '# SKIP' | grep dummy | wc -l
)
[[ $output == 2 ]]

# Test option -t
output=$(
    prove -ve bait ./bait.t :: -t 1,4 2>&1 \
      | grep -v '# SKIP' | egrep '^ok (1|4)\b' | wc -l
)
[[ $output == 2 ]]

# Test option -T and -x
output=$(prove -ve bait ./bait.t :: -T 3,5 -x '*SKIP*' 2>&1)
[[ $(echo "$output" | grep '# SKIP' | wc -l) == 3 ]]
[[ $(echo "$output" | grep -v '# SKIP' | egrep '^ok (3|5|6)\b' | wc -l) == 0 ]]
