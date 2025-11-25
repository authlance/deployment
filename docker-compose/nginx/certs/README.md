Place your TLS certificate and private key here.

Required filenames (default):
- server.crt
- server.key

For local dev you can create a self-signed pair (example):

openssl req -x509 -newkey rsa:2048 -keyout server.key -out server.crt -sha256 -days 365 -nodes -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

Or with mkcert (recommended for trust in browsers):

mkcert -install
mkcert localhost 127.0.0.1 ::1
mv localhost+2-key.pem server.key
mv localhost+2.pem server.crt
