<?php

$CONFIG = [
	'enabledPreviewProviders' => [
		'OC\Preview\BMP',
		'OC\Preview\GIF',
		'OC\Preview\HEIC',
		'OC\Preview\Imaginary',
		'OC\Preview\JPEG',
		'OC\Preview\Krita',
		'OC\Preview\MarkDown',
		'OC\Preview\Movie',
		'OC\Preview\MP3',
		'OC\Preview\OpenDocument',
		'OC\Preview\PNG',
		'OC\Preview\SVG',
		'OC\Preview\TIFF',
		'OC\Preview\TXT',
		'OC\Preview\WebP',
		'OC\Preview\XBitmap',
	],
	'preview_max_x' => 8192,
	'preview_max_y' => 8192,
	'preview_max_filesize_image' => 256,
	'preview_imaginary_url' => (string)getenv('IMAGINARY_HOST'),
	'preview_imaginary_key' => (string)getenv('IMAGINARY_KEY'),
	'preview_ffmpeg_path' => '/usr/bin/ffmpeg',
];
