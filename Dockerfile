FROM nginx:1

# Enable built-in interpolation of templates
ENV NGINX_ENVSUBST_TEMPLATE_DIR=/usr/share/nginx/templates \
    NGINX_ENVSUBST_OUTPUT_DIR=/usr/share/nginx/html

# Define variables that will be interpolated
ENV SIGN_IN_URL='#'

# For templated HTML
COPY *.template ${NGINX_ENVSUBST_TEMPLATE_DIR}/

# For static HTML
#COPY *.html ${NGINX_ENVSUBST_OUTPUT_DIR}/
