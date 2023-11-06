# Dokumentasi Belajar Confluent Platform

- Source:

* [Confluent Platform](https://docs.confluent.io/platform/current/platform-quickstart.html)

## Langkah 1: Instalasi

1.1 Instalasi di Lokal

Terdapat beberapa cara yang dapat digunakan untuk mengunduh confluent platform:

1. [Download dan install menggunakan ZIP atau TAR](https://docs.confluent.io/platform/current/installation/installing_cp/zip-tar.html#prod-kafka-cli-install)
2. [Lewat docker dengan opsi masih menggunakan ZooKeeper](https://github.com/confluentinc/cp-all-in-one/blob/7.5.1-post/cp-all-in-one/docker-compose.yml)
3. [Lewat docker tanpa ZooKeeper](https://raw.githubusercontent.com/confluentinc/cp-all-in-one/7.5.1-post/cp-all-in-one-kraft/docker-compose.yml)
4. [Lewat linux package manager](https://docs.confluent.io/platform/current/installation/installing_cp/deb-ubuntu.html)

5. [Via Ansible](https://docs.confluent.io/ansible/current/ansible-download.html)

6. [Via Kubernetes](https://docs.confluent.io/operator/current/overview.html)

Dalam dokumentasi belajar kali ini saya hanya akan mencoba pilihan nomor satu untuk menginstal confluent platform, yakni dengan menggunakan via ZIP atau TAR file dikarenakan linux distribution yang saya gunakan saat ini merupakan arch based dan secara resmi confluent tidak membuat repository resmi untuk arch based system. Walaupun bisa saja saya menggunakan AUR repository [confluent platform](https://aur.archlinux.org/packages/confluent-platform)namun saya tidak tahu dan yakin apakah repository tersebut masih di-manage oleh user yang membuatnya. Maka opsi pertama lebih aman karena akan mendapatkan versi terbaru.

Setelah saya mengunduh dan mengekstrak file tersebut, saya simpan di direktori tempat saya biasa menyimpan aplikasi yang saya install manual di `~/Apps/` dan di dalam `PATH` sudah saya lakukan penyesuaian di `.zshrc` menjadi:

```bash

## Confluent
export CONFLUENT_HOME=/home/permaditya/Apps/confluent-platform/confluent-7.5.1/
export JAVA_HOME=/home/permaditya/.sdkman/candidates/java/11.0.21-amzn/

```

Jadi binary file dapat lebih mudah untuk dieksekusi. Perintah eksekusinya pun cukup mudah yakni hanya dengan `confluent local services start` maka semua servicenya pun akan jalan:

![confluent-local-service-start](https://github.com/adtyap26/learning-kafka/assets/101618848/b0eb1ec6-da7d-48fa-8d68-13b1f8b91c39)

**Note**
Disaat dokumentasi ini ditulis terdapat minor update pada aplikasi confluent setelah menjalan `confluent update`

```bash

Bug Fixes
---------
- In on-premises `confluent kafka topic produce`, the `--ca-location` flag is no longer required

```

## Langkah 2 membuat Kafka Client

2.1 Membuat Kafka client untuk produce dan consume data menggunakan avro schema

Perbedaan mendasar menggunakan confluent platform dibanding native kafka ialah terdapatnya `Confluent Control Center` sebuah GUI-based web app yang memudahkan kita untuk mengatur kafka. Hal ini sama dengan ketika kita memiliki sebuah webserver, terdapat pilihan untuk menjalankannya lewat command line atau menggunakan control panel.

kita dapat melihatnya di `http://localhost:9021/clusters`

![control-center](https://github.com/adtyap26/learning-kafka/assets/101618848/1597c1e1-9c55-46c4-8d1e-723d0a735c52)



2.1.1 Membuat Topic pada control-center

Di dalam tutorial, kita diminta untuk membuat dua topik yakni `pageviews` dan `users`. Namun saya akan mencoba membuat topic dengan nama yang berbeda, karena ternyata dalam tutorialnya sudah dibuat mockup data yang dapat di'generate' secara otomatis, berikut sumbernya [kafka-connect-datagen](https://github.com/confluentinc/kafka-connect-datagen#configuration). Di dalam salah satu konfigurasinya terdapat sebuah namespace `gaming` yang terdiri dari `gaming_games.avro` `gaming_player_activity.avro` dan `gaming_player.avro`.

Maka saya akan mencoba membuat dua topic yakni, `gaminggames` dan `gamingplayers`.

Hal yang perlu dilakukan pertama ialah cukup membuka `controlcenter.cluster` >> `Topics` >> `Add a topic` kemudian isi topic name dengan `gaminggames` sebagai topic pertama dan `gamingplayers` sebagai topic keduanya.

![createtopic_gaminggames](https://github.com/adtyap26/learning-kafka/assets/101618848/67ae742d-46a0-4c1e-8c61-cc8b460a0f79)
![createtopic_gamingpalyers](https://github.com/adtyap26/learning-kafka/assets/101618848/07d52cad-26e0-4a0a-9719-a3b900840e7c)



## Langkah 3 membuat connector dengan kafka connect

3.1 Melakukan generate mockup data

Jika dilihat dari penjelasannya kafka connect yakni:

> Kafka Connect can ingest entire databases or collect metrics from all your application servers into Kafka topics, making the data available for stream processing with low latency.

Kita dapat dengan mudah mengkoneksikan kafka dengan beragam aplikasi yang memiliki sebuah data, database atau metrics di dalamnya. Keuntungan dari kafkafka connect ini tentu saja selain untuk mempermudah abstraksi sebuah data dari sebuah aplikasi namun juga ada fleksibilitas, skalabilitas, dapat digunakan berkali-kali dan tentunya sangat extensible digunakan sesuai kebutuhan.

Di dalam control-centernya pun mudah untuk digunakan hanya dengan:

`klik connect >> connect-default >> add connector >> DatagenConnector `

Setelah itu kita akan coba ikuti set configurasi dari tutorialnya dengan tentunya menyesusaikan topic yang telah kita buat sebelumnya

```
Enter the following configuration values in the following sections:

Common section:

    Key converter class: org.apache.kafka.connect.storage.StringConverter.

General section:

    kafka.topic: gaminggames. You can choose this from the dropdown.
    max.interval: 100.
    quickstart: gaming_games (Jika kita salah melakukan konfig ini akan muncul pilihan dari default config seperti apa, jadi tinggal menyesusaikan saja)


```

Maka kita dapat melihat schema yang dibuat oleh connector tersebut:

![schemma_add_connector](https://github.com/adtyap26/learning-kafka/assets/101618848/792e8c18-3b06-4b95-832e-434bb98cf4df)


Langkah selanjutnya kita buat juga kafka connect untuk `gamingplayers`. Secara umum konfigurasinya sama tinggal di quickstartnya saja kita ganti dengan `gaming_players`

![addconnector_gaminggames](https://github.com/adtyap26/learning-kafka/assets/101618848/0c391b52-8f1c-4801-aba5-f36d22ab0b01)


Lalu jika kita lihat di `Topics >> gamingplayers >> Messages` maka kita akan melihat ada produksi event data yang masuk seperti gambar berikut:


![message_topic_gamingplayers](https://github.com/adtyap26/learning-kafka/assets/101618848/cef31992-2cce-4aab-98ea-3da31742b2f8)



Namun hubungan koneksi di atas masih menggunakan unsecure connection. Kalau kita lihat di dokumentasi resminya ada beberapa service yang bisa kita optimalkan keamanannya:

| Component                | Test      |
| ------------------------ | --------- |
| Confluent Control Center | HTTPS     |
| Kafka Connect            | None      |
| Kafka                    | SASL, SSL |
| Rest Proxy               | HTTPS     |
| Schema Registry          | HTTPS     |
| ZooKeeper                | SASL      |

Untuk itu kita akan setup keamanannya menggunakan SASL_SSL, sebagaimana yang telah kita pelajari sebelumnya di [dokumentasi kafka security basic week 2](https://github.com/adtyap26/learning-kafka/tree/main/week_2).

Setelah kita membuat certificate yang dibutuhkan: `zookeeper` dan `kafka` termasuk klien dari kafka seperti producer dan consumer, serta kita juga meski mengamankan `schema registry`, `ksqlDB` dan `control center`.

 
![local-service-SSl](https://github.com/adtyap26/learning-kafka/assets/101618848/fe1bf881-d26c-4828-841c-3f13ea4ceb2b)



4.1 Membuat Kafka Client Untuk Produce dan Consume Data Menggunakan Avro Schema

4.1 Memproduksi Data Menggunakan Kafka REST

5.1 Membuat Sebuah Stream Proses Menggunakan ksqlDB
