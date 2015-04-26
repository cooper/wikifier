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

#####################
### READ REQUIRED ###
#####################

# page request.
sub handle_page {
    my ($connection, $msg) = read_required(@_, 'name') or return;
    my $result = $connection->{wiki}->display_page($msg->{name}, 1);
    $connection->send('page', $result);
    Wikifier::l("Page '$$msg{name}' requested by $$connection{id}");
}

# image request.
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

# category posts.
sub handle_catposts {
    my ($connection, $msg) = read_required(@_, 'name') or return;
    Wikifier::lindent("Category posts for '$$msg{name}' requested by $$connection{id}");
    my $result = $connection->{wiki}->display_category_posts($msg->{name});
    Wikifier::back();
    $connection->send('catposts', $result);
}

######################
### WRITE REQUIRED ###
######################



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
