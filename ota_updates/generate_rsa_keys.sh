# 1. Generate the 2048-bit private key
openssl genrsa -out private.pem 2048

# 2. Extract the public key from that private key
openssl rsa -in private.pem -out public.pem -pubout