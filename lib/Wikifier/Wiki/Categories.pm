# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use HTTP::Date qw(time2str);
use JSON::XS ();
use HTML::Strip;
use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(
    page_names_equal cat_name cat_name_ne
    keys_maybe hash_maybe L E
);

my $json = JSON::XS->new->pretty->convert_blessed;

##################
### CATEGORIES ###
##################

# Categories are stored as JSON objects with the following properties.
#
#   category        category name without extension
#
#   file            category filename, including the .cat extension
#
#   created         UNIX timestamp of when the category was created
#
#   mod_unix        UNIX timestamp of when the category was last modified.
#                   this is updated when pages are added and deleted
#
#   pages           object of pages in the category. keys are page filenames,
#                   and values are objects with page metadata from ->page_info
#
#                       asof        UNIX timestamp at which the page metadata
#                                   in this category file was last updated.
#                                   this is compared against page file
#                                   modification time
#
#                       mod_unix    UNIX timestamp at which the page was last
#                                   modified. this may not be the actual page
#                                   modification time, just that as of the
#                                   last update (as indicated by 'asof')
#
#                       (created)   UNIX timestamp at which the page was created
#
#                       (draft)     true if the page is marked as a draft
#
#                       (generated) true if the page was auto-generated
#
#                       (redirect)  page redirect target, if applicable
#
#                       (fmt_title) human-readable page title, including any
#                                   possible HTML formatting
#
#                       (title)     human-readable page title in plain text,
#                                   with HTML tags removed
#
#                       (author)    full name of the page author
#
#                       (dimensions)    for cat_type 'image', an array of
#                                   image dimensions used on this page.
#                                   dimensions are guaranteed to be positive
#                                   integers. the number of elements will
#                                   always be even, since each occurence of the
#                                   image produces two (width and then height)
#
#                       (lines)     for cat_type 'page', an array of line
#                                   numbers on which the target page is
#                                   referenced from this page
#
#   (title)         human-readable category title
#
#
#   Category extras
#
#
#   (cat_type)      if applicable, this is the type of pseudocategory. examples
#                   include 'image', 'model', and 'page'
#
#   (image_file)    for cat_type 'image', the image filename
#
#   (width)         for cat_type 'image', the image width. this may be omitted
#                   if the image does not exist but is referenced by at least
#                   one page
#
#   (height)        for cat_type 'image', the image height. this may be omitted
#                   if the image does not exist but is referenced by at least
#                   one page
#


# Displays a pages from a category in a blog-like form.
#
# %opts = (
#   cat_type    category type
#   page_n      page number
# )
#
sub display_cat_posts {
    my ($wiki, $cat_name, %opts) = @_; my $result = {};
    $cat_name = cat_name($cat_name);
    my $cat_name_ne = cat_name_ne($cat_name);
    my ($err, $pages, $title) = $wiki->cat_get_pages($cat_name,
        cat_type => $opts{cat_type}
    );

    # some error in fetching pages
    return display_error($err)
        if $err;

    $result->{type}     = 'cat_posts';
    $result->{cat_type} = $opts{cat_type};
    $result->{file}     = $cat_name;
    $result->{category} = $cat_name_ne;
    $result->{title}    = $wiki->opt("cat.$cat_name_ne.title") // $title;
    $result->{all_css}  = '';

    # load each page if necessary.
    my (%times, %reses);
    foreach my $page_name (keys %$pages) {
        my $res  = $wiki->display_page($page_name);
        my $time = $res->{page}                 ?
            $res->{page}->get('page.created')   :
            $res->{created} || 0;

        # there was an error or it's a draft, skip.
        next if $res->{error} || $res->{draft};

        # store time.
        # if this is the main page of the category, it should come first.
        my $main = $wiki->_is_main_page($cat_name_ne, $res);
        $times{$page_name}  = $time || 0;
        $times{$page_name} += time  if $main == 1;
        $times{$page_name}  = 'inf' if $main == 2;

        # store res.
        $reses{$page_name} = $res;
    }

    # order with newest first.
    my @pages_in_order = sort { $times{$b} cmp $times{$a} } keys %times;
    @pages_in_order    = map  { $reses{$_} } @pages_in_order;

    # order into PAGES of pages. wow.
    my $limit = $wiki->opt('cat.per_page') || 'inf';
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
            $result->{all_css} .= $page->{css} if length $page->{css};
        }
        $n++;
    }

    return $result;
}

# true if the page result is the main page of a category.
sub _is_main_page {
    my ($wiki, $cat_name_ne, $res) = @_;

    # if it is defined in the configuration,
    # this always overrides all other pages.
    return 2 if page_names_equal(
        $res->{file},
        $wiki->opt("cat.$cat_name_ne.main") || ''
    );

    # in the just-parsed page, something like
    # @category.some_cat.main; # was found
    return 1 if
        $res->{page} &&
        $res->{page}->get("category.$cat_name_ne.main");

    # in the JSON data, something like
    # { "categories": { "some_cat": { "main": 1 } } }
    my $cats = $res->{categories};
    return 1 if
        ref $cats eq 'HASH'                 &&
        ref $cats->{$cat_name_ne} eq 'HASH' &&
        $cats->{$cat_name_ne}{main};

    return 0;
}

# deal with categories after parsing a page.
sub cat_check_page {
    my ($wiki, $page) = @_;
    $wiki->cat_add_page($page, 'pages', cat_type => 'data');

    # actual categories.
    my $cats = $page->get('category');
    $cats = $cats->to_data if blessed $cats;
    if ($cats && ref $cats eq 'HASH') {
        $page->{categories} = $cats;
        $wiki->cat_add_page($page, $_) for keys %$cats;
    }

    # image categories
    foreach my $image_name (keys_maybe $page->{images}) {
        last if !$wiki->opt('image.enable.tracking');
        $wiki->cat_add_page($page, $image_name,
            cat_type    => 'image',
            page_extras => { dimensions => $page->{images}{$image_name} },
            cat_extras  => {
                image_file  => $image_name,
                width       => $page->{images_fullsize}{$image_name}[0],
                height      => $page->{images_fullsize}{$image_name}[1]
            }
        );
    }

    # page link categories
    foreach my $page_name (keys_maybe $page->{target_pages}) {
        $wiki->cat_add_page($page, $page_name,
            cat_type    => 'page',
            page_extras => { lines => $page->{target_pages}{$page_name} },
            create_ok   => 1
        );
    }

    # model categories
    foreach my $model_name (keys_maybe $page->{models}) {
        $wiki->cat_add_page($page, $model_name, cat_type => 'model');
    }
}

# add a page to a category if it is not in it already.
# update the page data within the category if it is outdated.
#
# $cat_name     name of category, with or without extension
#
# %opts = (
#
#   cat_type        for pseudocategories, the type, such as 'image' or 'model'
#
#   page_extras     for pseudocategories, a hash ref of additional page data
#
#   cat_extras      for pseudocategories, a hash ref of additional cat data
#
#   create_ok       for page pseudocategories, allows ->path_for_category
#                   to create new paths in dir.category as needed
# )
#
# returns true on success. unchanged is also considered success.
#
sub cat_add_page {
    my ($wiki, $page, $cat_name, %opts) = @_;
    $cat_name = cat_name($cat_name);
    my $time = time;
    my $cat_file = $wiki->path_for_category(
        $cat_name,
        $opts{cat_type},
        $opts{create_ok}
    );

    # set page infos.
    my $page_data = {
        asof => $time,
        hash_maybe $page->page_info,
        hash_maybe $opts{page_extras}
    };

    # first, check if the category exists yet.
    if (-f $cat_file) {
        my $cat = eval { $json->decode(file_contents($cat_file)) };

        # JSON error or the value is not a hash.
        if (!$cat || ref $cat ne 'HASH') {
            E "Error parsing JSON category '$cat_file': $@";
            return;
        }
        
        # if the page was just renamed, delete the old entry.
        if (length(my $old_name = $page->{old_name})) {
            delete $cat->{pages}{$old_name};
        }

        # the page has not changed since the asof time, so do nothing.
        my $page_ref = $cat->{pages}{ $page->name } ||= {};
        if ($page_ref->{asof} && $page_ref->{asof} >= $page->modified) {
            return 1;
        }

        # update information for this page,
        # or add it if it is not there already.
        %$page_ref = %$page_data;

        # open the file or log error.
        my $fh;
        if (!open $fh, '>', $cat_file) {
            E "Cannot open '$cat_file': $!";
            return;
        }

        # print the resulting JSON.
        binmode $fh, ':utf8';
        print {$fh} $json->encode($cat);
        close $fh;

        return 1;
    }

    # open file or error.
    my $fh;
    if (!open $fh, '>', $cat_file) {
        E "Cannot open '$cat_file': $!";
        return;
    }

    # the category does not yet exist.
    binmode $fh, ':utf8';
    print {$fh} $json->encode({
        hash_maybe $opts{cat_extras},
        category   => cat_name_ne($cat_name),
        file       => $cat_name,
        cat_type   => $opts{cat_type},
        created    => $time,
        mod_unix   => $time,
        pages      => { $page->name => $page_data }
    });

    close $fh;
    return 1;
}

# returns a name-to-metadata hash of the pages in the given category.
# if the category does not exist, returns nothing.
# returns (error, page data, category title)
sub cat_get_pages {
    my ($wiki, $cat_name, %opts) = @_;
    $cat_name = cat_name($cat_name);
    my $cat_name_ne = cat_name_ne($cat_name);
    
    # this should read a file for pages of a category.
    # it should then check if the 'asof' time is older than the modification
    # date of the page file in question. if it is, it should check the page
    # again. if it still in the category, the time in the cat file should be
    # updated to the current time. if it is no longer in the category, it should
    # be removed from the cat file.

    # this category does not exist.
    my $cat_file = $wiki->path_for_category($cat_name, $opts{cat_type});
    if (!defined $cat_file || !-f $cat_file) {
        return 'Category does not exist.';
    }

    # it exists; let's see what's inside.
    my $cat = eval { $json->decode(file_contents($cat_file)) };

    # JSON error or the value is not a hash.
    if (!$cat || ref $cat ne 'HASH') {
        E "Error parsing JSON category '$cat_file': $@";
        return 'Malformed category file';
    }

    # check each page's modification date.
    my ($time, $changed, %final_pages) = time;
    PAGE: foreach my $page_name (keys_maybe $cat->{pages}) {
        my $page_data = $cat->{pages}{$page_name};

        # page no longer exists.
        my $page_path = $wiki->path_for_page($page_name);
        if (!defined $page_path || !-f $page_path) {
            $changed++;
            next PAGE;
        }

        # check if the modification date is more recent than as of date.
        my $mod_date = (stat $page_path)[9];
        if ($mod_date > $page_data->{asof}) {
            $changed++;

            # the page has since been modified.
            # we will create a page that will stop after reading variables.
            my $page = Wikifier::Page->new(
                name      => $page_name,
                file_path => $page_path,
                wikifier  => $wiki->{wikifier},
                vars_only => 1
            );

            # parse variables. if an error occurs, don't change anything.
            my $err = $page->parse;
            if ($err) {
                $changed--;
                next PAGE;
            }

            # update data.
            $page_data = {
                asof => $time,
                hash_maybe $page->page_info
            };

            # page is no longer member of category.
            if (length $opts{cat_type} && $opts{cat_type} eq 'image') {
                next PAGE unless $page->{images}{$cat_name_ne};
            }
            elsif (length $opts{cat_type} && $opts{cat_type} eq 'model') {
                next PAGE unless $page->{models}{$cat_name_ne};
            }
            else {
                next PAGE unless $page->get("category.$cat_name_ne");
            }
        }

        # this one made it.
        $page_data->{mod_unix}   = $mod_date;
        $final_pages{$page_name} = $page_data;
    }

    # is this category now empty?
    if ($wiki->cat_should_delete($cat_name_ne, $cat, \%final_pages)) {
        unlink $cat_file;
        return 'Purge';
    }

    # it looks like something has changed. we need to update the cat file.
    elsif ($changed) {

        # no, there are still page(s) in it.
        # update the file.
        $cat->{mod_unix} = $time;
        $cat->{pages}    = \%final_pages;

        # unable to open.
        my $fh;
        if (!open $fh, '>', $cat_file) {
            E "Cannot open '$cat_file': $!";
            return 'Cannot write category file';
        }

        binmode $fh, ':utf8';
        print {$fh} $json->encode($cat);
        close $fh;
    }

    return (undef, \%final_pages, $cat->{title});
}

# returns true if a category should be deleted.
sub cat_should_delete {
    my ($wiki, $cat_name_ne, $cat, $final_pages) = @_;

    # don't even consider it if there are still pages
    return if scalar keys %$final_pages;

    # no pages using the image, and the image doesn't exist
    if ($cat->{cat_type} && $cat->{cat_type} eq 'image') {
        return !-e $wiki->path_for_image($cat_name_ne);
    }

    # no pages using the model, and the model doesn't exist
    if ($cat->{cat_type} && $cat->{cat_type} eq 'model') {
        return !-e $wiki->path_for_model($cat_name_ne);
    }

    return !$cat->{preserve};
}

1
