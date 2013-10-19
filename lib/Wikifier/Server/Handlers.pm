#!/usr/bin/perl
# Copyright (c) 2013 Mitchell Cooper
package Wikifier::Server::Handlers;

use warnings;
use strict;
use feature qw(say switch);

my ($loop, $conf) = ($Wikifier::server:loop, $Wikifier::Server::conf);

sub handle_wiki {
    my ($connection, $msg) = _required(@_, qw(name password)) or return;

    say "Got wiki command: $$msg{name} $$msg{password}";
}

# check for all required things.
# disconnect from the client if one is missing.
sub _required {
    my ($connection, $msg, @required) = @_;
    foreach (@required) {
        next if defined $msg->{$_};
        $connection->error('Required option \''.$_.'\' missing');
        return;
    }
    return my @a = ($connection, $msg);
}

1
