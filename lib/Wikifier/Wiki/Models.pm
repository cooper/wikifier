# Copyright (c) 2016, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use HTTP::Date qw(time2str);
use Wikifier::Utilities qw(page_name align L);
use Scalar::Util qw(blessed);

##############
### MODELS ###
##############

# create a page object with this wiki
sub model_named {
    my ($wiki, $name, %opts) = @_;
    (my $no_ext_name = $name) =~ s/\.page$//;
    my $page = Wikifier::Page->new(
        file_path  => $wiki->path_for_model($name),
        name       => $name,
        model_name => $no_ext_name,
        #wikifier   => $page->wikifier, FIXME?
        wiki       => $wiki,
        %opts
    );
    return $page;
}

# Displays a model.
sub display_model {
    my ($wiki, $page_name) = (shift, shift);
    my $page = $page_name if blessed $page_name;
    $page_name = page_name($page_name);
    my $result = $wiki->_display_model($page_name, @_);
    L(align('Error', $result->{error}))
        if $result->{error} && !$result->{draft} && !$result->{parse_error};
    L(align('Draft', 'skipped'))
        if $result->{draft};
    $page->{recent_result} = $result if $page;
    return $result;
}
sub _display_model {
    my ($wiki, $page_name) = @_;
    my $result = {};

    # create a page object
    my $page = $wiki->model_named($page_name);
    $result->{page} = $page;

    # get page info
    $page_name = $page->name;
    my $path   = $page->path;

    # file does not exist.
    return display_error("Model '$page_name' does not exist.")
        if !-f $path;

    # set path, file, and meme type.
    $result->{file} = $page_name;
    $result->{path} = $path;
    $result->{mime} = 'text/html';

    # parse the model.
    # if an error occurs, parse it again in variable-only mode.
    # then hopefully we can at least get the metadata and categories.
    my $err = $page->parse;
    if ($err) {
        $page->{vars_only}++;
        $page->parse;
        #$wiki->cat_check_page($page); FIXME
        return display_error($err, parse_error => 1);
    }

    # update categories
    #$wiki->cat_check_page($page); FIXME

    # if this is a draft, pretend it doesn't exist.
    if ($page->get('page.draft')) {
        return display_error(
            "Model '$page_name' has not yet been published.",
            draft => 1
        );
    }

    # generate the HTML and headers.
    $result->{type}       = 'model';
    $result->{content}    = $page->html;
    $result->{css}        = $page->css;
    $result->{all_css}    = $result->{css};
    $result->{length}     = length $result->{content};
    $result->{generated}  = 1;
    $result->{modified}   = time2str(time);
    $result->{mod_unix}   = time;
    # $result->{categories} = [ _cats_to_list($page->{categories}) ]; FIXME

    return $result;
}

# Displays the wikifier code for a model.
# display_model = 1  also include ->display_model result, omitting  {content}
# display_model = 2  also include ->display_model result, including {content}
sub display_model_code {
    my ($wiki, $page_name, $display_model) = @_;
    $page_name = page_name($page_name);
    my $path   = $wiki->path_for_model($page_name);
    my $result = {};

    # file does not exist.
    if (!-f $path) {
        return display_error("Model '$page_name' does not exist.");
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
    $result->{type}     = 'model_code';
    $result->{content}  = $code;
    $result->{length}   = length $result->{content};

    # we might want to also call ->display_model(). this would be useful
    # for determining where errors occur on the page.
    if ($display_model) {
        my %model_res_copy = %{ $wiki->display_model($page_name) };
        delete $model_res_copy{content}
            unless $display_model == 2;
        $result->{display_result} = \%model_res_copy;
    }

    return $result;
}

1
