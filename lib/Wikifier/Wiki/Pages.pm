# Copyright (c) 2016, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use HTTP::Date qw(time2str);
use Wikifier::Utilities qw(page_name);
use JSON::XS ();

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
sub display_page {
    my ($wiki, $page_name) = (shift, shift);
    my $page = $page_name if blessed $page_name;
    $page_name = page_name($page_name);
    my $result = $wiki->_display_page($page_name, @_);
    Wikifier::l("Error     $page_name: $$result{error}")
        if $result->{error} && !$result->{draft};
    Wikifier::l("Draft     $page_name; skipped")
        if $result->{draft};
    $page->{recent_result} = $result if $page;
    return $result;
}
sub _display_page {
    my ($wiki, $page_name) = @_;
    my $result = {};

    # create a page object
    my $page = $wiki->page_named($page_name);

    # get page info
    $page_name     = $page->name;
    my $path       = $page->path;
    my $cache_path = $page->cache_path;

    # file does not exist.
    return display_error("Page '$page_name' does not exist.")
        if !-f $path;

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
            my $time_str = time2str($cache_modify);
            $result->{type}     = 'page';
            $result->{content}  = "<!-- cached page dated $time_str -->\n\n";

            # fetch the prefixing data.
            my $cache_data = file_contents($cache_path);
            my @data = split /\n\n/, $cache_data, 2;

            # decode.
            my $jdata = eval { $json->decode(shift @data) };
            if (ref $jdata eq 'HASH') {
                $result->{$_} = $jdata->{$_} for keys %$jdata;
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
            $result->{modified} = $time_str;
            $result->{mod_unix} = $cache_modify;
            $result->{length}   = length $result->{content};

            return $result;
        }
    }

    # cache was not used. generate a new copy.
    $result->{page} = $page;

    # parse the page.
    # if an error occurs, parse it again in variable-only mode.
    # then hopefully we can at least get the metadata and categories.
    my $err = $page->parse;
    if ($err) {
        $page->{vars_only}++;
        $page->parse;
        $wiki->check_categories($page);
        return display_error($err);
    }

    # update categories
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
        print {$fh} $json->encode({
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
    my ($wiki, $page_name, $display_page) = @_;
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

    # we might want to also call ->display_page(). this would be useful
    # for determining where errors occur on the page.
    if ($display_page) {
        my %page_res_copy = %{ $wiki->display_page($page_name) };
        delete $page_res_copy{content}
            unless $display_page == 2;
        $result->{display_result} = \%page_res_copy;
    }

    return $result;
}

1
