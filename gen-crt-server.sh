#!/bin/bash

# Variable yang dapat kita ubah
CA_NAME="BrokerCA"
CA_P12="server.ca.p12"
CA_CRT_NAME="server.ca.crt"
STOREPASS="latihan"
KEYPASS="latihan"
ALIAS_CA="ca"
ALIAS_KEYSTORE="server"
KEYSTORE_NAME="server.ks.p12"
TRUSTSTORE_NAME="server.ts.p12"
CN="localhost"
CSR_NAME="server.csr"
CRT_NAME="server.crt"

# Langkah 1: Kita buat self signed CA untuk server
keytool -genkeypair -keyalg RSA -keysize 2048 -keystore "$CA_P12" \
-storetype PKCS12 -storepass "$STOREPASS" -keypass "$KEYPASS" \
-alias "$ALIAS_CA" -dname "CN='$CA_NAME'" -ext bc=ca:true -validity 365

keytool -export -file "$CA_CRT_NAME" -keystore "$CA_P12" \
-storetype PKCS12 -storepass "$STOREPASS" -alias "$ALIAS_CA" -rfc

# Langkah 2: Kita buat Keystore dan certificate request untuk di signed sama CA  
keytool -genkey -keyalg RSA -keysize 2048 -keystore "$KEYSTORE_NAME" \
-storepass "$STOREPASS" -keypass "$KEYPASS" -alias "$ALIAS_KEYSTORE" \
-storetype PKCS12 -dname "CN='$CN',O=AllData,C=ID" -validity 365

# Cert req to be signed
keytool -certreq -file "$CSR_NAME" -keystore "$KEYSTORE_NAME" -storetype PKCS12 \
-storepass "$STOREPASS" -keypass "$KEYPASS" -alias "$ALIAS_KEYSTORE"

keytool -gencert -infile "$CSR_NAME" -outfile "$CRT_NAME" \
-keystore "$CA_P12" -storetype PKCS12 -storepass "$STOREPASS" \
-alias "$ALIAS_CA" -ext SAN=DNS:localhost -validity 365


# Kita gunakan command cat to concatenate file jadi lebih ringkas gak perlu import 2 kali
cat "$CRT_NAME" "$CA_CRT_NAME" > serverchain.crt 

keytool -importcert -file serverchain.crt -keystore "$KEYSTORE_NAME" \
-storepass "$STOREPASS" -keypass "$KEYPASS" -alias "$ALIAS_KEYSTORE" \
-storetype PKCS12 -noprompt

# Kita buat trustore untuk server 
keytool -import -file "$CA_CRT_NAME" -keystore "$TRUSTSTORE_NAME" \
-storetype PKCS12 -storepass "$STOREPASS" -alias "$ALIAS_KEYSTORE" -noprompt




