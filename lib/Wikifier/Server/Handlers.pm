#!/usr/bin/perl
# Copyright (c) 2013 Mitchell Cooper
package Wikifier::Server::Handlers;

use warnings;
use strict;
use feature qw(say switch);

use Digest::SHA 'sha1_hex';

my ($loop, $conf);

sub initialize {
    ($loop, $conf) = ($Wikifier::server::loop, $Wikifier::Server::conf);
}

# authentication.
sub handle_wiki {
    my ($connection, $msg) = _required(@_, qw(name password)) or return;
    my $name = (split /\./, $msg->{name})[0];
    
    # ensure that this wiki is configured on this server.
    if (!$conf->get("server.wiki.$name") || !$Wikifier::Server::wiki{$name}) {
        $connection->error("Wiki '$name' not configured on this server");
        return;
    }
    
    # see if the passwords match.
    my $encrypted = sha1_hex($msg->{password});
    if ($encrypted ne $conf->get("server.wiki.$name.password")) {
        $connection->error("Password does not match configuration");
        return;
    }
    
    # authentication succeeded.
    $connection->{authenticated} = 1;
    $connection->{wiki_name}     = $name;
    $connection->{wiki}          = $Wikifier::Server::wiki{$name};
    
    say "Successful authentication for '$name' by $$connection{id}";
    
}

# page request.
sub handle_page {
    my ($connection, $msg) = _required(@_, 'name') or return;
    my $result = $connection->{wiki}->display_page($msg->{name});
    $connection->send('page', $result);
    say "Page '$$msg{name}' requested by $$connection{id}";
}

# check for all required things.
# disconnect from the client if one is missing.
sub _required {
    my ($connection, $msg, @required) = @_;
    foreach (@required) {
        next if defined $msg->{$_};
        $connection->error("Required option '$_' missing");
        return;
    }
    return my @a = ($connection, $msg);
}

1