#!/usr/bin/env bait

test_data1 () { local data=42; }
test_data2 () { local data=69; }

@setup test_data1
@setup test_data2
Case "An Example Test Case Definition" {
    [[ $data -ge 42 ]]
}

Case "Another example with assert checks" {
    assert (( 1 + 1 == 2 ))
    assert { : Check if www.google.com is up
        local url=https://www.google.com/ 
        [[ $(curl -I -L -sf -w '%{http_code}\n' "$url" | tail -1) == 200 ]]
    }
}
