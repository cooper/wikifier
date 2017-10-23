# Log types

Wikifier::Wiki log types and attributes.

## login_fail

Denied user credentials for write authentication.

* __username__
* __crypt__ - _optional_, the crypt method used by this user. not available when
  reason is `username`
* __reason__ - why the login was denied. one of:
  * `username` - user doesn't exist
  * `crypt` - crypt function failed or unavailable
  * `password` - password was wrong
  
## login

User logged in for write authentication.

* __username__
* __crypt__ - the crypt method used to login
* __name__ - _optional_, user display name
* __email__ - _optional_, user email address

## page_write

Page source was written.

* __user__ - _optional_, object with info on user responsible. none are
  guaranteed to be present, nor is the object itself
  * `username`
  * `name` - display name
  * `email`
* __is_model__ - true if the file written is a model
* __file__ - file path, relative to [`dir.wiki`](../configuration.md#dir)
* __message__ - commit message
* __commit__ - sha commit ID

## page_write_fail

Page source write failed.

* __user__ - _optional_, object with info on user responsible. none are
  guaranteed to be present, nor is the object itself
  * `username`
  * `name` - display name
  * `email`
* __is_model__ - true if the file we tried to write is a model
* __file__ - file path, relative to [`dir.wiki`](../configuration.md#dir)
* __message__ - commit message
* __errors__ - array of string error messages

## page_delete

Page was deleted.

* __user__ - _optional_, object with info on user responsible. none are
  guaranteed to be present, nor is the object itself
  * `username`
  * `name` - display name
  * `email`
* __is_model__ - true if the file deleted was a model
* __file__ - file path, relative to [`dir.wiki`](../configuration.md#dir)
* __message__ - commit message
* __commit__ - sha commit ID

## page_delete_fail

Page delete failed.

* __user__ - _optional_, object with info on user responsible. none are
  guaranteed to be present, nor is the object itself
  * `username`
  * `name` - display name
  * `email`
* __is_model__ - true if the file we tried to delete is a model
* __file__ - file path, relative to [`dir.wiki`](../configuration.md#dir)
* __message__ - commit message
* __errors__ - array of string error messages

## page_move

Page was moved.

* __user__ - _optional_, object with info on user responsible. none are
  guaranteed to be present, nor is the object itself
  * `username`
  * `name` - display name
  * `email`
* __is_model__ - true if the file moved is a model
* __src_file__ - source file path, relative to
  [`dir.wiki`](../configuration.md#dir)
* __dest_file__ - destination file path, relative to
  [`dir.wiki`](../configuration.md#dir)
* __src_name__ - old page name
* __dest_name__ - new page name
* __message__ - commit message
* __commit__ - sha commit ID

## page_move_failed

Page move failed.

* __user__ - _optional_, object with info on user responsible. none are
  guaranteed to be present, nor is the object itself
  * `username`
  * `name` - display name
  * `email`
* __is_model__ - true if the file we tried to move is a model
* __src_file__ - source file path, relative to
  [`dir.wiki`](../configuration.md#dir)
* __dest_file__ - destination file path to which we tried moving, relative to
  [`dir.wiki`](../configuration.md#dir)
* __src_name__ - old page name
* __dest_name__ - page name to which we tried moving
* __errors__ - array of string error messages
