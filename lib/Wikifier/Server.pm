#!/usr/bin/perl
# Copyright (c) 2013 Mitchell Cooper
package Wikifier::Server;

use warnings;
use strict;
use feature 'say';

use IO::Async::Loop;
use IO::Async::Listener;
use IO::Socket::UNIX;
use JSON qw(encode_json decode_json);

use Wikifier::Wiki;
use Wikifier::Server::Connection;
use Wikifier::Server::Handlers;

our ($loop, $conf);

# start the server.
sub start {
    ($loop, $conf) = @_;

    # create a new listener and add it to the loop.
    my $listener = IO::Async::Listener->new(on_stream => \&handle_stream);
    $loop->add($listener);

    # if a file already exists and is a socket, I assume we should delete it.
    my $path = $conf->get('server.socket.path');
    if ($path && -S $path) {
        unlink $path;
    }

    # create the socket.
    my $socket = IO::Socket::UNIX->new(
        Local  => $path || die("No socket file path specified\n"),
        Listen => 1
    ) or die "Can't create UNIX socket: $!\n";

    # begin listening.
    $listener->listen(handle => $socket);
    say 'Listening on '.$path;

    # set up handlers.
    Wikifier::Server::Handlers::initialize();

    # run forever.
    $loop->run;
    
}

# handle a new stream.
sub handle_stream {
    my (undef, $stream) = @_;
   
    say "New connection $stream";
    $stream->{connection} = Wikifier::Server::Connection->new($stream);
   
    # configure the stream.
    $stream->configure(
        on_read         => \&handle_data,
        on_write_eof    => sub { shift->{connection}->close },
        on_read_eof     => sub { shift->{connection}->close },
        on_read_error   => sub { shift->{connection}->close },
        on_write_error  => sub { shift->{connection}->close }
    );
    
    # add the stream to the loop.
    $loop->add($stream);

}

# handle incoming data.
sub handle_data {
    my ($stream, $buffref, $eof) = @_;
    while ($$buffref =~ s/^(.*?)\n//) {
        # handle the data ($1)
        $stream->{connection}->handle($1);
    }
}

1
