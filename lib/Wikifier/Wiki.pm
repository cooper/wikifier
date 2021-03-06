# Copyright (c) 2017, Mitchell Cooper
#
# Wikifier::Wiki provides a full wiki suite featuring image sizing, page and
# image caching, category management, revision tracking, and more.
#
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use HTTP::Date qw(time2str);
use Scalar::Util qw(blessed);
use Cwd qw(abs_path);
use File::Basename qw(basename fileparse);
use File::Path qw(make_path);
use File::Spec;

use Wikifier;
use Wikifier::Wiki::Log;
use Wikifier::Wiki::Pages;
use Wikifier::Wiki::Images;
use Wikifier::Wiki::Models;
use Wikifier::Wiki::Revision;
use Wikifier::Wiki::Categories;
use Wikifier::Utilities qw(L E Lindent back make_dir);

# default options.
our %wiki_defaults = (
    'page.enable.cache'             => 1,
    'image.enable.restriction'      => 1,
    'image.enable.cache'            => 1,
    'image.enable.retina'           => 3,
    'image.enable.tracking'         => 1,
    'image.enable.pregeneration'    => 1,
    'image.rounding'                => 'up',
    'image.size_method'             => 'server',
    'image.sizer'                   => \&_wiki_default_sizer,   # from Images
    'image.calc'                    => \&_wiki_default_calc,    # from Images
    'cat.per_page'                  => 5,
    'search.enable'                 => 1
);

# create a new wiki object.
sub new {
    my ($class, %opts) = @_;
    my $wiki = bless \%opts, $class;

    # create the Wiki's wikifier instance.
    # using the same wikifier instance over and over makes parsing much faster.
    $wiki->{wikifier} ||= Wikifier->new;

    # if a config file is provided, use it.
    $wiki->_read_config($opts{config_file}, $opts{private_file})
        if defined $opts{config_file};

    # make directories when necessary
    $wiki->_check_directories;

    return $wiki;
}

# read options from a configuration page file.
sub _read_config {
    my ($wiki, $file, $private_file) = @_;
    my $conf = $wiki->{conf} = Wikifier::Page->new(
        file_path => $file,
        wiki      => $wiki,
        wikifier  => $wiki->{wikifier},
        vars_only => 1
    );
    
    # set dir.wiki and dir.wikifier
    $conf->set('dir.wiki'     => $wiki->opt('dir.wiki'));
    $conf->set('dir.wikifier' => $wiki->opt('dir.wikifier'));
    
    # error.
    my $bn_file = basename($file);
    Lindent "($bn_file)";
        if (my $err = $conf->parse) {
            E "Failed to parse configuration";
            back;
            return;
        }
    back;

    # global wiki variables
    my %vars_maybe = $conf->get_hash('var');
    @{ $wiki->{variables} }{ keys %vars_maybe } = values %vars_maybe;

    # private configuration.
    if (length $private_file) {
        my $pconf = $wiki->{pconf} = Wikifier::Page->new(
            file_path => $private_file,
            wiki      => $wiki,
            wikifier  => $wiki->{wikifier},
            vars_only => 1
        );

        # set dir.wiki and dir.wikifier
        $pconf->set('dir.wiki'     => $wiki->opt('dir.wiki'));
        $pconf->set('dir.wikifier' => $wiki->opt('dir.wikifier'));

        # error.
        my $bn_private_file = basename($private_file);
        Lindent "($bn_private_file)";
            if (my $err = $pconf->parse) {
                E "Failed to parse private configuration";
                back;
                return;
            }
        back;
    }

    # if there's no private conf, assume the main conf also
    # contains private settings.
    else {
        $wiki->{pconf} = $conf;
    }

    return 1;
}

our @main_dirs  = qw(page image model md cache);
our @cat_dirs   = qw(page image model data);
our @cache_dirs = qw(page image category md);
push @cache_dirs, map { "category/$_" } @cat_dirs;

sub _check_directories {
    my $wiki = shift;

    # main dirs
    my @directories = map {
        [ $_, $wiki->opt("dir.$_") ]
    } @main_dirs;

    # cache dirs
    push @directories, map {
        [ 'cache', $wiki->opt('dir.cache')."/$_" ]
    } @cache_dirs;

    my (%skipped, $suspicious);
    foreach (@directories) {
        my ($dir, $path) = @$_;

        # wiki option for this dir isn't set
        if (!$path) {
            E "\@dir.$dir is not set" unless $dir eq 'md';
            next;
        }

        # already exists
        next if -d $path;

        # exists but not a directory
        if (-e $path) {
            E "\@dir.$dir ($path) exists but is not a directory";
            next;
        }

        # dir.wiki must not be defined
        if (index($path, '(null)') != -1) {
            E "\@dir.$dir ($path) looks suspicious; skipped";
            $suspicious++;
            next;
        }

        # looks like we are relative to the wikifier
        next if $skipped{$dir};
        my (undef, $parent_dir) = fileparse($path);
        if (-e "$parent_dir/wiki.example.conf") {
            $skipped{$dir}++;
            E "\@dir.$dir is relative to the wikifier dir; skipped";
            next;
        }

        # create it
        L "Creating \@dir.$dir ($path)";
        my $err;
        next if make_path($path, { error => \$err });

        E "... Failed: @$err"
    }
    E 'Maybe you forgot to set @dir.wiki?' if $suspicious;
}

# returns a wiki option.
sub opt {
    my ($wiki, $opt, @args) = @_;
    return Wikifier::Page::_call_opt(
        $wiki->{opts}{$opt}         //          # provided to wiki initializer
        ($wiki->{conf}               ?          # defined in configuration
            $wiki->{conf}->get($opt) :
            undef)                  //
        $wiki_defaults{$opt}        //          # wiki default value fallback
        $Wikifier::Page::wiki_defaults{$opt},   # page default value fallback
        @args
    );
}

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
    return unique_files_in_dir(shift->opt('dir.page'), 'page');
}

# an array of file names in category directory.
sub all_categories {
    my ($wiki, $cat_type) = @_;
    my $dir = $wiki->opt('dir.cache').'/category';
    $dir .= "/$cat_type" if length $cat_type;
    return unique_files_in_dir($dir, 'cat', 1);
}

# an array of file names in the model directory.
sub all_models {
    return unique_files_in_dir(shift->opt('dir.model'), 'model');
}

# an array of file names in the image directory.
# you may be looking for ->get_images, which includes metadata.
sub all_images {
    return unique_files_in_dir(
        shift->opt('dir.image'),
        ['png', 'jpg', 'jpeg']
    );
}

# all markdown files
sub all_markdowns {
    my $wiki = shift;
    my $dir = $wiki->opt('dir.md');
    return if !length $dir;
    return unique_files_in_dir($dir, 'md');
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
        E 'Attempted verify_login() without configured credentials';
        return;
    }

    # find the user.
    my %user = $wiki->{pconf}->get_hash("admin.$username");
    if (!keys %user) {
        $wiki->Log(login_fail => {
            username => $username,
            reason   => 'username'
        });
        L "Attempted to login as '$username' which does not exist";
        return;
    }

    $user{username} = $username;

    # hash it.
    my $crypt = delete $user{crypt};
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
        $wiki->Log(login_fail => {
            username => $username,
            crypt    => $crypt,
            reason   => 'crypt'
        });
        E "Error with $crypt: $@";
        return;
    }

    # invalid credentials
    if ($hash ne delete $user{password}) {
        $wiki->Log(login_fail => {
            username => $username,
            crypt    => $crypt,
            reason   => 'password'
        });
        L "Incorrect password for '$username'";
        return;
    }

    $wiki->Log(login => {
        username    => $username,
        name        => $user{name},
        email       => $user{email},
        crypt       => $crypt
    });
    
    # return the user info, with crypt and password removed.
    return \%user;
}

#####################
### MISCELLANEOUS ###
#####################

sub display_error {
    my ($error_str, %opts) = @_;
    L align('Error', $error_str)
        if !$opts{draft} && !$opts{parse_error};
    return {
        type => 'not found',
        error => $error_str,
        %opts
    };
}

# return abs path for a page
sub path_for_page {
    my ($wiki, $page_name, $create_ok, $dir_page) = @_;
    $dir_page  = $wiki->opt('dir.page') if !length $dir_page;
    $page_name = page_name($page_name);
    make_dir($dir_page, $page_name) if $create_ok;
    return abs_path("$dir_page/$page_name");
}

# return abs path for a category
sub path_for_category {
    my ($wiki, $cat_name, $cat_type, $create_ok) = @_;
    $cat_name = cat_name($cat_name);
    $cat_type = length $cat_type ? "$cat_type/" : '';
    my $dir = $wiki->opt('dir.cache').'/category';
    make_dir($dir, $cat_type.$cat_name) if $create_ok;
    return abs_path("$dir/$cat_type$cat_name");
}

# return abs path for an image
sub path_for_image {
    my ($wiki, $image_name) = @_;
    return abs_path($wiki->opt('dir.image')."/$image_name");
}

# return abs path for a model
sub path_for_model {
    my ($wiki, $model_name) = @_;
    $model_name = page_name($model_name, '.model');
    return abs_path($wiki->opt('dir.model')."/$model_name");
}

# files in directory.
# resolves symlinks only counts each file once.
sub unique_files_in_dir {
    my ($dir, $ext, $this_dir_only) = @_;
    $ext = join '|', @$ext if ref $ext eq 'ARRAY';
    return if !length $dir;
    
    my %files;
    my $do_dir; $do_dir = sub {
        my ($pfx) = @_;
        my $dir = "$dir/$pfx";
        
        # can't open
        my $dh;
        if (!opendir $dh, $dir) {
            E "Cannot open dir '$dir': $!";
            return;
        }
        
        # read each filename
        while (my $file = readdir $dh) {
            my $path = $dir.$file;
            
            # skip hidden files.
            next if substr($file, 0, 1) eq '.';
            
            # this is a directory
            if (-d $path) {
                $do_dir->("$pfx$file/") unless $this_dir_only;
                next;
            }

            # skip files without desired extension.
            next if $ext && $file !~ m/.+\.($ext)$/;

            # resolve symlinks.
            my $abs = abs_path($path);
            next if !$abs; # couldn't resolve symlink.
            
            # use the basename of the resolved path only if the target file is
            # in the same directory. otherwise use the original path.
            my $same_dir = index(File::Spec->abs2rel($abs, $dir), '/') == -1;
            my $filename = basename($same_dir ? $abs : $path);

            $files{$pfx.$filename}++;
        }
        closedir $dh;
    };
    
    $do_dir->('');
    return keys %files;
}

# returns entire contents of a file.
sub file_contents {
    my ($file, $binary) = @_;
    local $/ = undef;
    my $fh;
    if (!open $fh, '<', $file) {
        E "Cannot open file '$file': $!";
        return;
    }
    binmode $fh, ':raw' if  $binary;
    binmode $fh, ':encoding(utf8)' if !$binary;
    my $content = <$fh>;
    close $fh;
    return $content;
}

# returns the relative path to a file
sub rel_path {
    my ($wiki, $dir) = @_;
    return File::Spec->abs2rel($dir, $wiki->opt('dir.wiki'));
}

1
