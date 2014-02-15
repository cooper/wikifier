# Copyright (c) 2014, Mitchell Cooper
#
# Wikifier::Utilities provides several functions used throughout the Wikifier.
# It exports any of the functions as needed.
package Wikifier::Utilities;

use warnings;
use strict;

sub import {
    my $package = caller;
    no strict 'refs';
    *{$package.'::'.$_} = *{__PACKAGE__.'::'.$_} foreach @_[1..$#_];
}

#################
### UTILITIES ###
#################

# Increase indention level by $times indents.
sub indent {
    my ($string, $times) = (shift, shift || 1);
    my $space = '    ' x $times;
    my $final_string = q();
    foreach my $line (split "\n", $string) {
        $final_string .= "$space$line\n";
    }
    return $final_string;
}

# 'Some Article' -> 'Some_Article'
sub safe_name {
    my ($string, $lc) = @_;
    $string =~ s/ /_/g;
    return $lc ? lc $string : $string;
}

# 'Some_Article' -> 'Some Article'
sub unsafe_name {
    my $string = shift;
    $string =~ s/_/ /g;
    return $string;
}

# removes leading and trailing whitespace from a string.
sub trim {
    my $string = shift;
    $string =~ s/^\s*//g;     # remove leading whitespace.
    $string =~ s/\s*$//g;     # remove trailing whitespace.
    return $string;
}

1
