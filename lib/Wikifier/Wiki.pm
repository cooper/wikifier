#
# Copyright (c) 2014, Mitchell Cooper
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

use HTTP::Date 'time2str';              # HTTP date formatting
use Cwd 'abs_path';                     # resolving symlinks
use File::Basename 'basename';          # determining object names
use JSON qw(encode_json decode_json);   # caching and storing
use Scalar::Util 'blessed';

use Wikifier;
use Wikifier::Wiki::Revision;
use Wikifier::Wiki::Images;

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
    if (!$conf->parse) {
        Wikifier::l("Failed to parse configuration");
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
        if (!$pconf->parse) {
            Wikifier::l("Failed to parse private configuration");
            return;
        }
    }
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
    return defined $v ? $v :
        $wiki_defaults{$opt} //
        $Wikifier::Page::wiki_defaults{$opt};
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
#       catposts:   a category with HTML for several pages
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

#############
### PAGES ###
#############

# Displays a page.
sub display_page {
    my ($wiki, $page_name) = (shift, shift);
    $page_name = $page_name->name if blessed $page_name;
    my $result = $wiki->_display_page($page_name, @_);
    Wikifier::l("Error     $page_name: $$result{error}")
        if $result->{error} && !$result->{draft};
    Wikifier::l("Draft     $page_name; skipped")
        if $result->{draft};
    return $result;
}
sub _display_page {
    my ($wiki, $page_name) = @_;
    my $result = {};
    $page_name = $page_name->name if blessed $page_name;

    my $page = Wikifier::Page->new(
        name     => $page_name,
        wiki     => $wiki,
        wikifier => $wiki->{wikifier}
    );

    $page_name     = $page->name;
    my $path       = $page->path;
    my $cache_path = $page->cache_path;

    # file does not exist.
    if (!-f $path) {
        return display_error("Page '$page_name' does not exist.");
    }

    # set path, file, and meme type.
    $result->{file} = $page_name;
    $result->{path} = $path;
    $result->{mime} = 'text/html';

    # caching is enabled, so let's check for a cached copy.

    if ($wiki->opt('enable.cache.page') && -f $cache_path) {
        my ($page_modify, $cache_modify) =
            map { (stat $_)[9] } $path, $cache_path;

        # the page's file is more recent than the cache file.
        # discard the outdated cached copy.
        if ($page_modify > $cache_modify) {
            unlink $cache_path;
        }

        # the cached file is newer, so use it.
        else {
            my $time = time2str($cache_modify);
            $result->{type}     = 'page';
            $result->{content}  = "<!-- cached page dated $time -->\n\n";

            # fetch the prefixing data.
            my $cache_data = file_contents($cache_path);
            my @data = split /\n\n/, $cache_data, 2;

            # decode.
            my $jdata = eval { decode_json(shift @data) } || {};
            if (ref $jdata eq 'HASH') {
                $result->{$_} = $jdata->{$_} foreach keys %$jdata;
            }

            # if this is a draft, pretend it doesn't exist.
            if ($result->{draft}) {
                return display_error(
                    "Page '$page_name' has not yet been published.",
                    draft => 1
                );
            }

            $result->{content} .= shift @data;
            $result->{all_css}  = $result->{css} if length $result->{css};
            $result->{cached}   = 1;
            $result->{modified} = $time;
            $result->{mod_unix} = $cache_modify;
            $result->{length}   = length $result->{content};

            return $result;
        }
    }

    # cache was not used. generate a new copy.
    $result->{page} = $page;

    # parse the page.
    $page->parse();
    $wiki->check_categories($page);

    # if this is a draft, pretend it doesn't exist.
    if ($page->get('page.draft')) {
        return display_error(
            "Page '$page_name' has not yet been published.",
            draft => 1
        );
    }

    # generate the HTML and headers.
    $result->{type}       = 'page';
    $result->{content}    = $page->html;
    $result->{css}        = $page->css;
    $result->{all_css}    = $result->{css};
    $result->{length}     = length $result->{content};
    $result->{generated}  = 1;
    $result->{modified}   = time2str(time);
    $result->{mod_unix}   = time;
    $result->{categories} = $page->{categories} if $page->{categories};

    # caching is enabled, so let's save this for later.
    if ($wiki->opt('enable.cache.page')) {
        open my $fh, '>', $cache_path;

        # save prefixing data.
        print {$fh} JSON->new->pretty(1)->encode({
            %{ $page->get('page') || {} },
            css        => $result->{css},
            categories => $result->{categories} || []
        }), "\n";

        # save the content.
        print {$fh} $result->{content};

        close $fh;

        # overwrite modified date to actual.
        my $modified = (stat $cache_path)[9];
        $result->{modified}  = time2str($modified);
        $result->{mod_unix}  = $modified;
        $result->{cache_gen} = 1;
    }

    return $result;
}

# Displays the wikifier code for a page.
sub display_page_code {
    my ($wiki, $page_name) = @_;
    $page_name = page_name($page_name);
    my $path   = $wiki->path_for_page($page_name);
    my $result = {};

    # file does not exist.
    if (!-f $path) {
        return display_error("Page '$page_name' does not exist.");
    }

    # read.
    my $code = file_contents($path);
    if (!defined $code) {
        return display_error("Failed to read '$page_name'");
    }

    # set path, file, and meme type.
    $result->{file}     = $page_name;
    $result->{path}     = $path;
    $result->{mime}     = 'text/plain';
    $result->{type}     = 'page_code';
    $result->{content}  = $code;
    $result->{length}   = length $result->{content};

    return $result;
}

##################
### CATEGORIES ###
##################

# displays a pages from a category in a blog-like form.
sub display_category_posts {
    my ($wiki, $category, $page_n) = @_; my $result = {};
    my ($pages, $title) = $wiki->cat_get_pages($category);

    # no pages means no category.
    return display_error("Category '$category' does not exist.")
        if !$pages;

    my $opts = $wiki->opt('cat') || {};
    my $main_page = $opts->{main}{$category} || '';

    $result->{type}     = 'catposts';
    $result->{category} = $category;
    $result->{title}    = $opts->{title}->{$category} // $title;

    # load each page if necessary.
    my (%times, %reses);
    foreach my $page_name (keys %$pages) {
        my $page_data = $pages->{$page_name};
        my $res  = $wiki->display_page($page_name);
        my $time = $res->{page} ? $res->{page}->get('page.created')
                   : $res->{created} || 0;

        # there was an error or it's a draft, skip.
        next if $res->{error} || $res->{draft};

        $times{$page_name} = $time || 0;
        $reses{$page_name} = $res;

        # if this is the main page of the category, it should come first.
        $times{$page_name} = 'inf'
            if Wikifier::Utilities::pages_equal($page_name, $main_page);

    }

    # order with newest first.
    my @pages_in_order = sort { $times{$b} cmp $times{$a} } keys %times;
    @pages_in_order    = map  { $reses{$_} } @pages_in_order;

    # order into PAGES of pages. wow.
    my $limit = $wiki->opt('cat.per_page')               ||
                $wiki->opt('enable.category_post_limit') ||
                'inf';
    my $n = 1;
    while (@pages_in_order) {
        $result->{pages}{$n} ||= [];
        for (1..$limit) {

            # there are no more pages.
            last unless @pages_in_order;

            # add the next page.
            my $page = shift @pages_in_order;
            push @{ $result->{pages}{$n} }, $page;

            # add the CSS.
            ($result->{all_css} ||= '') .= $page->{css} if length $page->{css};

        }
        $n++;
    }

    return $result;
}

# deal with categories after parsing a page.
sub check_categories {
    my ($wiki, $page) = @_;
    $wiki->cat_add_page($page, 'all');

    # actual categories.
    my $cats = $page->get('category');
    if ($cats && ref $cats eq 'HASH') {
        $page->{categories} = [keys %$cats];
        $wiki->cat_add_page($page, $_) foreach keys %$cats;
    }

    # image categories.
    return unless $wiki->opt('image.enable.tracking');
    $wiki->cat_add_page($page, "image-$_") foreach keys %{ $page->{images} || {} };

}

# add a page to a category if it is not in it already.
sub cat_add_page {
    my ($wiki, $page, $category) = @_;
    my ($time, $fh) = time;
    my $cat_file = $wiki->path_for_category($category);

    # fetch page infos.
    my $p_vars = $page->get('page');
    my $page_data = {
        asof     => $time,
        mod_unix => $page->modified_time
    };
    foreach my $var (keys %$p_vars) {
        last if ref $p_vars ne 'HASH';
        $page_data->{$var} = $p_vars->{$var};
    }

    # this is an image category, so include the dimensions.
    if ($category =~ m/^image-(.+)$/) {
        $page_data->{dimensions} = $page->{images}{$1};
    }

    # first, check if the category exists yet.
    if (-f $cat_file) {
        my $cat = eval { decode_json(file_contents($cat_file)) };

        # JSON error or the value is not a hash.
        if (!$cat || ref $cat ne 'HASH') {
            Wikifier::l("Error parsing JSON category '$cat_file': $@");
            close $fh;
            return;
        }

        # update information for this page,
        # or add it if it is not there already.
        $cat->{pages}{ $page->{name} } = $page_data;

        # open the file or log error.
        if (!open $fh, '>', $cat_file) {
            Wikifier::l("Cannot open '$cat_file': $!");
            return;
        }

        # print the resulting JSON.
        print {$fh} JSON->new->pretty(1)->encode($cat);
        close $fh;

        return 1;
    }

    # open file or error.
    if (!open $fh, '>', $cat_file) {
        Wikifier::l("Cannot open '$cat_file': $!");
        return;
    }

    # the category does not yet exist.
    print {$fh} JSON->new->pretty(1)->encode({
        category   => $category,
        created    => $time,
        pages      => { $page->{name} => $page_data }
    });

    close $fh;
    return 1;
}

# returns the names of the pages in the given category.
# if the category does not exist, an undefined value is returned.
sub cat_get_pages {
    my ($wiki, $category) = @_;
    # this should read a file for pages of a category.
    # it should then check if the 'asof' time is older than the modification date of the
    # page file in question. if it is, it should check the page again. if it still in
    # the category, the time in the cat file should be updated to the current time. if it
    # is no longer in the category, it should be removed from the cat file.

    # this category does not exist.
    my $cat_file = $wiki->path_for_category($category);
    return unless -f $cat_file;

    # it exists; let's see what's inside.
    my $cat = eval { decode_json(file_contents($cat_file)) };

    # JSON error or the value is not a hash.
    if (!$cat || ref $cat ne 'HASH') {
        Wikifier::l("Error parsing JSON category '$cat_file': $@");
        return;
    }

    # check each page's modification date.
    my ($time, $changed, %final_pages) = time;
    PAGE: foreach my $page_name (%{ $cat->{pages} || {} }) {
        my $page_data = my $p = $cat->{pages}{$page_name};

        # page no longer exists.
        my $page_path = $wiki->path_for_page($page_name);
        if (!-f $page_path) {
            $changed = 1;
            next PAGE;
        }

        # check if the modification date is more recent than as of date.
        my $mod_date = (stat $page_path)[9];
        if ($mod_date > $p->{asof}) {
            $changed = 1;

            # the page has since been modified.
            # we will create a dummy Wikifier::Page that will stop after reading variables.
            my $page = Wikifier::Page->new(
                name      => $page_name,
                file_path => $page_path,
                wikifier  => $wiki->{wikifier},
                vars_only => 1
            );
            $page->parse;

            # update data.
            my $p_vars = $page->get('page');
            $page_data = { asof => $time };
            foreach my $var (keys %$p_vars) {
                last if ref $p_vars ne 'HASH';
                $page_data->{$var} = $p_vars->{$var};
            }

            # page is no longer member of category.
            if ($category =~ m/^image-(.+)/) {
                next PAGE unless defined $page->{images}{$1};
            }
            else {
                next PAGE unless $page->get("category.$category");
            }
        }

        # this one made it.
        $page_data->{mod_unix}   = $mod_date;
        $final_pages{$page_name} = $page_data;
    }

    # it looks like something has changed. we need to update the cat file.
    if ($changed) {

        # is this category now empty?
        if (!scalar keys %final_pages) {
            unlink $cat_file;
            return;
        }

        # no, there are still page(s) in it.
        # update the file.

        $cat->{updated} = $time;
        $cat->{pages}   = \%final_pages;

        # unable to open.
        my $fh;
        if (!open $fh, '>', $cat_file) {
            Wikifier::l("Cannot open '$cat_file': $!");
            return;
        }

        print {$fh} JSON->new->pretty(1)->encode($cat);
        close $fh;

    }

    return wantarray ? (\%final_pages, $cat->{title}) : \%final_pages;
}

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
        Wikifier::l('Attempted verify_login() without configured credentials');
        return;
    }

    # find the user.
    my $user = $wiki->{pconf}->get("admin.$username");
    if (!$user) {
        Wikifier::l("Attempted to login as '$username' which does not exist");
        return;
    }

    # make a copy of the user.
    $user = { %$user };

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
        Wikifier::l("Error with $crypt: $@");
        return;
    }

    # invalid credentials
    if ($hash ne delete $user->{password}) {
        Wikifier::l("Incorrect password for '$username'");
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

sub path_for_page {
    my ($wiki, $page_name) = @_;
    $page_name = page_name($page_name);
    return abs_path($wiki->opt('dir.page').'/'.$page_name);
}

sub path_for_category {
    my ($wiki, $cat_name) = @_;
    return abs_path($wiki->opt('dir.category')."/$cat_name.cat");
}

sub path_for_image {
    my ($wiki, $image_name) = @_;
    return abs_path($wiki->opt('dir.image').'/'.$image_name);
}

# page_name(some_page)      -> some_page.page
# page_name(some_page.page) -> some_page.page
# page_name($page)          -> some_page.page
sub page_name {
    my $page_name = shift;
    return $page_name->name if blessed $page_name;
    return Wikifier::Page::_page_filename($page_name);
}

# create a page object with this wiki
sub page_named {
    my ($wiki, $page_name, %opts) = @_;
    my $page = Wikifier::Page->new(
        name     => page_name($page_name),
        wiki     => $wiki,
        wikifier => $wiki->{wikifier},
        %opts
    );
}

# files in directory.
# resolves symlinks only counts each file once.
sub files_in_dir {
    my ($dir, $ext) = @_;
    opendir my $dh, $dir or Wikifier::l("Cannot open dir '$dir': $!") and return;
    my %files;
    while (my $file = readdir $dh) {

        # skip hidden files.
        next if substr($file, 0, 1) eq '.';

        # skip files without desired extension.
        next if $ext && $file !~ m/.+\.$ext$/;

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
    open my $fh, '<', $file or Wikifier::l("Cannot open file '$file': $!") and return;
    binmode $fh if $binary;
    my $content = <$fh>;
    close $fh;
    return $content;
}

1
