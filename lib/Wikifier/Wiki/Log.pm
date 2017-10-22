# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use Wikifier::Utilities qw(E);
use Scalar::Util qw(openhandle);
use JSON::XS ();

my $json = JSON::XS->new->pretty->convert_blessed;

my %allowed_log_types = (
    login_fail => [],
    login => []
);

sub Log {
    my ($wiki, $log_type, $attributes) = (shift, @_);
    my $log_file = $wiki->opt('dir.cache').'/wiki.log';
    
    # must be hash
    if (ref $attributes ne 'HASH') {
        E("Expected HASH reference of attributes for log type '$log_type'");
        return;
    }
    
    # encode to JSON
    my $json_data = $json->encode([ time, $log_type, $attributes ]);
    $json_data   .= "\n";
    
    # an IO::Async::Stream is open
    return $wiki->{log_stream}->write($json_data)
        if $wiki->{log_stream};
        
    # a filehandle is open
    return print { $wiki->{log_fh} } $json_data
        if openhandle($wiki->{log_fh});
    
    # need to open a logfile
    open my $fh, '>', $log_file
        or E("Failed to open wiki log file '$log_file'")
        and return;
    $wiki->{log_fh} = $fh;
    

    # create a stream if possible
    my $loop = $Wikifier::Server::loop;
    if ($INC{'IO/Async/Stream.pm'} && $loop) {
        my $handle_error = sub {
            E("Error writing to $log_file: @_");
            delete $wiki->{log_stream};
            delete $wiki->{log_fh};
        };
        $wiki->{log_stream} = IO::Async::Stream->new(
            write_handle => $fh,
            on_write_error => $handle_error,
            on_write_eof   => $handle_error
        );
        $loop->add($wiki->{log_stream});
    }

    # redo now that we've opened the filehandle
    return $wiki->Log(@_);
}

1
