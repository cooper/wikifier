#
# Copyright (c) 2014, Mitchell Cooper
#
package Wikifier::Block::Model;

use warnings;
use strict;

use Cwd qw(abs_path);
use Wikifier::Utilities qw(page_name);

our %block_types = (
    model => {
        base   => 'hash',
        parse  => \&model_parse,
        html   => \&model_html
    }
);

sub model_parse {
    my ($block, $page) = (shift, @_);

    # parse the hash.
    $block->parse_base(@_);

    # create a page.
    my $name  = $block->{name};
    my $file  = page_name($name, '.model');
    my $path  = abs_path($page->wiki_opt('dir.model')."/$file");
    my $model = $block->{model} = Wikifier::Page->new(
        is_model   => 1,
        file_path  => $path,
        name       => $file,
        model_name => $name,
        #wikifier   => $page->wikifier,
        wiki       => $page->{wiki}, # (might not exist)
        variables  => { 'm' => $block->{hash} }
    );

    # parse the page.
    $model->parse;
}

sub model_html {
    my ($block, $page, $el) = (shift, @_);
    my $model      = $block->{model} or return;
    my $main_block = $model->{wikifier}{main_block} or return;

    $block->html_base($page); # call hash html.

    # generate the DOM. configure model element with all
    # of the options from the main element of the model.
    my $main_el = $main_block->html($model) or return;
    $el->configure(%$main_el);

    # add the main page element to our element.
    $el->remove_class('main');
    $el->add_class("model-$$model{model_name}");
}

__PACKAGE__
