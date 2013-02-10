package Wikifier::nginx;

use warnings;
use strict;

use nginx;

# global wiki variables.
my %wiki_variables = (
    stats => {
        library => {
            books => '151,785,778'
        }
    }
);

#############
# OPTIONS ###
#############

our %options = (

    header => '/home/www/source/about/header.tpl',
    footer => '/home/www/source/about/footer.tpl',
    
    enable_page_caching  => 1,
    enable_image_caching => 1,

    name            => 'NoTrollPlzNet Library',
    variables       => \%wiki_variables,
    wiki_root       => '',
    image_root      => 'http://images.notroll.net/paranoia/files',
    
    external_root   => 'http://en.wikipedia.org/wiki',
    image_directory => '/home/www/main/paranoia/files',
    cache_directory => '/home/www/main/paranoia/cache',
    page_directory  => '/home/www/source/about/pages',
    wkfr_directory  => '/home/www/wikifier'
);

push @INC, (delete $options{wkfr_directory}).'/lib';
require Wikifier::Wiki;

our $wiki = Wikifier::Wiki->new(%options);

sub handler {
    my $r = shift;
    
    $r->uri =~ m|/(.+?)$|;
    my $page_name = $1;
    my $result    = $wiki->display($page_name);

    if ($result->{type} eq 'not found') {
        return &HTTP_NOT_FOUND;
    }
    
    $r->header_out('Content-Type',   $result->{mime}    );
    $r->header_out('Content-Length', $result->{length}  );
    $r->header_out('Last-Modified',  $result->{modified});
    $r->header_out('Etag',           $result->{etag}    )   if defined $result->{etag};
    
    # if we have an etag and the client sent an etag, check if they're the same.
    if (defined $result->{etag} && defined(my $etag_in = $r->header_in('If-None-Match'))) {
    
        # they're equak.
        if ($etag_in eq $result->{etag}) {
            $r->send_http_header();
            return &HTTP_NOT_MODIFIED;
        }
        
    }
    
    $r->send_http_header();
    return &OK if $r->header_only;
    
    $r->print($result->{content});
    return &OK;
}

# VERY illegal regex replaces for template variables.
sub _replace_variables {
    my ($result, $html) = @_;
    
    $html =~ s/\{\$page\.title\}/$$result{title}/g;
    $html =~ s/\{\$page\.file\}/$$result{file}/g;
    
    return $html;
}

1;
__END__
