# Hands On Basic Kafka: Security

Pada minggu kedua yang saya pelajari adalah bagaimana membuat sebuah zookeeper dan kafka cluster yang terhubung dengan berbagai client menjadi secure, dalam arti bukan hanya proses autentikasi clientnya saja namun juga terdapat protokol keamanan yang dapat melindungi atau meng-enkripsi sebuah data yang ditransfer melalui proses hubungan client-server.

Sebelum lebih jauh, saya ingin mengutip pernyataan terkait isu keamanan di dalam buku [Kafka: The Definitive Guide, 2nd Edition](https://www.oreilly.com/library/view/kafka-the-definitive/9781492043072/).

> ..security is an aspect of the system that must be addressed for the system as a whole, rather than component by component.

Jadi, membuat sebuah sistem yang aman memang mesti menyeluruh, bukan hanya pada sisi kafka clusternya saja, namun seluruh pendukung seperti tempat kafka cluster tersebut berjalan dan berinteraksi pun harus dibuat dengan standar keamanan tertentu.

Secara default security pada `port listerner` di dalam kafka menggunakan `PLAINTEXT` artinya tidak memiliki enkripsi keamanan sama sekali dimana jika terdapat data yang ditransfer dari client sebagai producer ke dalam kafka cluster, maka akan dapat terbaca dengan metode sniffing atau tempering menggunakan wireshark.

Contohnya saya akan membuat sebuah topik yang bernama insecureData dan akan mem-produce pesan ke dalamnya.

Pada posisi ini config `server.properties` nya menggunakan `listeners=PLAINTEXT://localhost:9092`

Sedang dalam konfigurasi wiresharknya saya memastikan bahwa protocol kafka terpasang di dalam `edit => preferences => Protocols`. Setelah itu kita akan melakukan paket capture menggunakan interface `Loopback:lo` untuk sniffing paket localhost.

Berikut adalah hasil dari sniffingnya:

![wiresharkoverview](https://github.com/adtyap26/learning-kafka/assets/101618848/2a63370e-948c-4fbe-aa41-eeaee0c64d34)

Jika kita melakukan follow dan tcp stream pada salah satu pake data tersebut maka hasilnya sebagai berikut:

![sniff_wireshark](https://github.com/adtyap26/learning-kafka/assets/101618848/6bd624a0-d1d0-46ce-8da9-23f8b41eaf2a)

Dapat kita lihat, gambar sebelah kiri adalah sebuah client yang melakukan produce data, sedang gambar sebelah kanan wireshark dapat melihat pesan yang ditransfer dari producer tersebut.

Kafka memiliki solusi terhadap permasalahan tersebut dengan memiliki bebrapa opsi security protocol yakni adanya SSL (Secure Socket Layer) sebagai enkripsinya dan SASL (Simple Authentication and Security Layer) sebagai autentikasinya. Berikut tabel lengkapnya:

| No  | Protokol       | Keterangan                                       |
| --- | -------------- | ------------------------------------------------ |
| 1   | PLAINTEXT      | Komunikasi tanpa enkripsi data.                  |
| 2   | SSL            | Komunikasi dengan menggunakan enkripsi SSL/TLS.  |
| 3   | SASL_PLAINTEXT | Autentikasi tanpa menggunakan enkripsi           |
| 4   | SASL_SSL       | Autentikasi dengan menggunakan enkripsi SSL/TLS. |

Hal ini berarti apabila pada bagian listerner kita ubah menggunakan SSL atau SASL, maka data dipastikan terenkripsi dan terautensifikasi dengan baik dan tidak akan dapat disniff menggunakan wireshark.

Untuk SSl, kita membutuhkan certificate yang menunjukkan kalau sistem kita telah mendapatkan sebuah otoritas untuk melakukan sebuah hubungan dengan perangkat atau sistem yang lain, maka kita perlu membuat sebuah "legal formalnya", berikut penjelasan singkatnya:

Kita akan membuat sebuah dokumen resmi (certificate) untuk Zookeeper kepada clientya yakni Kafka broker, serta Kafka broker kepada clientnya yakni producer dan consumer apps dengan memberikannya sebuah tanda-tangan jaminan (certificate authority) menggunakan `openssl` untuk menunjukkan bahwa certificate dari zookeeper serta kafka brokernya otentik.

Sertifikat yang telah memiliki jaminan ini akan disimpan dengan aman dan digunakan oleh masing masing server untuk berkomunikasi dengan system atau client lainnya lewat pertukaran data yang terenkripsi, dengan demikian membuat satu sistem dengan sistem lainnya akan saling "percaya" karena memiliki bukti certificate otentik tadi.

**Note**
Lebih lanjut mengenai `openssl` dapat dilihat lewat `man openssl`

## 1. Mengaplikasikan Keamanan Untuk Zookeeper Quorum (Enkripsi dan Autentikasi)

### 1.1 Membuat Self Signing Certificate

Setidaknya yang saya pelajari dari self signing certificate terdapat beberapa istilah. Pertama itu `Certificate Authority (CA)` sebagai otoritas yang bisa berikan jaminan bahwa sebuah certificate itu memiliki "izin" atau tidak, kedua `Certificate Signing Request (CSR)` yakni dimana sebuah certificate meminta untuk ditanda-tangan atau diberi otentifikasi untuk mendapatkan ssl dari CA, ketiga `KeyStore` sebagai sebuah brankas atau tempat penyimpanan di mana kita meletakkan certificate yang kita telah percayai. certificates ini memberikan jaminan tentang identitas client atau bahkan server lain yang ingin kita hubungi secara aman. Dan terakhir `trustStore` yang dalam hal ini sebenarnya bekerja layaknya keystore. Simple nya kita bisa mengaggapnya, jika `keyStore` berisi private key sedangkan `trustStore` berisi public key.

#### Certificate Authority (CA) Menggunakan OpenSSl

Untuk mengamankan akses dari Zookeeper sebagai server terdahdap clientnya yakni kafka brokers, kita akan jalankan perintah berikut:

```bash
# Membuat private key Certificate Authority (CA)
openssl genpkey -algorithm RSA -out ca-key.pem

# Membuat pub key dari private key tersebut
openssl req -new -x509 -key ca-key.pem -out ca-cert.pem

```

Jadi, perintah ini menciptakan otoritas sertifikasi yang ditandatangani sendiri dengan nama "ca-cert.pem" yang merupakan generate dari file private key ("ca-key.pem"). Lalu sertifikat CA ("ca-cert.pem") akan digunakan untuk membuat keystore dan truststore. Sedangkan untuk memberikan tanda-tangan otentifikasi kepada certificate lainnya akan menggunakan keduanya baik `ca-key.pem` maupun ca-cert.pem.

Terdapat beberapa flag yang dapat digunakan seperti `-days 365` artinya cert CA berlaku 1 tahun, dapat juga menambahkan `-newkey rsa:4096` yakni menggunakan algoritma RSA sepanjang 4096 bit.

#### Membuat Certificate Zookeeper Untuk TrustStore

```bash

keytool -keystore zookeeper-truststore.jks -alias CARoot -import -file ca-cert.pem

```

Tool yang akan kita gunakan merupakan sebuah tool yang bernama `keytool` dalam JDK (Java Developement Kit). Untuk lebih lengkap kita dapat melihatnya di manual `man keytool`

Di dalam perintah tersebut kita melakukan import pub key CA (ca-cert.pem) kita ke dalam TrustStore dengan nama file `zookeeper-truststore.jks`

#### Membuat certificate zookeeper ke dalam keystore

berikut perintahnya:

```bash
keytool -genkey -keystore zookeeper-keystore.jks -keyalg RSA -alias zookeeper-server -validity 365 -ext SAN=dns:localhost

```

Terdapat beberapa hal penting yang perlu diperhatikan yang membedakan dengan perintah sebelumnya antara lain, nama filenya sekarang bernama `zookeeper-keystore.jks` dengan alias zookeeper, menggunakan validasi waktu 1 tahun, menggunakan juga RSA security dan terakhir `Subject Alternative Name atau SAN` dengan alamat dns yakni local machine.

Untuk melakukan verifikasi certificate yang baru saja kita buat dapat menggunakan command `keytool -list -v -keystore zookeeper-keystore.jks` di mana kita akan diminta memasukkan password KeyStore.

#### Membuat Certificate Signing Request (CSR)

```bash

keytool -certreq -keystore zookeeper-keystore.jks -alias zookeeper-server -file ca-request-zookeeper.csr

```

Perintah ini akan menghasilkan sebuah file CSR `ca-request-zookeeper.csr` yang berisi informasi tentang certificate server yang kita buat sebelumnya. Kita kemudian dapat mengirimkan CSR ini ke CA untuk mendapatkan certificate yang ditandatangani yang dapat digunakan dalam konfigurasi SSL/TLS berikutnya.

#### Mendapatkan CSR signed Lewat CA

```bash
openssl x509 -req -in ca-request-zookeeper.csr -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out ca-signed-zookeeper.pem -days 365

```

Perintah ini, yakni `openssl` digunakan oleh CA untuk menandatangani CSR yang dikirimkan oleh server atau entitas lain yang meminta certificate.

Kita dapat melakukan verifikasi certificate yang telah ditanda-tangan tersebut lewat perintah `keytool -printcert -v -file ca-signed-zookeeper.pem`
hasilnya sebagai berikut:

![signed-certs](https://github.com/adtyap26/learning-kafka/assets/101618848/1e1426bc-0334-4045-b821-377cefb1a69a)


#### Import CA certificate Ke dalam KeyStore

Kita perlu melakukan import CA certificate yang telah kita buat di awal dengan menggunakan `keytool` ke dalam KeyStore agar verifikasi sistem terjadi saat berkomunikasi melalui SSL/TLS.

```bash

keytool -keystore zookeeper-keystore.jks -alias CARoot -import -file ca-cert.pem

```

Inti dari command di atas adalah kita memastikan kalau `ca-cert.pem` atau pub key kita terdaftar ke dalam KeyStore.

#### Import signed certificate atau signed CSR to KeyStore

Certificate yang telah ditandatangani sebelumnya dengan nama file `ca-signed-zookeeper.pem` juga perlu dimasukkan ke dalam `KeyStore`

```bash

keytool -keystore zookeeper-keystore.jks -alias zookeeper-server -import -file ca-signed-zookeeper.pem

```

Sekarang kita ubah konfigurasi dari `zookeeper.properties`.

```bash

## Settings for ssl starts here
secureClientPort=2181
# java class implementation
authProvider.x509=org.apache.zookeeper.server.auth.X509AuthenticationProvider
serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory

# Lokasi penyimpanan certificate
ssl.trustStore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/zookeeper-truststore.jks
ssl.trustStore.password=latihan
ssl.keyStore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/zookeeper-keystore.jks
ssl.keyStore.password=latihan
ssl.clientAuth=need

## Settings for ssl ends here


```

Jika kita run atau restart service dari zookeeper dan tidak ada masalah, maka, servernya sudah berjalan dengan baik. Selanjutnya kita akan membuat konfigurasi untuk klient dari zookeeper seperti `zookeeper-shell` kita bisa membuat filenya bernama `zookeeper-client.properties`.

![zookeeper-server-ssl](https://github.com/adtyap26/learning-kafka/assets/101618848/25a8bdf1-b704-4da2-89b6-91b2032afe2d)

## 2. Mengaplikasikan Keamanan Untuk Zookeeper Client dan Melakukan Koneksi Dengan Menggunakan Enkripsi dan Autentikasi.

Untuk membuat zookeeper client (dalam hal ini contohnya `zookeeper-shell`) dapat berjalan dengan enkripsi ssl kita hanya perlu mengulang proses self signing certificate pada bagian pertama. Jadi saya akan menuliskannya sekaligus:

```bash
# Membuat zookeeper-client trustStore dan Import CA certificate ke dalamnya
keytool -keystore zookeeper-client.truststore.jks -alias CARoot -import -file ca-cert.perm

# Membuat zookeeper-client keystore
keytool -keystore zookeeper-client.keystore.jks -alias zookeeper-client -validity 365 -genkey -keyalg RSA -ext SAN=dns:localhost

# Membuat CSR untuk zookeeper-client
keytool -keystore zookeeper-client.keystore.jks -alias zookeeper-client -certreq -file ca-request-zookeeper-client.csr

# Tanda tangan CSR tersebut dengan menggunakan self signed CA
openssl x509 -req -CA ca-cert.pem -CAkey ca-key.pem -in ca-request-zookeeper-client.csr -out ca-signed-zookeeper-client.pem -days 365 -CAcreateserial

# Import certificate yang telah ditandatangani dan juga CA ke dalam keystore
keytool -keystore zookeeper-client.keystore.jks -alias CARoot -import -file ca-cert.pem

keytool -keystore zookeeper-client.keystore.jks -alias zookeeper-client -import -file ca-signed-zookeeper-client.pem

```

Setelah itu kita akan membuat `zookeeper-client.properties`

```bash

# Input Properties to be passed while connecting ZK clients such as zookeeper-shell.sh, kafka-configs.sh,
# kafka-acls.sh, etc. to ZK running in two-way SSL mode

zookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty
zookeeper.ssl.client.enable=true
zookeeper.ssl.protocol=TLSv1.2

zookeeper.ssl.truststore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/zookeeper-client.truststore.jks
zookeeper.ssl.truststore.password=latihan
zookeeper.ssl.keystore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/zookeeper-client.keystore.jks
zookeeper.ssl.keystore.password=latihan


```

Sekarang untuk melihat apakah secure connection yang telah kita buat berjalan di zookeeper-client dapat kita gunakan command berikut ` bin/zookeeper-shell.sh localhost:2181 -zk-tls-config-file config/zookeeper-client.properties`

Hasilnya seperti ini:

![zookeeper-client-ssl](https://github.com/adtyap26/learning-kafka/assets/101618848/9bc64e91-3723-4d86-977b-5d50e5bec50f)

## 3. Mengaplikasikan Keamanan Untuk Kafka Inter Broker

Untuk membuat security pada kafka inter broker yang artinya mengamankan server kafka. Baik saat dia berfungsi sebagai "client" terhadap zookeeper atau juga saat berfungsi sebagai "server" terhadap producer apps dan consumer apps.

### 3.1 Kafka-broker sebagai client dari Zookeeper

Cara yang dilakukan relatif mengulang dengan cara sebelumnya untuk mendapatkan SSL certificate. Tinggal untuk mempermudah kita hanya perlu memberikan nama certificate atau JKS yang berbeda.

```bash

# Membuat kafka-broker trustStore dan Import CA certificate ke dalamnya
keytool -keystore kafka.broker.truststore.jks -alias CARoot -import -file ca-cert.pem

# Membuat kafka-broker keystore
keytool -keystore kafka.broker.keystore.jks -alias kafka-broker -validity 365 -genkey -keyalg RSA -ext SAN=dns:localhost

# Membuat CSR untuk kafka-broker
keytool -keystore kafka.broker.keystore.jks -alias kafka-broker -certreq -file ca-request-kafka-broker.csr

# Tanda tangan CSR tersebut dengan menggunakan self signed CA
openssl x509 -req -CA ca-cert -CAkey ca-key -in ca-request-kafka-broker.csr -out ca-signed-kafka-broker.pem -days 365 -CAcreateserial

# Import certificate yang telah ditandatangani dan juga CA ke dalam keystore
keytool -keystore kafka.broker.keystore.jks -alias CARoot -import -file ca-cert.pem

keytool -keystore kafka.broker.keystore.jks -alias kafka-broker -import -file ca-signed-kafka-broker.pem

```

Sekarang kita perlu menambahkan juga SSL settings pada `server.properties`. Karena kafka-broker bertindak sebagai client terhadap zookeeper, maka bentuk configurasinya pun tidak berbeda dangan zookeeper client lainnya yang sebelumnya kita buat. Tinggal dipenambahan `zookeeper.set.acl=true` pada config tersebur. Access control lists (ACLs) merupakan salah satu fitur keamanan yang berfungsi seperti file permission di linux. Lebih jauh terkait hal ini akan kita bahas pada bagian akhir.

```bash

############################# SSL Configs Settings #############################
#### Kafka broker as client to zookeeper

zookeeper.ssl.client.enable=true
zookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty
zookeeper.ssl.protocol=TLSv1.2
zookeeper.ssl.keystore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/kafka.broker0.keystore.jks
zookeeper.ssl.keystore.password=latihan
zookeeper.ssl.truststore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/kafka.broker0.truststore.jks
zookeeper.ssl.truststore.password=latihan
zookeeper.set.acl=true


```

Untuk membuktikan configurasi yang kita buat berjalan kita akan running `kafka-server-start.sh -daemon config/server.properties`

![kafka-server-start-ssl](https://github.com/adtyap26/learning-kafka/assets/101618848/573a03a5-0cc3-45b5-b89d-4e4d92810fda)

![ls-broker0](https://github.com/adtyap26/learning-kafka/assets/101618848/7e24b54d-510a-4333-b366-0dca1db7c07c)

### 3.2 Kafka Broker Sebagai Server

Untuk membuat konfigurasi SSL di Kafka yang kali ini bertindak sebagai server maka saya akan mencoba dengan cara yang sedikit berbeda dari sebelumnya yang masih menggunakan `openssl` untuk membuat CA. Kali ini saya akan mengikuti tutorial dari buku Kafka: The Definitive Guide, 2nd Edition.

**Note**
Terdapat sebuah error yang cukup mengganggu yakni `NoAuth for /config/users/kafka-admin` yang belum secara pasti diketahui penyebabnya. Namun ketika saya menggunakan certificate authority yang sama dengan saat saya membuat keamanan zookeeper. Error ini pun hilang. Jadi intruksi bisa skip pembuatan CA key yang baru seperti di bawah ini jika terdapat error yang sama. Lebih jelas terkai error ini akan dibahas pada bagian 5 menjalankan ACL.

```bash

### Membuat CA key pair ###
# Membuat private key
keytool -genkeypair -keyalg RSA -keysize 2048 -keystore server.ca.p12 -storetype PKCS12 -storepass latihan -keypass latihan -alias ca -dname "CN=BrokerCA" -ext bc=ca:true -validity 365

# Membuat pub key dari private key
keytool -export -file server.ca.crt -keystore server.ca.p12 -storetype PKCS12 -storepass latihan -alias ca -rfc

```

Terdapat perbedaan pada flag `-ext` yang sebelumnya kita tentukan `SAN` atau Subject Alternative Name dimana jika kita melihat pada `man keytool` SAN dapat menggunakan beberapa type seperti EMAIL, URI, DNS, IP atau OID. Kali ini kita menggunakan extension yang lain yakni `BC` atau `BasicConstraints`, nah menurut yang saya baca dari manual dan beberapa forum online bc ini semacam type permission yang memberikan izin certificate yang kita buat ini dapat memberikan tanda-tangans sebagai CA (ca:true). Selain itu terdapat flag `-storetype PKCS12` merupakan java keystore format yang bisa digunakan untuk cross platform.

```bash
### Membuat keystore untuk brokers dengan certificate yang telah ditanda-tangan oleh CA.

# Membuat keystore untuk kafka broker dengan nama file `server.ks.p12`
keytool -genkey -keyalg RSA -keysize 2048 -keystore server.ks.p12 -storepass latihan -keypass latihan -alias server -storetype PKCS12 -dname "CN=localhost,O=Alldata,C=ID" -validity 365

# Membuat CSR
keytool -certreq -file server.csr -keystore server.ks.p12 -storetype PKCS12 -storepass latihan -keypass latihan -alias server

# menandatangani CSR tersebut dengan CA server

keytool -gencert -infile server.csr -outfile server.crt -keystore server.ca.p12 -storetype PKCS12 -storepass latihan -alias ca -ext SAN=DNS:localhost -validity 365

# Membuat serverchain yang berisi signed certificate `server.crt` dan pub key CA sebelumnya yaitu `server.ca.crt`

cat server.crt server.ca.crt > serverchain.crt

# Import serverchain tersebut ke dalam keystore

keytool -importcert -file serverchain.crt -keystore server.ks.p12 -storepass latihan -keypass latihan -alias server -storetype PKCS12 -noprompt

# Membuat trustStore untuk Komunikasi antar brokers agar masing-masing dari broker dapat berkomunikasi satu sama lain lewat secure connection

keytool -import -file server.ca.crt -keystore server.ts.p12 -storetype PKCS12 -storepass latihan -alias server -noprompt

# Begitu pun untuk setiap client dari broker, trustStore file clientnya perlu dibuat

keytool -import -file server.ca.crt -keystore client.ts.p12 -storetype PKCS12 -storepass latihan -alias ca -noprompt



```

Di dalam konfigurasi `server.properties` nya pun perlu kita tambahkan lokasi certificate:

```bash

#### Kafka broker as server to other broker and client
ssl.keystore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/kafka-broker/server.ks.p12
ssl.keystore.password=latihan
ssl.keystore.type=PKCS12
ssl.truststore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/kafka-broker/server.ts.p12
ssl.truststore.password=latihan
ssl.key.password=latihan
ssl.truststore.type=PKCS12
security.inter.broker.protocol=SSl
ssl.client.auth=required

```

Jika berhasil dijalankan lewat `bin/kafka-server-start.sh` maka hasilnya akan seperti ini:
![kafka-broker-ssl-start](https://github.com/adtyap26/learning-kafka/assets/101618848/d344fcfc-a6f2-47db-9d76-8348560ae13e)

## 4. Mengaplikasikan Keamanan Untuk Kafka Client

Sekarang kita telah masuk ke Kafka client, dalam hal ini producer dan consumer. Untuk membuat komunikasi yang aman antara producer/consumer sebagai client menuju Kafka broker sebagai server dengan menggunakan SSL, kita hanya perlu mengulang perintah seperti sebelumnya. Kita hanya akan mengganti beberapa hal seperti pembuatan CA khusus untuk client serta keystore serta truststore certificate masing-masing untuk producer dan clientnya. Akan tetapi untuk tujuan percobaan kita dapat menggunakan keystore dan truststore yang sama baik untuk producer dan consumernya.

Sebelumnya kita juga telah men-generate truststore file khusus untuk client yang bernama `client.ts.p12` dan telah tersimpan di dalamnya informasi mengenai broker CA yakni `server.ca.cert`. Maka, kita tidak perlu membuatnya lagi.

```bash
### Membuat CA untuk client
# Private key CA
keytool -genkeypair -keyalg RSA -keysize 2048 -keystore client.ca.p12 -storetype PKCS12 -storepass latihan -keypass latihan -alias ca -dname "CN=ClientCA" -ext bc=ca:true -validity 365
# Pub key CA
keytool -export -file client.ca.crt -keystore client.ca.p12 -storetype PKCS12 -storepass latihan -alias ca -rfc

# Keystore untuk client dengan nama `client.ks.p12`
keytool -genkey -keyalg RSA -keysize 2048 -keystore client.ks.p12 -storepass latihan -keypass latihan -alias client -storetype PKCS12 -dname "CN=localhost,O=Alldata,C=ID" -validity 365

# Membuat CSR untuk certificate client
keytool -certreq -file client.csr -keystore client.ks.p12 -storetype PKCS12 -storepass latihan -keypass latihan -alias client

# Membuat tanda-tangan file CSR tersebut dengan CA client
keytool -gencert -infile client.csr -outfile client.crt -keystore client.ca.p12 -storetype PKCS12 -storepass latihan -alias ca -ext SAN=DNS:localhost -validity 365

# Membuat clientchain yang berisi signed certificate `client.crt` dan pub key CA client yaitu `client.ca.crt`

cat client.crt client.ca.crt > clientchain.crt

# Import clientchain tersebut ke dalam keystore client

keytool -importcert -file clientchain.crt -keystore client.ks.p12 -storepass latihan -keypass latihan -alias client -storetype PKCS12 -noprompt

# Menambahkan CA client certificate ke dalam broker trustStore

keytool -import -file client.ca.crt -keystore server.ts.p12 -storetype PKCS12 -storepass latihan -alias client -noprompt

```

Kemudian karena producer berperan sebagai client, maka konfigurasi pun harus ditambah:

```bash

bootstrap.servers=localhost:9092,localhost:9093

ssl.keystore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/kafka-broker/client.ks.p12
ssl.keystore.password=latihan
ssl.keystore.type=PKCS12
ssl.truststore.location=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/certs/kafka-broker/client.ts.p12
ssl.truststore.password=latihan
ssl.key.password=latihan
ssl.truststore.type=PKCS12


```

Jika semuanya berjalan dengan lancar kita dapat memeriksa apakah ketika kita membuat sebuah topik dan membuat pesan dari topik tersebut wireshark masih dapat melakukan sniffing atau tidak.

berikut hasilnya jika config kita berhasil:
![securedataproduce](https://github.com/adtyap26/learning-kafka/assets/101618848/04efdd6b-d427-4518-a55d-04b344ebca60)

## 5. Menjalankan ACL (Access Control List)

Pada tahap ini, kita akan membahas dua komponen penting dalam pengamanan Apache Kafka: `SASL SCRAM` dan `Access Control List (ACL)`. Kedua komponen ini memiliki peran kunci dalam memastikan keamanan akses dan otentikasi di lingkungan Kafka.

### 5.1 SASL SCRAM (Simple Authentication and Security Layer Salted Challenge Response Authentication Mechanism)

SASL SCRAM adalah mekanisme otentikasi yang sangat aman yang digunakan dalam Kafka untuk memverifikasi identitas pengguna. Mekanisme ini memastikan bahwa pengguna yang mencoba terhubung ke broker Kafka adalah pengguna yang sah dan memiliki izin yang sesuai. SASL SCRAM menggunakan teknik salted challenge-response untuk mengamankan otentikasi.

Sebenarnya terdapat beberapa jenis SASL yang bisa dijalankan di kafka,antara lain:

| Jenis SASL         | Deskripsi Singkat                                                                                                                                                             |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SASL/PLAIN         | Mekanisme otentikasi yang sederhana menggunakan nama pengguna dan kata sandi. Sangat tidak disarankan untuk digunakan dalam produksi karena tidak aman.                       |
| SASL/SCRAM-SHA-256 | Mekanisme otentikasi yang aman dan direkomendasikan. Menggunakan teknik _salted challenge-response_ dengan algoritma hash SHA-256. Lebih aman dibandingkan dengan SASL/PLAIN. |
| SASL/SCRAM-SHA-512 | Varian dari SASL/SCRAM yang menggunakan algoritma hash SHA-512 untuk tingkat keamanan yang lebih tinggi. Sangat direkomendasikan untuk produksi jika tersedia.                |
| SASL/GSSAPI        | Menggunakan GSSAPI (Generic Security Services Application Program Interface) untuk otentikasi, biasanya digunakan dalam integrasi dengan Kerberos.                            |
| SASL/OAUTHBEARER   | Mekanisme otentikasi yang digunakan untuk mengintegrasikan Kafka dengan aliran otentikasi berbasis OAuth, seperti OAuth 2.0.                                                  |

Kali ini saya hanya akan mendokumentasikan hasil belajar saya menggunakan metode `SCRAM`, di lain waktu akan saya tambah metode lainnya. Dari apa yang saya pelajari SASL akan berguna untuk melakukan verifikasi autentikasi berikut:

Dalam konteks pembelajaran, untuk memulai pengaturan `SCRAM` ini kita tidak perlu repot membuat java class nya atau jika menggunakan bahasa pemograman lain, kita tidak perlu membuat program untuk mengimplementasikan SCRAM tersebut, karena kafka telah membuatnya mudah, kita cukup running beberapa command berikut:

```bash

# Membuat koneksi antar broker menggunakan SASL_SSL
bin/kafka-configs.sh --zookeeper localhost:2181 --zk-tls-config-file config/zookeeper-client.properties --alter --add-config 'SCRAM-SHA-256=[password=latihan]' --entity-type users --entity-name administrator

```

Karena inter-broker kafka merupakan client dari zookeeper, maka konfigurasi yang akan kita gunakan ialah `zookeeper-client.properties` yang telah kita buat sebelumnya.

Dan di dalam `server.properties` atau tempat konfigurasi broker kita tambahkan berikut ini:

```bash

listeners=SASL_SSL://host.name:port
security.inter.broker.protocol=SASL_SSL
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-256 (or SCRAM-SHA-512)
sasl.enabled.mechanisms=SCRAM-SHA-256 (or SCRAM-SHA-512)

listener.name.sasl_ssl.scram-sha-256.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
   username="administrator" \
   password="latihan";

```

Namun sepertinya terdapat kesalahan configurasi yang saya lakukan, atau kekeliruan yang saya belum bisa mengerti penyebabnya kenapa. Karena ketika saya running kafka brokernya terdapat error `org.apache.zookeeper.KeeperException$NoAuthException: KeeperErrorCode = NoAuth for /config/users/kafka-admin`

![error_kafkastart](https://github.com/adtyap26/learning-kafka/assets/101618848/76f1ac4f-66f6-4d08-9d08-30b901eb9c2f)

Dari pencarian ke dokumentasi resmi dan beberapa forum termasuk diskusi internal dengan teman, ada dua cara untuk menyelesaikannya. Pertama di dalam `zookeeper.properties` kita dapat menambahkan `skipACL=yes`. Keterangan dari hal ini masih belum sepenuhnya saya pahami. Apa yang sebenarnya terjadi di belakang layar ketika perintah tersebut dijalankan. Namun jika di lihat dari source code zookeepernya sendiri sepertinya perintah tersebut tidak akan melakukan proses checking terdapat ACL.

![source-code-skipacl](https://github.com/adtyap26/learning-kafka/assets/101618848/373d9ccb-674d-4087-a881-d5d856991ddd)



Hasinya ketika `kafka-server-start.sh`:

![kafka-start-after-skipacl](https://github.com/adtyap26/learning-kafka/assets/101618848/2250098e-9281-4802-9971-39dda6635f96)

Cara kedua sepertinya lebih rumit lagi, karena saya memang belum ada pengalaman melakukan konfigurasi berbasis env java. Dimana dalam cara kedua kita mencoba membuat super user dan memasukkannya langsung ke dalam zookeeper. Sehingga kita dapat melakukan perubahan lewat admin privileges. Berikut linknya [zookeeper doc](https://zookeeper.apache.org/doc/r3.5.3-beta/zookeeperAdmin.html#sc_authOptions) atau artikel di medium [Overcoming Zookeeper ACLs](https://medium.com/@johny.urgiles/overcoming-zookeeper-acls-1b205cfdc301).

Untuk membuat user client bagi producer dan consumer saya menggunakan command ini:

```bash
#Producer
bin/kafka-configs.sh --zookeeper localhost:2181 --zk-tls-config-file config/zookeeper-client.properties  \
--alter --add-config 'SCRAM-SHA-256=[password=latihan]' \
--entity-type users --entity-name producer-one

# Atau untuk client dari kafka-broker kita dapat gunakan `--bootstrap-server`
bin/kafka-configs.sh --bootstrap-server localhost:9092 --command-config config/producer.properties  \
--alter --add-config 'SCRAM-SHA-512=[password=latihan]' \
--entity-type users --entity-name producer-one


#consumer
bin/kafka-configs.sh --zookeeper localhost:2181 --zk-tls-config-file config/zookeeper-client.properties  \
--alter --add-config 'SCRAM-SHA-256=[password=latihan]' \
--entity-type users --entity-name consumer-one

```

Menurut dokumentasi di [doc confluent.id](https://docs.confluent.io/platform/current/kafka/authentication_sasl/authentication_sasl_scram.html#auth-sasl-scram-broker-config) jika ingin membuat broker yang saling mengautentifikasi diri masing-masing kita gunakan `--zookeeper` sebagai flagnya.

### 5.2 Access Control List (ACL)

ACL, atau daftar kontrol akses, adalah alat yang digunakan untuk mengatur dan mengelola hak akses pengguna ke topik dan partisi Kafka. Dengan ACL, kita dapat menentukan siapa yang memiliki izin untuk membaca, menulis, atau melakukan operasi lain di Kafka.

Dalam hal ini kita mesti memberikan izin kepada user untuk producer dan consumer untuk bisa menulis dan membaca isi dari topic.

Sebelumnya kita telah membuat beberapa user yang pertama sebagai admin atau pemegang `super.user` dengan nama administrator dan yang kedua user yang bertindak sebagai producer dan consumer dengan nama producer-one dan consumer-one. Untuk producer dan consumer akan kita batasi atau atur aksesnya. Di dalam internal standar java client untuk kafka terdapat perintah `kafka-acls.sh` yang mampu mengatur hak akses para user tersebut.

```bash
# Allow producer user to write message
bin/kafka-acls.sh --bootstrap-server localhost:9092 --command-config config/producer.properties --add --topic secureData --producer --allow-principal User:producer-one

# Allow consumer user to read message

bin/kafka-acls.sh --bootstrap-server localhost:9092 --command-config config/consumer.properties --add --resource-pattern-type PREFIXED --topic secureData --operation Read --allow-principal User:consumer-one


```

Hasil dari write dan read menggunakan `SASL_SSL`:

![write_read_SASL_SSL](https://github.com/adtyap26/learning-kafka/assets/101618848/6f3c3dd3-ba4b-4a66-838a-5b4dce39c689)



- Source

[Kafka: The Definitive Guide, 2nd Edition](https://www.oreilly.com/library/view/kafka-the-definitive/9781492043072/)
[Kafka Security Overview](https://kafka.apache.org/documentation/#security_overview)
[Data Engineering Mind Github](https://github.com/vinclv/data-engineering-minds-kafka/)
