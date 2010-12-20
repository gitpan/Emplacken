package Emplacken::Role::CodeBuilder;
BEGIN {
  $Emplacken::Role::CodeBuilder::VERSION = '0.01';
}

use Moose::Role;

use namespace::autoclean;

use Class::Load qw( try_load_class );
use Emplacken::Types qw( ArrayRefFromConfig Bool File Str );
use List::AllUtils qw( uniq );
use Text::Template;

requires 'psgi_app_code';

has app => (
    is       => 'ro',
    isa      => 'Emplacken::App',
    required => 1,
    weak_ref => 1,
);

has middleware => (
    is      => 'ro',
    isa     => ArrayRefFromConfig,
    coerce  => 1,
    default => sub { [] },
);

has reverse_proxy => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has pid_file => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

has access_log => (
    is        => 'ro',
    isa       => File,
    coerce    => 1,
    predicate => '_has_access_log',
);

has access_log_format => (
    is        => 'ro',
    isa       => Str,
    predicate => '_has_access_log_format',
);

has error_log => (
    is        => 'ro',
    isa       => File,
    coerce    => 1,
    predicate => '_has_error_log',
);

has error_log_format => (
    is        => 'ro',
    isa       => File,
    coerce    => 1,
    predicate => '_has_error_log_format',
);

my $Template = <<'EOF';
use strict;
use warnings;

{{$modules}}
{{$pre}}
{{$setup}}

builder {
    {{ if (defined $builder_pre) { $builder_pre } }}
    {{ if (defined $mw) { $mw } }}
    {{$app_core}}
};

{{$post}}
EOF

sub _psgi_app_code {
    my $self     = shift;
    my $mods     = shift;
    my $setup    = shift;
    my $app_core = shift;
    my $template = shift || $Template;

    my @modules = ( 'Plack::Builder', @{$mods} );
    my @pre;
    my @mw;
    my @post;

    push @mw,
        map { sprintf( '    enable %s;', B::perlstring($_) ) }
            @{ $self->middleware };

    if ( my $mw = $self->_reverse_proxy_code() ) {
        push @mw, $mw;
    }

    if ( my ( $pre, $mw ) = $self->_access_log_code() ) {
        push @modules, 'autodie';
        push @pre, $pre;
        push @mw,  $mw;
    }

    my $builder_pre;

    if ( my ( $pre, $post ) = $self->_error_log_code() ) {
        push @modules, 'autodie', 'Emplacken::Stderr';
        push @pre, $pre;
        $builder_pre = 'local $Emplacken::Stderr::Env = $_[0];';
    }

    if ( my ( $pre, $post ) = $self->_pid_file_code() ) {
        push @modules, 'File::Pid';
        push @pre,  $pre;
        push @post, $post;
    }

    my $use  = join q{}, map {"use $_;\n"} uniq @modules;
    my $pre  = join q{}, map { $_ . "\n" } @pre;
    my $mw   = join q{}, map { $_ . "\n" } @mw;
    my $post = join q{}, map { $_ . "\n" } @post;

    $builder_pre .= "\n" if defined $builder_pre;
    undef $mw unless length $mw;

    my $tt = Text::Template->new(
        type       => 'string',
        source     => $template,
        delimiters => [ '{{', '}}' ]
    );

    my $code = $tt->fill_in(
        hash => {
            modules     => $use,
            pre         => $pre,
            setup       => $setup,
            builder_pre => $builder_pre,
            mw          => $mw,
            app_core    => $app_core,
            post        => $post,
        },
    );

    if ( try_load_class('Perl::Tidy') ) {
        my $tidied;

        Perl::Tidy::perltidy( source => \$code,
                              destination => \$tidied,
                            );

        $code = $tidied;
    }

    return $code;
}

sub _reverse_proxy_code {
    my $self = shift;

    return unless $self->reverse_proxy();

    return
        q{enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' } 'Plack::Middleware::ReverseProxy';};
}

sub _access_log_code {
    my $self = shift;

    return unless $self->_has_access_log();

    my $pre = sprintf(
        q{open my $access_log_fh, '>>', %s;},
        B::perlstring( $self->access_log() )
    );

    my $mw = q{    enable 'Plack::Middleware::AccessLog'};

    $mw .= sprintf(
        qq{,\n        format => %s},
        B::perlstring( $self->access_log_format() )
    ) if $self->_has_access_log_format();

    $mw .= ",\n" . q[        logger => sub { print {$access_log_fh} @_ }];

    $mw .= q{;};

    return ( $pre, $mw );
}

sub _error_log_code {
    my $self = shift;

    return unless $self->_has_error_log();

    my $pre = sprintf(
        q{open my $error_log_fh, '>>', %s;},
        B::perlstring( $self->error_log() )
    );
    $pre .= "\n";
    $pre .= q{tie *STDERR, 'Emplacken::Stderr', fh => $error_log_fh};
    $pre .= sprintf(
        q{, format => %s},
        B::perlstring( $self->error_log_format() )
    ) if $self->_has_error_log_format();
    $pre .= q{;};
    $pre .= "\n";

    return $pre;
}

sub _pid_file_code {
    my $self = shift;

    return if $self->app()->manages_pid_file();

    my $pre = sprintf(
        q{my $pid = File::Pid->new( file => %s );},
        B::perlstring( $self->pid_file() )
    );

    $pre .= "\n";

    $pre .= sprintf(
        q{die 'The ' . %s . " application is already running\n" if $pid->running();},
        B::perlstring( $self->app()->name() )
    );

    $pre .= "\n";

    $pre .= sprintf(
        q{$pid = File::Pid->new( file => %s, pid => $$ );},
        B::perlstring( $self->pid_file() )
    );

    $pre .= "\n";

    $pre .= q{$pid->write();};

    $pre .= "\n";

    my $post = q{$pid->remove();};

    return ( $pre, $post );
}

1;
