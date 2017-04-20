# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Server;

use warnings;
use strict;

use IO::Async::Loop;
use IO::Async::File;
use IO::Async::Stream;
use IO::Async::Timer::Periodic;
use IO::Socket::UNIX;
use File::Basename qw(basename);

use Wikifier::Wiki;
use Wikifier::Server::Message;
use Wikifier::Server::Handlers;
use Wikifier::Server::Connection;
use Wikifier::Utilities qw(align L Lindent back page_name);

our ($loop, $conf, %wikis, %files, %sessions);

# start the server.
sub start {
    ($loop, my $conf_file, my $stdio) = @_;
    Lindent 'Initializing server';

        # load configuration.
        ($conf = Wikifier::Page->new(
            file_path => $conf_file,
            name      => basename($conf_file)
        ) or die "Error in configuration\n")->parse;

        # create a timer for session disposal.
        my $timer = IO::Async::Timer::Periodic->new(
            interval => 300,
            on_tick  => \&delete_old_sessions
        );
        $timer->start;
        $loop->add($timer);

        # listen
        listen_unix();
        listen_stdio() if $stdio;
    back;

    # set up handlers.
    Wikifier::Server::Handlers::initialize();

    # create Wikifier::Wiki instances.
    Lindent 'Initializing wikis';
        create_wikis();
        pregenerate();
    back;

    # run forever.
    L 'Done initializing';
    $loop->run;
}

sub listen_unix {
    
    # unix is disabled
    my $path = $conf->get('server.socket.path');
    return if !length $path;
    
    # if a file already exists and is a socket, I assume we should delete it.
    unlink $path if $path && -S $path;
    
    # create a new listener and add it to the loop.
    require IO::Async::Listener;
    my $listener = IO::Async::Listener->new(on_stream => \&handle_stream);
    $loop->add($listener);

    # create the socket.
    my $socket = IO::Socket::UNIX->new(
        Local  => $path || die("No socket file path specified\n"),
        Listen => 1
    ) or die "Can't create UNIX socket: $!\n";

    # begin listening.
    L align('Listen', $path);
    $listener->listen(handle => $socket);
}

sub listen_stdio {
    L align('Listen', '(stdio)');
    my $stream = IO::Async::Stream->new_for_stdio;
    handle_stream(undef, $stream, 'stdio');
}

# handle a new stream.
sub handle_stream {
    my (undef, $stream, $type) = @_;
    $type ||= 'unix';
    
    # create a connection
    $stream->{conn} = Wikifier::Server::Connection->new(
        stream => $stream,
        stdio  => $type eq 'stdio'
    );
    $stream->{conn}->l("New connection ($type)");

    # configure the stream.
    my $close = sub { shift->{conn}->close };
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
        return unless $stream->{conn}; # might be closed.
        $stream->{conn}->handle($1);
    }
}

# create Wikifier::Wiki instances.
sub create_wikis {
    my $w = $conf->get('server.wiki');
    my %confwikis = $conf->get_hash('server.wiki');
    foreach my $name (keys %confwikis) {
        Lindent "[$name]";

        # not enabled
        next if !$conf->get("server.wiki.$name.enable");

        # find the configuration --
        # first, try @server.wiki.[name].config
        # if not set, try [@server.dir.wiki]/[name]/wiki.conf
        my $wiki_dir_wiki;
        my $config = $conf->get("server.wiki.$name.config");
        if (!length $config) {
            my $dir_wiki = $conf->get('server.dir.wiki');
            die "\@server.dir.wiki is required because ".
                "\@server.wiki.$name.config is not set.\n"
                if !length $dir_wiki;
            $wiki_dir_wiki = "$dir_wiki/$name";
            $config = "$wiki_dir_wiki/wiki.conf";
        }

        # load the wiki
        my $wiki = Wikifier::Wiki->new(
            config_file  => $config,
            private_file => $conf->get("server.wiki.$name.private"),
            opts => {
                'dir.wikifier' => $conf->get("server.dir.wikifier"),
                'dir.wiki'     => $wiki_dir_wiki
            }
        );

        # it failed
        unless ($wiki) {
            L 'Failed to initialize';
            next;
        }

        # it succeeded
        $wikis{$name} = $wiki;
        $wiki->{name} = $name;
    } continue {
        back;
    }
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
    my $md_dir    = $wiki->opt('dir.md');

    # create file monitors
    foreach my $path ($page_dir, $md_dir) {
        next if !length $path;
        next if $files{ $wiki->{name} }{$path};
        my $file = $files{ $wiki->{name} }{$path} = IO::Async::File->new(
            filename => $path,
            on_mtime_changed => sub { gen_wiki($wiki) }
        );
        $loop->add($file);
    }

    Lindent "[$$wiki{name}]";

    # markdown files
    foreach my $md_name ($wiki->all_markdowns) {
        
        # can't load
        if (!eval { require Wikifier::Wiki::Markdown }) {
            L 'Unable to load Markdown translator;';
            L 'Please see docs for how to install CommonMark';
            last;
        }

        my $md_path   = "$md_dir/$md_name";
        my $page_name = page_name($md_name);
        my $page_path = "$page_dir/$page_name";
        
        # determine modification times
        my $md_modified    = (stat $md_path   )[9];
        my $page_modified  = (stat $page_path )[9] if $page_path;
        
        # page is newer; skip this markdown
        if ($page_modified && $md_modified) {
            next if $page_modified >= $md_modified;
        }

        # markdown page has not been generated, or .md file has changed
        $wiki->convert_markdown($md_name);
    }

    # pages
    foreach my $page_name ($wiki->all_pages) {
        my $page_path  = "$page_dir/$page_name";
        my $cache_path = "$cache_dir/$page_name.cache";

        # determine modification times.
        my $page_modified  = (stat $page_path )[9];
        my $cache_modified = (stat $cache_path)[9] if $cache_path;

        # cached copy is newer; skip this page.
        if ($page_modified && $cache_modified) {
            next if $cache_modified >= $page_modified;
        }

        # page is not cached or has changed since cache time.
        $wiki->display_page($page_name, draft_ok => 1);
    }

    # categories
    foreach my $cat_type (undef, @Wikifier::Wiki::pseudo_cats) {
    foreach my $cat_name ($wiki->all_categories($cat_type)) {
        my (undef, undef, $err) = $wiki->cat_get_pages($cat_name,
            cat_type => $cat_type
        );
        defined $err or next;
        L "($cat_name)", sub { L $err };
    } }

    back;
}

# dispose of sessions older than 5 hours
sub delete_old_sessions {
    foreach my $session_id (keys %sessions) {
        next if time - $sessions{$session_id}{time} < 18000;
        L "Disposing of old session '$session_id'";
        delete $sessions{$session_id};
    }
}

1
