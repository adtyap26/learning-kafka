# Dokumentasi Belajar Kafka

Dokumentasi ini berisi langkah-langkah yang saya pelajari saat belajar tentang Apache Kafka. Dalam dokumentasi ini saya menggunakan system operasi linux berbasis arch.

## 1. Deploy Kafka Cluster Menggunakan Systemd

### Langkah 1: Instalasi Apache Kafka

1.1. Unduh dan ekstrak distribusi Apache Kafka dari situs web resminya.
1.2. Mulai mengikuti langkah yang dijelaskan pada laman berikut [kafka quickstart](https://kafka.apache.org/quickstart)

1.2.1 Start zookeeper service
`bin/zookeeper-server-start.sh config/zookeeper.properties`
Pada bagian ini, zookeeper akan running di terminal, tentu hal ini akan tidak efisien karena ketika terminal tersebut ditutup maka zookeeper servicenya pun berakhir.

![zookeper_start_without_persistent](https://github.com/adtyap26/learning-kafka/assets/101618848/6e881640-33af-4469-bc97-3d4fdf67faed)

- Untuk menyelesaikan masalah tersebut terdapat berbagai cara untuk membuat terminal yang sedang running sebuah process tadi tetap persistent atau tetap running sebagai background process, diantaranya:

* Menggunakan linux systemd
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

- [Unit] mewakili opsi-opsi apa saja yang akan kita define atau jelaskan, dalam hal ini dengan sederhana kita menjelaskan deskripsi singkat mengenai servicenya. `Requires=network.target remote-fs.target` artinya zookeeper.service membutuhkan network.target untuk terlebih dulu diaktivasi sebelum servicenya dimulai. Semisal kita memiliki sebuah NFS (The Network Filesystem) server, hal ini berarti service zookeeper akan memastikan terlebih dahulu remote-fs.target berjalan atau mounting. Lebih lengkap lihat `man systemd.special`

- [Service] Di dalam service kita dapat jelas melihat bahwas service ini melakukan eksekusi file binary zookeeper dalam bentuk shell script.
  `Restart=on-abnormal` untuk memastikan bahwa servicenya akan melakukan restart secara otomatis apabila terjadi error(ditandai dengan non-zero exit status).

- [Install] pada bagian ini menjelaskan bagaimana service di install atau di enable. Serta memastikan dengan `WantedBy=multi-user.target` service akan enable atau berjalan saat reboot system (dengan GUI login).

Untuk penjelasan lebih lanjut bisa dilihat dengan perintah `man systemd`

1.2.2 Start the Kafka broker service

Selanjutnya untuk menjalankan kafka dengan perintah berikut `bin/kafka-server-start.sh config/server.properties`, sama seperti zookeeper tadi, kita mesti membuatnya running secara persistent dengan menggunakan systemd.

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

Perbedaan unit service ini dengan zookeeper.service, kafka.service memiliki requirement untuk berjalan setelah zookeeper.service berjalan. Selain itu juga menggunakan binary shell dengan argumen -c agar dapat running shell script yang lebih complicated seperti piping (|), && atau ||, bisa dilihat dicontoh jika terdapat error akan di redirect dengan stdout `2>&1` ke direktori yang sudah saya siapkan terlebih dahulu.

**Note** Pada bagian `server.properties` saya telah melakukan sedikit penyesuaian dengan mengganti direktori untuk kafka logs.

Selanjutnya dengan perintah `sudo systemctl enable --now kafka.service` maka akan menjalankan dua service sekaligus yang telah kita buat sebelumnya tanpa perlu khawatir service tersebut akan mati ketika terminal di tutup atau bahkan saat system reboot.

### Langkah 2: Verifikasi Kafka Cluster

2.1. Periksa status Kafka cluster dengan perintah `systemctl status kafka`.

![kafka_service_status](https://github.com/adtyap26/learning-kafka/assets/101618848/d40b11b1-e8b5-4eb0-9265-05756eaeeb54)

## 2. Buat Topic, Test Produce Data, dan Consume Data Menggunakan CLI

### Langkah 1: Buat Kafka Topic

1.1. Jika mengikuti tutorial kita hanya perlu melakukan perintah `bin/kafka-topics.sh --create --topic quickstart-events --bootstrap-server localhost:9092` isi dari shell script tersebut sebenarnya hanya sebagai wrapper dari sebuah lib yang dibuat dalam bahasa java di direktori yang berbeda. Pihak apache telah menghandle "all the heavy lifting" jadi kita tidak perlu lagi membuat aplikasi yang berfungsi sebagai producer ataupun consumernya.

berikut isi dari command `kafka-topics.sh`

```bash

if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-Xmx512M"
fi
exec $(dirname $0)/kafka-run-class.sh kafka.tools.ConsoleProducer "$@"

```

bisa kita lihat script ini hanya mengeksekusi sebuah script lainnya yaitu `kafka-run-class.sh` yang terhubung ke library di di dalam direktori lain (dalam hal ini `/lib/kafka-tools-3.6.0.jar`)

![kafka_tools](https://github.com/adtyap26/learning-kafka/assets/101618848/5a397249-b165-4ddf-b388-f8939b4b3fd4)

Beragam opsi lain dari command `kafka-topics.sh` dapat kita lakukan seperti menambah jumlah partisi, replikasi dan portnya dsb `~/Apps/kafka/kafka_2.13-3.6.0/bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic latest-topic`

1.2. Untuk melihat topic yang telah kita buat, kita dapat menggunakan perintah `bin/kafka-topics.sh --describe --topic quickstart-events --bootstrap-server localhost:9092`

![describe_topic](https://github.com/adtyap26/learning-kafka/assets/101618848/6c62db56-1be7-4d25-8567-8b4d7371ae4b)

### Langkah 2: Produksi Data Ke dalam topic

2.1. Untuk memproduksi sebuah data atau event dari topic yang telah kita buat bisa gunakan perintah berikut `bin/kafka-console-producer.sh --topic quickstart-events --bootstrap-server localhost:9092`

Sekali lagi semua "heavy lifting" sudah dibuat oleh kafka, inti dari `kafka-console-producer.sh` hanya sebagai wrapper untuk mengeksekusi library java.

Ketika kita running perintah tadi maka akan muncul teks yang bisa kita tulis sebagai sebuah pesan atau event yang akan disimpan oleh kafka.

![create_event](https://github.com/adtyap26/learning-kafka/assets/101618848/c9f4e3a6-dc04-4253-8186-59464fb81a1d)

**Note**

Saya juga baru menyadari, kalau kafka tidak punya web interface, ketika kita buka di localhost:9092 via browser. Tapi kita dapat melakukan inpeksi dengan `netcat` `nc -vz localhost 9092`. Mungkin disinilah peran dari [confluent](https://www.confluent.io/) seperti confluent platform yang akan memberikan GUI web interface (pembahasan ini akan saya buat dokumentasinya di week ke dua).

![netcat9092](https://github.com/adtyap26/learning-kafka/assets/101618848/242f4e20-e0d5-463f-b4bf-230e9bf12d90)

### Langkah 3: Konsumsi Data

3.1. Untuk mengkonsumsi data apache pun telah menyediakan aplikasinya, dan kita hanya perlu running command `bin/kafka-console-consumer.sh --topic quickstart-events --from-beginning --bootstrap-server localhost:9092`

Mungkin tujuannya agar kita jadi lebih memahami bagaimana proses produce and consume lewat kafka terjadi dengan cara praktik secara langsung tanpa perlu report membuat aplikasinya terlebih dahulu.

3.2. Verifikasi bahwa saya dapat melihat pesan yang telah saya produksi.

![produce_and_consume](https://github.com/adtyap26/learning-kafka/assets/101618848/bc8dd66b-9343-4717-8250-491ba6f2f6e8)

## 3. Lakukan Pengecekan ZooKeeper Quorum dan Kafka Cluster ID

### Langkah 1: Pengecekan ZooKeeper Quorum

1.1. Penjelasan terkait zookeeper quorum dari yang saya dapat sementara ini ialah angka minimum sebuah server yang dibutuhkan untuk running zookeeper itu sendiri.

Angka ini merupakan batas aman terkait jumlah server untuk menyimpan data klien.

Dari beragam sumber di internet terdapat rumus dasar seperti `Majority rule: QN = (N + 1) / 2` dimana QN merupakan batas minimal server di quorum sedang (N + 1) adalah total server yang kita punya (angka ganjil), semisal jika punya 7 server maka batas amannya kira-kita jika dibagi dua adalah 3.

1.2. Verifikasi bahwa ZooKeeper ensemble berjalan dengan benar dan memiliki quorum.

Untuk melakukan pengecekannya saya masih perlu waktu untuk belajar terkait hal ini namun saya menemukan perintah `./kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe --status` dimana jika dilihat dari situs doc kafka sepertinya hanya running untuk kRaft mode.

sebab, command tersebut saya jalankan hasilnya seperti ini:

![quorum_unssuport](https://github.com/adtyap26/learning-kafka/assets/101618848/6d9be63e-a24f-4881-a890-dd9170e9cb37)

### Langkah 2: Pengecekan Kafka Cluster ID

2.1. Untuk mengecek Cluster ID, yang saya lakukan adalah melihat log dengan file yang berisi `meta.properties`

![cat_metaprop](https://github.com/adtyap26/learning-kafka/assets/101618848/af42c026-a377-4a6b-bfd8-0e9cb45d5494)

Dengan langkah-langkah ini, saya telah berhasil memahami dasar-dasar Apache Kafka, termasuk deploy Kafka cluster dan running lewat systemd, membuat topic, serta meng-produce dan meng-consume data. Selain itu, saya juga dapat memastikan keberhasilan cluster ZooKeeper dan mendapatkan informasi tentang Kafka cluster ID.
