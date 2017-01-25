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
    public $login_again_cb;

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
    private function connect($n = 1, $is_login = false) {
        $this->sock = fsockopen('unix://'.$this->path, 0, $errno, $errstr, 10);
        if (!$this->sock) {
            if ($n == 5) return;
            $this->connect($n + 1, $is_login);
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
        if (isset($this->session_id) && !$is_login) {
            $auth2 = array('resume', array(
                'session_id' => $this->session_id
            ));
            fwrite($this->sock, json_encode($auth2)."\n");
        }

        return $this->connected;
    }

    // send a command/message.
    private function command($command, $opts = array()) {
        if ($command != 'wiki' && !$this->connected)
            $this->connect(1, $command == 'login');
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
        unset($this->sock);
        $this->connected = false;

        // decode JSON.
        $res = json_decode(trim($data));
        $res[1]->response = $res[0];
        $res = $res[1];

        // check if the session expired.
        if (isset($res->login_again)) {
            if ($this->login_again_cb)
                $this->login_again_cb->__invoke();
            return;
        }

        return $res;
    }

    // send login for write access.
    function login($username, $password, $session_id) {
        return $this->command('login', array(
            'username'   => $username,
            'password'   => $password,
            'session_id' => $session_id
        ));
    }

    /*********** PUBLIC READ METHODS ***********/

    // send a page request.
    function page($name) {
        return $this->command('page', array( 'name' => $name ));
    }

    // send a page code request.
    function page_code($name, $display_page) {
        return $this->command('page_code', array(
            'name'         => $name,
            'display_page' => $display_page
        ));
    }

    // send a page list request.
    function page_list($sort = 'm-') {
        return $this->command('page_list', array(
            'sort' => $sort
        ));
    }

    // send a model code request.
    function model_code($name, $display_model) {
        return $this->command('model_code', array(
            'name'          => $name,
            'display_model' => $display_model
        ));
    }

    // send a model list request
    function model_list($sort = 'm-') {
        return $this->command('model_list', array(
            'sort' => $sort
        ));
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
    function cat_posts($name, $page_n) {
        return $this->command('cat_posts', array(
            'name'   => $name,
            'page_n' => $page_n
        ));
    }

    // send a category list request
    function cat_list($sort = 'm-') {
        return $this->command('cat_list', array(
            'sort' => $sort
        ));
    }

    // check connection
    function ping() {
        return $this->command('ping');
    }

    /*********** PUBLIC WRITE METHODS ***********/

    function page_save($name, $content, $message) {
        return $this->command('page_save', array(
            'name'    => $name,
            'content' => $content,
            'message' => $message
        ));
    }

    function page_del($name) {
        return $this->command('page_del', array(
            'name' => $name
        ));
    }

    function page_move($name, $new_name) {
        return $this->command('page_move', array(
            'name'     => $name,
            'new_name' => $new_name
        ));
    }

    function model_save($name, $content, $message) {
        return $this->command('model_save', array(
            'name'    => $name,
            'content' => $content,
            'message' => $message
        ));
    }

    function model_del($name) {
        return $this->command('model_del', array(
            'name' => $name
        ));
    }

    function model_move($name, $new_name) {
        return $this->command('model_move', array(
            'name'     => $name,
            'new_name' => $new_name
        ));
    }

}

?>
