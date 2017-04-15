# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Server::Connection;

use warnings;
use strict;
use 5.010;

use JSON::XS ();
use Wikifier::Utilities qw(L filter_nonempty);
use Scalar::Util qw(weaken);

my $json = JSON::XS->new->allow_blessed;
my $id = 'a';

# create a new connection.
sub new {
    my ($class, $stream) = @_;
    return bless { stream => $stream, id => '@'.$id++ }, $class;
}

# write a line of JSON-encoded data.
sub send {
    my ($conn, $command, $args, @rest) = @_;
    my $json_text = $json->encode([
        $command,
        filter_nonempty($args),
        @rest
    ]);
    print STDERR "S: $json_text\n" if $ENV{WIKIFIER_DEBUG};
    $conn->{stream}->write("$json_text\n");
}

# close the connection.
sub close : method {
    my $conn = shift;
    return if $conn->{closed};
    $conn->{closed} = 1;
    my $stream = delete $conn->{stream};
    delete $stream->{conn};
    $conn->l('Connection closed');
    $stream->close;
}

# send an error and close connection.
sub error {
    my ($conn, $error, %other) = @_;
    $conn->send(error => { reason => $error, %other });
    $conn->l("Error: $error");
    $conn->close;
}

# handle a line of data.
sub handle {
    my ($conn, $line) = @_;
    my $return = undef;
    print STDERR "C: $line\n" if $ENV{WIKIFIER_DEBUG};

    # not interested if we're dropping the connection
    return if $conn->{closed};

    # make sure it's a JSON array.
    my $data = eval { $json->decode($line) };
    if (!$line || !$data || ref $data ne 'ARRAY') {
        $conn->error('Message must be a JSON array');
        $conn->close;
        return;
    }

    # make sure it has a message type.
    my ($command, $msg, $possible_id) = @$data;
    if (!length $command) {
        $conn->error('Message has no type');
        return;
    }

    # make sure the second element is an object.
    if ($msg && ref $msg ne 'HASH') {
        $conn->error('Message content must be a JSON object');
        return;
    }

    # make sure the second element, if present, is an integer.
    if (defined $possible_id && $possible_id =~ m/\D/) {
        $conn->error('Message ID must be an integer');
        return;
    }

    # Safe point - the message is synactically valid, so we should use
    # $msg->reply and $msg->error from this point on.

    # store the connection and ID
    bless $msg, 'Wikifier::Server::Message';
    weaken($msg->{conn} = $conn);
    $msg->{_reply_id} = $possible_id + 0 if defined $possible_id;

    # pass it on to handlers.
    if (my $code = Wikifier::Server::Handlers->can("handle_$command")) {

        # set the user in the wiki for the handler
        my ($wiki, $sess) = @$conn{'wiki', 'sess'};
        $wiki->{user} = $sess->{user} if $sess && $sess->{user};

        # call the code
        $return = $code->($conn, $msg || {});

        delete $wiki->{user} if $wiki;
    }

    # if the 'close' option exists, close the connection afterward.
    $conn->close if $msg->{close};

    return $return;
}

sub l {
    my $conn = shift;
    my $wiki = $conn->{wiki_name};
    $wiki = length $wiki ? "/$wiki" : '';
    L "[$$conn{id}$wiki] @_";
}

1
