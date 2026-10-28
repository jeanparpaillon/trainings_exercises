<?php
/*
 * Plugin Name: F021 banner
 * Description: Shows the environment and the image version at the bottom of every page.
 *
 * A must-use plugin: WordPress loads it without activation.
 * F021_ENV comes from the overlay's ConfigMap, F021_VERSION from the image.
 */

add_action('wp_footer', function () {
    $env     = getenv('F021_ENV') ?: 'unknown';
    $version = getenv('F021_VERSION') ?: 'unknown';
    $colour  = '#1565c0';   // change me: a visible code change

    printf(
        '<div style="position:fixed;left:0;right:0;bottom:0;z-index:9999;padding:.6em;'
        . 'text-align:center;font:bold 18px sans-serif;color:#fff;background:%s">%s · %s</div>',
        esc_attr($colour),
        esc_html($env),
        esc_html($version)
    );
});
