package Emplacken::App::Starman;
BEGIN {
  $Emplacken::App::Starman::VERSION = '0.01';
}

use Moose;

use namespace::autoclean;

use Emplacken::Types qw( Bool File Int );

extends 'Emplacken::App';

has pid_file => (
    is     => 'ro',
    isa    => File,
    coerce => 1,
);

has workers => (
    is        => 'ro',
    isa       => Int,
    predicate => '_has_workers',
);

has backlog => (
    is        => 'ro',
    isa       => Int,
    predicate => '_has_backlog',
);

has max_requests => (
    is        => 'ro',
    isa       => Int,
    predicate => '_has_max_requests',
);

has preload_app => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has disable_keepalive => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

sub _build_command_line {
    my $self = shift;

    my @cli = ( 'starman', '-D' );

    push @cli, '--workers', $self->workers()
        if $self->_has_workers();

    push @cli, '--disable-keepalive'
        if $self->disable_keepalive();

    push @cli, '--preload-app'
        if $self->preload_app();

    push @cli, '--backlog', $self->backlog()
        if $self->_has_backlog();

    push @cli, '--max-requests', $self->max_requests()
        if $self->_has_max_requests();

    push @cli, '--user', $self->user()
        if $self->_has_user();

    push @cli, '--group', $self->group()
        if $self->_has_group();

    push @cli, '--pid', $self->pid_file();

    push @cli, $self->_common_command_line_options();

    return \@cli;
}

# The Starman server handles tihs itself
override _set_uid => sub { };
override _set_gid => sub { };

sub manages_pid_file { 1 }

__PACKAGE__->meta()->make_immutable();

1;
