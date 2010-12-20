package Emplacken;
BEGIN {
  $Emplacken::VERSION = '0.01';
}

use Moose;

use Class::Load qw( is_class_loaded try_load_class );
use Config::Any;
use Emplacken::App;
use Emplacken::Types qw( ArrayRef Bool Dir File );
use Getopt::Long;
use List::AllUtils qw( first );

with 'MooseX::Getopt::Dashes';

Getopt::Long::Configure('pass_through');

has dir => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    default => '/etc/emplacken',
    documentation =>
        'The directory which contains your emplacken config files',
);

has file => (
    is            => 'ro',
    isa           => File,
    coerce        => 1,
    predicate     => '_has_file',
    documentation => 'You can supply a single file instead of a directory',
);

has verbose => (
    is            => 'ro',
    isa           => Bool,
    default       => 1,
    documentation => 'Controls whether some commands print output to stdout',
);

has __psgi_apps => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => ArrayRef ['Emplacken::App'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_psgi_apps',
    handles  => {
        _psgi_apps => 'elements',
        _app_count => 'count',
    },
);

sub run {
    my $self = shift;

    my $command = $self->extra_argv()->[0] || 'start';
    my $meth = q{_} . $command;

    unless ( $self->can($meth) ) {
        die "Invalid command for emplacken: $command\n";
    }

    unless ( $self->_app_count() ) {
        if ( $self->_has_file() ) {
            die $self->file() . " is not a PSGI application config file\n";
        }
        else {
            die "Did not find any PSGI application config files in "
                . $self->dir() . "\n";
        }
    }

    if ( $self->$command() ) {
        _exit(0);
    }
    else {
        _exit(1);
    }
}

# This is a sub so we can override it for testing
sub _exit {
    exit shift;
}

sub _start {
    my $self = shift;

    return $self->_run_for_all_apps('start');
}

sub _stop {
    my $self = shift;

    return $self->_run_for_all_apps('start');
}

sub _restart {
    my $self = shift;

    return $self->_run_for_all_apps('stop')
        + $self->_run_for_all_apps('start');
}

sub _run_for_all_apps {
    my $self = shift;
    my $meth = shift;

    my $failed = 0;
    for my $app ( $self->_psgi_apps() ) {

        my $result = $app->$meth() ? 'OK' : 'failed';

        my $message = sprintf(
            "    %50s ... [%s]\n",
            "${meth}ing " . $app->name(),
            $result
        );

        $self->_maybe_print($message);
    }

    return !$failed;
}

sub _status {
    my $self = shift;

    for my $app ( $self->_psgi_apps() ) {
        printf(
            "    %50s ... [%s]\n",
            $app->name(),
            $app->is_running() ? 'running' : 'stopped'
        );
    }
}

sub _build_psgi_apps {
    my $self = shift;

    my @files
        = $self->_has_file()
        ? $self->file()
        : grep { ! $_->is_dir } $self->dir()->children();

    return [
        map { $self->_build_app_from_file($_) }
        grep {/\.conf/} grep {-s} @files
    ];
}

sub _build_app_from_file {
    my $self = shift;
    my $file = shift;

    my $cfg = Config::Any->load_files(
        {
            files           => [$file],
            flatten_to_hash => 1,
            use_ext         => 0,
        }
    );

    die "$file does not seem to contain any configuration\n"
        unless $cfg->{$file};

    $cfg = $cfg->{$file};

    die "$file does not contain a server key"
        unless defined $cfg->{server} && length $cfg->{server};

    my $app_class = first { try_load_class($_) } (
        'Emplacken::App::' . $cfg->{server},
        'Emplacken::App'
    );

    return $app_class->new( file => $file, %{$cfg} );
}

sub _maybe_print {
    my $self = shift;
    my $msg  = shift;

    return unless $self->verbose();

    print $msg;
}

1;

#ABSTRACT: Manage multiple plack apps with a directory of config files



=pod

=head1 NAME

Emplacken - Manage multiple plack apps with a directory of config files

=head1 VERSION

version 0.01

=head1 SYNOPSIS

  emplacken --dir /etc/emplacken start

  emplacken --dir /etc/emplacken stop

=head1 DESCRIPTION

B<NOTE: This is all still experimental. Things may change in the future.>

Emplacken is a tool for managing a set of L<Plack> applications based on
config files. It also adds support for privilege dropping and error logs to
those Plack servers that don't support these features natively.

It works be reading a config file and using that to I<generate> a PSGI
application file based on your config. It knows how to generate L<Catalyst>,
L<Mojo>, and L<Mason> app files natively. For other apps, or more complicated
setups, you can supply a template to Emplacken and it will use that to
generate the PSGI app.

=head1 COMMAND LINE OPTIONS

The C<emplacken> command accepts either a C<--dir> or C<--file> option. If you
don't specify either, it defaults to using the F</etc/emplacken> directory.

You must also pass a command, one of C<start>, C<stop>, C<restart>, or
C<status>.

Finally, you can specify a C<--verbose> or C<--no-verbose> flag. This
determines whether the C<start> and C<stop> command print to stdout. The
C<status> command I<always> prints to stdout.

=head1 CONFIG FILES

This module uses L<Config::Any> to read config files, so you have a number of
choices for config file syntax. These examples will use either INI or JSON
syntax.

All the config options should be in a single top-level section.

=head2 Common Config Options

These options are shared for all servers and code builders.

For config file styles that don't support multiple values for a single option,
you can use a comma-separated string to set multiple options.

=head3 server

This will be passed to the C<plackup> command to tell it what server class to
use, for example L<Starlet> or L<Corona>. If you specify C<Starman>, then the
C<starman> command will be used instead of C<plackup>.

You can also use the value "plackup" here, which will let the Plack code pick
the server automagically.

This is required.

=head3 builder

The code builder to use. Currently, this can be one of L<Catalyst>, L<Mason>,
L<Mojo>, or L<FromTemplate>. Each code builder support different config
options. See below for details.

=head3 pid_file

The location of the pid file for this application.

This is required.

=head3 include

A set of include directories to be passed to C<plackup>. You can specify
multiple values.

=head3 modules

A set of modules to be passed to C<plackup>. You can specify multiple
values. These modules will be preloaded by C<plackup>.

=head3 listen

This can be "HOST", "HOST:PORT", ":PORT", or a path for a Unix socket. This
can be set multiple times, but some servers may not support multiple values.

=head3 user

If this is set then Emplacken will attempt to become this user before starting
the PSGI app.

=head3 group

If this is set then Emplacken will attempt to become this group before
starting the PSGI app.

=head3 middleware

This can be one or more middleware modules that should be enabled. Note that
there is no way to pass config options to these modules (yet?). You can
specify multiple values.

=head3 reverse_proxy

If this is true, then the L<Plack::Middleware::ReverseProxy> module is enabled
for requests coming from 127.0.0.1.

=head3 access_log

If this is set to a file, then the L<Plack::Middleware::AccessLog> module is
enabled. It will log to the specified file.

=head3 access_log_format

This can be used to change the access log format.

=head3 error_log

If this is set, then the generated PSGI app will tie C<STDERR> and log to a
file. The log format is like Apache's error log, so you'll get something like
this:

  [Sun Dec 19 00:42:32 2010] [error] [client 1.2.3.4] Some error

Any error output from Perl will be tweaked so that it fits on a single
line. All non-printable characters will be replaced by their hex value.

=head2 Starman Options

If you are using the Starman server, there are several more options you can
set in the config file.

=head3 workers

The number of worker processes to spawn.

=head3 backlog

The maximum number of backlogged listener sockets allowed.

=head3 max_requests

The maximum number of requests per child.

=head3 preload_app

If this is true, then your PSGI app is preloaded by Starman before any child
processes are forked.

=head3 disable_keepalive

If this is true, then keepalive is disabled.

=head2 Catalyst Options

If you are using the Catalyst code builder, you must specify an C<app_class>
config option. This is the name of the class for your web application.

=head2 Mason Options

If you are using the Mason code builder, you must specify C<comp_root> and
C<data_dir> config options.

=head2 Mojo Options

If you are using the Mojo code builder, you must specify an C<app_class>
config option. This is the name of the class for your web application.

=head2 FromTemplate

If you are using the FromTemplate code builder, you must specify a C<template>
config option. This should be the file which contains the PSGI app template to
use.

=head2 Template Variables

You can provide your own L<Text::Template> template file for Emplacken to use
as a template when building the PSGI application file. The builder will set
the code delimeters to C<{{> and C<}}>.

You should design your template to expect several variables:

=over 4

=item * {{$modules}}

This will be a set of C<use> statements loading any needed modules. This will
include modules specified in the C<modules> config key, and well as additional
modules Emplacken may require in your PSGI application file.

=item * {{$pre}}

This will be a chunk of code that should come before any setup code you need
to write, and before the C<builder> block.

=item * {{$builder_pre}}

This should go immediately inside your C<builder> block.

=item * {{$mw}}

This will be a chunk of code that enables middleware. It will include
middleware specified by the C<middleware> config option as well as anything
else Emplacken needs (like the access log code).

=item * {{$post}}

This will be a chunk of code that should come after the C<builder> block at
the end of the file.

=back

Here is an example template for a Catalyst application called C<MyApp>:

  use strict;
  use warnings;

  use MyApp;
  {{$modules}}
  {{$pre}}

  MyApp->setup_engine('PSGI');

  builder {
      {{ $builder_pre }}
      {{ $mw }}
      sub { MyApp->run(@_) };
  };

  {{$post}}

=head1 DONATIONS

If you'd like to thank me for the work I've done on this module, please
consider making a "donation" to me via PayPal. I spend a lot of free time
creating free software, and would appreciate any support you'd care to offer.

Please note that B<I am not suggesting that you must do this> in order for me
to continue working on this particular software. I will continue to do so,
inasmuch as I have in the past, for as long as it interests me.

Similarly, a donation made in this way will probably not make me work on this
software much more, unless I get so many donations that I can consider working
on free software full time, which seems unlikely at best.

To donate, log into PayPal and send money to autarch@urth.org or use the
button on this page: L<http://www.urth.org/~autarch/fs-donation.html>

=head1 BUGS

Please report any bugs or feature requests to C<bug-emplacken@rt.cpan.org>, or
through the web interface at L<http://rt.cpan.org>.  I will be notified, and
then you'll automatically be notified of progress on your bug as I make
changes.

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2010 by Dave Rolsky.

This is free software, licensed under:

  The Artistic License 2.0

=cut


__END__

