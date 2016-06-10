What is it?
=============
Bait is a small test framework in Bash.

It produces TAP style test outputs, and unlike most of the test tools in Bash,
it doesn't require you to run every test in its own subprocess.

I'm not sure what it might be good for yet, but I had fun implementing it
and like how it has turned out so far. I hope it might be useful to you.

Suggestions, bug reports, or pull requests are most welcomed!

> *NOTE*: This is still a work in progress..., and it's not recommended for production use!
          In particular, by default(can be turned off with `-P`), Bait preprocesses
          the test file, so there are some conventions(undocumented) on how you must format
          your `Case` and `assert` blocks, and Bait may not get everything preprocessed
          correctly yet!


What does it look like?
==========================
```
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
    assert {
        : Check if www.google.com is up
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
+ check
+ assert
+ : Check if www.google.com is up
+ local url=https://www.google.com/
++ curl -I -L -sf -w '%{http_code}\n' https://www.google.com/
++ tail -1
+ [[ 200 == 200 ]]
+ local rc=0
ok
All tests successful.
Files=1, Tests=3,  1 wallclock secs ( 0.01 usr  0.00 sys +  0.04 cusr  0.02 csys =  0.07 CPU)
Result: PASS
```

For more examples, take a look at [bait.t](t/bait.t).


Writing Tests
====================
You define test cases using functions provided by Bait.
A test case definition starts with the `Case` command like this:

    Case "test case description here..., it's optional though."

Then you define a `Do()` function, which will be converted to a test
function that represents your test case declared above it. Finally,
to complete the test case definition, you end it with the `End Case`
command. The whole thing usually looks like this:

    Case "Test case description"; Do () {
        # commands here will be run when the test case is run.
        echo Hello World
        (( 1 + 1 == 2 ))
         
        # Note: In Bash, the return status of a function is the status
        #       of the last command run in it, unless you return explicitly.
    }
    End Case   # Note: You can't nest test case defintions.

Notice that this is all written in Bash, and your test case is just
a Bash function defined by the `Do()` function. Also, note that if define the
`Do()` function using `(` and `)` instead of `{` and `}` for the body, then it
will be run in a subshell, which might work better for you if you'd like better
isolation between different test case runs.

The return status of your test function determines the success(`ok`) and
failure(`not ok`) of your test case when it's run. `0` indicates success; other
values indicate failure.


Using assert-checks
---------------------
Sometimes you'd like to perform several checks in one test case. Bait
provides a `check` function do help you do that. Example:

    Case "An assert-check example"; Do () {
        assert () { true; }; check
        assert () { false && true; }; check   # this check fails
        assert () { true || false; }; check
    }
    End Case

Basically, you define an `assert()` function containing your check logic,
and then you call `check` immediately after the functinon definition.
The above example will result in a failed test case when it's run because the
second assert check fails.

The advantage of defining your check in an `assert()` function like this is that
you can put anything in it easily without messing with quotes. Plus, when a check
fails, Bait will show the source code of its `assert()` function for you to see.

Using SKIP and TODO
----------------------
FIXME

Preprocessing
-----------------
Now, defining test cases using `Case`, `Do()`, and `End Case`, like above, as well
as writing `assert() { ... ; }; check`, can be tedious. Therefore, Bait by default
preprocesses your test script and turn test cases and asserts written like below into
valid test case definitions like above. Here's a table illustrating the transformations:

<table>
<tr><th>Before</th><th>After</th></tr>
<tr>
    <td><pre>Case { ...; }</pre></td><td><pre>Case; Do () { ...; }; End Case</pre></td>
</tr>
<tr>
  <td>
<pre>
Case {
    ...
}
</pre>
  </td>
  <td>
<pre>
Case; Do () {
    ...
}
End Case
</pre>
  </td>
</tr>
<tr><td><pre>Case ... { ...; }</pre></td><td><pre>Case ...; Do () { ...; }; End Case</pre></td></tr>
<tr>
  <td>
<pre>
Case ... {
    ...
}
</pre>
  </td>
  <td>
<pre>
Case ...; Do () {
    ...
}
End Case
</pre>
  </td>
</tr>
<tr><td><pre>assert ...</pre></td><td><pre>assert () { ...; }; check</pre></td></tr>
<tr>
  <td>
<pre>
assert {
    ...
}
</pre>
  </td>
  <td>
<pre>
assert () {
    ...
}
check
</pre>
  </td>
</tr>
</table>


One caveat with preprocessing is that it can't 100% get it right in all cases. Particularly,
it requires you to indent your closing `}` or `)` correctly to match the starting `Case` or `assert`.
However, in practice, this is usually not a problem if you have set up auto-indent in your text editor.

> **NOTE**: Preprocessing can be turned off via the `-P` command line option to Bait. Together with
            the `-n` (don't run tests) option, you will be able to see how Bait preprocessed your
            test script.



Defining and Using Test Fixtures
==================================
FIXME


Running Tests
===============

You can define as many test cases as you want, and you can put them in
different files organized under different directories.




