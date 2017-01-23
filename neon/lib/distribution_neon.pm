package distribution_neon;
use base 'distribution';
use strict;

use testapi qw(send_key %cmd assert_screen check_screen check_var get_var match_has_tag set_var type_password type_string wait_idle wait_serial mouse_hide send_key_until_needlematch record_soft_failure wait_still_screen wait_screen_change);

sub init() {
    my ($self) = @_;
    $self->SUPER::init();
}

sub x11_start_program($$$) {
    my ($self, $program, $timeout, $options) = @_;
    # enable valid option as default
    $options->{valid} //= 1;
    send_key "alt-f2";
    mouse_hide(1);
    check_screen("desktop-runner", $timeout);
    type_string $program;
    wait_idle 5;
    send_key "ret";
    wait_still_screen;
}

1;
# vim: set sw=4 et:
