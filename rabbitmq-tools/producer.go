package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

// producer sends N messages to a queue (declared durable=false by default for test speed)
func main() {
	var (
		count    = flag.Int("count", 10000, "number of messages to publish")
		queue    = flag.String("queue", "test_load_queue", "queue name")
		exchange = flag.String("exchange", "", "exchange name (blank for default)")
		routing  = flag.String("routing", "test_load_queue", "routing key")
		url      = flag.String("url", "amqp://admin:admin@localhost:5672/", "AMQP connection URL")
	)
	flag.Parse()

	conn, err := amqp.Dial(*url)
	if err != nil { log.Fatalf("dial: %v", err) }
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil { log.Fatalf("channel: %v", err) }
	defer ch.Close()

	_, err = ch.QueueDeclare(*queue, false, true, false, false, nil)
	if err != nil { log.Fatalf("queue declare: %v", err) }

	ctx := context.Background()
	rnd := rand.New(rand.NewSource(time.Now().UnixNano()))
	start := time.Now()
	for i := 1; i <= *count; i++ {
		body := fmt.Sprintf("msg-%d-%d", i, rnd.Int())
		err = ch.PublishWithContext(ctx, *exchange, *routing, false, false, amqp.Publishing{
			Timestamp:   time.Now(),
			ContentType: "text/plain",
			Body:        []byte(body),
		})
		if err != nil { log.Fatalf("publish: %v", err) }
		if i%1000 == 0 { log.Printf("published %d/%d", i, *count) }
	}
	dur := time.Since(start)
	log.Printf("✅ Published %d messages in %s (%.0f msg/s)", *count, dur, float64(*count)/dur.Seconds())

	// Keep queue around briefly if ephemeral
	if os.Getenv("PRODUCER_WAIT") != "" { time.Sleep(5 * time.Second) }
}
