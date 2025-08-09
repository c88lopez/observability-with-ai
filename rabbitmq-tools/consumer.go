package main

import (
	"flag"
	"fmt"
	"log"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

// consumer reads messages from a queue until it reaches target count (or indefinitely if count=0)
func main() {
	var (
		queue = flag.String("queue", "test_load_queue", "queue name")
		url   = flag.String("url", "amqp://admin:admin@localhost:5672/", "AMQP connection URL")
		count = flag.Int("count", 10000, "messages to consume (0 => infinite)")
		ack   = flag.Bool("ack", true, "send manual acks")
	)
	flag.Parse()

	conn, err := amqp.Dial(*url)
	if err != nil { log.Fatalf("dial: %v", err) }
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil { log.Fatalf("channel: %v", err) }
	defer ch.Close()

	msgs, err := ch.Consume(*queue, "", *ack == false, false, false, false, nil)
	if err != nil { log.Fatalf("consume: %v", err) }

	deadline := time.Now()
	received := 0
	for m := range msgs {
		received++
		if *ack { m.Ack(false) }
		if received%1000 == 0 { log.Printf("consumed %d", received) }
		if *count > 0 && received >= *count {
			break
		}
	}
	log.Printf("✅ Consumed %d messages in %s", received, time.Since(deadline))
	fmt.Println("Done")
}
