package MyFunctions;

our $VERSION = '1.0';
our $CREATED_DATE = '2023-05-26';

use strict;
use warnings;

sub add {
    my ($a, $b) = @_;
    return $a + $b;
}

sub subtract {
    my ($a, $b) = @_;
    return $a - $b;
}

1;