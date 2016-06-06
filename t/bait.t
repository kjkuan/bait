# vim: set ft=sh:

source bait.sh

Case; Do () {
    : An empty test case without description.
}
End Case

Case "A simple test case that suceeds"; Do () { true; }; End Case
Case "A simple test case that fails"; Do () { echo "# This will fail"; false; }; End Case
Case "A test case is just a function"; Do () { declare -f Test_4; }; End Case

Case "A test case with a few checks"; Do () {
    assert () { (( 2 > 1 && 1 + 1 == 2 )); }; check

    local greeting="hello world"
    assert () { [[ "$greeting" == "hello world" ]]; }; check

    assert () { : a failing assert; false; }; check

    assert () { date; }; check

    Case; Do () { echo "Nested test case won't be run"; }; End Case
}
End Case

Case "Test the SKIP directive"; Do () { SKIP "skipping..."; return; false; }; End Case
Case "Test the TODO directive"; Do () { TODO "still a work in progress..."; false; }; End Case

pid=$$
Case "A test case that runs in a subshell"; Do () (
    assert () { [[ $BASHPID != "$pid" ]]; }; check
)
End Case

my_fixture() {
    local data=abc123
}
my_fixture_teardown() { echo 'tearing down resources...'; }

test_data() {
    local data2=${data}xyz
}

@setup my_fixture test_data
Case "Testing fixtures..."; Do () {
    assert () {  [[ $data == abc123 ]]; }; check
    assert () {  [[ $data2 == abc123xyz ]]; }; check
}
End Case

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
Case "Test case using fixture and redirection"; Do () {
    assert () {
        [[ $line1 = line1 && $line2 = line2 && $line3 = line3 ]]
    }; check
}
End Case

fixture1() { local data=fixture1data; }
fixture2() { local data=fixture2data; }

@setup fixture1
@setup fixture2
Case "Test multiple fixture setups"; Do () {
    [[ $data == fixture?data ]]
}
End Case

run_tests
