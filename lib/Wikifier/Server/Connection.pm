#!/usr/bin/perl
# Copyright (c) 2013 Mitchell Cooper
package Wikifier::Server::Connection;

use warnings;
use strict;
use feature qw(say switch);

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
    return if $connection->{closed};
    $connection->{closed} = 1;
    my $stream = delete $connection->{stream};
    delete $stream->{connection};
    say 'Closing connection '.$connection;
    $stream->close;
}

# send an error and close connection.
sub error {
    my ($connection, $error) = @_;
    $connection->send(error => { reason => $error });
    $connection->close;
}

# handle a line of data.
sub handle {
    my ($connection, $line) = @_;
    
    # make sure it's a JSON array.
    my $data = eval { decode_json($line) };
    if (!$line || !$data || ref $data ne 'ARRAY') {
        $connection->error('Message must be a JSON array');
        $connection->close;
        return;
    }
    
    # make sure it has a message type.
    if (!$data->[0] && !length $data->[0]) {
        $connection->error('Empty message type received');
        return;
    }
    
    # make sure the second element is an object.
    if ($data->[1] && ref $data->[1] ne 'HASH') {
        $connection->error('Second element of message must be a JSON object');
        return;
    }
    
    # pass it on to handlers.
    if (my $code = Wikifier::Server::Handlers->can("handle_$$data[0]")) {
        return $code->($connection, $data->[1] || {});
    }
    
    return;
}

1
