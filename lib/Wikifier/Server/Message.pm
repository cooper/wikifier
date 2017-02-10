# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Server::Message;

use warnings;
use strict;
use 5.010;

# reply
sub reply {
    my ($msg, $reply_type, $href) = @_;
    my @args = ($reply_type => $href);
    push @args, $msg->{_reply_id} if defined $msg->{_reply_id};
    $msg->conn->send(@args);
}

# error
sub error {
    my ($msg, $error, %other) = @_;
    $msg->reply(error => { reason => $error, %other });
    $msg->l("Error: $error");
    $msg->conn->close;
}

sub l       { shift->conn->l(@_)    }
sub conn    { shift->{conn}         }

1
