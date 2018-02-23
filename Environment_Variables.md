Generally you want to prefix all new vars with `OPENQA_` as they will get auto
routed all the way through to vars.json and thus `testapi::get_var`. Older vars
do not have the prefix (yet).

# Tooling Variables

Tooling variables are used to influence our tooling but generally aren't
available in os-autoinst (or have a different name, being env vars you could
still fish them out of `ENV` I suppose).

|Variable|Description|
|--------|-----------|
|QEMUVGA|Overrides the qemu VGA default.|
|OPENQA_BIOS|Modifies the system to boot in BIOS mode instead of UEFI (our tooling only). In os-autoinst this var is `UEFI` and inverted.|
|PLASMA_MOBILE|Enables special config for plasma mobile|

# Test Variables

|Variable|Description|
|--------|-----------|
|TYPE|Identifies the image type. This is the ISO identifier not the build type (i.e. devedition-gitunstable not unstable)|
|BIOS|Modifies the system to boot in BIOS mode instead of UEFI (our tooling only). In os-auto-inst this var is `UEFI` and inverted.
|SECUREBOOT|Modifier for INSTALLATION to run in secureboot (gets bootstrapped before ISO starts)|
|INSTALLATION_OEM|Modifier for INSTALLATION to run in OEM mode|
|OEM_USERNAME|User name to use for the temporary oem user (i.e. the user the vendor uses to configure the system)|
|OEM_PASSWORD|Password of the oem user|
|OPENQA_APT_UPGRADE|Can be a space separated list of packages or `all` to do a dist-upgrade|
|OPENQA_INSTALLATION_OFFLINE|Modifier for INSTALLATION to switch networking offline before starting the install|
|OPENQA_IN_CLOUD|Set by CI nodes. Used internally to optimize perform for builds on some cloud server (e.g. use apt mirrors for speed)|

# Test Suites

Suites are more or less hardcoded variants of a suite comprised of multiple
tests. Suites are generally mutually exclusive.

|Variable|Description|
|--------|-----------|
|INSTALLATION|Test group. Conduct an installation test. Requires a TYPE to decide which ISO to install|
|PLASMA_DESKTOP|Test group. Core Plasma behavior|
|TESTS_TO_RUN|Colon separated list of test files to run (e.g. `tests/install_ubiquity.pm:tests/plasma_folder.pm`). Only used unless a test group is set.|
