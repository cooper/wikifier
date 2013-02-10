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

    header_html     => '/home/www/source/about/header.tpl',
    footer_html     => '/home/www/source/about/footer.tpl',
    
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
    
    # it is a page.
    if ($result->{type} eq 'page') {
        $r->send_http_header("text/html");
        return &OK if $r->header_only;
        
        # header.
        $r->print(Wikifier::Wiki::file_contents($options{header}) if $options{header};
        
        # generated HTML content.
        $r->print($result->{content});
        
        # footer.
        $r->print(Wikifier::Wiki::file_contents($options{footer}) if $options{footer};
        
        $r->rflush;
    }
    
    # not found.
    if ($result->{type} eq 'not found') {
        $r->send_http_header("text/plain");
        $r->print("error: $$result{error}");
    }
    
    return &OK;
}

1;
__END__
