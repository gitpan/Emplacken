package Emplacken::Types;
BEGIN {
  $Emplacken::Types::VERSION = '0.01';
}

use strict;
use warnings;

use base 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw(
        Emplacken::Types::Internal
        MooseX::Types::Moose
        MooseX::Types::Path::Class
        MooseX::Types::Perl
        )
);

1;

# ABSTRACT: Exports Emplacken types as well as Moose and Path::Class types

__END__
=pod

=head1 NAME

Emplacken::Types - Exports Emplacken types as well as Moose and Path::Class types

=head1 VERSION

version 0.01

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2010 by Dave Rolsky.

This is free software, licensed under:

  The Artistic License 2.0

=cut

