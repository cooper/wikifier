# Configuration

This document describes all of the available configuration options. The options
are categorized by the lowest-level wikifier interface at which they are used.
Some are required for the generation of a single page, others for the operation
of a full wiki, and others yet for the operation of a wiki server.

### Configuration files

The primary method of configuration is to define options in a configuration
file. All wikifier configuration files are written in the wikifier language:
```
@name:          MyWiki;
@dir.wiki:      /home/www/mywiki;
@dir.page:      [@dir.wiki]/pages;
```

If you are using a **wiki server**, you must have a dedicated configuration file
for the server. This tells it where to listen and where to find the wikis you
have configured on the server. This is typically called `wikiserver.conf`, and
it is required as the first argument to the `wikiserver` executable.

**Every wiki** also requires its own configuration file. It may make sense to
store your wiki configuration file at a path outside of the wiki root, just in
case it contains sensitive information. If you are using a wiki server, the path
of each wiki's configuration file is defined in the server configuration using
the `server.wiki.<name>.config` option. If you are using Wikifier::Wiki
directly, the path to the wiki configuration must be provided to the
constructor:
```
my $wiki = Wikifier::Wiki->new(config_file => '/home/www/mywiki/wiki.conf');
```

Each wiki can optionally have a **private configuration** file. This is where
the credentials of administrators can exist more securely than in the primary
configuration. This file certainly should not be within the wiki root because
that would probably allow anyone to download it from the web server. If you are
using a wiki server, the path of the private configuration is defined by
`server.wiki.<name>.private`. If you are using Wikifier::Wiki directly, the path
to the private configuration may be provided to the constructor:
```
my $wiki = Wikifier::Wiki->new(
    config_file  => '/home/www/mywiki/wiki.conf',
    private_file => '/home/www/mywiki-private.conf',
);
```

### Configuration directly from code

Another method of defining configuration values (rather than in a configuration
file) is to do so directly from the code where you initialize the interface.
This is probably only useful if you are using Wikifier::Page directly:

```perl
my $page = Wikifier::Page->new(
    file_path => $path,
    opts => {
        'name' => 'MyWiki',
        'root.wiki' => '/wiki',
        'root.page' => '/wiki/page'
    }
);
```

## Wikifier::Page options

```
name                            Default: Wiki

    The name of the wiki.

root.wiki                       Default: '' (i.e. /)
root.page                       Default: /page
root.image                      Default: /images

    HTTP roots. These are relative to the server HTTP root, NOT the wiki root.
    They are used for link targets and image URLs; they will never be used to
    locate content on the filesystem. Do not include trailing slashes.

    It may be useful to use root.wiki within the definitions of the rest:
        @root.wiki:     /mywiki;
        @root.page:     [@root.wiki]/page;
        @root.image:    [@root.wiki]/images;

dir.wikifier            the wikifier repository
dir.wiki                wiki root directory
dir.page                page files stored here
dir.image               image originals stored here
dir.model               models stored here
dir.cache               generated page and image cache files stored here
dir.category            generated category files stored here

    Directories on the filesystem. It is strongly recommended that they are
    absolute paths; otherwise they will be dictated by whichever directory the
    script is started from. All are required except dir.wikifier and dir.wiki.
    The directories will be created if they do not exist. Do not include
    trailing slashes.

    It may be useful to use dir.wiki within the definitions of the rest:
        @dir.wiki:      /home/www/mywiki;
        @dir.page:      [@dir.wiki]/pages;
        @dir.cache:     [@dir.wiki]/cache;

    It is recommended that all of the files related to one wiki exist within
    a master wiki directory (dir.wiki), but this is not technically required
    unless you are using Wikifer::Wiki's built-in revision tracking.

external.name                   Default: Wikipedia
external.root                   Default: http://en.wikipedia.org/wiki

    External wiki information. This is used for External wiki links in the form
    of [! article !].

    name = the name to be displayed in link tooltips.
    root = the HTTP root for articles.

    Page names will be translated to URLs in a format compatible with MediaWiki.
    Currently this is non-configurable.

page.enable.titles              Default: enabled

    If enabled, the first section's title will be the title of the page. You
    may want to disable this if your wiki content is embedded within a template
    that has its own place for the page title.

page.enable.footer              Default: disabled

    If enabled, the closing </div> tags will be omitted from the final section
    and wiki block. This allows a footer to be injected before closing them off.

image.size_method               Default (Page): javascript
                                Default (Wiki): server

    The method which the wikifier should use to scale images.

    'javascript' = JavaScript-injected (bad)
    'server'     = server-side using image.sizer and image.calc (recommended)

    When set to 'server', the options image.calc and image.sizer are required.
    If using Wikifier::Page directly, image.calc is provided but requires that
    you install Image::Size. In that case, you are required to provide a
    custom image.sizer routine. If using Wikifier::Wiki, image.calc and
    image.sizer are both provided, but GD must be installed from CPAN.

image.calc                      Default (Page): built in, uses Image::Size
                                Default (Wiki): built in, uses GD

    A code reference that calculates a missing dimension of an image.
    This is utilized only when image.size_method is 'server.'

    Returns (width, height)

image.rounding                  Default: normal

    The desired rounding method used when determining image dimensions. Used by
    the default image.calc. If a custom image.calc is provided, this will not be
    utilized.

    'normal' = round up from .5 or more, down for less
    'up'     = always round up
    'down'   = always round down

image.sizer                     Default (Page): none; custom code required
                                Default (Wiki): built in

    A code reference that returns the URL to a sized version of an image. After
    using image.calc to find the dimensions of an image, image.sizer is called
    to generate a URL for the image at those dimensions.

    If using image.size_method 'server', image.sizer must be provided
    (unless using Wikifier::Wiki, which provides its own).

    Returns a URL.
```

## Wikifier::Wiki options

```
image.type                      Default: png

    The desired file type for generated images. This is used by Wikifier::Wiki
    when generating images of different dimensions. All resulting images will be
    in this format, regardless of their original format.

    'png'  = larger, lossless compression format
    'jpeg' = smaller, lossy compression format

image.quality                   Default: 100

    The desired quality of generated images. This is only utilized if image.type
    is set to jpeg.

image.enable.retina             Default: 2

    Enable retina display support. Wikifier::Wiki will interpret and properly
    handle @2x or larger scaled versions of images.

    This option is a comma-separated list of scales, such as
        @image.enable.retina: 2,3;
    to support @2x and @3x scaling both.

image.enable.pregeneration      Default: enabled

    Enable pregeneration of images. Images will be generated as pages that
    require them are generated. This contrasts from the default behavior in
    which images are generated as they are requested.

    The advantage of this option is that it allows images to be served directly
    by a web server without summoning any Wikifier software, decreasing the page
    load time.

    The disadvantage is slower page generation time if new images have been
    added since the last generation time.

    Requires:
        image.enable.cache

image.enable.tracking           Default: enabled

    If enabled, Wikifier::Wiki will create page categories that track image
    usage. This is particularly useful for a Wikifier::Server feature that
    allows images and pages to be generated as they are modified.

image.enable.restriction        Default: enabled

    If enabled, Wikifier::Wiki will only generate images in dimensions used by
    pages on the wiki. This prevents useless resource usage and abuse.

image.enable.cache              Default: enabled

    Enable caching of generated images.

    Required for:
        image.enable.pregeneration
        image.enable.restriction

page.enable.cache               Default: enabled

    Enable caching of generated pages.

cat.per_page                    Default: unlimited

    Number of pages to display on a single category posts page.

cat.<name>.main                 Default: no main page; show newest at top

    Set the main page for the category by the name of <name>.
    This means that it will be displayed before all other categories, regardless
    of their creation dates. The value of this option is the page filename.

    You can also mark a page as the main page of a category from within the page
    source itself, like so:
        @category.some_cat.main;

    If multiple pages are marked as the main page of a category, the one with
    the most recent creation time is preferred. If this option is provided,
    however, the page specified by it will always be preferred.

cat.<name>.title                Default: page filename displayed as title

    Sets the human-readable title for the category by the name of <name>.

    You can also set the title of a category from within the category file
    itself using the "title" key.

PRIVATE Wikifier::Wiki options may be in a separation configuration file.
This is where administrator credentials are stored. You can also put them in the
primary configuration file, but this is not recommended.

admin.<username>.name

    The real name for the administrator <username>. This is used to attribute
    page creation, image upload, etc. to the user. It may be displayed to the
    public as the author or maintainer of a page or the owner of some file.
    It is also used for Wikifier::Wiki's built-in revision tracking.

admin.<username>.email

    The email address of the administrator <username>. Currently this is used
    only for Wikifier::Wiki's built-in revision tracking.

admin.<username>.crypt

    The type of encryption used for the password of administrator <username>.

    Accepted values:
        none    (plain text)
        sha1    (default)
        sha256
        sha512

admin.<username>.password

    The password of the administrator <username>. It must be encrypted in
    the crypt set by admin.<username>.crypt.
```

## Wikifier::Server options

```
server.socket.type              Default: unix

    The socket domain to use for listening. Currently, only UNIX is supported.

server.socket.path              Default: none

    The path of a UNIX socket to listen on.

server.enable.pregeneration     Default: disabled (but recommended)

    If enabled, the Wikifier::Server will generate all pages upon the first
    start. It will then monitor all page files and regenerate them as soon as
    they are modified, greatly reducing the first page load time.

    Requires:
        page.enable.cache

server.wiki.<name>.config       Default: none

    The path to the configuration file for the wiki by the name of <name>.
    Any number of wikis can be configured on a single server using this.

server.wiki.<name>.private       Default: none

    The path to the PRIVATE configuration file for the wiki by the name of
    <name>. This is where administrator credentials are stored. If it is not
    provided, it will be assumed that this information is in the primary
    configuration file. Be sure that the private configuration is not inside
    the HTTP server root or has proper permissions to deny access to it.

server.wiki.<name>.password     Default: none

    The read authentication password for the wiki by the name of <name>
    in plain text.
```
