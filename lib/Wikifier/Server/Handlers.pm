# Copyright (c) 2014 Mitchell Cooper
package Wikifier::Server::Handlers;

use warnings;
use strict;

use Digest::SHA  'sha1_hex';
use Scalar::Util 'weaken';

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
    'm+' => sub {   ($_[0]{modified} ||  0) <=>   ($_[1]{modified} ||  0)   },
    'm-' => sub {   ($_[1]{modified} ||  0) <=>   ($_[0]{modified} ||  0)   },
    'u+' => sub { lc($_[0]{author}   // '') cmp lc($_[1]{author}   // '')   },
    'u-' => sub { lc($_[1]{author}   // '') cmp lc($_[0]{author}   // '')   }
);

sub _simplify_errors {
    my @errs = @_;
    my @final;
    foreach $err (@errs) {
        @lines = grep { s/\r//g; !/^#/ } split /\n/, $err;
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
    
    Wikifier::l("Successful authentication for read access to '$name' by $$connection{id}");
}

# method 1: username/password authentication
#
#   username:       the plaintext account name
#   password:       the plaintext password
#   session_id:     a string to identify the session (optional)
#
sub handle_login {
    my ($connection, $msg) = read_required(@_, qw(username password)) or return;

    # verify password
    if (!$connection->{wiki}->verify_login($msg->{username}, $msg->{password})) {
        $connection->error('Incorrect password', incorrect => 1);
        return;
    }
    
    # authentication succeeded.
    $connection->{username}   = $msg->{username};
    $connection->{priv_write} = 1;
    $connection->{session_id} = $msg->{session_id};
    $connection->send(login => { logged_in => 1 });
    $Wikifier::Server::sessions{ $msg->{session_id} } = [ time, $connection->{username} ];

    Wikifier::l("Successful authentication for write access to '$$connection{wiki_name}' by $$connection{id}");
}

# method 2: session ID authentication
#
#   session_id:     a string to identify the session
#
sub handle_resume {
    my ($connection, $msg) = read_required(@_, 'session_id') or return;

    # session is too old or never existed.
    if (!$Wikifier::Server::sessions{ $msg->{session_id} }) {
        Wikifier::l("Bad session ID for $$connection{id}; refusing authentication");
        $connection->error('Please login again', login_again => 1);
        return;
    }
    
    # authentication succeeded.
    $connection->{priv_write} = 1;
    $connection->{session_id} = $msg->{session_id};
    $Wikifier::Server::sessions{ $msg->{session_id} }[0] = time;

    Wikifier::l("Resuming write access to '$$connection{wiki_name}' by $$connection{id}");
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
    Wikifier::l("Page '$$msg{name}' requested by $$connection{id}");
}

# page code request
#
#   name:   the name of the page
#
sub handle_page_code {
    my ($connection, $msg) = read_required(@_, 'name') or return;
    my $result = $connection->{wiki}->display_page_code($msg->{name});
    $connection->send('page_code', $result);
    Wikifier::l("Code for page '$$msg{name}' requested by $$connection{id}");
}

# page list
#
#   sort:   method to sort the results
#
sub handle_page_list {
    my ($connection, $msg) = read_required(@_, 'sort') or return;
    
    # get all pages
    my %pages = %{ $connection->{wiki}->cat_get_pages('all') };
    my @pages = map { my $ref = $pages{$_}; $ref->{file} = $_; $ref } keys %pages;
    
    # sort
    # TODO: m+ and m- won't work because 'modified' doesn't exist
    my $sorter = $sort_options{ $msg->{sort} } || $sort_options{'m-'};
    @pages = sort { $sorter->($a, $b) } @pages;
    
    $connection->send('page_list', { pages => \@pages });
    Wikifier::l("Complete page list requested by $$connection{id}");
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
    Wikifier::lindent("Image '$$msg{name}' requested by $$connection{id}");
    my $result = $connection->{wiki}->display_image(
        [ $msg->{name}, $msg->{width} || 0, $msg->{height} || 0 ],
        1
    );
    delete $result->{content};
    Wikifier::back();
    $connection->send('image', $result);
}

# category posts
#
#   name:   the name of the category
#
sub handle_catposts {
    my ($connection, $msg) = read_required(@_, 'name') or return;
    Wikifier::lindent("Category posts for '$$msg{name}' requested by $$connection{id}");
    my $result = $connection->{wiki}->display_category_posts($msg->{name});
    Wikifier::back();
    $connection->send('catposts', $result);
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
    my ($connection, $msg) = write_required(@_, qw(name content));
    
    # remove carriage returns injected by the browser
    $msg->{content} =~ s/\r\n/\n/g;
    $msg->{content} =~ s/\r//g;
    
    # update the page
    my $wiki = $connection->{wiki} or return;
    my $page = $wiki->page_named($msg->{name}, content => $msg->{content});
    my @errs = $wiki->write_page($page);
    
    $connection->send(page_save => {
        saved      => !@errs,
        rev_errors => \@errs,
        rev_error  => _simplify_errors(@errs),
        rev_latest => @errs ? undef : $wiki->rev_latest
    });
}

sub handle_page_del {
    # copy old page to revisions
    # delete the page file
    # remove it from all categories
    # commit: deleted page x.page
    my ($connection, $msg) = write_required(@_, 'name');

    # delete the page
    my $wiki = $connection->{wiki};
    my $page = $wiki->page_named($msg->{name});
    $wiki->delete_page($page);
    
    $connection->send(page_del => { deleted => 1 });
}

sub handle_page_move {
    # rename page file
    # commit: moved page a.page -> b.page
    my ($connection, $msg) = write_required(@_, qw(name new_name));
    
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

#################
### UTILITIES ###
#################

# check for all required things.
# disconnect from the client if one is missing.
sub read_required {
    my ($connection, $msg, @required) = @_;
    foreach (@required) {
        next if defined $msg->{$_};
        $connection->error("Required option '$_' missing");
        return;
    }
    return my @a = ($connection, $msg);
}

# check for all required things.
# disconnect from the client if one is missing.
# disconnect if the client does not have write access.
sub write_required {
    my ($connection) = @_;
    if (!$connection->{priv_write}) {
        $connection->error('No write access');
        return;
    }
    &read_required;
}

1
