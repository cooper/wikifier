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
    #return $page->{wikifier}{main_block}->result($page);
    $page->set('hi.are.you.there', 'yes'); return ''
}

# set a variable.
sub set {
    my ($page, $var, $value) = @_;
    my $hash = ($page->{variables} ||= {});
    my $i    = 0;
    my @parts = split /\./, $var;
    foreach my $part (@parts) {
        last if $i == $#parts;
        $hash->{$part} ||= {};
        $hash = $hash->{$part};
        $i++;
    }
    $hash->{$parts[-1]} = $value;
}

# fetch a variable.
sub get {
    my ($page, $var) = @_;
}

sub wikifier { shift->{wikifier} }

1
