#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# Wikifier::Page provides an objective interface to a wiki page or article. It implements
# the very user-friendly programming interface of the Wikifier.
#
package Wikifier::Page;

use warnings;
use strict;
use feature qw(switch);

# create a new page.
sub new {
    my ($class, %opts) = @_;
    $opts{content} ||= [];
    return bless \%opts, $class;
}

# parses the file.
sub parse {
    my $page = shift;
    $page->{wikifier} = Wikifier->new(file => $page->{file});
    return $page->wikifier->parse($page);
}

# returns the generated page HTML.
sub html {
    my $page = shift;
    return $page->{wikifier}{main_block}->result($page);
}

# set a variable.
sub set {
    my ($page, $var, $value) = @_;
    my ($hash, $name) = $page->_get_hash($var);
    $hash->{$name} = $value;
}

# fetch a variable.
sub get {
    my ($page, $var) = @_;
    my ($hash, $name) = $page->_get_hash($var);
    return $hash->{$name};
}

# interna use only.
sub _get_hash {
    my ($page, $var) = @_;
    my $hash = ($page->{variables} ||= {});
    my $i    = 0;
    my @parts = split /\./, $var;
    foreach my $part (@parts) {
        last if $i == $#parts;
        $hash->{$part} ||= {};
        $hash = $hash->{$part};
        $i++;
    }
    return ($hash, $parts[-1]);
}

# returns HTML for formatting.
sub parse_formatted_text {
    my ($page, $text) = @_;
    return $page->wikifier->parse_formatted_text($page, $text);
}

sub wikifier { shift->{wikifier} }

1
