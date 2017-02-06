# Configuration

This document describes all of the available configuration options. The options
are categorized by the lowest-level wikifier interface at which they are used.
Some are required for the generation of a single page, others for the operation
of a full wiki, and others yet for the operation of a wiki server.

* [Configuration](#configuration)
    * [Configuration files](#configuration-files)
    * [Configuration directly from code](#configuration-directly-from-code)
  * [Wikifier::Page options](#wikifierpage-options)
    * [name](#name)
    * [root](#root)
    * [dir](#dir)
    * [external](#external)
    * [page\.enable\.title](#pageenabletitle)
    * [page\.enable\.footer](#pageenablefooter)
    * [image\.size\_method](#imagesize_method)
    * [image\.calc](#imagecalc)
    * [image\.rounding](#imagerounding)
    * [image\.sizer](#imagesizer)
  * [Wikifier::Wiki public options](#wikifierwiki-public-options)
    * [image\.type](#imagetype)
    * [image\.quality](#imagequality)
    * [image\.enable\.retina](#imageenableretina)
    * [image\.enable\.pregeneration](#imageenablepregeneration)
    * [image\.enable\.tracking](#imageenabletracking)
    * [image\.enable\.restriction](#imageenablerestriction)
    * [image\.enable\.cache](#imageenablecache)
    * [page\.enable\.cache](#pageenablecache)
    * [cat\.per\_page](#catper_page)
    * [cat\.[name]\.main](#catnamemain)
    * [cat\.[name]\.title](#catnametitle)
    * [var\.\*](#var)
  * [Wikifier::Wiki private options](#wikifierwiki-private-options)
    * [admin\.[username]\.name](#adminusernamename)
    * [admin\.[username]\.email](#adminusernameemail)
    * [admin\.[username]\.crypt](#adminusernamecrypt)
    * [admin\.[username]\.password](#adminusernamepassword)
  * [Wikifier::Server options](#wikifierserver-options)
    * [server\.socket\.type](#serversockettype)
    * [server\.socket\.path](#serversocketpath)
    * [server\.enable\.pregeneration](#serverenablepregeneration)
    * [server\.wiki\.[name]\.config](#serverwikinameconfig)
    * [server\.wiki\.[name]\.private](#serverwikinameprivate)
    * [server\.wiki\.[name]\.password](#serverwikinamepassword)

### Configuration files

The primary method of configuration is to define options in a configuration
file. All wikifier configuration files are written in the wikifier language:

    @name:          MyWiki;
    @dir.wiki:      /home/www/mywiki;
    @dir.page:      [@dir.wiki]/pages;

If you are using a **wiki server**, you must have a dedicated configuration file
for the server. This tells it where to listen and where to find the wikis you
have configured on the server. This is typically called `wikiserver.conf`, and
it is required as the first argument to the `wikiserver` executable.

**Every wiki** also requires its own configuration file. It may make sense to
store your wiki configuration file at a path outside of the wiki root, just in
case it contains sensitive information. If you are using a wiki server, the path
of each wiki's configuration file is defined in the server configuration using
the `server.wiki.[name].config` option. If you are using Wikifier::Wiki
directly, the path to the wiki configuration must be provided to the
constructor:
```perl
my $wiki = Wikifier::Wiki->new(config_file => '/home/www/mywiki/wiki.conf');
```

Each wiki can optionally have a **private configuration** file. This is where
the credentials of administrators can exist more securely than in the primary
configuration. This file certainly should not be within the wiki root because
that would probably allow anyone to download it from the web server. If you are
using a wiki server, the path of the private configuration is defined by
`server.wiki.[name].private`. If you are using Wikifier::Wiki directly, the path
to the private configuration may be provided to the constructor:
```perl
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

### name

Name of the wiki.

__Default__: *Wiki*

### root

* `root.wiki`   - wiki root.    __Default__: '' (i.e. /)
* `root.page`   - page root.    __Default__: /page
* `root.image`  - image root.   __Default__: /images

HTTP roots. These are relative to the server HTTP root, NOT the wiki root.
They are used for link targets and image URLs; they will never be used to
locate content on the filesystem. Do not include trailing slashes.

It may be useful to use root.wiki within the definitions of the rest:

    @root.wiki:     /mywiki;
    @root.page:     [@root.wiki]/page;
    @root.image:    [@root.wiki]/images;

If you are using Wikifier::Wiki (or a wiki server) in conjunction with
image.enable.cache and image.enable.pregeneration, you should set root.image
to wherever your cache directory can be found on the HTTP root. This is
where generated images are cached, and full-sized images are symbolically
linked to. This allows the web server to deliver images directly, which is
certainly most efficient.

### dir

* `dir.wikifier`  - wikifier repository
* `dir.wiki`      - wiki root directory
* `dir.page`      - page files stored here
* `dir.image`     - image originals stored here
* `dir.model`     - models stored here
* `dir.cache`     - generated page and image cache files stored here
* `dir.category`  - generated category files stored here

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

### external

* `external.name` - External wiki name, displayed in link tooltips.
  __Default__: *Wikipedia*
* `external.root` - External wiki page root.
  __Default__: *http://en.wikipedia.org/wiki*

External wiki information. This is used for External wiki links in the form
of `[! article !]`.

Page names will be translated to URLs in a format compatible with MediaWiki.
Currently this is non-configurable.

### page.enable.title

If enabled, the first section's title will be the title of the page. You
may want to disable this if your wiki content is embedded within a template
that has its own place for the page title.

__Default__: Enabled

### page.enable.footer

If enabled, the closing `/div>` tags will be omitted from the final section
and wiki block. This allows a footer to be injected before closing them off.

__Default__: Disabled

### image.size_method

The method which the Wikifier should use to scale images.

* _javascript_ - JavaScript-injected image sizing
* _server_ - server-side image sizing using `image.sizer` and `image.calc`
  (recommended)

When set to 'server', the options image.calc and image.sizer are required.
If using Wikifier::Page directly, image.calc is provided but requires that
you install Image::Size. In that case, you are required to provide a
custom image.sizer routine. If using Wikifier::Wiki, image.calc and
image.sizer are both provided, but GD must be installed from CPAN.

__Default__ (Page): _javascript_

__Default__ (Wiki): _server_

### image.calc

A code reference that calculates a missing dimension of an image.
This is utilized only when `image.size_method` is _server_.

Returns `(width, height)`.

__Default__ (Page): built in, uses Image::Size

__Default__ (Wiki): built in, uses GD

### image.rounding

The desired rounding method used when determining image dimensions. Used by
the default `image.calc`. If a custom `image.calc` is provided, this will not be
utilized.

* _normal_ - round up from .5 or more, down for less
* _up_ - always round up
* _down_ - always round down

__Default__: _normal_

### image.sizer

A code reference that returns the URL to a sized version of an image. After
using `image.calc` to find the dimensions of an image, `image.sizer` is called
to generate a URL for the image at those dimensions.

If using `image.size_method` _server_, `image.sizer` must be provided
(unless using Wikifier::Wiki, which provides its own).

Returns a URL.

__Default__ (Page): none; custom code required

__Default__ (Wiki): built in

## Wikifier::Wiki public options

### image.type

The desired file type for generated images. This is used by Wikifier::Wiki
when generating images of different dimensions. All resulting images will be
in this format, regardless of their original format.

* _png_ - larger, lossless compression
* _jpeg_ - smaller, lossy compression

__Default__: *png*

### image.quality

The desired quality of generated images. This is only utilized if `image.type`
is set to jpeg.

__Default__: *100*

### image.enable.retina

Enable retina display support. Wikifier::Wiki will interpret and properly
handle @2x or larger scaled versions of images.

This option is a comma-separated list of scales, such as

    @image.enable.retina: 2,3;

to support @2x and @3x scaling both.

__Default__: *2*

### image.enable.pregeneration

Enable pregeneration of images. Images will be generated as pages that
require them are generated. This contrasts from the default behavior in
which images are generated as they are requested.

The advantage of this option is that it allows images to be served directly
by a web server without summoning any Wikifier software, decreasing the page
load time.

The disadvantage is slower page generation time if new images have been
added since the last generation time.

__Requires__: `image.enable.cache`

__Default__: Enabled

### image.enable.tracking

If enabled, Wikifier::Wiki will create page categories that track image
usage. This is particularly useful for a Wikifier::Server feature that
allows images and pages to be generated as they are modified.

__Default__: Enabled

### image.enable.restriction

If enabled, Wikifier::Wiki will only generate images in dimensions used by
pages on the wiki. This prevents useless resource usage and abuse.

__Default__: Enabled

### image.enable.cache

Enable caching of generated images.

__Required by__: `image.enable.pregeneration`, `image.enable.restriction`

__Default__: Enabled

### page.enable.cache

Enable caching of generated pages.

__Default__: Enabled

### cat.per_page

Number of pages to display on a single category posts page.

__Default__: Unlimited

### cat.[name].main

Set the main page for the category by the name of `[name]`.
This means that it will be displayed before all other categories, regardless
of their creation dates. The value of this option is the page filename.

You can also mark a page as the main page of a category from within the page
source itself, like so:

    @category.some_cat.main;

If multiple pages are marked as the main page of a category, the one with
the most recent creation time is preferred. If this option is provided,
however, the page specified by it will always be preferred.

__Default__: None; show newest at top

### cat.[name].title

Sets the human-readable title for the category by the name of `[name]`.

You can also set the title of a category from within the category file
itself using the "title" key.

__Default__: None; page filename displayed as title

### var.*

Global wiki variable space. Variables defined in this space will be
available throughout the wiki. However they may be overwritten on a
particular page.

Example (in config):

    @var.site.url: http://mywiki.example.com
    @var.site.display_name: MyWiki;

Example (on main page):

    Welcome to [@site.display_name]!

## Wikifier::Wiki private options

Private Wikifier::Wiki options may be in a separation configuration file.
This is where administrator credentials are stored. You can also put them in the
primary configuration file, but this is not recommended.

### admin.[username].name

The real name for the administrator `[username]`. This is used to attribute
page creation, image upload, etc. to the user. It may be displayed to the
public as the author or maintainer of a page or the owner of some file.
It is also used for Wikifier::Wiki's built-in revision tracking.

### admin.[username].email

The email address of the administrator `[username]`. Currently this is used
only for Wikifier::Wiki's built-in revision tracking.

### admin.[username].crypt

The type of encryption used for the password of administrator `[username]`.

* _none_ (plain text)
* _sha1_
* _sha256_
* _sha512_

__Default__: *sha1*

### admin.[username].password

The password of the administrator `[username]`. It must be encrypted in
the crypt set by `admin.[username].crypt`.


## Wikifier::Server options

### server.socket.type

The socket domain to use for listening. Currently, only UNIX is supported.

__Default__: _unix_

### server.socket.path

The path of a UNIX socket to listen on.

### server.enable.pregeneration

If enabled, the Wikifier::Server will generate all pages upon the first
start. It will then monitor all page files and regenerate them as soon as
they are modified, greatly reducing the first page load time.

__Requires__: `page.enable.cache`

__Default__: Disabled (but recommended)

### server.wiki.[name].config

The path to the configuration file for the wiki by the name of `[name]`.
Any number of wikis can be configured on a single server using this.

### server.wiki.[name].private

The path to the PRIVATE configuration file for the wiki by the name of
`[name]`. This is where administrator credentials are stored. If it is not
provided, it will be assumed that this information is in the primary
configuration file. Be sure that the private configuration is not inside
the HTTP server root or has proper permissions to deny access to it.

### server.wiki.[name].password

The read authentication password for the wiki by the name of `[name]`
in plain text.
