# Copyright (c) 2014, Mitchell Cooper
#
# Wikifier::Utilities provides several functions used throughout the Wikifier.
# It exports any of the functions as needed.
package Wikifier::Utilities;

use warnings;
use strict;
use Scalar::Util qw(blessed);

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
    my $final_string = '';
    foreach my $line (split "\n", $string) {
        $final_string .= "$space$line\n";
    }
    return $final_string;
}

# 'Some Article' -> 'Some_Article.page'
sub page_name {
    my $page_name = shift;
    return $page_name->name if blessed $page_name;

    # replace non-alphanumerics with _ and lowercase.
    $page_name =~ s/[^\w\.]/_/g;
    $page_name = lc $page_name;

    # append .page if it isn't already there.
    if ($page_name !~ m/\.(page|conf)$/) {
        $page_name .= '.page';
    }

    return $page_name;
}

# two page names equal?
sub page_names_equal {
    my ($page_name_1, $page_name_2) = @_;
    return page_name($page_name_1) eq page_name($page_name_2);
}

# removes leading and trailing whitespace from a string.
sub trim {
    my $string = shift;
    $string =~ s/^\s*//g;     # remove leading whitespace.
    $string =~ s/\s*$//g;     # remove trailing whitespace.
    return $string;
}

sub page_log {
    my ($page_name, $action, $info) = @_;
    Wikifier::l(sprintf '%-10s %s%s',
        $action,
        page_name($page_name),
        length $info ? ": $info" : ''
    );
}

sub L {
    my ($what) = @_;
    if (ref $what eq 'CODE') {
        Wikifier::indent();
        $what->();
        Wikifier::back();
        return;
    }
    Wikifier::l(@_);
}

1
