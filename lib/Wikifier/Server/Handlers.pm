# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Server::Handlers;

use warnings;
use strict;

use Scalar::Util qw(weaken blessed);
use Wikifier::Utilities qw(notice values_maybe hash_maybe);

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
#   d+  sort by dimensions              ascending   (images only)
#   d-  sort by dimensions              descending  (images only)
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
    'd+' => sub { _sort_dimensions(1, @_)                                   },
    'd-' => sub { _sort_dimensions(0, @_)                                   },
    'm+' => sub {   ($_[0]{mod_unix} ||  0) <=>   ($_[1]{mod_unix} ||  0)   },
    'm-' => sub {   ($_[1]{mod_unix} ||  0) <=>   ($_[0]{mod_unix} ||  0)   },
    'u+' => sub { lc($_[0]{author}   // '') cmp lc($_[1]{author}   // '')   },
    'u-' => sub { lc($_[1]{author}   // '') cmp lc($_[0]{author}   // '')   }
);

sub _sort_dimensions {
    my ($ascend, $img1, $img2) = @_;
    return 0 if !defined $img1->{width};
    $img1 = $img1->{width} * $img1->{height};
    $img2 = $img2->{width} * $img2->{height};
    return $img1 <=> $img2 if $ascend;
    return $img2 <=> $img1;
}

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

# ro method 1: anonymous authentication with password
sub handle_wiki {
    $_[0]->{no_read_ok}++;
    my (undef, $msg) = read_required(@_, qw(name password)) or return;
    my $conn = $msg->conn;
    my $name = (split /\./, $msg->{name})[0];

    # ensure that this wiki is configured on this server.
    if (!$conf->get("server.wiki.$name") || !$Wikifier::Server::wikis{$name}) {
        $msg->error("Wiki '$name' not configured on this server");
        return;
    }

    # see if the passwords match.
    my $ok = $conn->{stdio};
    if (!$ok && $msg->{password} ne $conf->get("server.wiki.$name.password")) {
        $msg->error("Password does not match configuration");
        return;
    }

    # find the wiki.
    my $wiki = $Wikifier::Server::wikis{$name};
    if (!$wiki) {
        $msg->error("Wiki is unavailable");
        return;
    }

    # anonymous authentication succeeded.
    $conn->{priv_read}{$name}++;
    $conn->{wiki_name} = $name;
    weaken($conn->{wiki} = $wiki);

    # normally we do not reply to this, but if the client requested the
    # wiki configuration, send it. see issue #27
    if ($msg->{config}) {
        my %conf = hash_maybe $wiki->{conf}{variables};

        # FIXME: this needs to be recursive! ->to_data might contain more objs!
        # blessed objects will be serialized as null, so convert them to
        # Pure Perl where posssible
        my $nav;
        foreach my $key (keys %conf) {
            my $val = $conf{$key};
            next if !blessed $val || !$val->can('to_data');

            # special case for navigation, to preserve the order
            if ($key eq 'navigation' && $val->can('map_array')) {
                my (@keys, @vals);
                for ($val->map_array) {
                    my ($key_title, $val) = @$_{'key_title', 'value'};
                    push @keys, $key_title;
                    push @vals, $val;
                }
                $conf{$key} = [ \@keys, \@vals ];
                next;
            }

            $conf{$key} = $val->to_data;
        }
        $msg->reply(wiki => { config => \%conf });
    }

    $msg->l("Authenticated for read access");
}

# ro method 2: anonymous reauthentication
sub handle_select {
    $_[0]->{no_read_ok}++;
    my (undef, $msg) = read_required(@_, qw(name)) or return;
    my $conn = $msg->conn;
    my $name = $msg->{name};
    
    # check we're OK to select this.
    if (!$conn->{priv_read}{$name}) {
        $msg->error("Not authenticated for read access");
        return;
    }
    
    # find the wiki.
    my $wiki = $Wikifier::Server::wikis{$name};
    if (!$wiki) {
        $msg->error("Wiki is unavailable");
        return;
    }
    
    # re-select it.
    $conn->{wiki_name} = $name;
    weaken($conn->{wiki} = $wiki);
    
    $msg->reply(select => { name => $name });
    $msg->l("Selected");
}

# rw method 1: username/password authentication
#
#   username:       the plaintext account name
#   password:       the plaintext password
#   session_id:     (optional) a string to identify the session
#
sub handle_login {
    my ($wiki, $msg) = read_required(@_, qw(username password)) or return;
    my $sess_id = $msg->{session_id};
    my $conn    = $msg->conn;

    # verify password
    my $username  = $msg->{username};
    my $user_info = $wiki->verify_login(
        $username,
        $msg->{password}
    );
    if (!$user_info) {
        $msg->error('Incorrect password', incorrect => 1);
        return;
    }

    # authentication succeeded.
    $msg->reply(login => {
        logged_in => 1,
        %$user_info,
        conf => $wiki->{conf}{variables} || {}
    });

    notice(user_logged_in => %$user_info);

    # store the session in the connection no matter what
    $conn->{sess} = {
        login_time  => time,        # session creation time
        time        => time,        # time of last (re)authentication
        id          => $sess_id,    # session ID (optional)
        username    => $username,   # username
        user        => $user_info,  # user info hash
        notices     => [],          # pending notifications
        priv_write  => 1            # write access
    };

    # also store it in the session hash if an ID was provided
    $Wikifier::Server::sessions{$sess_id} = $conn->{sess}
        if length $sess_id;

    $msg->l("Authenticated for write access ($username)");
}

# rw method 2: session ID authentication
#
#   session_id:     a string to identify the session
#
sub handle_resume {
    my ($wiki, $msg) = read_required(@_, 'session_id') or return;
    my $conn = $msg->conn;

    # session is too old or never existed.
    my $sess = $Wikifier::Server::sessions{ $msg->{session_id} };
    if (!$sess) {
        $msg->l("Bad session ID; refusing reauthentication");
        $msg->error('Please login again', login_again => 1);
        return;
    }

    # authentication succeeded.
    $sess->{time} = time;
    $conn->{sess} = $sess;

    $msg->l('Resuming write access');
}

#####################
### READ REQUIRED ###
#####################

# page request
#
#   name:   the name of the page
#
sub handle_page {
    my ($wiki, $msg) = read_required(@_, 'name') or return;
    my $result = $wiki->display_page($msg->{name});
    $msg->reply('page', $result);
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
    my ($wiki, $msg) = write_required(@_, 'name') or return;
    my $result = $wiki->display_page_code(
        $msg->{name},
        display_page => $msg->{display_page}
    );
    $msg->reply('page_code', $result);
}

# model code request
#
#   name:           the name of the model
#
#   display_model:  (optional). 1 to call ->display_model and set its result
#                   to {display_result} in the response, except for the
#                   {content}. 2 to do the same except also preserve the content
#
sub handle_model_code {
    my ($wiki, $msg) = write_required(@_, 'name') or return;
    my $result = $wiki->display_model_code(
        $msg->{name},
        $msg->{display_model}
    );
    $msg->reply('model_code', $result);
}

# page list
#
#   sort:   method to sort the results
#
sub handle_page_list {
    my ($wiki, $msg) = write_required(@_, 'sort') or return;

    # get all pages
    my $all = $wiki->cat_get_pages('pages', cat_type => 'data');
    return if !$all || ref $all ne 'HASH';
    my %pages = %$all;
    my @pages = map {
        my $ref = $pages{$_};
        $ref->{file} = $_;
        $ref
    } keys %pages;

    # sort
    my $sorter = $sort_options{ $msg->{sort} } || $sort_options{'m-'};
    @pages = sort { $sorter->($a, $b) } @pages;

    $msg->reply(page_list => { pages => \@pages });
}

# model list
#
#   sort:   method to sort the results
#
sub handle_model_list {
    my ($wiki, $msg) = write_required(@_, 'sort') or return;

    # get all models
    my @models;
    foreach my $model_name ($wiki->all_models) {
        push @models, { # FIXME: real info
            file  => $model_name,
            title => $model_name
        };
    }

    # sort
    my $sorter = $sort_options{ $msg->{sort} } || $sort_options{'m-'};
    @models = sort { $sorter->($a, $b) } @models;

    $msg->reply(model_list => { models => \@models });
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
    my ($wiki, $msg) = read_required(@_, 'name') or return;
    my $result = $wiki->display_image(
        [ $msg->{name}, $msg->{width} || 0, $msg->{height} || 0 ],
        dont_open => 1 # don't open the image
    );
    delete $result->{content};
    $msg->reply('image', $result);
}

sub handle_image_list {
    my ($wiki, $msg) = write_required(@_, 'sort') or return;

    # get all images
    my @cats = values_maybe $wiki->get_images;

    # sort
    my $sorter = $sort_options{ $msg->{sort} } || $sort_options{'m-'};
    @cats = sort { $sorter->($a, $b) } @cats;

    $msg->reply(image_list => { images => \@cats });
}

# category posts
#
#   name:   the name of the category
#
sub handle_cat_posts {
    my ($wiki, $msg) = read_required(@_, 'name') or return;
    my $result = $wiki->display_cat_posts($msg->{name});
    $msg->reply('cat_posts', $result);
}

# category list.
#
#   sort:   method to sort the results
#
sub handle_cat_list {
    my ($wiki, $msg) = write_required(@_, 'sort') or return;

    # get all cats
    my @cats;
    foreach my $cat_name ($wiki->all_categories) {
        push @cats, { # FIXME: real info
            file  => $cat_name,
            title => $cat_name
        };
    }

    # sort
    my $sorter = $sort_options{ $msg->{sort} } || $sort_options{'m-'};
    @cats = sort { $sorter->($a, $b) } @cats;

    $msg->reply(cat_list => { categories => \@cats });
}


######################
### WRITE REQUIRED ###
######################

# Pages

# page save
#
#   name:       the name of the page
#   content:    the page code
#
sub  handle_page_save { _handle_page_save(0, @_) }
sub _handle_page_save {
    # update the page file
    # regenerate it
    # commit: (existed? added : modified) x.page: user edit message
    my $is_model = shift;
    my ($wiki, $msg) = write_required(@_, qw(name content)) or return;
    my $method;

    # remove carriage returns injected by the browser
    my $content = $msg->{content};
    $content =~ s/\r\n/\n/g;
    $content =~ s/\r//g;

    # update the page
    $method  = $is_model ? 'model_named' : 'page_named';
    my $page = $wiki->$method($msg->{name}, content => $content);
    $method  = $is_model ? 'write_model' : 'write_page';
    my @errs = $wiki->$method($page, $msg->{message});

    $msg->reply($is_model ? 'model_save' : 'page_save' => {
        result     => $page->{recent_result},
        saved      => !@errs,
        rev_errors => \@errs,
        rev_error  => _simplify_errors(@errs),
        rev_latest => @errs ? undef : $wiki->rev_latest,
    });
}

sub  handle_page_del { _handle_page_del(0, @_) }
sub _handle_page_del {
    # copy old page to revisions
    # delete the page file
    # remove it from all categories
    # commit: deleted page x.page
    my $is_model = shift;
    my ($wiki, $msg) = write_required(@_, 'name') or return;
    my $method;

    # delete the page
    $method  = $is_model ? 'model_named' : 'page_named';
    my $page = $wiki->$method($msg->{name});
    $method  = $is_model ? 'delete_model' : 'delete_page';
    $wiki->$method($page);

    $msg->reply($is_model ? 'model_del' : 'page_del' => {
        deleted => 1
    });
}

sub  handle_page_move { _handle_page_move(0, @_) }
sub _handle_page_move {
    # rename page file
    # commit: moved page a.page -> b.page
    my $is_model = shift;
    my ($wiki, $msg) = write_required(@_, qw(name new_name)) or return;
    my $method;

    # rename the page
    $method  = $is_model ? 'model_named' : 'page_named';
    my $page = $wiki->$method($msg->{name});
    $method  = $is_model ? 'move_model' : 'move_page';
    $wiki->$method($page, $msg->{new_name});

    $msg->reply($is_model ? 'model_move' : 'page_move' => {
        moved => 1
    });
}

# Models

# model save
sub handle_model_save   { _handle_page_save(1, @_) }
sub handle_model_del    { _handle_page_del (1, @_) }
sub handle_model_move   { _handle_page_move(1, @_) }

# Categories

sub handle_cat_del {
    # copy all affected old pages to revisions
    # search all affected pages for @category.(x)
    # commit: deleted category x.cat
}

sub handle_ping {
    my ($wiki, $msg) = write_required(@_) or return;
    my $conn = $msg->conn;
    my $notices = delete $conn->{sess}{notifications};
    $conn->{sess}{notifications} = [];
    $msg->reply(pong => {
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
    my ($conn, $msg, @required) = @_;
    my @good;
    
    # if the connection is not authenticated, this better be a wiki command.
    if (!$conn->{wiki_name} && !delete $conn->{no_read_ok}) {
        $msg->error('No read access');
        return;
    }

    # each option must be present
    foreach (@required) {
        if (defined $msg->{$_}) {
            push @good, $msg->{$_};
            next;
        }
        $msg->error("Required option '$_' missing");
        return;
    }
    
    return ($conn->{wiki}, $msg, @good);
}

# check for all required things.
# disconnect from the client if one is missing.
# disconnect if the client does not have write access.
sub write_required {
    my ($conn, $msg) = @_;
    if (!$conn->{sess} || !$conn->{sess}{priv_write}) {
        $msg->error('No write access');
        return;
    }
    &read_required;
}

1
