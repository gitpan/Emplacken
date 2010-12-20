package Emplacken::CodeBuilder::Mason;
BEGIN {
  $Emplacken::CodeBuilder::Mason::VERSION = '0.01';
}

use Moose;

use namespace::autoclean;

use B ();
use Emplacken::Types qw( File );

with 'Emplacken::Role::CodeBuilder';

has comp_root => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

has data_dir => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

sub psgi_app_code {
    my $self = shift;

    my $setup_tmpl = <<'EOF';
my $handler = HTML::Mason::PSGIHandler->new(
    comp_root => %s,
    data_dir  => %s,
);
EOF

    my $setup = sprintf(
        $setup_tmpl,
        B::perlstring( $self->comp_root() ),
        B::perlstring( $self->data_dir() )
    );

    my $core = q[sub { $handler->handle_psgi(@_) };];

    return $self->_psgi_app_code(
        [ 'HTML::Mason::PSGIHandler' ],
        $setup,
        $core,
    );
}

1;
