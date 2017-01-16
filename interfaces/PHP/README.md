# PHP Wikiclient

This is a PHP interface to Wikifier::Server.

## Constructor

Create a new wikiclient instance.
```php
$wikiclient = new Wikiclient($path, $wiki_name, $wiki_pass, $session_id);
```

* __$path__: Path the wikifier UNIX socket.
* __$wiki_name__: shortname of the wiki. This is the one used in the wikiserver
  configuration file.
* __$wiki_pass__: password for read access to the wiki. This is also set
  in the wikiserver configuration file.
* __$session_id__: _optional_, a string which identifies a logged in user.
  Once the user logs in initially with [`->login()`](#login), the session ID can
  be used to resume the session on each page load without having to send the
  username and password again. This is only useful if you need write access to
  the wiki from this wikiclient.

## High-level methods

### login

```php
$wikiclient->login($username, $password, $session_id);
```

Used to obtain write access to this wiki. This is not needed if you are only
going to be reading with this wikiclient.

* __$username__ - account username.
* __$password__ - account password.
* __$session_id__ - _optional_, a string which will later be used to re-identify
  the user without having to send the username and password again. See
  [constructor](#constructor) for more information.

Returns an object with properties
* __->logged_in__ - true if the login was successful.
* __->name__ - user's real name, if configured.
* __->email__ - user's email, if configured.

### page



### page_code

### page_list

### image

### catposts

### page_save

### page_del

### page_move

## Low-level methods

These methods usually aren't used directly.

### connect

```php
$wikiclient->connect();
```

Connects to the wikiserver. You don't have to call this directly, as other
methods will automatically connect if needed.

### command

```php
$wikiclient->command($command, $opts);
```

Sends a raw command to the wikiserver. You shouldn't have to use this directly,
since the other high-level methods wrap it.
