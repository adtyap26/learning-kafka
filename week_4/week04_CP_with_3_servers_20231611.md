# Confluent Platform Setup Dengan 3 Server

Pada minggu ini dokumentasi belajarnya akan membahas tentang bagaimana cara mengelola Confluent Platform (CP) menggunakan 3 server. Ketiga server ini berbasis virtual machine dengang menggunakan CentOS 8 sebagai sistem operasinya.

## Langkah 1 Pengamanan server

Sebelum memulai melakukan instalasi CP kita akan menyiapkan keamanan untuk ke tiga 3 vm ini terlebih dahulu. Terdapat beberapa langkah basic yang dapat kita lakukan seperti:

#### 1.1 Update system

Setelah login ke sistem untuk pertama kali dengan menggunakan akun root, langkah awal yang dapa kita gunakan ialah malakukan update pada sistem agar repositori yang kita gunakan dapat melakukan akses ke aplikasi yang baru sehingga mengurangi celah keamanan pada obsolete sistem. Sistem operasi yang kita gunakan merupakan RHEL based. Maka cara melakukan update sistemnya menggunakan `dnf update`, kita tentunya juga masih dapat menggunakan `yum update` walaupun sebenarnya yum atau The Yellowdog Updater Modified ini telah deprecated namun lewat berbagai alasan seperti faktor kebiasaan dan masih banyak sumber informasi mengenai RHEL based OS yang menyarankan penggunaan yum, maka yum masih exist, walaupun sebenarnya kalau kita lihat di `/usr/bin/yum` perintah ini hanyalah symbolic link ke perintah `dnf`.

![update_server_yum](https://github.com/adtyap26/learning-kafka/assets/101618848/f9884cf7-37e1-484a-9b1d-1642fd22da9f)



#### 1.2 Add user dan setup env

Membuat pengguna baru adalah praktik umum dalam administrasi sistem. Hal ini memungkinkan kita untuk mengendalikan akses ke server dengan lebih baik, mencegah penggunaan langsung sebagai root, serta memberikan hak sudo hanya kepada pengguna yang dibutuhkan untuk menjalankan perintah dengan hak istimewa (The principle of least privilege (PoLP)).

##### 1.2.1 Perintah `adduser` `passwd` dan `visudo`

Kita menggunakan perintah `adduser` untuk lebih mudah karena terdapat fitur interaksi di dalamnya, opsi lain perintah bisa menggunakan `useradd`.

`adduser aditya` dan `passwd aditya` ikuti perintahnya seperti memasukkan password untuk user tersebut.

`visudo` adalah perintah yang digunakan untuk mengedit file konfigurasi sudoers dengan menggunakan editor teks yang ditentukan oleh env `EDITOR`, pilihannya vim, nano atau hhmm.. emacs(seriously!?). I am a vim fanboy, so..

File sudoers berisi aturan yang menentukan siapa yang memiliki izin untuk menjalankan perintah dengan hak istimewa sudo.

di bawah baris yang berisi `root ALL=(ALL) ALL` kita dapat tambahkan `aditya ALl=(ALL) ALL`.

#### 1.3 Konfigurasi dasar SSH

Pada local machine kita dapat membuat ssh key-pair dengan perintah `ssh-keygen -t rsa -b 2048 -f ~/.ssh/nama_vm` lalu kita dapat melakukan ini untuk copy pub-key kita ke server `ssh-copy-id -i ~/.ssh/nama_vm.pub user@ip-or-hostname`. Lalu jalankan perintah berikut:

`cat ~/.ssh/nama_vm.pub | ssh user@ip_or_hostname 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'` Tujuan perintah ini ialah kita membuat direktori .ssh di dalam `$HOME` user dan memasukkan pub key kita ke authorized_keys file di dalam server atau vm tersebut.

Karena selanjutnya kita akan setup server/vm dengan aturan hanya user yang memiliki pub-key di dalam authorized_keys yang diijinkan masuk.

Ubah konfigurasi pada SSH server:

`sudo vim /etc/ssh/sshd_config`

```bash


PermitRootLogin no: Nonaktifkan login langsung sebagai root.
PasswordAuthentication no: Matikan otentikasi kata sandi dan gunakan pub-key SSH.
PubkeyAuthentication yes: Hanya user yang memiliki pub-key yang dapat masuk ke server.

```

Lalu restart `sudo systemctl restart sshd`

Terdapat langkah optional selanjutnya seperti menyiapkan aplikasi, tools atau env seperti apa yang akan kita gunakan di dalam server. Hal ini tentu kembali ke user masing-masing yang memiliki workflow berbeda. Untuk saya beberapa aplikasi yang wajib di install tentunya neovim dengan konfigurasi personal serta beberap tool seperti htop dan fzf (terdapat aplikasi tambahan seperti tmux yang sangat berguna untuk handle server, akan tetapi tidak perlu kita install di server melainkan cukup di local machine). Serta tidak lupa mengatur `.bashrc` sesuai kebutuhan.

## Langkah 2 Instal CP

Di dalam minggu sebelumnya [week 3 Learn Confluent Platform](https://github.com/adtyap26/learning-kafka/blob/main/week_3/week03-learn_confluent_platform_20232010.md) kita sudah bahas cara install CP menggunakan zip atau tar. Saat ini kita akan menginstall menggunakan metode lain yakni package manager bawaan dari sistem operasi yang kita pakai.

Pertama kita pastikan bahwa kita memiliki aplikasi seperti `curl` dan `which` yang biasanya sudah terinstall di dalam sistem.
lalu kita tambahkan CP pub-key ke dalam repositori:

`sudo rpm --import https://packages.confluent.io/rpm/7.5/archive.key`

Setelah itu masuk ke dalam direktori `/etc/yum.repos.d/` untuk membuat file `confluent.repo` dan masukkan isi berikut kedalamnya:

```bash

[Confluent]
name=Confluent repository
baseurl=https://packages.confluent.io/rpm/7.5
gpgcheck=1
gpgkey=https://packages.confluent.io/rpm/7.5/archive.key
enabled=1

[Confluent-Clients]
name=Confluent Clients repository
baseurl=https://packages.confluent.io/clients/rpm/centos/$releasever/$basearch
gpgcheck=1
gpgkey=https://packages.confluent.io/clients/rpm/archive.key
enabled=1

```

Selanjutnya kita akan dapat menginstallnya menggunakan package manager `sudo dnf clean all && sudo dnf install confluent-platform`.

Karena kita memiliki 3 server maka hal di atas akan kita ulang prosesnya untuk server yang lain.

## Langkah 3 Konfigurasi CP

Tujuan dari dokumentasi belajar menggunakan CP ke dalam 3 server/vm ini adalah untuk membuat setup sederhana CP dimana kita akan membuat 3 zookeeper server, satu di masing-masing vm, sebuah kafka cluster yang berisi 3 broker yang juga satu di install di masing-masing vm, menggukanan keamanan SSL/TLL untuk enkripsi datanya dan SASL-SCRAM untuk autentifikasinya. Sedang service lainnya seperti producer, consumer, ksqldb, kafka connect serta control-senternya hanya diperlukan di dalam salah satu dari ketiga server tadi. Setiap service pun kita akan setup menggunakan system seperti pada week pertama.

#### 3.1 Konfigurasi Untuk Setiap Service

Beberapa hal perlu disetup untuk zookeeper dapat running pada ke tiga vm ini, berikut langkahnya:

Konfigurasi dapat dilakukan dengan menggunakan IP based atau host based dimana jika host based maka kita perlu setup `/etc/hosts` agar ip kita dapat resolvable. Seperti contoh berikut:

```
sudo vim /etc/hosts

<VM-IP-Address>    <Hostname>
192.168.1.100    server1
192.168.1.101    server2
192.168.1.102    server3

```

Namun, yang saya gunakan adalah IP based. Jadi saya hardcoded setiap file yang membutuhkan alamat ip vm. Seperti misalnya kita perlu setup `/etc/kafka/zookeeper.properties` file seperti berikut ini:

```

tickTime=2000
dataDir=/var/lib/zookeeper/
clientPort=2181
initLimit=5
syncLimit=2
server.1=ip-address:2888:3888
server.2=ip-address:2888:3888
server.3=ip-address:2888:3888
autopurge.snapRetainCount=3
autopurge.purgeInterval=24


format untuk konfigurasi ip-address zookeeper:

server.<myid>=<hostname>:<leaderport>:<electionport>

```

Karena kita setup menggunakan keamanan SSL dan SASL maka ada beberapa langkah yang mesti kita lakukan:

1. Membuat SSL certificate, caranya bisa kita lihat pada [week 2 securing kafka](https://github.com/adtyap26/learning-kafka/blob/main/week_2/week02-securing_overview_kafka_basic_20232410.md) dan untuk mempermudahnya bisa gunakan shell script untuk generate server dan client certificate di repositori ini.

**NOTE** Pengunaan SAN (Subject Alternative Name) di dalam pembuatan script sangat berpengaruh dan kebutuhannya dapat disesuaikan dengan server masing-masing. Pastikan certificate menggunakan SAN baik berbasis IP ataupun host.

2. Setelah menambahkan file configurasi SSL/TLS di seluruh `zookeeper.properties` di setiap vm, kita juga membuat file properti untuk client dari zookeeper sebut saja `zk-client.properties` dan kita masukan juga konfigurasi SSLnya disana, tidak lupa juga kita tambahkan file konfigurasi SSL untuk `server.properties` sebagai client dari zookeeper juga.

3. Untuk SASL SCRAM, untuk mempermudah proses kita hanya akan membuat 1 super user bernama admin, yang bisa kita gunakan berulang untuk setup properti di config yang lain. perintahnya sebagai berikut

`sudo /bin/kafka-configs --zookeeper your-ip-hostname:2182 --zk-tls-config-file /etc/kafka/zk-client.properties \
--alter --add-config 'SCRAM-SHA-512=[password=yourpassword]' \
--entity-type users --entity-name admin`

Maka konfigurasi dari zookeeper dan kafka brokernya akan seperti ini:

`zookeeper.properties`

```
## zookeeper.properties

## Settings for ssl starts here
secureClientPort=2182
# java class implementation
authProvider.x509=org.apache.zookeeper.server.auth.X509AuthenticationProvider
serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory

# Lokasi penyimpanan certificate
ssl.trustStore.location=/path/to/trustStore/
ssl.trustStore.password=yourpassword
ssl.truststore.type=PKCS12
ssl.keyStore.location=/path/to/keyStore
ssl.keyStore.password=yourpassword
ssl.clientAuth=need
ssl.key.password=yourpassword
ssl.keystore.type=PKCS12

# server.properties


```

`server.properties`

```

listeners=SASL_SSL://0.0.0.0:9092

# Listener name, hostname and port the broker will advertise to clients.
# If not set, it uses the value for "listeners".
advertised.listeners=SASL_SSL://your-ip-hostname:9092


zookeeper.connect=your-ip-hostname:2182



############################# SSL Configs Settings #############################
#### Kafka broker as client to zookeeper

# Properties for SSL Zookeeper Security between Zookeeper and Broker

zookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty
zookeeper.ssl.client.enable=true
zookeeper.ssl.protocol=TLSv1.2

zookeeper.ssl.truststore.location=path/to/zk-server/kafka-client-1/client.ts.p12
zookeeper.ssl.truststore.password=yourpassword
ssl.truststore.type=PKCS12
zookeeper.ssl.keystore.location=path/to/zk-server/kafka-client-1/client.ks.p12
zookeeper.ssl.keystore.password=yourpassword
ssl.key.password=yourpassword
ssl.keystore.type=PKCS12
zookeeper.set.acl=true


#### Kafka broker as server to other broker and client
ssl.truststore.location=path/to/kafka-server/server.ts.p12
ssl.truststore.password=yourpassword
ssl.truststore.type=PKCS12
ssl.keystore.location=path/to/kafka-server/server.ks.p12
ssl.keystore.type=PKCS12
ssl.keystore.password=yourpassword
ssl.key.password=yourpassword
security.inter.broker.protocol=SASL_SSL
# security.inter.broker.protocol=SSL
ssl.client.auth=none
ssl.protocol=TLSv1.2

# ssl.endpoint.identification.algorithm= ## only use this if you SAN (Subject Alternative Name) is not preconfigured

### SASL_SSL configuration between kafka to other broker and client

# List of enabled mechanisms, can be more than one
sasl.enabled.mechanisms=SCRAM-SHA-512

# Specify one of of the SASL mechanisms
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512

listener.name.sasl_ssl.scram-sha-512.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="yourpassword";
super.users=User:admin
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
allow.everyone.if.no.acl.found=true

# Use for metrics

##################### Confluent Metrics Reporter #######################
# Confluent Control Center and Confluent Auto Data Balancer integration
#
# Uncomment the following lines to publish monitoring data for
# Confluent Control Center and Confluent Auto Data Balancer
# If you are using a dedicated metrics cluster, also adjust the settings
# to point to your metrics kakfa cluster.
metric.reporters=io.confluent.metrics.reporter.ConfluentMetricsReporter
confluent.metrics.reporter.bootstrap.servers=your-ip-hostname:9092,your-ip-hostname:9092,your-ip-hostname:9092
#
# Uncomment the following line if the metrics cluster has a single broker
confluent.metrics.reporter.topic.replicas=3
confluent.metrics.reporter.security.protocol=SASL_SSL
confluent.metrics.reporter.ssl.keystore.location=path/to/kafka-server/metrics/client.ks.p12
confluent.metrics.reporter.ssl.keystore.password=latihan
confluent.metrics.reporter.ssl.truststore.location=path/to/kafka-server/metrics/client.ts.p12
# confluent.metrics.reporter.ssl.endpoint.identification.algorithm=
# confluent.metrics.reporter.ssl.client.auth=required
confluent.metrics.reporter.ssl.truststore.password=latihan
confluent.metrics.reporter.ssl.key.password=latihan

confluent.metrics.reporter.sasl.mechanism=SCRAM-SHA-512
confluent.metrics.reporter.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="yourpassword";


```

Kita juga menerapkan seluruh konfigurasi dengan pola yang relatif hampir sama untuk service lainnya sesuai kebutuhan untuk: `connect-distributed.properties`, `control-center.properties` `kafka-rest-properties` `schema-registry.properties` `ksql-server.properties`.

Mungkin diantarnya akan ada sedikit perbedaan, namun pada dasarnya sama, kita hanya perlu menambahkan configurasi SSL/TLS dan SASL yang telah kita buat dan pastikan setiap service saling terhubung via zookeeper connect atau bootstrap-server.

Lebih jelasnya untuk melihat file-file tersebut saya telah meng-upload semua filenya.

#### 3.2 Konfigurasi systemd

Untuk konfigurasi systemd pun tidak jauh berbeda dengan [week 01 Kafka dasar](https://github.com/adtyap26/learning-kafka/blob/main/week_1/week01-learn_doc_kafka_20231710.md) dan keseluruhan file yang telah dibutuhkan pun telah saya upload.

Pada intinya keseluruhan service yang perlu running untuk membuat control-center dapa berjalan dengan minimal setup adalah sebagai berikut:

![list-systemd](https://github.com/adtyap26/learning-kafka/assets/101618848/303984f0-e82a-4c66-94ed-8808366ad54b)


Karena akan cukup merepotkan untuk untuk terus mengulang perintah dalam `systemctl` saya menggunakan beberapa cara antara lain:

1. Menggunakan [sysz](https://github.com/joehillen/sysz/blob/master/sysz), dengan sysz kita dapat mudah melihat status dari setiap service lewat bantun fzf atau fuzzy finder.

2. Menggunakan alias. Perintah systemctl cukup panjang, dengan alias kita dapat mempersingkatnya

![alias-systemctl](https://github.com/adtyap26/learning-kafka/assets/101618848/46c4302d-0d91-4858-a320-98b4da6aa1a8)


3. Membuat shell script untuk auto start dan auto stop keseluruhan service CP

Untuk start service:

```bash

#!/bin/bash

services=(
    "confluent-zookeeper.service"
    "confluent-server.service"
    "confluent-schema-registry.service"
    "confluent-ksqldb.service"
    "confluent-kafka-rest.service"
    "confluent-kafka-connect.service"
    "confluent-control-center.service"
)

for service in "${services[@]}"; do
    echo "Starting $service now..."
    sudo systemctl start "$service"
    if [ $? -eq 0 ]; then
        echo "$service started  "
    else
        echo "Failed to start $service"
    fi
done

```

Service stop

```bash

#!/bin/bash

services=(
    "confluent-control-center.service"
    "confluent-schema-registry.service"
    "confluent-ksqldb.service"
    "confluent-kafka-rest.service"
    "confluent-kafka-connect.service"
    "confluent-server.service"
    "confluent-zookeeper.service"
)

for service in "${services[@]}"; do
    echo "Stopping $service now..."
    sudo systemctl stop "$service"
    if [ $? -eq 0 ]; then
        echo "$service stopped  "
    else
        echo "Failed to stop $service"
    fi
done


```

## Langkah 4 Menajalankan CP

Jika seluruh service telah menggunakan SASL, terenkripsi SSL/TLS dan telah menggunakan systemd maka kita hanya perlu memulai seluruh system service tersebut. Kita akan gunakan script yang telah dibuat sebelumnya:




https://github.com/adtyap26/learning-kafka/assets/101618848/15c5a3fe-35a3-4bda-a086-c10d42a22537




Selanjutnya kita dapat mengikuti tutorial dalam minggu sebelumnya untuk running confluent control-center.



![running_topics](https://github.com/adtyap26/learning-kafka/assets/101618848/05e4835d-e606-49eb-a5ce-e1ec349b3674)







