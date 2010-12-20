package Emplacken::CodeBuilder::Catalyst;
BEGIN {
  $Emplacken::CodeBuilder::Catalyst::VERSION = '0.01';
}

use Moose;

use namespace::autoclean;

use B ();
use Emplacken::Types qw( PackageName );

with 'Emplacken::Role::CodeBuilder';

has app_class => (
    is       => 'ro',
    isa      => PackageName,
    required => 1,
);

sub psgi_app_code {
    my $self = shift;

    my $setup = sprintf(
        q{%s->setup_engine('PSGI');},
        $self->app_class()
    );

    my $core = sprintf(
        q[sub { %s->run(@_) };],
        $self->app_class(),
    );

    return $self->_psgi_app_code(
        [ $self->app_class() ],
        $setup,
        $core,
    );
}

1;
