<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once 'lib/predis/autoload.php';
require_once 'Spyc.class.php';

$config = Spyc::YAMLLoad('config.yaml');

$redis = new Predis\Client(array(
	'host' => $config['redis']['host'], 
	'port' => $config['redis']['port'], 
	'password' => $config['redis']['password'], 
));

foreach (array('QB', 'RB', 'WR') as $key) {
	$redisresult = $redis->get($key);
	// check if it is in redis
	if (isset($redisresult) && $redisresult !== "") {
		$result[] = json_decode($redisresult,1);
	} else {
		$script = sprintf('ruby ./football.rb -p %s', $key);
		$resp = exec($script, $out, $err);
		$redis->set($key, $resp);
		$redis->expire($key, 900);
		$result[] = json_decode($resp,1);
	}
}

echo "<pre>";
print_r($result);
