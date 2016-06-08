#!/usr/bin/env bait -n
#
# vim: set ft=sh:

Case {
    : An empty test case without description.
}

Case "A simple test case that suceeds" { true; }
Case "A simple test case that fails" { echo "# This will fail"; false; }
Case "A test case is just a function" { declare -f Test_4; }

Case "A test case with a few checks" {
    assert (( 2 > 1 && 1 + 1 == 2 ))

    local greeting="hello world"
    assert [[ "$greeting" == "hello world" ]]

    assert : a failing assert; false

    assert date

    Case { echo "Nested test case won't be run"; } 
}


Case "Test the SKIP directive" { SKIP "skipping..."; return; false; } 
Case "Test the TODO directive" { TODO "still a work in progress..."; false; } 

pid=$$
Case "A test case that runs in a subshell" (
    assert [[ $BASHPID != "$pid" ]]
)


my_fixture() {
    local data=abc123
}
my_fixture_teardown() { echo 'tearing down resources...'; }

test_data() {
    local data2=${data}xyz
}

@setup my_fixture test_data
Case "Testing fixtures..." {
    assert [[ $data == abc123 ]]
    assert [[ $data2 == abc123xyz ]]
}


test_data2 () { 
    local line1 line2 line3
    read -r line1; read -r line2; read -r line3
    : __HOLE__
} < <(
    echo line1
    echo line2
    echo line3
    )

@setup test_data2
Case "Test case using fixture and redirection" {
    assert {
        [[ $line1 = line1 && $line2 = line2 && $line3 = line3 ]]
    }; check
}


fixture1() { local data=fixture1data; }
fixture2() { local data=fixture2data; }

@setup fixture1
@setup fixture2
Case "Test multiple fixture setups" {
    [[ $data == fixture?data ]]
}
