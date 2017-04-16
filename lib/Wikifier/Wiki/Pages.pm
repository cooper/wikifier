# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use HTTP::Date qw(time2str);
use Scalar::Util qw(blessed);
use JSON::XS ();
use HTML::Strip;
use Wikifier::Utilities qw(page_name align L Lindent back filter_nonempty);

my $stripper = HTML::Strip->new(emit_spaces => 0);
my $json = JSON::XS->new->pretty(1);

#############
### PAGES ###
#############

# create a page object with this wiki
sub page_named {
    my ($wiki, $page_name, %opts) = @_;
    my $page = Wikifier::Page->new(
        name     => $page_name,
        wiki     => $wiki,
        wikifier => $wiki->{wikifier},
        %opts
    );
}

# Displays a page.
#
# Input
#
#   $page_name          name of the page, with or without the extension
#
#   %opts = (
#
#       draft_ok        if true, drafts will not be skipped
#
#       no_redir        if true, symbolic links will not be redirected. the
#                       page content of the redirected page will be served
#
#   )
#
# Result
#
#   for type 'not found':
#
#       error           a human-readable error string. sensitive info is never
#                       included, so this may be shown to users
#
#       (parse_error)   true if the error occurred during parsing
#
#       (draft)         true if the page cannot be displayed because it has not
#                       yet been published for public viewing
#
#   for type 'redirect':
#
#       redirect        a relative or absolute URL to which the page should
#                       redirect, suitable for use in a Location header
#
#       file            basename of the page, with the extension. this is not
#                       reliable for redirects, as it may be either the name of
#                       this page itself or that of the redirect page
#
#       name            basename of the page, without the extension. like 'file'
#                       this is not well-defined for redirects
#
#       path            absolute file path of the page. like 'file' this is not
#                       well-defined for redirects
#
#       mime            'text/html' (appropriate for Content-Type header)
#
#       content         a link to the redirect target, which normally will not
#                       be displayed, but may if the frontend does not support
#                       the 'redirect' type
#
#   for type 'page':
#
#       file            basename of the page, with the extension
#
#       name            basename of the page, without the extension
#
#       path            absolute file path of the page
#
#       mime            'text/html' (appropriate for Content-Type header)
#
#       content         the page content (HTML)
#
#       mod_unix        UNIX timestamp of when the page was last modified.
#                       if 'cache_gen' is true, this is the current time.
#                       if 'cached' is true, this is the modified date of the
#                       cache file. otherwise, this is the modified date of the
#                       page file itself
#
#       modified        like 'mod_unix' except in HTTP date format, suitable for
#                       use in the Last-Modified header
#
#       (css)           CSS generated for the page from style{} blocks. omitted
#                       when the page does not include any styling
#
#       (cached)        true if the content being served was read from a cache
#                       file (opposite of 'generated')
#
#       (generated)     true if the content being served was just generated in
#                       order to fulfill this request (opposite of 'cached')
#
#       (cache_gen)     true if the content generated in order to fulfill this
#                       request was written to a cache file for later use. this
#                       can only be true if 'generated' is true
#
#       (text_gen)      true if this request resulted in the generation of a
#                       text file based on the contents of this page
#
#       (draft)         true if the page has not yet been published for public
#                       viewing. this only ever occurs if the 'draft_ok' option
#                       was used; otherwise result would be of type 'not found'
#
#       (warnings)      an array reference of warnings produced by the parser.
#                       omitted when no warnings were produced
#
#       (created)       UNIX timestamp of when the page was created, as
#                       extracted from the special @page.created variable.
#                       ommitted when @page.created is not set
#
#       (author)        name of the author of the page, as extracted from the
#                       special @page.author variable. omitted when
#                       @page.author is not set
#
#       (categories)    array reference of categories the page belongs to. these
#                       do not include the '.cat' extension. omitted when the
#                       page does not belong to any categories
#
#       (fmt_title)     the human-readable page title, as extracted from the
#                       special @page.title variable, including any possible
#                       HTML-encoded text formatting. omitted when @page.title
#                       is not set
#
#       (title)         like 'fmt_title' except that all formatting has been
#                       stripped. suitable for use in the <title> tag. omitted
#                       when @page.title is not set
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
    my ($wiki, $_page_name, %opts) = @_;
    my $result = {};

    # create a page object
    my $page = $wiki->page_named($_page_name);

    # get page info
    my $path = $page->path;
    my $cache_path = $page->cache_path;

    # file does not exist.
    return display_error("Page does not exist.")
        if !-f $path;
    
    # filename and path info
    $result->{file} = $page->name;      # with extension
    $result->{name} = $page->name_ne;   # without extension
    $result->{path} = $path;            # absolute path
    
    # page content
    $result->{type} = 'page';
    $result->{mime} = 'text/html';

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
        return $wiki->display_error_cache($page, $err, parse_error => 1);
    }

    # update categories
    $wiki->cat_check_page($page);

    # if this is a draft, so pretend it doesn't exist
    if ($page->draft && !$opts{draft_ok}) {
        return $wiki->display_error_cache($page,
            "Page has not yet been published.",
            draft => 1
        );
    }

    # redirect
    my $redir = $page->redirect;
    if (!$opts{no_redir} && $redir) {
        $result->{type}     = 'redirect';
        $result->{content}  = qq{<a href="$redir">Permanently moved</a>};
        $result->{redirect} = $redir;
        $wiki->write_page_cache_maybe($page, $result);
        return $result;
    }

    # generate the HTML and headers.
    $result->{generated}  = 1;
    $result->{page}       = $page;
    $result->{draft}      = $page->draft;
    $result->{warnings}   = $page->{warnings};
    $result->{mod_unix}   = time;
    $result->{modified}   = time2str($result->{mod_unix});
    $result->{content}    = $page->html;
    $result->{css}        = $page->css;
    $result->{categories} = [ _cats_to_list($page->{categories}) ];

    # write cache file if enabled
    $result = $wiki->write_page_cache_maybe($page, $result);
    return $result if $result->{error};

    # search is enabled, so generate a text file
    $result = $wiki->write_page_text($page, $result)
        if $wiki->opt('search.enable');

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

    # if this is a draft, so pretend it doesn't exist.
    if ($result->{draft} && !$opts->{draft_ok}) {
        return display_error(
            "Page has not yet been published.",
            draft  => 1,
            cached => 1
        );
    }

    # cached error
    if (length(my $err = $result->{error})) {
        return display_error($err, %$result);
    }

    # this is a redirect
    if (my $redir = $result->{redirect}) {
        $result->{type}     = 'redirect';
        $result->{content}  = qq{<a href="$redir">Permanently moved</a>};
        $result->{redirect} = $redir;
        return $result;
    }

    $result->{cached}   = 1;
    $result->{content} .= shift @data;
    $result->{mod_unix} = $cache_modify;
    $result->{modified} = $time_str;

    return $result;
}

# display an error and write the error to cache if enabled
sub display_error_cache {
    my ($wiki, $page, @opts) = @_;
    my $res = display_error(@opts);
    return $wiki->write_page_cache_maybe($page, $res);
}

# write page to cache only if enabled
sub write_page_cache_maybe {
    my ($wiki, $page, $res) = @_;
    return $res if !$wiki->opt('page.enable.cache');
    
    # title, author, etc.
    my $page_info = $page->page_info;
    @$res{ keys %$page_info } = values %$page_info;

    # caching is enabled, so let's save this for later.
    $res = $wiki->write_page_cache($page, $res, $page_info);
    
    return $res;
}

# write page to cache
sub write_page_cache {
    my ($wiki, $page, $result, $page_info) = @_;
    open my $fh, '>', $page->cache_path
        or return display_error('Could not write page cache file');
    binmode $fh, ':utf8';

    # save prefixing data.
    print {$fh} $json->encode(filter_nonempty {

        # page info
        %$page_info,

        # generated CSS
        css => $result->{css},

        # categories
        categories => $page->{categories},

        # warnings
        warnings => $result->{warnings},
        
        # errors
        error => $result->{error}

    }), "\n";

    # save the content.
    print {$fh} $result->{content}
        if length $result->{content};
    close $fh;

    # overwrite modified date to actual.
    $result->{mod_unix}  = $page->cache_modified;
    $result->{modified}  = time2str($result->{mod_unix});
    $result->{cache_gen} = 1;

    return $result;
}

# write page text for search
sub write_page_text {
    my ($wiki, $page, $result) = @_;
    open my $fh, '>', $page->search_path
        or return display_error('Could not write page text file');
    binmode $fh, ':utf8';
    print {$fh} $stripper->parse($result->{content});
    close $fh;
    $result->{text_gen} = 1;
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
