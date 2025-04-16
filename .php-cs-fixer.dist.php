<?php

declare(strict_types=1);
require_once './vendor/autoload.php';

use PhpCsFixer\Runner\Parallel\ParallelConfigFactory;
use Nextcloud\CodingStandard\Config;

$config = new Config();
$config
	->setParallelConfig(ParallelConfigFactory::detect())
	->getFinder()
	->ignoreVCSIgnored(true)
	->notPath('composer')
	->notPath('node_modules')
	->notPath('vendor')
	->in('configs')
	->in(__DIR__);

return $config;
