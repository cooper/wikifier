# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use HTTP::Date qw(time2str);
use Wikifier::Utilities qw(page_name align L Lindent back);
use Scalar::Util qw(blessed);
use JSON::XS ();
use HTML::Strip;

my $json = JSON::XS->new->pretty(1);

#############
### PAGES ###
#############

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

# Displays a page.
#
# %opts = (
#   draft_ok        if true, drafts will not be skipped
# )
#
sub display_page {
    my ($wiki, $page_name) = (shift, shift);
    my $page = $page_name if blessed $page_name;
    $page_name = page_name($page_name);
    Lindent "($page_name)";
    my $result = $wiki->_display_page($page_name, @_);
    L align('Error', $result->{error})
        if $result->{error} && !$result->{draft} && !$result->{parse_error};
    L align('Draft', 'skipped')
        if $result->{error} && $result->{draft};
    $page->{recent_result} = $result if $page;
    back;
    return $result;
}
sub _display_page {
    my ($wiki, $page_name, %opts) = @_;
    my $result = {};

    # create a page object
    my $page = $wiki->page_named($page_name);

    # get page info
    $page_name     = $page->name;
    my $path       = $page->path;
    my $cache_path = $page->cache_path;

    # file does not exist.
    return display_error("Page does not exist.")
        if !-f $path;
        
    # redirect.
    if ($page->redirect) {
        $result->{type}     = 'redirect';
        $result->{file}     = $page->abs_name;
        $result->{path}     = $path;
        $result->{mime}     = 'text/plain';
        $result->{content}  = "Redirect to '$$result{file}'";
        return $result;
    }

    # set path, file, and meme type.
    $result->{type} = 'page';
    $result->{mime} = 'text/html';
    $result->{file} = $page_name;
    $result->{path} = $path;

    # caching is enabled, so let's check for a cached copy.
    if ($wiki->opt('page.enable.cache') && -f $cache_path) {
        $result = $wiki->get_page_cache($page, $result, \%opts);
        return $result if $result->{cached};
    }

    # Safe point - we will be generating the page right now.

    # parse the page.
    # if an error occurs, parse it again in variable-only mode.
    # then hopefully we can at least get the metadata and categories.
    my $err = $page->parse;
    if ($err) {
        $page->{vars_only}++;
        $page->parse;
        $wiki->cat_check_page($page);
        return display_error($err, parse_error => 1);
    }

    # update categories
    $wiki->cat_check_page($page);

    # if this is a draft, pretend it doesn't exist.
    if ($page->draft && !$opts{draft_ok}) {
        return display_error(
            "Page has not yet been published.",
            draft => 1
        );
    }

    # generate the HTML and headers.
    $result->{generated}  = 1;
    $result->{page}       = $page;
    $result->{draft}      = $page->draft;
    $result->{warnings}   = $page->{warnings};
    $result->{mod_unix}   = time;
    $result->{modified}   = time2str($result->{mod_unix});
    $result->{content}    = $page->html;
    $result->{length}     = length $result->{content};
    $result->{css}        = $page->css;
    $result->{categories} = [ _cats_to_list($page->{categories}) ];

    # title, author, etc.
    my $page_info = $page->page_info;
    @$result{ keys %$page_info } = values %$page_info;

    # caching is enabled, so let's save this for later.
    $result = $wiki->write_page_cache($page, $result, $page_info)
        if $wiki->opt('page.enable.cache');

    return $result;
}

# get page from cache
sub get_page_cache {
    my ($wiki, $page, $result, $opts) = @_;
    my $cache_modify = $page->cache_modified;
    my $time_str = time2str($cache_modify);

    # the page's file is more recent than the cache file.
    # discard the outdated cached copy.
    if ($page->modified > $cache_modify) {
        unlink $page->cache_path;
        return $result;
    }

    $result->{content}  = "<!-- cached page dated $time_str -->\n\n";

    # fetch the prefixing data.
    my $cache_data = file_contents($page->cache_path);
    my @data = split /\n\n/, $cache_data, 2;

    # decode.
    my $jdata = eval { $json->decode(shift @data) };
    if (ref $jdata eq 'HASH') {
        @$result{ keys %$jdata } = values %$jdata;
    }

    # if this is a draft, pretend it doesn't exist.
    if ($result->{draft} && !$opts->{draft_ok}) {
        return display_error(
            "Page has not yet been published.",
            draft  => 1,
            cached => 1
        );
    }

    $result->{cached}   = 1;
    $result->{content} .= shift @data;
    $result->{length}   = length $result->{content};
    $result->{mod_unix} = $cache_modify;
    $result->{modified} = $time_str;

    return $result;
}

# write page to cache
sub write_page_cache {
    my ($wiki, $page, $result, $page_info) = @_;
    open my $fh, '>', $page->cache_path;

    # save prefixing data.
    print {$fh} $json->encode({

        # page info
        %$page_info,

        # generated CSS
        css => $result->{css},

        # categories
        categories => $page->{categories} || {},

        # warnings
        warnings => $result->{warnings}

    }), "\n";

    # save the content.
    print {$fh} $result->{content};
    close $fh;

    # overwrite modified date to actual.
    $result->{mod_unix}  = $page->cache_modified;
    $result->{modified}  = time2str($result->{mod_unix});
    $result->{cache_gen} = 1;

    return $result;
}

# stored categories -> list of category names
sub _cats_to_list {
    my $cats = shift;
    return keys %$cats  if ref $cats eq 'HASH';
    return @$cats       if ref $cats eq 'ARRAY';
    return;
}

# Displays the wikifier code for a page.
#
# %opts = (
#   display_page = 1  also include ->display_page result, omitting  {content}
#   display_page = 2  also include ->display_page result, including {content}
# )
#
sub display_page_code {
    my ($wiki, $page_name) = (shift, shift);
    my $page = $page_name if blessed $page_name;
    $page_name = page_name($page_name);
    Lindent "($page_name)";
    my $result = $wiki->_display_page_code($page_name, @_);
    L align('Error', $result->{error})
        if $result->{error};
    back;
    return $result;
}
sub _display_page_code {
    my ($wiki, $page_name, %opts) = @_;
    my $path   = $wiki->path_for_page($page_name);
    my $result = {};

    # file does not exist.
    if (!-f $path) {
        return display_error("Page does not exist.");
    }

    # read.
    my $code = file_contents($path);
    if (!defined $code) {
        return display_error("Failed to read page.");
    }

    # set path, file, and meme type.
    $result->{file}     = $page_name;
    $result->{path}     = $path;
    $result->{mime}     = 'text/plain';
    $result->{type}     = 'page_code';
    $result->{content}  = $code;
    $result->{length}   = length $result->{content};

    # we might want to also call ->display_page(). this would be useful
    # for determining where errors occur on the page.
    if (my $display_page = $opts{display_page}) {
        my %page_res_copy = %{ $wiki->display_page($page_name, draft_ok => 1) };
        delete $page_res_copy{content}
            unless $display_page == 2;
        $result->{display_result} = \%page_res_copy;
    }

    return $result;
}

1
