# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use Wikifier::Utilities qw(E);
use Scalar::Util qw(openhandle);
use JSON::XS ();

my $json = JSON::XS->new->convert_blessed;

my %allowed_log_types = (
    login_fail          => [ qw(username crypt reason)                        ],
    login               => [ qw(username name email crypt)                    ],
    page_write          => [ qw(file message commit)                          ],
    page_write_fail     => [ qw(file message errors)                          ],
    page_delete         => [ qw(file commit)                                  ],
    page_delete_fail    => [ qw(file errors)                                  ],
    page_move           => [ qw(src_name src_file dest_name dest_file commit) ],
    page_move_fail      => [ qw(src_name src_file dest_name dest_file errors) ]
);

sub Log {
    my ($wiki, $log_type, $attributes) = (shift, @_);
    my $log_file = $wiki->opt('dir.cache').'/wiki.log';
    
    # unknown log type
    my $allowed_attrs = $allowed_log_types{$log_type};
    if (!$allowed_attrs) {
        E("Unknown log type '$log_type'");
        return;
    }
    
    # must be hash
    if (ref $attributes ne 'HASH') {
        E("Expected HASH reference of attributes for log type '$log_type'");
        return;
    }
    
    # weed out unknown attributes
    my %ok = map { $_ => 1 } @$allowed_attrs;
    foreach my $bad (keys %$attributes) {
        next if $ok{$bad};
        E("Unknown attribute '$bad' for log type '$log_type'");
        delete $attributes->{$bad};
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
    open my $fh, '>>', $log_file
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
