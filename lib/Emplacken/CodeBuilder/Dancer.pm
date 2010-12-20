package Emplacken::CodeBuilder::Dancer;
BEGIN {
  $Emplacken::CodeBuilder::Dancer::VERSION = '0.01';
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

    my $setup_tmpl = <<'EOF';
load_app %s;
use Dancer::Config 'setting';
setting apphandler => 'PSGI';
Dancer::Config->load()
EOF

    my $setup;

    my $core = sprintf(
        q[sub { Dancer->dance],
        $self->app_class(),
    );

    return $self->_psgi_app_code(
        [ 'Dancer', $self->app_class() ],
        $setup,
        $core,
    );
}

1;
