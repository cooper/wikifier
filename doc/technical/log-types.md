# Log types

Wikifier::Wiki log types and attributes.

## login

## login_fail

Denied user credentials for write authentication.

* __username__
* __crypt__ - _optional_, the crypt method used by this user. not available when
  reason is `username`
* __reason__ - why the login was denied
  * `username` - user doesn't exist
  * `crypt` - crypt function failed or unavailable
  * `password` - password was wrong
  
## login

User logged in for write authentication.

* __username__
* __crypt__ - the crypt method used to login
* __name__ - _optional_, user display name
* __email__ - _optional_, user email address
