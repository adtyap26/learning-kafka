# Dokumentasi Belajar Kafka

Dokumentasi ini berisi langkah-langkah yang saya pelajari saat belajar tentang Apache Kafka. Dalam dokumentasi ini seya menggunakan system operasi linux.

## 1. Deploy Kafka Cluster Menggunakan Systemd

### Langkah 1: Instalasi Apache Kafka

1.1. Unduh dan ekstrak distribusi Apache Kafka dari situs web resmi.
1.2. Mulai mengikuti langkah yang dijelaskan pada laman berikut [kafka quickstart](https://kafka.apache.org/quickstart)

1.2.1 Start zookeeper service
`bin/zookeeper-server-start.sh config/zookeeper.properties`
Pada bagian ini, zookeeper akan running di terminal, tentu hal ini akan tidak efisien karena jika terminal tersebut ditutup maka zookeeper servicenya pun berakhir.

-pic zookeeper without systemd-

- Untuk menyelesaikan masalah tersebut terdapat berbagai cara untuk membuat terminal yang sedang running sebuah process tadi tetap persistent atau bisa running sebagai background process, diantanya:

* Menggunakan systemd
* Menggunakan perintah `nohup` (melakukan bloking `SIGHUP` signal )
* Menggunakan `tmux` atau terminal multiplexer lainnya seperti `GNU Screen`

Pada dokumentasi ini kita akan menggunakan systemd sebagai init service untuk keseluruhan service di dalam binary kafka termasuk zookeepernya.

lakukan perintah berikut `sudo nvim /etc/systemd/system/zookeeper.service` atau biasanya saya langsung menggunakan `sudoedit` dimana `EDITOR` env sudah saya set untuk menggunakan `neovim`.

```
[Unit]
Description=Apache zookeeper
Documentation=https://zookeeper.apache.org/
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=simple
User=permaditya
ExecStart=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/bin/zookeeper-server-start.sh /home/permaditya/Apps/kafka/kafka_2.13-3.6.0/config/zookeeper.properties
ExecStop=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/bin/zookeeper-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target

```

Penjelasan singkat mengenai konfigurasi di atas:

- [Unit] mewakili opsi-opsi apa saja yang akan kita define atau jelaskan, dalam hal ini dengan sederhana kita menjelaskan deskripsi singkat mengenai servicenya. `Requires=network.target remote-fs.target` artinya zookeeper.service membutuhkan network.target untuk terlebih dulu diaktivasi sebelum servicenya dimulai.

- [Service] Di dalam service kita dapat jelas melihat bahwas service ini melakukan eksekusi file binary zookeeper dalam bentuk shell script.
  `Restart=on-abnormal` untuk memastikan bahwa servicenya akan melakukan restart secara otomatis apabila terjadi error(ditandai dengan non-zero exit status).

- [Install] pada bagian ini menjelaskan bagaimana service di install atau di enable. Serta memastikan dengan `WantedBy=multi-user.target` service akan enable atau berjalan saat reboot system (dengan GUI login).

Untuk penjelasan lebih lanjut bisa dilihat dengan perintah `man systemd`

1.2.2 Start the Kafka broker service

Selanjutnya untuk menjalankan kafka dengan perintah berikut `bin/kafka-server-start.sh config/server.properties`, sama seperti zookeeper tadi, kita mesti membuatnya running secara persistent dengan menggukanan systemd.

kita dapat membuatnya dengan perintah `sudoedit /etc/systemd/system/kafka.service`

Berikut isi dari filenya:

```

[Unit]
Description=Apache kafka
Documentation=https://kafka.apache.org/documentation/
Requires=zookeeper.service
After=zookeeper.service

[Service]
Type=simple
User=permaditya
ExecStart=/bin/sh -c '/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/bin/kafka-server-start.sh /home/permaditya/Apps/kafka/kafka_2.13-3.6.0/config/server.properties > /home/permaditya/Database/server/kafka/log/kafka.log 2>&1'
ExecStop=/home/permaditya/Apps/kafka/kafka_2.13-3.6.0/bin/kafka-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target

```

Perbedaan unit service ini dengan zookeeper.service, kafka.service memiliki requirement untuk berjalan setelah zookeeper.service berjalan. Selain itu juga menggunakan binary shell dengan argumen -c agar dapat running semua command selanjutnya dengan tanda '' dan jika terdapat error akan di redirect dengan stdout `2>&1` ke direktori yang sudah saya siapkan terlebih dahulu.

**Note** Pada bagian `server.properties` saya telah melakukan sedikit penyesuain dengan mengganti direktori untuk kafka logs.

Selanjutnya dengan perintah `sudo systemctl enable --now kafka.service`
` maka akan menjalankan dua service yang telah kita buat sebelumnya tanpa perlu khawatir service tersebut akan mati ketika terminal di tutup atau bahkan saat system reboot.

### Langkah 2: Verifikasi Kafka Cluster

2.1. Periksa status Kafka cluster dengan perintah `systemctl status kafka`.

-pic systemctl status kafka-

## 2. Buat Topic, Test Produce Data, dan Consume Data Menggunakan CLI

### Langkah 1: Buat Kafka Topic

1.1. Jika mengikuti tutorial kita hanya perlu melakukan perintah `bin/kafka-topics.sh --create --topic quickstart-events --bootstrap-server localhost:9092` isi dari shell script tersebut sebenarnya hanya sebagai wrapper dari sebuah lib yang dibuat dalam bahasa java di direktori yang berbeda. Pihak apache telah menghandle "all the heavy lifting" jadi kita tidak perlu lagi membuat aplikasi sebagai producer ataupun consumernya.

berikut isi dari command `kafka-topics.sh`

```bash

if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-Xmx512M"
fi
exec $(dirname $0)/kafka-run-class.sh kafka.tools.ConsoleProducer "$@"

```

bisa kita lihat script ini hanya mengeksekusi sebuah script lainnya yaitu `kafka-run-class.sh` yang terhubung ke library di didalam direktori lain (dalam hal ini `/lib/kafka-tools-3.6.0.jar`)

-pic kafkatool-

Beragam opsi lain dari command `kafka-topics.sh` dapat kita lakukan seperti menambah jumlah partisi, replikasi dan portnya dsb `~/Apps/kafka/kafka_2.13-3.6.0/bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic latest-topic`

1.2. Untuk melihat topic yang telah kita buat, kita dapat menggunakan perintah `bin/kafka-topics.sh --describe --topic quickstart-events --bootstrap-server localhost:9092`

-pic describe kafkatopic-

### Langkah 2: Produksi Data Ke dalam topic

2.1. Untuk memproduksi sebuah data atau event dari topic yang telah kita buat bisa gunakan perintah berikut `bin/kafka-console-producer.sh --topic quickstart-events --bootstrap-server localhost:9092`

Sekali lagi semua "heavy lifting" sudah dibuat oleh kafka, inti dari `kafka-console-producer.sh` hanya sebagai wrapper untuk mengeksekusi libray java.

Ketika kita running perintah tadi maka akan muncul teks yang bisa kita tulis sebagai sebuah pesan atau event yang akan disimpan oleh kafka

-pic event kafka-

**Note**

Saya juga baru menyadari, kalau kafka tidak punya web interface, ketika kita buka di localhost:9092 via browser. Tapi kita dapat melakukan inpeksi dengan `netcat` `nc -vz localhost 9092`. Munkin disinilah peran dari [confluent](https://www.confluent.io/)

-pic netstat-

### Langkah 3: Konsumsi Data

3.1. Untuk mengkonsumsi data apache pun telah menyediakan aplikasinya, dan kita hanya perlu running command `bin/kafka-console-consumer.sh --topic quickstart-events --from-beginning --bootstrap-server localhost:9092`

Mungkin tujuannya agar kita jadi lebih memahami bagaiman proses produce and consume lewat kafka terjadi dengan cara praktik secara langsung.

3.2. Verifikasi bahwa saya dapat melihat pesan yang telah saya produksi.

-pic produce and consume-

## 3. Lakukan Pengecekan ZooKeeper Quorum dan Kafka Cluster ID

### Langkah 1: Pengecekan ZooKeeper Quorum

1.1. Penjelasan terkait zookeeper quorum dari yang saya dapat sementara ini ialah angka minimum sebuah server yang dibutuhkan untuk running zookeeper itu sendiri.

Angka ini merupakan batas aman terkait jumlah server untuk menyimpan data klien.

Dari beragam sumber di internet terdapat rumus dasar seperti `Majority rule: QN = (N + 1) / 2` dimana QN merupakan batas minimal server di quorum sedang (N + 1) adalah total server yang kita punya (angka ganjil), semisal jika punya 7 server maka batas amannya kira-kita jika dibagi dua adalah 3.

1.2. Verifikasi bahwa ZooKeeper ensemble berjalan dengan benar dan memiliki quorum.

Untuk melakukan pengecekannya saya masih perlu waktu untuk belajar terkait hal ini namun saya menemukan perintah `./kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe --status` dimana jika dilihat dari situs doc kafka sepertinya hanya running untuk kRaft mode.

sebab, command tersebut saya jalankan hasilnya seperti ini.

### Langkah 2: Pengecekan Kafka Cluster ID

2.1. Untuk mengecek Cluster ID, yang saya lakukan adalah melihat log dengan file yang berisi `meta.properties`

-pic metaprop-

Dengan langkah-langkah ini, saya telah berhasil memahami dasar-dasar Apache Kafka, termasuk deploy Kafka cluster dan running lewat systemd, membuat topic, serta meng-produce dan meng-consume data. Selain itu, saya juga dapat memastikan keberhasilan cluster ZooKeeper dan mendapatkan informasi tentang Kafka cluster ID.
