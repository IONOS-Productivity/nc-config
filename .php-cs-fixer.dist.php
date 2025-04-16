<?php

declare(strict_types=1);

use PhpCsFixer\Runner\Parallel\ParallelConfigFactory;

$config = new PhpCsFixer\Config();
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
