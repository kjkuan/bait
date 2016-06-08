What is it?
-------------
Bait is a small test framework in Bash.

It produces TAP style test outputs, and unlike most of the test tools in Bash,
it doesn't require you to run every test in its own subprocess.

I'm not sure what it might be good for yet, but I had fun implementing it
and like how it has turned out so far. I hope it might be useful to you.

Suggestions, bug reports, or pull requests are most welcomed!

```bash
# --- FILE: t/example.t --------
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
# -----------------------------
```

```
$ prove -ve bait t/example.t
t/example.t .. 
1..3
ok 1 - An Example Test Case Definition
ok 2 - An Example Test Case Definition
ok 3 - Another example with assert checks
---Test_1: An Example Test Case Definition 
+ test_data1_hooked
+ local data=42
+ Test_1
+ [[ 42 -ge 42 ]]
---Test_2: An Example Test Case Definition 
+ test_data2_hooked
+ local data=69
+ Test_2
+ [[ 69 -ge 42 ]]
---Test_3: Another example with assert checks 
+ Test_3
+ check
+ assert
+ ((  1 + 1 == 2  ))
+ local rc=0
ok
All tests successful.
Files=1, Tests=3,  0 wallclock secs ( 0.02 usr  0.00 sys +  0.01 cusr  0.01 csys =  0.04 CPU)
Result: PASS
```

For more examples, take a look at the `t/bait.t`.
