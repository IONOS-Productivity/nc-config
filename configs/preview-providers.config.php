<?php

$CONFIG = [

	'preview_max_x' => 8192,
	'preview_max_y' => 8192,
	'preview_max_filesize_image' => 256,
	'preview_imaginary_url' => (string)getenv('IMAGINARY_HOST'),
	'preview_imaginary_key' => (string)getenv('IMAGINARY_KEY'),
	'preview_ffmpeg_path' => '/usr/bin/ffmpeg',
];
