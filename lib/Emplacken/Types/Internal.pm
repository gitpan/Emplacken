package Emplacken::Types::Internal;
BEGIN {
  $Emplacken::Types::Internal::VERSION = '0.01';
}

use strict;
use warnings;

use MooseX::Types -declare => [
    qw(
        ArrayRefFromConfig
        ValidClassName
        )
];

use MooseX::Types::Moose qw( ArrayRef Str );

#<<<
subtype ArrayRefFromConfig,
    as ArrayRef[Str];

coerce ArrayRefFromConfig,
    from Str,
    via { [ split /\s*,\s*/, $_ ] };
#>>>

1;
