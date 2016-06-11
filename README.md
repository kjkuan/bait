What is it?
=============
Bait(Bash Automated Integration Test) is a small test framework in Bash.

It produces [TAP](http://testanything.org) style test outputs, and unlike most
of the test tools in Bash, it doesn't require you to run every test in its own
subprocess.

Suggestions, bug reports, or pull requests are most welcomed!


What does it look like?
==========================
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
The above example will run all three checks and result in a failed test case when
because the second assert check fails.

The advantage of defining your check in an `assert()` function like this is that
you can put anything in it easily without messing with quotes. Plus, when a check
fails, Bait will show the source code of its `assert()` function for you to see.

Using SKIP and TODO
----------------------
In your test case function, you can use the `SKIP` command to skip the test case.
Example:

    Case "Skipping a Test"; Do () {
        echo "About to skip this test case..."
        SKIP "you can provide a reason here..., it's optional."
        echo "Execution won't reach here."
    }
    End Case
    
However, when using `SKIP` in a loop directly or indirectly, you need to specify
an extra integer argument for it. See [here](bait#L206) for more details.

Similarly, you can also mark a test case as TODO, using the `TODO` command.
Example:

    Case "Test someting"; Do () { TODO; }; End Case

NOTE: Unlike `SKIP`, `TODO` won't change the execution flow


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
A test fixture is a function that prepares the test data(in the form of local or
global variables), or external resources(e.g., files or database) to be used by
other test cases. For example:

    my_series() {
        local series=(2 3 5 7 11 13 17)
    }
    
    @setup my_series
    Case "Sum of the series must be greater than 42" {
        local i sum=0
        for i in ${series[*]}; do
            (( sum += i ))
        done
        (( sum > 42 ))
    }

You use `@setup` to "decorate" a test case with the fixture functions it needs,
and Bait will take care of setting up the call chain so that the test data
set up by the fixtures will be available to your test case function.

Notice that in the test case, it's using `series`, which is a local variable
in the fixture. This is possible because of [dynamic scoping] in Bash.

You can chain multiple fixtures with `@setup fixture1 fixture2 ...`, and Bait will
call your test case function like this: `fixture1 -> fixture2 -> ... -> test case`.
This also means local variables in `fixture1` will be available in `fixture2`, and
local variables in `fixture2` will be available in `fixture3`, and so on..., and
all of them will be available in your test case.

You can also decorate your test case with multiple `@setup` chains, and Bait will
create one test case for each chain. This could be useful when you have a test
case, but need it to be run with different test data setups, for example.

[dynamic scoping]: https://en.wikipedia.org/wiki/Dynamic_scoping#Dynamic_scoping


Running Tests
===============
You can define as many test cases as you want, and you can put them in
different files organized under different directories. 

To run your test cases with Bait, first make sure the `bait` script is in your
`PATH`. One way to run a test script is to make your test script self-executable
by using the `#!/usr/bin/env bait` shebang line, `chmod +x` the script, and then
just run it.

If you have many test scripts, another way to run them is to use the `prove`
utility, which comes with perl so you probably already have it installed. It should
be invoked with `-e bait`, for example:

    # Run all test cases under the t/ directory
    $ prove -e bait

See `prove` man page for more details.


