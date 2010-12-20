package Emplacken::App;
BEGIN {
  $Emplacken::App::VERSION = '0.01';
}

use Moose;

use namespace::autoclean;
use autodie;

use Class::Load qw( load_class );
use Emplacken::Types qw( ArrayRef ArrayRefFromConfig File Str );
use English qw( -no_match_vars );
use File::Pid;
use File::Spec;
use Path::Class qw( dir );

has file => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

has name => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_name',
);

has _builder => (
    is       => 'ro',
    does     => 'Emplacken::Role::CodeBuilder',
    init_arg => undef,
    writer   => '_set_builder',
);

has server => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has include => (
    is      => 'ro',
    isa     => ArrayRefFromConfig,
    coerce  => 1,
    default => sub { [] },
);

has modules => (
    is      => 'ro',
    isa     => ArrayRefFromConfig,
    coerce  => 1,
    default => sub { [] },
);

has listen => (
    is        => 'ro',
    isa       => ArrayRefFromConfig,
    coerce    => 1,
    predicate => '_has_listen',
);

has user => (
    is        => 'ro',
    isa       => Str,
    predicate => '_has_user',
);

has group => (
    is        => 'ro',
    isa       => Str,
    predicate => '_has_group',
);

has _command_line => (
    is       => 'ro',
    isa      => ArrayRef,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_command_line',
);

has psgi_app_file => (
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_psgi_app_file',
);

sub BUILD {
    my $self = shift;
    my $p     = shift;

    my $builder = delete $p->{builder}
        or die "Must specify a code builder for the $p->{file} app\n";

    my $cb_class = 'Emplacken::CodeBuilder::' . $builder;
    load_class($cb_class);

    $self->_set_builder( $cb_class->new( %{$p}, app => $self ) );

    return $p;
};

sub _build_name {
    my $self = shift;

    my $basename = $self->file()->basename();

    $basename =~ s/\.conf$//;

    return $basename;
}

sub start {
    my $self = shift;

    return if fork;

    $self->_set_uid();
    $self->_set_gid();

    my $cli = $self->_command_line();

    exec { $cli->[0] } @{$cli};

    die "Failed to exec @{$cli}: $!";
}

sub _maybe_drop_privs{
    my $self = shift;

    $self->_set_uid();
}

sub _set_uid {
    my $self = shift;

    return unless $self->_has_user();

    my $uid
        = $self->user() =~ /^\d+$/
        ? $self->user()
        : getpwuid( $self->user() );

    $UID = $EUID = $uid;

    die "Could not set uid to $uid\n"
        unless $UID == $uid && $EUID == $uid;
}

sub _set_gid {
    my $self = shift;

    return unless $self->_has_group();

    my $gid
        = $self->group() =~ /^\d+$/
        ? $self->group()
        : getpwgid( $self->group() );

    $GID = $EGID = $gid;

    my %gids  = map { $_ => 1 } split /\s/, $GID;
    my %egids = map { $_ => 1 } split /\s/, $EGID;

    die "Could not set gid to $gid\n"
        unless $gids{$gid} && $egids{$gid};
}

sub stop {
    my $self = shift;
}

sub is_running {
    my $self = shift;

    return 0 unless -e $self->pid_file();

    my $pid = File::Pid->new( file => $self->pid_file() );

    return $pid->running() ? 1 : 0;
}

sub _build_command_line {
    my $self = shift;

    my @cli = ( 'plackup', '-D' );

    push @cli, '-S', $self->server()
        unless $self->server() eq 'plackup';

    push @cli, $self->_common_command_line_options();

    return \@cli;
}

sub _common_command_line_options {
    my $self = shift;

    return (
        ( map { ( '-I',       $_ ) } @{ $self->include() } ),
        ( map { ( '-M',       $_ ) } @{ $self->modules() } ),
        ( map { ( '--listen', $_ ) } @{ $self->listen() } ),
        $self->psgi_app_file()
    );
}

after _build_command_line => sub {
    my $self = shift;

    $self->_write_psgi_app();
};


sub _build_psgi_app_file {
    my $self = shift;

    return dir( File::Spec->tmpdir() )->file( $self->name() . '.psgi' );
}

sub _write_psgi_app {
    my $self = shift;

    open my $fh, '>', $self->psgi_app_file();
    print {$fh} $self->_builder()->psgi_app_code();
    close $fh;

    return;
}

sub manages_pid_file { 0 }

__PACKAGE__->meta()->make_immutable();

1;
