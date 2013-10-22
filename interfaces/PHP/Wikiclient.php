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
    private $wiki_pass;
    private $path;
    private $sock;
    
    public function __construct($path, $wiki_name, $wiki_pass) {
        $this->path = $path;
        $this->wiki_name = $wiki_name;
        $this->wiki_pass = $wiki_pass;
    }
    
    // connect to unix listener.
    private function connect() {
        $this->sock = fsockopen('unix://'.$this->path, 0, $errno, $errstr, 10);
        if (!$this->sock) return;
        
        // send login info
        $auth = array('wiki', array(
            'name'     => $this->wiki_name,
            'password' => $this->wiki_pass
        ));
        
        if (fwrite($this->sock, json_encode($auth)."\n")) {
            $this->connected = true;
            return true;
        }
        
        return;
    }
    
    // send a command/message.
    private function command($command, $opts) {
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

    // send a page request.
    public function page($name) {
        if (!$this->connected) $this->connect();
        return $this->command('page', array( 'name' => $name ));
    }
    
    // send an image request.
    public function image($name, $width, $height) {
        if (!$this->connected) $this->connect();
        return $this->command('image', array(
            'name'   => $name,
            'width'  => $width,
            'height' => $height
        ));
    }
    
    // send a category posts request.
    public function catposts($category, $page_n) {
        return $this->command('catposts', array(
            'name'   => $category,
            'page_n' => $page_n
        ));
    }

}

?>
