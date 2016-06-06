#!/usr/bin/env bash
#

ESC=$'\e'
C_RED=$ESC[31m
C_GREEN=$ESC[32m
C_CYAN=$ESC[36m
C_YELLOW=$ESC[33m
C_OFF=$ESC[39m

OK=ok
NOT_OK='not ok'

CASES=()        # A temporary stack for storing test case name.

# test case functinon name --> case description
declare -gA CASE_DESCRIPTIONS

CASE_STATE=;    # SKIP or TODO.
STATE_REASON=;  # reason for the above state.

TESTS=()        # A list of test case function names accumulated so far.
                # These are candidates for run_test().


# Accumulate each `@setup` call's arguments for the current defining
# test case.
SETUPS=()       # ("setup_func1 setup_func2 ..." ...)

# test case function name --> a string of space separated list of
# setup function names.
declare -gA TEST_SETUPS

TEST_STATUS=0   # The last test run status; 0 means OK.


die() { echo "Bail out!"; echo "$@" >&2; exit 1; }


# Usage: `Case` `[description]`
#
# Mark the beginning of a test case, optionally with a case description.
# This command should be followed immediately with a `Do()` function
# definition, which should be followed immediately with an `End` command.
#
# Example:
#
#     Case "test case description..."; Do () {
#         ...asserts and checks go here...
#     }
#     End Case
#
# Here the `Do()` provides the actual test case function definition,
# inside which you can run your checks. The status(i.e., 0 or 1) of a test
# case is the return status of its `Do` function call OR(`||`, i.e., the
# logical OR) together with the status of all `check` calls in it.
#
Case () {
    if [[ ${#CASES[*]} != 0 ]]; then
        die "ERROR: Nested test cases not supported."
    fi
    if [[ $* == *#* ]]; then
        die "ERROR: Sorry, '#' is not allowed in test case descriptions."
    fi
    CASES+=("$*")
}

# Usage: `End Case`
#
# Mark the end of a test case definition.
# This command should be run immediately after a `Do()` definition.
#
# The first argument is reserved, and currently can only be `Case`.
# The rest of arguments can be anything and will be ignored.
#
# See `Case()` above.
#
End () {
    if [[ ${#CASES[*]} -eq 0 ]]; then
        die "ERROR: No matching 'Case' command!"
    fi
    if (( ! ${#SETUPS[*]} )); then
        SETUPS+=("")
    fi

    local fbody; fbody=$(declare -f Do | sed 1d)
    [[ ${fbody:-} ]] || die "ERROR: No matching 'Do' definition!"
    unset -f Do

    local desc=${CASES[-1]}; unset 'CASES[-1]'

    local setup_funcs funcname
    for setup_funcs in "${SETUPS[@]}"; do
        funcname=Test_$(( ${#TESTS[*]} + 1 ))
        eval "$funcname () $fbody"

        CASE_DESCRIPTIONS[$funcname]=$desc
        if [[ ${setup_funcs:-} ]]; then
            TEST_SETUPS[$funcname]=$setup_funcs
        fi
        TESTS+=($funcname)
    done
    SETUPS=()
}

# Check the last assert definition and set the status of the
# current test case.
#
# This command is usually invoked immediately after an `assert()`
# definition.
#
# Example:
#
#     assert () { (( 1 + 1 == 2 )); }; check
#
check () {
    assert; local rc=$?
    set +x
    if [[ $rc -ne 0 ]]; then
        echo "$C_RED$(declare -f assert)$C_OFF" >&2
    fi
    TEST_STATUS=$(($TEST_STATUS || $rc))
    set -x
}

# Test result directives. These should only be used at
# the test case level.
#

# Mark the test case as one to be skipped.
# This command must be used together with a `return` statement.
#
SKIP () { CASE_STATE=SKIP; STATE_REASON=$*; }

# Mark the test case as todo, and as such, this test
# result will won't count towards the final results.
#
TODO () { CASE_STATE=TODO; STATE_REASON=$*; }


# Specify a list of setup functions for its following test case.
#
# A setup function can be any function. It is used to set up the
# test fixture(i.e., test data or whatever needed for its tests),
# and when the test case is run, such setup function will call
# the actuall test case function, and therefore giving it access
# to all its local variables via dynamic scoping.
#
# Example:
#
#     @setup A B C
#     Case MyTest; Do () { ...; }; End Case
#
# To run the `MyTest` case, we'll run `A()`, which will call `B()` at the
# end, which will call `C()` at the end, which will call `MyTest`'s 
# test function at the end.
#
# In rare cases, you might want/need to specify where in a setup
# function the next setup function is called. This can be accomplished
# by the `: __HOLE__` null command. If specified, the line that starts
# with such null command will be replaced by the call to the next setup
# function.
#
# It's also possible to have multiple `@setup` for a test case.
# For example:
#
#     @setup A B
#     @setup A C
#     Case MyTest; Do () { ...; }; End Case
#
# This will actually create two test cases, with the same test case
# function, with different setups; one for `@setup A B` and the other
# for `@setup A C`. This way, you can easily prepare different fixtures
# to run your test case.
#
@setup () { SETUPS+=("$*"); }


# Run the test cases, producing TAP style outputs.
#
run_tests () {
    local test_func target case_desc setups directive

    echo 1..${#TESTS[*]}

    for test_func in "${TESTS[@]}"; do

        case_desc=${CASE_DESCRIPTIONS[$test_func]}
        echo "${C_CYAN}---$test_func: $case_desc $C_OFF" >&2

        setups=(${TEST_SETUPS[$test_func]:-})
        if (( ${#setups[*]} )); then
            _hook_up ${setups[*]} $test_func
            target=${setups%% *}_hooked
        else
            target=$test_func
        fi

        CASE_STATE=; STATE_REASON=; TEST_STATUS=0

        set -x
        $target; TEST_STATUS=$(($TEST_STATUS || $?))
        set +x

        directive=${CASE_STATE:+" # $CASE_STATE${STATE_REASON:+" $STATE_REASON"}"}
        echo "${OK[$TEST_STATUS]:-$NOT_OK} ${test_func##*_} - $case_desc$directive"

        local setup_func
        while (( ${#setups[*]} )); do
            setup_func=${setups[-1]}
            if declare -F ${setup_func}_teardown >/dev/null; then
                ${setup_func}_teardown 
            fi
            unset -f ${setup_func}_hooked
            unset 'setups[-1]'
        done
    done
} 2> >(sed '/^++* set +x$/d; /^++* TEST_STATUS=/d')



_hook_up () {
    local funcs src1 chain=()
    local opts=$- oIFS=$IFS

    # e.g., funcs=(test_func setup_func3 setup_func2   setup_func1)
    #              ^^^^^^^^^             ^^^^^^^^^^^   ^^^^^^^^^^^
    #                last                $second       $first
    local i=$(($# + 1)) funcs=()
    while (( --i )); do funcs+=(${!i}); done

    while (( ${#funcs[*]} > 1 )); do

        # take the last two items off the funcs
        local first=${funcs[-1]}; second=${funcs[-2]}; unset 'funcs[-1]'

        # get the source code for the function to be hooked
        src1=$(declare -f $first | sed "1s/^$first/${first}_hooked/"; exit $PIPESTATUS) || return $?

        # if there's a __HOLE__ marker indicating where we call $second in $first
        if [[ $src1 =~ $'\n'\ *:\ +__HOLE__ ]]; then
            src1=$(sed "s/^ *:  *__HOLE__/$second/" <<<"$src1")
        else
            # just call $second as the last command in $first

            set -f; IFS=$'\n'
            local lines=($src1)
            local last=${lines[-1]}

            # if this isn't the last iteration
            if [[ ${#funcs[*]} -gt 1 ]]; then
                lines[${#lines[*]} - 1]=${second}_hooked
            else
                lines[${#lines[*]} - 1]=$second  # this is the test_func
            fi
            lines+=("$last")
            src1=${lines[*]}
            IFS=$oIFS; set -$opts
        fi
        chain+=("$src1")
   done

   IFS=$'\n'; eval "${chain[*]}"; IFS=$oIFS
}
