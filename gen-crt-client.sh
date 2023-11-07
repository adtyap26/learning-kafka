#!/bin/bash

# Variable yang dapat kita ubah
CA_NAME="ClienCA"
CA_P12="client.ca.p12"
CA_CRT_NAME="client.ca.crt"
STOREPASS="latihan"
KEYPASS="latihan"
ALIAS_CA_SERVER="server"
ALIAS_KEYSTORE="client"
KEYSTORE_NAME="client.ks.p12"
TRUSTSTORE_NAME="client.ts.p12"
CN="localhost"
CSR_NAME="client.csr"
CRT_NAME="client.crt"

# Prompt the user for the paths to server.ca.crt and client.ca.crt
read -p "Enter the path to the server CA certificate (server.ca.crt): " server_ca_path
read -p "Enter the path to the server trustore (server.ts.p12): " server_ts_path
read -p "Enter alias for CA Client(this will be imported to Truststore Server): " ALIAS_CA_CLIENT

# Import server.ca.crt ke klien trustore
keytool -import -file "$server_ca_path" -keystore "$TRUSTSTORE_NAME" \
-storetype PKCS12 -storepass $STOREPASS -alias "$ALIAS_CA_SERVER" -noprompt


# Langkah 1: Kita buat self signed CA untuk client
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
cat "$CRT_NAME" "$CA_CRT_NAME" > clientchain.crt 

keytool -importcert -file clientchain.crt -keystore "$KEYSTORE_NAME" \
-storepass "$STOREPASS" -keypass "$KEYPASS" -alias "$ALIAS_KEYSTORE" \
-storetype PKCS12 -noprompt

# import client.ca.crt ke server trustore
keytool -import -file "$CA_CRT_NAME" -keystore "$server_ts_path" -alias "$ALIAS_CA_CLIENT" \
-storetype PKCS12 -storepass "$STOREPASS" -noprompt


