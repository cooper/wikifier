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
        html   => \&model_html
    }
);

sub model_html {
    my ($block, $page, $el) = @_;
    
    # create a page.
    my $name  = Wikifier::Utilities::safe_name($block->{name});
    my $path  = Cwd::abs_path($page->wiki_opt('dir.model').q(/)."$name.page");
    my $model = Wikifier::Page->new(
        file       => $path,
        name       => "$name.page",
        model_name => $name,
        wikifier   => $page->wikifier,
        wiki       => $page->{wiki}, # (might not exist)
        variables  => { m => $block->{hash} }
    );
    
    # parse the page.
    $model->parse;
    
    my $main_el = $model->{wikifier}{main_block}{element} or return;
    
    # inject it into $el.
    $main_el->remove_class('main');
    $main_el->add_class('model');
    $main_el->add_class("model-$$model{model_name}");
    
    $el->add($model->html);
    
}

__PACKAGE__
