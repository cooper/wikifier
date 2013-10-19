#!/usr/bin/perl
# Copyright (c) 2013 Mitchell Cooper
package Wikifier::Server::Connection;

use warnings;
use strict;

use JSON qw(encode_json decode_json);

# create a new connection.
sub new {
    my ($class, $stream) = @_;
    return bless { stream => $stream }, $class;
}

# write a line of JSON-encoded data.
sub send {
    my ($connection, @etc) = @_;
    $connection->{stream}->write(encode_json(\@etc)."\n");
}

# close the connection.
sub close {
    my $connection = shift;
    my $stream = delete $connection->{stream};
    delete $stream->{connection};
    $stream->close;
}

# handle a line of data.
sub handle {
    my ($connection, $line) = @_;
    
    # make sure it's a JSON array.
    my $data = eval { decode_json($line) };
    if (!$line || !$data) {
        $connection->send(error => { reason => 'Message must be a JSON array' });
        $connection->close;
        return;
    }
    
}

1
