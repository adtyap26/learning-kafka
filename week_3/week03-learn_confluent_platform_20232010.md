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

Untuk membuat client yang dapat produce dan consume data dan menampilkannya di `controlcenter` maka kita hanya perlu mengikut tutorial di dokumentasi resminya [On-Premises Schema Registry Tutorial](https://docs.confluent.io/platform/current/schema-registry/schema_registry_onprem_tutorial.html#). Namun karena tutorial tersebut menggunakan java sebagai client producer dan consumernya, sedang kemampuan bahasa pemograman java saya nyaris menyentuh angka 0 maka saya putuskan untuk mencoba membuat client nya di bahasa yang saya sedikit lebih mengerti yaitu Go.

Setelah mencari contoh dari penggunaan client go untuk kasus spesifik yang dicontohkan dalam tutorial saya menemukan satu contoh code yang mudah dibaca dan dipahami [Avro Usage Examples](https://github.com/riferrei/srclient/blob/master/EXAMPLES_AVRO.md).

Dari contoh yang ada dalam github tersebut saya memodifikasinya menjadi seperti ini:

```go

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/riferrei/srclient"
	"gopkg.in/confluentinc/confluent-kafka-go.v1/kafka"
)

type Payment struct {
	ID     string  `json:"id"`
	Amount float64 `json:"amount"`
}

func main() {
	topic := "transactions"

	// 1) Create the producer as you would normally do using Confluent's Go client
	p, err := kafka.NewProducer(&kafka.ConfigMap{"bootstrap.servers": "localhost"})
	if err != nil {
		panic(err)
	}
	defer p.Close()

	go func() {
		for event := range p.Events() {
			switch ev := event.(type) {
			case *kafka.Message:
				message := ev
				if ev.TopicPartition.Error != nil {
					fmt.Printf("Error delivering the message '%s'\n", message.Key)
				} else {
					fmt.Printf("Message '%s' delivered successfully!\n", message.Key)
				}
			}
		}
	}()

	// 2) Fetch the latest version of the schema, or create a new one if it is the first
	schemaRegistryClient := srclient.CreateSchemaRegistryClient("http://localhost:8081")
	schema, err := schemaRegistryClient.GetLatestSchema(topic)
	if schema == nil {
		schemaBytes, _ := os.ReadFile("Payment.avsc")
		schema, err = schemaRegistryClient.CreateSchema(topic, string(schemaBytes), srclient.Avro)
		if err != nil {
			panic(fmt.Sprintf("Error creating the schema %s", err))
		}
	}
	schemaIDBytes := make([]byte, 4)
	binary.BigEndian.PutUint32(schemaIDBytes, uint32(schema.ID()))

	// 3) Serialize the record using the schema provided by the client,
	// making sure to include the schema id as part of the record.
	// newPayment := Payment{ID: "231", Amount: 50.00} # You can do hardcode like this or loop like the ones below.

	for i := 0; i < 5; i++ { // Adjust the loop as needed
		newPayment := Payment{ID: fmt.Sprintf("%d", i+1), Amount: float64((i + 1) * 10)}
		value, _ := json.Marshal(newPayment)
		native, _, _ := schema.Codec().NativeFromTextual(value)
		valueBytes, _ := schema.Codec().BinaryFromNative(nil, native)

		var recordValue []byte
		recordValue = append(recordValue, byte(0))
		recordValue = append(recordValue, schemaIDBytes...)
		recordValue = append(recordValue, valueBytes...)

		key, _ := uuid.NewUUID()

		err = p.Produce(&kafka.Message{
			TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
			Key:            []byte(key.String()),
			Value:          recordValue,
		}, nil)
		if err != nil {
			fmt.Printf("Error producing message: %v\n", err)
		}

		time.Sleep(1 * time.Second) // Sleep for some time between producing messages
	}

	p.Flush(15 * 1000)
}

```

Di dalam tutorial kita membuat topik dengan nama `transactions` dan dengan melakukan load config dari [Payment.avsc](https://github.com/confluentinc/examples/blob/7.5.2-post/clients/avro/src/main/resources/avro/io/confluent/examples/clients/basicavro/Payment.avsc) kita mulai memproduksi pesan yang akan tampil pada controlcenter.

--produce-avro--

Berikut hasilnya di control-center:

--pic-control-center--

Selanjutnya kita juga perlu membuat client untuk consume data yang telah kita buat di atas. Tidak ada memodifikasi yang signifikan yang saya lakukan hanya mengubah `c.Close()` pada bagian akhir karena LSP dalam kode editor saya menjelaskan bahwa bagian line tersebut tidak akan sampai untuk tereksekusi karena looping di line sebelumnya. Lalu saya ubah dengan menggunakan `defer` menjadi `defer c.Close()`.

```go

import (
	"encoding/binary"
	"fmt"

	"github.com/riferrei/srclient"
	"gopkg.in/confluentinc/confluent-kafka-go.v1/kafka"
)

func main() {
	// 1) Create the consumer as you would
	// normally do using Confluent's Go client
	c, err := kafka.NewConsumer(&kafka.ConfigMap{
		"bootstrap.servers": "localhost",
		"group.id":          "myGroup",
		"auto.offset.reset": "earliest",
	})
	if err != nil {
		panic(err)
	}
	defer c.Close()

	c.SubscribeTopics([]string{"transactions"}, nil)

	// 2) Create a instance of the client to retrieve the schemas for each message
	schemaRegistryClient := srclient.CreateSchemaRegistryClient("http://localhost:8081")

	for {
		msg, err := c.ReadMessage(-1)
		if err == nil {
			// 3) Recover the schema id from the message and use the
			// client to retrieve the schema from Schema Registry.
			// Then use it to deserialize the record accordingly.
			schemaID := binary.BigEndian.Uint32(msg.Value[1:5])
			schema, err := schemaRegistryClient.GetSchema(int(schemaID))
			if err != nil {
				panic(fmt.Sprintf("Error getting the schema with id '%d' %s", schemaID, err))
			}
			native, _, _ := schema.Codec().NativeFromBinary(msg.Value[5:])
			value, _ := schema.Codec().TextualFromNative(nil, native)
			fmt.Printf("Here is the message %s\n", string(value))
		} else {
			fmt.Printf("Error consuming the message: %v (%v)\n", err, msg)
		}
	}
}


```

Hasil dari consumernya sebagai berikut:

--consumer-avro--

4.1 Memproduksi Data Menggunakan Kafka REST

5.1 Membuat Sebuah Stream Proses Menggunakan ksqlDB
