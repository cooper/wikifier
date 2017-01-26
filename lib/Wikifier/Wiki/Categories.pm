# Copyright (c) 2016, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use Wikifier::Utilities qw(page_names_equal L);
use HTTP::Date qw(time2str);
use JSON::XS ();

my $json = JSON::XS->new->pretty(1);

##################
### CATEGORIES ###
##################

# displays a pages from a category in a blog-like form.
sub display_cat_posts {
    my ($wiki, $category, $page_n) = @_; my $result = {};
    my ($pages, $title) = $wiki->cat_get_pages($category);
    my $opts = $wiki->opt('cat') || {};

    # no pages means no category.
    return display_error("Category '$category' does not exist.")
        if !$pages;

    $result->{type}     = 'cat_posts';
    $result->{category} = $category;
    $result->{title}    = $opts->{title}->{$category} // $title;

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
        my $main = $wiki->_is_main_page($category, $res, $opts);
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

# true if the page result is the main page of a category.
sub _is_main_page {
    my ($wiki, $category, $res, $opts) = @_;

    # if it is defined in the configuration,
    # this always overrides all other pages.
    return 2 if page_names_equal($res->{file}, $opts->{main}{$category} || '');

    # in the just-parsed page, something like
    # @category.some_cat.main; # was found
    return 1 if $res->{page} && $res->{page}->get("category.$category.main");

    # in the JSON data, something like
    # { "categories": { "some_cat": { "main": 1 } } }
    my $cats = $res->{categories};
    return 1 if
        ref $cats eq 'HASH'                 &&
        ref $cats->{$category} eq 'HASH'    &&
        $cats->{$category}{main};

    return 0;
}

# deal with categories after parsing a page.
sub cat_check_page {
    my ($wiki, $page) = @_;
    $wiki->cat_add_page($page, 'all');

    # actual categories.
    my $cats = $page->get('category');
    if ($cats && ref $cats eq 'HASH') {
        $page->{categories} = $cats;
        $wiki->cat_add_page($page, $_) for keys %$cats;
    }

    # image categories.
    return unless $wiki->opt('image.enable.tracking');
    $wiki->cat_add_page($page, "image-$_", $_)
        for keys %{ $page->{images} || {} };
    $wiki->cat_add_page($page, "model-$_", $_)
        for keys %{ $page->{models} || {} };
}

# add a page to a category if it is not in it already.
sub cat_add_page {
    my ($wiki, $page, $category, $image_name) = @_;
    my $time = time;
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
    if (length $image_name) {
        $page_data->{dimensions} = $page->{images}{$1};
    }

    # first, check if the category exists yet.
    if (-f $cat_file) {
        my $cat = eval { $json->decode(file_contents($cat_file)) };

        # JSON error or the value is not a hash.
        if (!$cat || ref $cat ne 'HASH') {
            L("Error parsing JSON category '$cat_file': $@");
            return;
        }

        # update information for this page,
        # or add it if it is not there already.
        $cat->{pages}{ $page->{name} } = $page_data;

        # open the file or log error.
        my $fh;
        if (!open $fh, '>', $cat_file) {
            L("Cannot open '$cat_file': $!");
            return;
        }

        # print the resulting JSON.
        print {$fh} $json->encode($cat);
        close $fh;

        return 1;
    }

    # open file or error.
    my $fh;
    if (!open $fh, '>', $cat_file) {
        L("Cannot open '$cat_file': $!");
        return;
    }

    # the category does not yet exist.
    print {$fh} $json->encode({
        category   => $category,
        created    => $time,
        pages      => { $page->{name} => $page_data }
    });

    close $fh;
    return 1;
}

# returns a name-to-metadata hash of the pages in the given category.
# if the category does not exist, returns nothing.
sub cat_get_pages {
    my ($wiki, $category) = @_;
    # this should read a file for pages of a category.
    # it should then check if the 'asof' time is older than the modification
    # date of the page file in question. if it is, it should check the page
    # again. if it still in the category, the time in the cat file should be
    # updated to the current time. if it is no longer in the category, it should
    # be removed from the cat file.

    # this category does not exist.
    my $cat_file = $wiki->path_for_category($category);
    return unless -f $cat_file;

    # it exists; let's see what's inside.
    my $cat = eval { $json->decode(file_contents($cat_file)) };

    # JSON error or the value is not a hash.
    if (!$cat || ref $cat ne 'HASH') {
        L("Error parsing JSON category '$cat_file': $@");
        return;
    }

    # check each page's modification date.
    my ($time, $changed, %final_pages) = time;
    PAGE: foreach my $page_name (%{ $cat->{pages} || {} }) {
        my $page_data = $cat->{pages}{$page_name};

        # page no longer exists.
        my $page_path = $wiki->path_for_page($page_name);
        if (!-f $page_path) {
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
                return;
            }

            # update data.
            my $p_vars = $page->get('page');
            $page_data = { asof => $time };
            foreach my $var (keys %$p_vars) {
                last if ref $p_vars ne 'HASH';
                $page_data->{$var} = $p_vars->{$var};
            }

            # page is no longer member of category.
            if ($category =~ m/^image-(.+)/) {
                next PAGE unless $page->{images}{$1};
            }
            elsif ($category =~ m/^model-(.+)/) {
                next PAGE unless $page->{models}{$1};
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
            L("Cannot open '$cat_file': $!");
            return;
        }

        print {$fh} $json->encode($cat);
        close $fh;

    }

    return wantarray ? (\%final_pages, $cat->{title}) : \%final_pages;
}

1
