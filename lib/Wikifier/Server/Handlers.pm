# Copyright (c) 2014 Mitchell Cooper
package Wikifier::Server::Handlers;

use warnings;
use strict;

use Digest::SHA  'sha1_hex';
use Scalar::Util 'weaken';
use Wikifier::Utilities qw(Lindent back notice);

my ($loop, $conf);

sub initialize {
    ($loop, $conf) = ($Wikifier::server::loop, $Wikifier::Server::conf);
}

# Sort options
#
#   a+  sort alphabetically             ascending   (a-z)
#   a-  sort alphabetically             descending  (z-a)
#   c+  sort by creation time           ascending   (oldest first)
#   c-  sort by creation time           descending  (recent first)
#   m+  sort by modification time       ascending   (oldest first)
#   m-  sort by modification time       descending  (recent first)
#   u+  sort by author alphabetically   ascending   (a-z)
#   u-  sort by author alphabetically   descending  (z-a)
#
sub _t { lc(length $_[0]{title} ? $_[0]{title} : $_[0]{file}) }
my %sort_options = (
    'a+' => sub { _t($_[0])                 cmp _t($_[1])                   },
    'a-' => sub { _t($_[1])                 cmp _t($_[0])                   },
    'c+' => sub {   ($_[0]{created}  ||  0) <=>   ($_[1]{created}  ||  0)   },
    'c-' => sub {   ($_[1]{created}  ||  0) <=>   ($_[0]{created}  ||  0)   },
    'm+' => sub {   ($_[0]{mod_unix} ||  0) <=>   ($_[1]{mod_unix} ||  0)   },
    'm-' => sub {   ($_[1]{mod_unix} ||  0) <=>   ($_[0]{mod_unix} ||  0)   },
    'u+' => sub { lc($_[0]{author}   // '') cmp lc($_[1]{author}   // '')   },
    'u-' => sub { lc($_[1]{author}   // '') cmp lc($_[0]{author}   // '')   }
);

sub _simplify_errors {
    my @errs = @_;
    my @final;
    foreach my $err (@errs) {
        my @lines = grep { s/\r//g; !/^#/ } split /\n/, $err;
        push @final, join "\n", @lines;
    }
    return join "\n\n", @final;
}

######################
### AUTHENTICATION ###
######################

# anonymous authentication
#
# note: there is a special exemption for this function so that
# it does not require read acces - checked BEFORE read_required().
#
sub handle_wiki {
    my ($connection, $msg) = read_required(@_, qw(name password)) or return;
    my $name = (split /\./, $msg->{name})[0];

    # ensure that this wiki is configured on this server.
    if (!$conf->get("server.wiki.$name") || !$Wikifier::Server::wikis{$name}) {
        $connection->error("Wiki '$name' not configured on this server");
        return;
    }

    # see if the passwords match.
    my $encrypted = sha1_hex($msg->{password});
    if ($encrypted ne $conf->get("server.wiki.$name.password")) {
        $connection->error("Password does not match configuration");
        return;
    }

    # anonymous authentication succeeded.
    $connection->{priv_read} = 1;
    $connection->{wiki_name} = $name;
    weaken($connection->{wiki} = $Wikifier::Server::wikis{$name});

    $connection->l("Successfully authenticated for read access");
}

# method 1: username/password authentication
#
#   username:       the plaintext account name
#   password:       the plaintext password
#   session_id:     (optional) a string to identify the session
#
sub handle_login {
    my ($connection, $msg) = read_required(@_, qw(username password)) or return;
    my $sess_id = $msg->{session_id};

    # verify password
    my $wiki = $connection->{wiki};
    my $username  = $msg->{username};
    my $user_info = $wiki->verify_login(
        $username,
        $msg->{password}
    );
    if (!$user_info) {
        $connection->error('Incorrect password', incorrect => 1);
        return;
    }

    # authentication succeeded.
    $connection->send(login => {
        logged_in => 1,
        %$user_info,
        conf => $wiki->{conf}{variables} || {}
    });

    notice(user_logged_in => %$user_info);

    # store the session in the connection no matter what
    $connection->{sess} = {
        login_time  => time,        # session creation time
        time        => time,        # time of last (re)authentication
        id          => $sess_id,    # session ID (optional)
        username    => $username,   # username
        user        => $user_info,  # user info hash
        notices     => [],          # pending notifications
        priv_write  => 1            # write access
    };

    # also store it in the session hash if an ID was provided
    $Wikifier::Server::sessions{$sess_id} = $connection->{sess}
        if length $sess_id;

    $connection->l('Successfully authenticated for write access');
}

# method 2: session ID authentication
#
#   session_id:     a string to identify the session
#
sub handle_resume {
    my ($connection, $msg) = read_required(@_, 'session_id') or return;

    # session is too old or never existed.
    my $sess = $Wikifier::Server::sessions{ $msg->{session_id} };
    if (!$sess) {
        $connection->l("Bad session ID; refusing reauthentication");
        $connection->error('Please login again', login_again => 1);
        return;
    }

    # authentication succeeded.
    $sess->{time} = time;
    $connection->{sess} = $sess;

    $connection->l('Resuming write access');
}

#####################
### READ REQUIRED ###
#####################

# page request
#
#   name:   the name of the page
#
sub handle_page {
    my ($connection, $msg) = read_required(@_, 'name') or return;
    my $result = $connection->{wiki}->display_page($msg->{name});
    $connection->send('page', $result);
    $connection->l("Page '$$msg{name}' requested");
}

# page code request
#
#   name:           the name of the page
#
#   display_page:   (optional). 1 to call ->display_page and set its result
#                   to {display_result} in the response, except for the
#                   {content}. 2 to do the same except also preserve the content
#
sub handle_page_code {
    my ($connection, $msg) = read_required(@_, 'name') or return;
    my $result = $connection->{wiki}->display_page_code(
        $msg->{name},
        $msg->{display_page}
    );
    $connection->send('page_code', $result);
    $connection->l("Page '$$msg{name}' code requested");
}

# page list
#
#   sort:   method to sort the results
#
sub handle_page_list {
    my ($connection, $msg) = write_required(@_, 'sort') or return;

    # get all pages
    my %pages = %{ $connection->{wiki}->cat_get_pages('all') };
    my @pages = map {
        my $ref = $pages{$_};
        $ref->{file} = $_;
        $ref
    } keys %pages;

    # sort
    my $sorter = $sort_options{ $msg->{sort} } || $sort_options{'m-'};
    @pages = sort { $sorter->($a, $b) } @pages;

    $connection->send('page_list', { pages => \@pages });
    $connection->l("Complete page list requested");
}

# image request
#
#   name:       the image filename
#   width:      desired image width     (optional)
#   height:     desired image height    (optional)
#
#   dimensions default to those of the original image
#
sub handle_image {
    my ($connection, $msg) = read_required(@_, 'name') or return;
    Lindent("Image '$$msg{name}' requested by $$connection{id}");
    my $result = $connection->{wiki}->display_image(
        [ $msg->{name}, $msg->{width} || 0, $msg->{height} || 0 ],
        1 # don't open the image
    );
    delete $result->{content};
    back;
    $connection->send('image', $result);
}

# category posts
#
#   name:   the name of the category
#
sub handle_cat_posts {
    my ($connection, $msg) = read_required(@_, 'name') or return;
    Lindent("Category posts for '$$msg{name}' requested by $$connection{id}");
    my $result = $connection->{wiki}->display_cat_posts($msg->{name});
    back;
    $connection->send('cat_posts', $result);
}

# category list.
#
#   sort:   method to sort the results
#
sub handle_cat_list {

}

######################
### WRITE REQUIRED ###
######################

# page save
#
#   name:       the name of the page
#   content:    the page code
#
sub handle_page_save {
    # update the page file
    # regenerate it
    # commit: (existed? added : modified) x.page: user edit message
    my ($connection, $msg) = write_required(@_, qw(name content)) or return;

    # remove carriage returns injected by the browser
    $msg->{content} =~ s/\r\n/\n/g;
    $msg->{content} =~ s/\r//g;

    # update the page
    my $wiki = $connection->{wiki};
    my $page = $wiki->page_named($msg->{name}, content => $msg->{content});
    my @errs = $wiki->write_page($page, $msg->{message});

    $connection->send(page_save => {
        result     => $page->{recent_result},
        saved      => !@errs,
        rev_errors => \@errs,
        rev_error  => _simplify_errors(@errs),
        rev_latest => @errs ? undef : $wiki->rev_latest,
    });
}

sub handle_page_del {
    # copy old page to revisions
    # delete the page file
    # remove it from all categories
    # commit: deleted page x.page
    my ($connection, $msg) = write_required(@_, 'name') or return;

    # delete the page
    my $wiki = $connection->{wiki};
    my $page = $wiki->page_named($msg->{name});
    $wiki->delete_page($page);

    $connection->send(page_del => { deleted => 1 });
}

sub handle_page_move {
    # rename page file
    # commit: moved page a.page -> b.page
    my ($connection, $msg) = write_required(@_, qw(name new_name)) or return;

    # rename the page
    my $wiki = $connection->{wiki};
    my $page = $wiki->page_named($msg->{name});
    $wiki->move_page($page, $msg->{new_name});

    $connection->send(page_move => { moved => 1 });
}

sub handle_cat_del {
    # copy all affected old pages to revisions
    # search all affected pages for @category.(x)
    # commit: deleted category x.cat
}

sub handle_ping {
    my ($connection) = write_required(@_) or return;
    my $notices = delete $connection->{sess}{notifications};
    $connection->{sess}{notifications} = [];
    $connection->send(pong => {
        connected     => 1,
        notifications => $notices
    });
}

#################
### UTILITIES ###
#################

# check for all required things.
# disconnect from the client if one is missing.
sub read_required {
    my ($connection, $msg, @required) = @_;
    my @good;
    foreach (@required) {
        if (defined $msg->{$_}) {
            push @good, $msg->{$_};
            next;
        }
        $connection->error("Required option '$_' missing");
        return;
    }
    return my @a = ($connection, $msg, @good);
}

# check for all required things.
# disconnect from the client if one is missing.
# disconnect if the client does not have write access.
sub write_required {
    my ($connection) = @_;
    if (!$connection->{sess} || !$connection->{sess}{priv_write}) {
        $connection->error('No write access');
        return;
    }
    &read_required;
}

1
