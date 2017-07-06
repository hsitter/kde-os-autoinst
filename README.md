OpenQA backend tech wired into KDE neon.

# OS-autoinst

This bugger is based on os-autoinst which is the backend tech used by openqa to conduct its tests.
It is wired up into the regular neon Jenkins which takes care of node provisioning and all that.
os-autoinst is largely written in perl, tests for os-autoinst are also written in perl.

testapi docs http://open.qa/api/testapi/

# Bootstrapperino

To use os-autoinst it is advisible to install KVM on the system as full
virtualziation will give obsurdly bad performance. KVM uses hardware
capabilities to give much higher virtualization performance. KVM is by default
enabled on specific nodes provisioned by build.neon for os-autoinst runs.

To mimic the setup used by build.neon you can simply docker contain your clone
into a standard `ubuntu:16.04` and get the environment bootstrapped via
`bin/bootstrap_from_ubuntu.sh`.
Note that when using docker you need to pass kvm around accordingly and the
docker user needs write access to /dev/kvm (for example by adding it to the kvm
group).

A simple bootstrap would look like this:

```
docker run --device /dev/kvm -v `pwd`:/workspace -it ubuntu:16.04 bash
cd /workspace
TYPE=devedition-gitunstable bin/bootstrap_from_ubuntu.sh
```

Note that this will probably fail because bootstrap will attempt to run tests
which we haven't specified.

# Testerino

Testing is primarily done via `bin/run.rb` which will setup a working dir
wherein the test artifacts will be dumped.
To run you either need to specify tests to run or enable installation mode.
These two modes are mutually exclusive as installation tests is meant to generate
a hard disk whereas tests are meant to consume them.
You also need to specify a TYPE corresponding to an ISO when doing an installation test.

Inside a docker container you can run tests like so:

```
TYPE=devedition-gitunstable INSTALLATION=1 bin/run.rb
# would generate a new hard disk in wok/raid/ using installation tests appropriate for the git unstable ISO
TYPE=devedition-gitunstable TESTS_TO_RUN="tests/plasma_lockscreen.pm" bin/run.rb
# would run the lockscreen test against an existing wok/raid/ hard disk
```

Note that presently test runs mutate the hard disk, so if you run different tests
on the same disk you may need to manually backup and restore the raid/ directory
in order to always boot a pristine installation.

## Test run

Test runs start in run.rb where the test variables are being set up, such as
how many cores are to be used for the test and which tests to run.

run.rb starts isotovideo from os-autoinst which in turn will run `neon/main.pm`
which is the actual test runner where the invidiual test cases are being loaded.
Which cases are being loaded depends on the environment when run.rb was run.

main.pm will also load `neon/lib/distribution_neon.pm` which is backing implementation
for the testapi. It implements distribution specific aspects needed to drive tests,
such as how to get a console terminal, or how to install packages if they are missing.

The individual test cases are in `neon/tests/**.pm`.

os-autoinst will create a new hard disk raid (if applicable) and then start qemu
to boot either from the ISO (which is obtianed by bin/sync.rb) or the hard disk
(if applicable).

os-autoinst will take screenshots of the qemu screen and then fuzzy compare
it to so called needles (expected screen content) in order to satisfy
the assertions made in the test case.

When the test is done the testresults/ content is converted to junit for consumption by jenkins.

## Needles

Needles are the way expecations are expressed. They always consist of one json
and one png file. They both have the same basename.

A needle is comprised of >= 1 area, and area is matching region inside the
associated png file. In order for a needle to "match" (satisfying the assertion)
all its areas must match the qemu screen.

Areas have x & y coordinates, dimensional width & height, a type attribute which
is basically always "match", and finally a match percentage.

The higher the match percentage the more accurate the match must be. For example
if you place an area above a line of text that says "Hi there." and it needs a
100% match any and all visual deviations from this expectation will result in a
failed assertion. Do note that the position of an area in the needle is not
necessarily where it needs to be in the screen. So, if the line is at the bottom
of the screen in the expectation but then gets moved to the top the assertion
would still hold as the area still is there and looks exactly the same, it
only changed location. Generally it is wise to use lower precision to
be more robust for minor visual changes. For example if the line were to drop
the period and become "Hi there" it would fail a 100% match but not a 95% match.
If it were to change color from black to yellow however it would also fail a 95%
match.

Needles are shared by all tests, this enables the creation of shared needles so
one can for example assert that a given action starts konsole. For management
reasons it is advisable to put needles in a subdir for the test they belong to.
They do not need to be in the same dir to be found, so having multiple dirs with
fewer fails makes things easier to navigate.

You can create needles by either opening the PNG in gimp, selecting the areas
you want and manually write the json file accordingly.

This is however super cumbersome so you may have better luck using the qml tool
in `needler/` (needs building).

## Needler

The needler tool is meant to help with managing needles. It accepts either a
json or png path as argument and will determine the respective other file
automatically. Both files must exist!

On the left hand side you will find overall needle attributes. Most important
are the tags. You must make sure that the needle at least lists
its own name in the tags, otherwise you will not be able to assert it.

On the right hand side you will find the expected screen. You can switch out the
png by drag and dropping another png onto this area. This immediately overwrites
the old png, so be careful. Right clicking here allows you to add a new area.
Right clicking on an area allows changing its match value. Areas can be moved
about at will. You can also mark ONE area as "clickable". This area will be the one
os-autoinst clicks on when you call `assert_screen_and_click` on the needle.
The clickable area is marked in yellow.

To save click save.

## Needle Tagging

Needles have any number of tags. As a matter of policy there must be at least
one which is equal to the basename of the needle file.

Tags are the means by which a test asserts what a screen needs to look like
(i.e. which areas it needs to match).

Tags do not need to be unqiue!

For example if a button has an active and inactive state and you do not want to
increase the matching percentage so both get accommodated, you can create two
needles foo-active.json and foo-inactive.json. You then tag them both as 'foo'
and in your test you `assert_screen 'foo';`. os-autoinst will do the heavy
lifting for you and attempt to match both needles as they are both tagged 'foo'.
Which ever one manages to satisfy the assertion first wins.

## Authoring tests

Authoring tests is a bit of a shitfest right now.

To author a test you either need to wait a lot for build.neon to actually spew
screenshots at you, or setup your own docker container (see above).

When using docker you'll want to make sure that you work off of a pristine raid/
hard disk, so the test is consistent.

Also note that all tests (except for installation tests...) go through
grub->plymouth->sddm, so you can use boiler-plate login code to get you to a
plasma session, from there you can then start your actual test.

To get started best copy an existing test which looks close enough to what you
need, then change the assertions to be roughly what you expect the test run will
produce.

At this point most of your assertions will not actually be backed up by a needle,
that is fine. They will simply fail. To facilitate this you can give all assertions
very short timeouts, so you don't have to wait too long.
The important thing here is that you have a test you can run and assertions that
are going to fail.

Run your test.

As the first assertion fails, grab the relevant screenshot out of the
testresults/ directory and use it to create a new needle for this assertion.

Start the test again, rinse and repeat.

Once all your assertions are backed up by a needle the test should be passing
as a whole and be good for production.

Make sure you give suitably high timeouts. In particular for installation tests
performance can be fluctuating substantially.
