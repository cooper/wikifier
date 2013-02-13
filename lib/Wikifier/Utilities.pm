# Copyright (c) 2013, Mitchell Cooper
package Wikifier::Utilities;

use warnings;
use strict;
use feature 'switch';

sub import {
    my $package = caller;
    no strict 'refs';
    *{$package.'::'.$_} = *{__PACKAGE__.'::'.$_} foreach @_[1..$#_]
}

#################
### UTILITIES ###
#################

sub indent {
    my ($string, $times) = (shift, shift || 1);
    my $space = '    ' x $times;
    my $final_string = q();
    foreach my $line (split "\n", $string) {
        $final_string .= "$space$line\n";
    }
    return $final_string;
}

sub safe_name {
    my $string = shift;
    $string =~ s/ /_/g;
    return $string;
}

sub unsafe_name {
    my $string = shift;
    $string =~ s/_/ /g;
    return $string;
}

sub trim {
    my $string = shift;
    $string =~ s/^\s*//g;     # remove leading whitespace.
    $string =~ s/\s*$//g;     # remove trailing whitespace.
    return $string;
}

1
