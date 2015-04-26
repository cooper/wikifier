# Copyright (c) 2014, Mitchell Cooper
package Wikifier::Server;

use warnings;
use strict;

use IO::Async::Loop;
use IO::Async::File;
use IO::Async::Listener;
use IO::Async::Timer::Periodic;
use IO::Socket::UNIX;
use JSON qw(encode_json decode_json);

use Wikifier::Wiki;
use Wikifier::Server::Connection;
use Wikifier::Server::Handlers;

our ($loop, $conf, %wikis, %files, %sessions);

# start the server.
sub start {
    ($loop, my $conf_file) = @_;
    Wikifier::lindent('Initializing Wikifier::Server');
    
    # load configuration.
    ($conf = Wikifier::Page->new(
        file => $conf_file,
        name => $conf_file
    ) or die "Error in configuration\n")->parse;

    # create a timer for session disposal.
    my $timer = IO::Async::Timer::Periodic->new(
        interval => 300,
        on_tick  => \&delete_old_sessions
    );
    $loop->add($timer);
    
    # create a new listener and add it to the loop.
    my $listener = IO::Async::Listener->new(on_stream => \&handle_stream);
    $loop->add($listener);

    # if a file already exists and is a socket, I assume we should delete it.
    my $path = $conf->get('server.socket.path');
    unlink $path if $path && -S $path;

    # create the socket.
    my $socket = IO::Socket::UNIX->new(
        Local  => $path || die("No socket file path specified\n"),
        Listen => 1
    ) or die "Can't create UNIX socket: $!\n";

    # begin listening.
    $listener->listen(handle => $socket);
    Wikifier::l("Listen    $path");
    Wikifier::back();

    # set up handlers.
    Wikifier::Server::Handlers::initialize();
    
    # create Wikifier::Wiki instances.
    create_wikis();
    pregenerate();

    # run forever.
    $loop->run;
    
}

# handle a new stream.
sub handle_stream {
    my (undef, $stream) = @_;
   
    $stream->{connection} = Wikifier::Server::Connection->new($stream);
    Wikifier::l("New connection $$stream{connection}{id}");
    
    # configure the stream.
    my $close = sub { shift->{connection}->close };
    $stream->configure(
        on_read         => \&handle_data,
        on_write_eof    => $close,
        on_read_eof     => $close,
        on_read_error   => $close,
        on_write_error  => $close,
    );
    
    # add the stream to the loop.
    $loop->add($stream);

}

# handle incoming data.
sub handle_data {
    my ($stream, $buffref, $eof) = @_;
    while ($$buffref =~ s/^(.*?)\n//) {
        print "~ $1\n";
        # handle the data ($1)
        return unless $stream->{connection}; # might be closed.
        $stream->{connection}->handle($1);
        
    }
}

# create Wikifier::Wiki instances.
sub create_wikis {
    my $w = $conf->get('server.wiki');
    my %confwikis = $w && ref $w eq 'HASH' ? %$w : {};
    Wikifier::lindent('Initializing Wikifier::Wiki instances');
    
    foreach my $name (keys %confwikis) {

        Wikifier::lindent("[$name]");
    
        # load the wiki.
        my $wiki = Wikifier::Wiki->new(
            config_file => $conf->get("server.wiki.$name.config")
        );
        
        # it failed.
        Wikifier::l("Error in wiki configuration") and next unless $wiki;
        
        # it succeeded.
        $wikis{$name} = $wiki;
        $wiki->{name} = $name;
        
        Wikifier::back();
        
    }
    
    Wikifier::lback('Done initializing');
}

# if pregeneration is enabled, do so.
sub pregenerate {
    return unless $conf->get('server.enable.pregeneration');
    gen_wiki($_) foreach values %wikis;
}

sub gen_wiki {
    my $wiki = shift;
    my $page_dir  = $wiki->opt('dir.page');
    my $cache_dir = $wiki->opt('dir.cache');

    # create a file monitor.
    if (!$files{ $wiki->{name} }) {
        my $file = $files{ $wiki->{name} } = IO::Async::File->new(
            filename => $page_dir,
            on_mtime_changed => sub { gen_wiki($wiki) }
        );
        $loop->add($file);
    }

    Wikifier::lindent("Checking [$$wiki{name}]");
    
    foreach my $page_name ($wiki->all_pages) {
        my $page_file  = "$page_dir/$page_name";
        my $cache_file = "$cache_dir/$page_name.cache";
        
        # determine modification times.
        my $page_modified  = (stat $page_file )[9];
        my $cache_modified = (stat $cache_file)[9] if $cache_file;
        
        # cached copy is newer; skip this page.
        if ($page_modified && $cache_modified) {
            next if $cache_modified >= $page_modified;
        }
        
        # page is not cached or has changed since cache time.
        Wikifier::lindent("($page_name)");
        $wiki->display_page($page_name);
        Wikifier::back();
        
    }
    
    Wikifier::lback("Done [$$wiki{name}]");
}

# dispose of sessions older than 5 hours
sub delete_old_sessions {
    foreach my $session_id (keys %sessions) {
        next if time - $sessions{$session_id} < 18000;
        delete $sessions{$session_id};
    }
}

1
