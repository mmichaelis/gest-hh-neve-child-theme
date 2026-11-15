<?php
/**
 * Plugin Name: GEST Local Environment Safeguards
 * Description: Blocks email and limits browser requests in the local copy.
 */

add_filter(
	'pre_wp_mail',
	static function () {
		return false;
	}
);

add_action(
	'send_headers',
	static function () {
		header(
			"Content-Security-Policy: default-src 'self' data: blob:; "
			. "base-uri 'self'; form-action 'self'; object-src 'none'; "
			. "frame-ancestors 'self'; connect-src 'self'; "
			. "font-src 'self' data: https://fonts.gstatic.com; "
			. "img-src 'self' data: blob:; "
			. "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
			. "script-src 'self' 'unsafe-inline'"
		);
	}
);
