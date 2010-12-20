package Emplacken::CodeBuilder::FromTemplate;
BEGIN {
  $Emplacken::CodeBuilder::FromTemplate::VERSION = '0.01';
}

use Moose;

use namespace::autoclean;
use autodie;

use Emplacken::Types qw( File );
use Text::Template;

with 'Emplacken::Role::CodeBuilder';

has template => (
    is       => 'ro',
    isa      => File,
    required => 1,
);

sub psgi_app_code {
    my $self = shift;

    open my $fh, '<', $self->template();
    my $template = do {
        local $/;
        <$fh>;
    };

    return $self->_psgi_app_code(
        [],
        q{},
        q{},
        $template,
    );
}

1;
