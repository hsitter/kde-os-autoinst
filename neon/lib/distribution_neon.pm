package distribution_neon;
use base 'distribution';

use testapi qw(send_key %cmd assert_screen check_screen check_var get_var match_has_tag set_var type_password type_string wait_serial mouse_hide send_key_until_needlematch record_soft_failure wait_still_screen wait_screen_change diag);

sub init() {
    my ($self) = @_;
    $self->SUPER::init();
    $self->init_consoles();
}

sub x11_start_program($$$) {
    my ($self, $program, $timeout, $options) = @_;
    # enable valid option as default
    $options->{valid} //= 1;
    send_key "alt-f2";
    mouse_hide(1);
    check_screen('desktop-runner', $timeout);
    type_string $program;
    wait_still_screen;
    send_key "ret";
}

sub ensure_installed {
    my ($self, $pkgs, %args) = @_;
    my $pkglist = ref $pkgs eq 'ARRAY' ? join ' ', @$pkgs : $pkgs;
    $args{timeout} //= 90;

    testapi::x11_start_program('konsole');
    assert_screen('konsole');
    testapi::assert_script_sudo("chown $testapi::username /dev/$testapi::serialdev");

    # make sure packagekit service is available
    testapi::assert_script_sudo('systemctl is-active -q packagekit || (systemctl unmask -q packagekit ; systemctl start -q packagekit)');
    $self->script_run(
"for i in {1..$retries} ; do pkcon -y install $pkglist && break ; done ; RET=\$?; echo \"\n  pkcon finished\n\"; echo \"pkcon-\${RET}-\" > /dev/$testapi::serialdev",
        0
    );

    if (check_screen('polkit-install', $args{timeout})) {
        type_password;
        send_key('ret', 1);
    }

    wait_serial('pkcon-0-', $args{timeout}) || die "pkcon failed";
    send_key('alt-f4');
}


# initialize the consoles needed during our tests
sub init_consoles {
    my ($self) = @_;

    $self->add_console('root-virtio-terminal', 'virtio-terminal', {});
    # NB: ubuntu only sets up tty1 to 7 by default.
    $self->add_console('log-console', 'tty-console', {tty => 6});
    if (get_var('OPENQA_SERIES') eq 'xenial') {
        $self->add_console('x11', 'tty-console', {tty => 7});
    } else {
        # in bionic ubuntu switched to tty1 for default. we adjusted our sddm
        # accordingly.
        $self->add_console('x11', 'tty-console', {tty => 1});
    }
    # oem-config runs on tty1, later it will drop into tty7 for the final
    # x11.
    $self->add_console('oem-config', 'tty-console', {tty => 1});

    return;
}

sub script_sudo($$) {
    my $self = shift;
    # Clear the TTY first, otherwise we may needle match a previous sudo
    # password query and get confused. Clearing first make sure the TTY is empty
    # and we'll either get a new password query or none (still in cache).
    type_string "clear\n";
    return $self->SUPER::script_sudo(@_);
}

sub activate_console {
    my ($self, $console) = @_;

    diag "activating $console";
    if ($console eq 'log-console') {
        assert_screen 'tty6-selected';

        type_string $testapi::username;
        send_key 'ret';
        assert_screen 'tty-password';
        type_password $testapi::password;
        send_key 'ret';

        assert_screen [qw(tty-logged-in tty-login-incorrect)];
        if (match_has_tag('tty-login-incorrect')) {
            # Let's try again if the login failed. If it fails again give up.
            # It can happen that due to IO some of the password gets lost.
            # Not much to be done about that other than retry and hope for the
            # best.
            type_string $testapi::username;
            send_key 'ret';
            assert_screen 'tty-password';
            type_password $testapi::password;
            send_key 'ret';
            assert_screen 'tty-logged-in';
        }

        # Mostly just a workaround. os-autoinst wants to write to /dev/ttyS0 but
        # on ubuntu that doesn't fly unless chowned first.
        testapi::assert_script_sudo("chown $testapi::username /dev/$testapi::serialdev");
    }

    return;
}

# Make sure consoles are ready and in a well known state. This prevents
# switching between consoles quickly from ending up on a console which isn't
# yet ready for use (e.g. typing on TTY before ready and losing chars).
sub console_selected {
    my ($self, $console, %args) = @_;
    # FIXME: should make sure the session is unlocked
    if ($console eq 'x11') {
        # Do not wait on X11 specifically. Desktop state is wildely divergent.
        # Instead wait screen. Which is a bit shit. But meh.
        # We could maybe needle the panel specifically?
        wait_still_screen;
        return;
    }
    assert_screen($console, no_wait => 1);
}

1;
