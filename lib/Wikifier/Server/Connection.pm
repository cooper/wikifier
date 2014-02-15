#!/usr/bin/perl
# Copyright (c) 2014 Mitchell Cooper
package Wikifier::Server::Connection;

use warnings;
use strict;

use JSON qw(encode_json decode_json);

my $id = 'a';

# create a new connection.
sub new {
    my ($class, $stream) = @_;
    return bless { stream => $stream, id => q(@).$id++ }, $class;
}

# write a line of JSON-encoded data.
sub send {
    my ($connection, @etc) = @_;
    my $json = JSON->new->allow_blessed(1)->encode(\@etc);
    $connection->{stream}->write("$json\n");
}

# close the connection.
sub close {
    my $connection = shift;
    return if $connection->{closed};
    $connection->{closed} = 1;
    my $stream = delete $connection->{stream};
    delete $stream->{connection};
    Wikifier::l('Closing connection '.$connection->{id});
    $stream->close;
}

# send an error and close connection.
sub error {
    my ($connection, $error) = @_;
    $connection->send(error => { reason => $error });
    Wikifier::l("Connection error '$error' $$connection{id}");
    $connection->close;
}

# handle a line of data.
sub handle {
    my ($connection, $line) = @_;
    my $return = undef;
    
    # make sure it's a JSON array.
    my $data = eval { decode_json($line) };
    if (!$line || !$data || ref $data ne 'ARRAY') {
        $connection->error('Message must be a JSON array');
        $connection->close;
        return;
    }
    my ($command, $msg) = @$data;
    
    # make sure it has a message type.
    if (!$command && !length $command) {
        $connection->error('Empty message type received');
        return;
    }
    
    # make sure the second element is an object.
    if ($msg && ref $msg ne 'HASH') {
        $connection->error('Second element of message must be a JSON object');
        return;
    }
    
    # if the connection is not authenticated, this better be a wiki command.
    if (!$connection->{authenticated} && $command ne 'wiki') {
        $connection->error('Authentication required');
        return;
    }
    
    # pass it on to handlers.
    if (my $code = Wikifier::Server::Handlers->can("handle_$command")) {
        $return = $code->($connection, $msg || {});
    }
    
    # if the 'close' option exists, close the connection afterward.
    if ($msg->{close}) {
        Wikifier::l("Connection $$connection{id} requested close");
        $connection->close;
    }
    
    return $return;
}

1
