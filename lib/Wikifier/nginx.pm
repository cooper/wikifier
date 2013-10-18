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

    #header => '/home/www/source/about/header.tpl',
    #footer => '/home/www/source/about/footer.tpl',
    
    enable_page_caching     => 1,                                   # cache pages?
    enable_image_sizing     => 1,                                   # use GD to resize images?
    enable_image_caching    => 1,                                   # cache images in different sizes?
    enable_retina_display   => 1,                                   # enable 2x images for retina displays?
    restrict_image_size     => 1,                                   # prevent abuse of image resizer?

    name            => 'Wikifier test wiki',                        # name of the wiki website
    variables       => \%wiki_variables,                            # wiki-wide variables
    wiki_root       => '',                                          # http address (typically relative) of wiki root
    image_root      => 'http://wikifier.rlygd.net/images',          # http address of wiki image root

    external_name   => 'Wikipedia',                                 # external wiki name
    external_root   => 'http://en.wikipedia.org/wiki',              # http address of external wiki root
    image_directory => '/home/www/test-wiki/images',                # local directory of wiki images
    cache_directory => '/home/www/test-wiki/imagecache',            # local directory for storing cached images
    page_directory  => '/home/www/test-wiki/pages',                 # local directory where pages are stored
    
    wkfr_directory  => '/home/www/wikifier'                         # local directory of the wikifier repository
    
);

push @INC, (delete $options{wkfr_directory}).'/lib';
require Wikifier::Wiki;

our $wiki = Wikifier::Wiki->new(%options);

sub handler {
    my $r      = shift;
    my $length = 0;
    
    $r->uri =~ m|/(.+?)$|;
    my $page_name = $1;
    my $result    = $wiki->display($page_name);

    if ($result->{type} eq 'not found') {
        return &HTTP_NOT_FOUND;
    }
    
    $length = $result->{length};
    
    # if we have an etag and the client sent an etag, check if they're the same.
    if (defined $result->{etag} && defined(my $etag_in = $r->header_in('If-None-Match'))) {
    
        # they're equal.
        if ($etag_in eq $result->{etag}) {
            return &HTTP_NOT_MODIFIED;
        }
        
    }
    
    # if we have a last modified date and the client sent one, check if they're the same.
    if (defined $result->{modified} &&
        defined(my $mod_in = $r->header_in('If-Modified-Since'))) {
        
        # they're equal.
        if ($mod_in eq $result->{modified}) {
            return &HTTP_NOT_MODIFIED;
        }
        
    }
        
    # if this is a page, inject the header and footer.
    if ($result->{type} eq 'page') {
        
        # header.
        if ($options{header}) {
            my $html = Wikifier::Wiki::file_contents($options{header});
            $html    = _replace_variables($result, $html);
            $result->{content} = $html.$result->{content};
            $length = length $result->{content};
        }
        
        # footer.
        if ($options{footer}) {
            my $html = Wikifier::Wiki::file_contents($options{footer});
            $html    = _replace_variables($result, $html);
            $result->{content} = $result->{content}.$html;
            $length  = length $result->{content};
        }
        
    }
    
    # send headers.
    
    $r->header_out('Last-Modified',  $result->{modified});
    $r->header_out('Etag',           $result->{etag}    )   if defined $result->{etag};
    $r->header_out('Content-Length', $length            );
    $r->header_out('X-Powered-By',   'https://github.com/cooper/wikifier');
    $r->send_http_header($result->{mime});
    return &OK if $r->header_only;
    
    # send body.
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
