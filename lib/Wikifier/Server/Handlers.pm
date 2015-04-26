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
    
    # FIXME: actually authenticate
    # authentication succeeded.
    $connection->{priv_write} = 1;
    $connectin->{session_id} = $msg->{session_id};
    $connection->send(login => { logged_in => 1 });
    
    Wikifier::l("Successful authentication for write access to '$$connection{wiki_name}' by $$connection{id}");
}

# method 2: session ID authentication
#
#   session_id:     a string to identify the session
#
sub handle_resume {
    my ($connection, $msg) = read_required(@_, 'session_id') or return;

    # FIXME: actually authenticate
    # authentication succeeded.
    $connection->{priv_write} = 1;
    $connection->{session_id} = $msg->{session_id};
    $connection->send(login => { logged_in => 1 });

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
    my $result = $connection->{wiki}->display_page($msg->{name}, 1);
    $connection->send('page', $result);
    Wikifier::l("Page '$$msg{name}' requested by $$connection{id}");
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

# Sort options
#
#   a+  sort alphabetically             ascending   (a-z)
#   a-  sort alphabetically             descending  (z-a)
#   c+  sort by creation time           ascending   (oldest first)
#   c-  sort by creation time           descending  (recent first)
#   m+  sort by modification time       ascending   (oldest first)
#   m-  sort by modification time       descending  (recent first)
#

# page list
#
#   sort:   method to sort the results
#
sub handle_pagelist {
    my ($connection, $msg) = read_required(@_, 'sort') or return;

}

# category list.
#
#   sort:   method to sort the results
#
sub handle_pagelist {
    
}

######################
### WRITE REQUIRED ###
######################

sub handle_pagedel {
    # copy old page to revisions
    # delete the page file
    # remove it from all categories
    # commit: deleted page x.page
}

sub handle_catdel {
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
    my $connection = @_;
    if (!$connection->{priv_write}) {
        $connection->error('No write access');
        return;
    }
    return read_required(@_);
}

1
