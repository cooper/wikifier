<?php

/*
    This is a PHP client interface to the Wikifier wikiserver.
    Create a client instance with
    $client = new Wikiclient($path_to_socket, $wiki_name, $wiki_password);
    
    Then, use one of the public functions to send a request. These functions return the
    result in the form of: array($response_message, $options) where
    
    $response_message is the command or message reply and
    $options is an associative array of message options
    
*/

class Wikiclient {

    public $connected = false;
    public $wiki_name;
    public $session_id;
    private $wiki_pass;
    private $path;
    private $sock;
    private $username;
    private $password;
    
    public function __construct($path, $wiki_name, $wiki_pass, $session_id) {
        $this->path = $path;
        $this->wiki_name  = $wiki_name;
        $this->wiki_pass  = $wiki_pass;
        $this->session_id = $session_id;
    }
    
    // connect to unix listener.
    private function connect($n = 1) {
        $this->sock = fsockopen('unix://'.$this->path, 0, $errno, $errstr, 10);
        if (!$this->sock) {
            if ($n == 5) return;
            $this->connect($n + 1);
        }
        
        // send anonymous login info.
        $auth = array('wiki', array(
            'name'     => $this->wiki_name,
            'password' => $this->wiki_pass
        ));
        if (fwrite($this->sock, json_encode($auth)."\n"))
            $this->connected = true;
        else return;

        // send session ID.
        if (isset($this->session_id)) {
            $auth2 = array('resume', array(
                'session_id' => $this->session_id
            ));
            fwrite($this->sock, json_encode($auth2)."\n");
        }
        
        return $this->connected;
    }
    
    // send a command/message.
    private function command($command, $opts) {
        if ($command != 'wiki' && !$this->connected)
            $this->connect();
        $opts['close'] = true;
        
        // send request
        $req = array($command, $opts);
        if (!fwrite($this->sock, json_encode($req)."\n")) return null;
        $data = '';
        
        // read until the server sends EOF.
        while (!feof($this->sock)) {
            $data .= fgets($this->sock, 128);
        }
        fclose($this->sock);
        
        // decode JSON.
        $res = json_decode(trim($data));
        $res[1]->response = $res[0];
        return $res[1];
        
    }
    
    /*********** PUBLIC METHODS ***********/

    // send a page request.
    function page($name) {
        return $this->command('page', array( 'name' => $name ));
    }
    
    // send an image request.
    function image($name, $width, $height) {
        return $this->command('image', array(
            'name'   => $name,
            'width'  => $width,
            'height' => $height
        ));
    }
    
    // send a category posts request.
    function catposts($category, $page_n) {
        return $this->command('catposts', array(
            'name'   => $category,
            'page_n' => $page_n
        ));
    }
    
    // send login for write access.
    function login($username, $password, $session_id) {
        return $this->command('login', array(
            'username'   => $username,
            'password'   => $password,
            'session_id' => $session_id
        ));
    }
    
}

?>
