# Copyright (c) 2017, Mitchell Cooper
#
# Wikifier::Utilities provides several functions used throughout the wikifier.
# It exports any of the functions as needed.
#
package Wikifier::Utilities;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);

sub import {
    my $package = caller;
    no strict 'refs';
    *{$package.'::'.$_} = \&{__PACKAGE__.'::'.$_} foreach @_[1..$#_];
}

#################
### UTILITIES ###
#################

# Increase indention level by $times indents.
sub indent_str {
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
    my ($page_name, $ext) = @_;
    return $page_name->name if blessed $page_name;

    $page_name = page_name_link($page_name);

    # append the extension if it isn't already there.
    if ($page_name !~ m/\.(page|conf|model)$/) {
        $ext //= '.page';
        $page_name .= $ext;
    }

    return $page_name;
}

# 'Some Article' -> 'some_article'
# 'Some Article' -> 'Some_Article' (with $no_lc)
sub page_name_link {
    my ($page_name, $no_lc) = @_;

    # replace non-alphanumerics with _ and lowercase.
    $page_name =~ s/[^\w\.\-]/_/g;
    $page_name = lc $page_name unless $no_lc;

    return $page_name;
}

# 'Some_Article.page' -> 'some_article'
sub page_name_ne {
    my $page_name = page_name(shift, '');
    $page_name =~ s/\.(page|conf|model)$//;
    return $page_name;
}

# two page names equal?
sub page_names_equal {
    my ($page_name_1, $page_name_2, $ext) = @_;
    return page_name($page_name_1, $ext) eq page_name($page_name_2, $ext);
}

# 'some_cat' -> 'some_cat.cat'
sub cat_name {
    my $cat_name = shift;

    # append the extension if it isn't already there.
    if ($cat_name !~ m/\.cat$/) {
        $cat_name .= '.cat';
    }

    return $cat_name;
}

# 'some_cat.cat' -> 'some_cat'
sub cat_name_ne {
    my $cat_name = cat_name(shift);
    $cat_name =~ s/\.cat$//;
    return $cat_name;
}

# removes leading and trailing whitespace from a string.
sub trim ($) {
    my $string = shift;
    return undef if !defined $string;
    $string =~ s/^\s*//g;     # remove leading whitespace.
    $string =~ s/\s*$//g;     # remove trailing whitespace.
    return $string;
}

# removes leading and trailing whitespace from a string, returning the
# new string and the number of newlines removed from front and back.
sub trim_count ($) {
    my $string = shift;
    return wantarray ? (undef, 0, 0) : undef if !defined $string;
    my ($front, $back) = (0, 0);
    while ($string =~ s/^(\s+)//) {
        $front += () = $1 =~ /\n/g;
    }
    while ($string =~ s/(\s+)$//) {
        $back += () = $1 =~ /\n/g;
    }
    return wantarray ? ($string, $front, $back) : $string;
}

sub no_length_undef ($) {
    my $str = shift;
    return undef if !length $str;
    return $str;
}

sub filter_defined ($) {
    my $hash = shift;
    ref $hash eq 'HASH' or return {};
    my %new;
    foreach my $key (keys %$hash) {
        my $value = $hash->{$key};
        next unless defined $value;
        $new{$key} = $value;
    }
    return \%new;
}

# human-readable truncation
sub truncate_hr {
    my ($string, $max_chars) = @_;
    return undef if !defined $string || !$max_chars;
    return $string if length $string <= $max_chars;
    return substr($string, 0, $max_chars - 3).'...';
}

sub hash_maybe($) {
    my $href = shift;
    return if ref $href ne 'HASH';
    return %$href;
}

sub keys_maybe($) {
    my %hash = hash_maybe(shift);
    return keys %hash;
}

sub values_maybe($) {
    my %hash = hash_maybe(shift);
    return values %hash;
}

sub fix_value (\$) {
    my $value = shift;
    my @new;
    return if !defined $$value;
    foreach my $item (@$$value) {
        if (blessed $item) {
            push @new, $item;
            next;
        }
        $item =~ s/(^\s*)|(\s*$)//g;
        push @new, $item if length $item;
    }
    $$value = \@new;
    $$value = $new[0] if @new == 1;
    $$value = undef   if !@new;
}

sub append_value (\$$) {
    my ($value, $item) = @_;

    # nothing
    return if !defined $item;

    # first item
    if (ref $$value ne 'ARRAY' || !@$$value) {
        $$value = [ $item ];
        return;
    }

    # if the last element or the append element are refs, push
    my $last = \$$value->[-1];
    if (ref $$last || ref $item) {
        push @$$value, $item;
        return;
    }

    # otherwise, append as text
    $$last .= $item;
}

### LOGGING

our $indent = 0;

sub indent () { $indent++ }
sub back   () { $indent-- }

# log.
sub L(@) {
    my @lines = @_;
    foreach my $str (@lines) {
        if (ref $str eq 'CODE') {
            indent;
            $str->();
            back;
            next;
        }
        chomp $str;
        say STDERR (('    ' x $indent).$str);
    }
}

# log and then indent.
sub Lindent(@) {
    L shift;
    indent;
}

# go back and then log.
sub Lback($) {
    back;
    L shift;
}

sub align {
    my ($action, $info) = @_;
    return sprintf '%-10s%s', $action, $info // '';
}

sub notice {
    my ($type, %opts) = @_;
    my $noti = { %opts, type => $type };
    foreach my $sess (values %Wikifier::Server::sessions) {
        # TODO: make it possible to subscribe to specific types of notifications
        push @{ $sess->{notifications} }, $noti;
    }
}

1
