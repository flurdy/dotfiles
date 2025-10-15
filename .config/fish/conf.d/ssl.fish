set -x SSL_CERT_FILE /etc/pki/tls/certs/ca-bundle.crt
set -x SSL_CERT_DIR  /etc/ssl/certs
set -x JAVA_TOOL_OPTIONS "-Djavax.net.ssl.trustStore=/etc/pki/java/cacerts"
