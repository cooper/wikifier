#
# Copyright (c) 2014, Mitchell Cooper
#
package Wikifier::Block::Model;

use warnings;
use strict;

use Scalar::Util 'blessed';

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
    my $name  = Wikifier::Utilities::safe_name($block->{name});
    my $path  = Cwd::abs_path($page->wiki_opt('dir.model').q(/)."$name.page");
    my $model = $block->{model} = Wikifier::Page->new(
        path       => $path,
        name       => "$name.page",
        model_name => $name,
        #wikifier   => $page->wikifier,
        wiki       => $page->{wiki}, # (might not exist)
        variables  => { m => $block->{hash} }
    );
    
    # parse the page.
    $model->parse;
    
}

sub model_html {
    my ($block, $page, $el) = @_;
    my $model      = $block->{model} or return;
    my $main_block = $model->{wikifier}{main_block} or return;

    # generate the objective DOM.
    my $main_el = $main_block->html($model) or return;
    
    # add the main page element to our element.
    $main_el->remove_class('main');
    $el->add_class("model-$$model{model_name}");
    $el->add($main_el);
    
}

__PACKAGE__
