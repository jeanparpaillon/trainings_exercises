# The official WordPress image, plus our own code: one must-use plugin.
# Files under /usr/src/wordpress are what the image's entrypoint copies into
# /var/www/html (an emptyDir) when a pod starts, so every new pod gets them.
FROM wordpress:7.1-apache

# The image tag, baked in at build time (.github/workflows/image.yaml): the
# banner shows which build a pod runs. The environment comes from the
# overlay, at run time — the same image goes to dev and to prod.
ARG VERSION=unknown
ENV F021_VERSION=$VERSION

COPY --chown=www-data:www-data f021-banner.php /usr/src/wordpress/wp-content/mu-plugins/f021-banner.php
