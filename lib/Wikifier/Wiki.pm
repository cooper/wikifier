# Copyright (c) 2016, Mitchell Cooper
#
# The Wikifier is a simple wiki language parser. It merely converts wiki language to HTML.
# Wikifier::Wiki, on the other hand, provides a full wiki management mechanism. It
# features image sizing, page and image caching, and more.
#
# The Wikifier and Wikifier::Page can operate as only a parser without this class.
# This is useful if you wish to implement your own image resizing and caching methods
# or if you don't feel that these features are necessary.
#
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use HTTP::Date qw(time2str);            # HTTP date formatting
use Cwd qw(abs_path);                   # resolving symlinks
use File::Basename qw(basename);        # determining object names
use Scalar::Util qw(blessed);

use Wikifier;
use Wikifier::Wiki::Pages;
use Wikifier::Wiki::Images;
use Wikifier::Wiki::Models;
use Wikifier::Wiki::Revision;
use Wikifier::Wiki::Categories;
use Wikifier::Utilities qw(L);

# default options.
our %wiki_defaults = (
    'image.enable.restriction'  => 1,
    'enable.cache.image'        => 1,
    'enable.cache.page'         => 1,
    'image.enable.retina'       => 1,
    'image.rounding'            => 'up',
    'image.size_method'         => 'server',
    'image.sizer'               => \&_wiki_default_sizer,   # from Images
    'image.calc'                => \&_wiki_default_calc     # from Images
);

# create a new wiki object.
sub new {
    my ($class, %opts) = @_;
    my $wiki = bless \%opts, $class;

    # create the Wiki's Wikifier instance.
    # using the same wikifier instance over and over makes parsing much faster.
    $wiki->{wikifier} ||= Wikifier->new;

    # if there were no provided options, assume we're reading from /etc
    $wiki->read_config('/etc/wikifier.conf', '/etc/wikifier_private.conf')
        if not scalar keys %opts;

    # if a config file is provided, use it.
    $wiki->read_config($opts{config_file}, $opts{private_file})
        if defined $opts{config_file};

    return $wiki;
}

# read options from a configuration page file.
sub read_config {
    my ($wiki, $file, $private_file) = @_;
    my $conf = $wiki->{conf} = Wikifier::Page->new(
        file_path => $file,
        wikifier  => $wiki->{wikifier},
        vars_only => 1
    );

    # error.
    if (my $err = $conf->parse) {
        L("Failed to parse configuration: $err");
        return;
    }

    # private configuration.
    if (length $private_file) {
        my $pconf = $wiki->{pconf} = Wikifier::Page->new(
            file_path => $private_file,
            wikifier  => $wiki->{wikifier},
            vars_only => 1
        );

        # error.
        if (my $err = $pconf->parse) {
            L("Failed to parse private configuration: $err");
            return;
        }
    }

    # if there's no private conf, assume the main conf also
    # contains private settings.
    else {
        $wiki->{pconf} = $conf;
    }

    return 1;
}

# returns a wiki option.
sub opt {
    my ($wiki, $opt) = @_;
    return $wiki->{$opt} if exists $wiki->{$opt};
    my $v = $wiki->{conf}->get($opt);
    return $v // $wiki_defaults{$opt} // $Wikifier::Page::wiki_defaults{$opt};
}

sub wiki_opt;
*wiki_opt = \&opt;

#######################
### DISPLAY METHODS ###
################################################################################
#
# Pages
# -----
#
#  Takes a page name such as:
#    Some Page
#    some_page
#
# Images
# ------
#
#  Takes an image in the form of:
#    image/[imagename].png
#    image/[width]x[height]-[imagename].png
#    image/[width]x[height]-[imagename]@[scale].png
#
#  For example:
#    image/flower.png
#    image/400x200-flower.png
#    image/400x200-flower\@2x.png (w/o slash)
#
# Returns
# -------
#
# Returns a hash reference of results for display.
#
#   type = one of these:
#       page        some HTML
#       page_code:  some wikifier code
#       image:      an image
#       cat_posts:   a category with HTML for several pages
#       not found:  used for all errors
#
#   if the type is 'page':
#       cached:     true if the content was fetched from cache.
#       generated:  true if the content was just generated.
#       cache_gen:  true if the content was generated and has been cached.
#       page:       the Wikifier::Page object representing the page. (if generated)
#       content:    this will be some HTML page content
#
#   if the type is 'image':
#       image_type: either 'jpeg' or 'png'
#       cached:     true if the image was fetched from cache.
#       generated:  true if the image was just generated.
#       cache_gen:  true if the image was generated and has been cached.
#       content:    this will be some binary image data
#
#   for anything except errors, the following will be set:
#       file:       the filename of the resource (not path) ex 'hello.png' or 'some.page'
#       path:       the full path of the resource ex '/srv/www/example.com/hello.png'
#       mime:       the MIME type, such as 'text/html' or 'image/png'
#       modified:   the last modified date of the resource in HTTP date format
#       mod_unix:   the modified UNIX timestamp
#       length:     the length of the resource in bytes
#       etag:       an HTTP etag for the resource in the form of an md5 string
#       content:    the content or binary data to be sent to the client
#
#   if the type is 'not found'
#       error:      a human-readable error message
#

##################
### WIKI FILES ###
##################

# an array of file names in page directory.
sub all_pages {
    return files_in_dir(shift->opt('dir.page'), 'page');
}

# an array of file names in category directory.
sub all_categories {
    return files_in_dir(shift->opt('dir.category'), 'cat');
}

# an array of file names in the model directory.
sub all_models {
    return files_in_dir(shift->opt('dir.model'), 'page', 'model');
}

######################
### AUTHENTICATION ###
######################

my %crypts = (
    'none'   => [ undef,            sub { shift()                           } ],
    'sha1'   => [ 'Digest::SHA',    sub { Digest::SHA::sha1_hex(shift)      } ],
    'sha256' => [ 'Digest::SHA',    sub { Digest::SHA::sha256_hex(shift)    } ],
    'sha512' => [ 'Digest::SHA',    sub { Digest::SHA::sha512_hex(shift)    } ]
);

sub verify_login {
    my ($wiki, $username, $password) = @_;
    if (!$wiki->{pconf}) {
        L('Attempted verify_login() without configured credentials');
        return;
    }

    # find the user.
    my $user = $wiki->{pconf}->get("admin.$username");
    if (!$user) {
        L("Attempted to login as '$username' which does not exist");
        return;
    }

    # make a copy of the user.
    $user = { %$user, username => $username };

    # hash it.
    my $crypt = delete $user->{crypt};
    $crypt = $crypts{$crypt} ? $crypt : 'sha1';
    my $hash = eval {
        my ($pkg, $func) = @{ $crypts{$crypt} };
        if ($pkg) {
            $pkg =~ s/::/\//;
            require "$pkg.pm";
        }
        scalar $func->($password);
    };

    # error
    if (!defined $hash) {
        L("Error with $crypt: $@");
        return;
    }

    # invalid credentials
    if ($hash ne delete $user->{password}) {
        L("Incorrect password for '$username'");
        return;
    }

    # return the user info, with crypt and password removed.
    return $user;
}

#####################
### MISCELLANEOUS ###
#####################

sub display_error {
    my ($error_str, %opts) = @_;
    return {
        type => 'not found',
        error => $error_str,
        %opts
    };
}

# return abs path for a page
sub path_for_page {
    my ($wiki, $page_name) = @_;
    $page_name = page_name($page_name);
    return abs_path($wiki->opt('dir.page').'/'.$page_name);
}

# return abs path for a category
sub path_for_category {
    my ($wiki, $cat_name) = @_;
    return abs_path($wiki->opt('dir.category')."/$cat_name.cat");
}

# return abs path for an image
sub path_for_image {
    my ($wiki, $image_name) = @_;
    return abs_path($wiki->opt('dir.image').'/'.$image_name);
}

# return abs path for a model
sub path_for_model {
    my ($wiki, $model_name) = @_;
    $model_name = page_name($model_name, '.model');
    return abs_path($wiki->opt('dir.model').'/'.$model_name);
}

# files in directory.
# resolves symlinks only counts each file once.
sub files_in_dir {
    my ($dir, @ext) = @_;
    my $ext = join '|', @ext;
    my $dh;
    if (!opendir $dh, $dir) {
        L("Cannot open dir '$dir': $!");
        return;
    }
    my %files;
    while (my $file = readdir $dh) {

        # skip hidden files.
        next if substr($file, 0, 1) eq '.';

        # skip files without desired extension.
        next if $ext && $file !~ m/.+\.($ext)$/;

        # resolve symlinks.
        my $file = abs_path("$dir/$file");
        next if !$file; # couldn't resolve symlink.
        $file = basename($file);

        # already got this one.
        next if $files{$file};

        $files{$file} = 1;
    }
    closedir $dh;
    return keys %files;
}

# returns entire contents of a file.
sub file_contents {
    my ($file, $binary) = @_;
    local $/ = undef;
    my $fh;
    if (!open $fh, '<', $file) {
        L("Cannot open file '$file': $!");
        return;
    }
    binmode $fh if $binary;
    my $content = <$fh>;
    close $fh;
    return $content;
}

1
