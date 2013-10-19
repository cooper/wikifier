#!/usr/bin/perl
# Copyright (c) 2013 Mitchell Cooper
package Wikifier::Server::Handlers;

use warnings;
use strict;
use feature qw(say switch);

sub handle_wiki {
    my ($connection, $msg) = @_;
    say "Got wiki command: $msg\n";
}

1
