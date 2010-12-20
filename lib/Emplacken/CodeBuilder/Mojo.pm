package Emplacken::CodeBuilder::Mojo;
BEGIN {
  $Emplacken::CodeBuilder::Mojo::VERSION = '0.01';
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
        q{my $server = Mojo::Server::PSGI->new( app_class => '%s' ); },
        $self->app_class()
    );

    my $core = q[sub { $server->run(@_) };];

    return $self->_psgi_app_code(
        [ 'Mojo::Server::PSGI', $self->app_class() ],
        $setup,
        $core,
    );
}

1;
