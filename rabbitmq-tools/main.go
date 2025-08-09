package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

// Unified RabbitMQ tool usage examples:
//   go run . --mode=produce --queue=test_queue --count=10000
//   go run . --mode=consume --queue=test_queue --count=10000
//   go run . --mode=consume --queue=test_queue --count=0   (infinite)
// Flags:
//   --mode produce|consume
//   --queue queue name
//   --routing routing key (default queue)
//   --exchange exchange (blank=default)
//   --count number of messages (produce: to publish, consume: to read; 0=infinite consume)
//   --url AMQP URL
//   --ack (consume) manual ack (default true)
//   --prefetch (consume) prefetch count
//   --batch (produce) progress interval
//   --size (produce) payload size bytes (padding)
//   --concurrency (produce) publisher goroutines
// Env:
//   RABBITMQ_URL overrides --url
//   RANDOM_SEED for deterministic randomness
func main() {
	// Custom usage before defining flags to allow -h / --help to print richer guidance.
	flag.Usage = func() { printUsage() }
	var (
		mode        = flag.String("mode", "produce", "mode: produce or consume")
		queue       = flag.String("queue", "test_load_queue", "queue name")
		exchange    = flag.String("exchange", "", "exchange name (blank=default)")
		routing     = flag.String("routing", "", "routing key (default=queue)")
		url         = flag.String("url", "amqp://admin:admin@localhost:5672/", "AMQP connection URL")
		count       = flag.Int("count", 10000, "message count (0=infinite consume)")
		ack         = flag.Bool("ack", true, "(consume) manual acks")
		prefetch    = flag.Int("prefetch", 0, "(consume) prefetch count")
		batch       = flag.Int("batch", 1000, "(produce) progress log interval")
		size        = flag.Int("size", 0, "(produce) payload size bytes (extra padding)")
		concurrency = flag.Int("concurrency", 1, "(produce) concurrent publisher goroutines")
		helpFlag    = flag.Bool("help", false, "show detailed usage and exit")
	)
	flag.Parse()
	if *helpFlag { flag.Usage(); return }

	if envURL := os.Getenv("RABBITMQ_URL"); envURL != "" { *url = envURL }
	if *routing == "" { *routing = *queue }

	seed := time.Now().UnixNano()
	if s := os.Getenv("RANDOM_SEED"); s != "" {
		var parsed int64
		fmt.Sscanf(s, "%d", &parsed)
		if parsed != 0 { seed = parsed }
	}
	rng := rand.New(rand.NewSource(seed))

	conn, err := amqp.Dial(*url)
	if err != nil { log.Fatalf("dial: %v", err) }
	defer conn.Close()
	ch, err := conn.Channel()
	if err != nil { log.Fatalf("channel: %v", err) }
	defer ch.Close()

	switch strings.ToLower(*mode) {
	case "produce", "pub", "publisher":
		runProducer(ch, rng, *exchange, *routing, *queue, *count, *batch, *size, *concurrency)
	case "consume", "sub", "consumer":
		runConsumer(ch, *queue, *count, *ack, *prefetch)
	default:
		log.Fatalf("unknown --mode=%s", *mode)
	}
}

func runProducer(ch *amqp.Channel, rng *rand.Rand, exchange, routing, queue string, count, batch, size, concurrency int) {
	if _, err := ch.QueueDeclare(queue, false, true, false, false, nil); err != nil { log.Fatalf("queue declare: %v", err) }
	if concurrency < 1 { concurrency = 1 }
	perWorker := count / concurrency
	remainder := count % concurrency
	log.Printf("Producing %d messages (concurrency=%d) queue=%s", count, concurrency, queue)
	start := time.Now()
	ctx := context.Background()
	errCh := make(chan error, concurrency)
	doneCh := make(chan int, concurrency)

	makePayload := func(i int) []byte {
		base := fmt.Sprintf("msg-%d-%d", i, rng.Int())
		if size <= 0 { return []byte(base) }
		if len(base) < size { return []byte(base + strings.Repeat("x", size-len(base))) }
		return []byte(base[:size])
	}

	publishRange := func(worker, startIdx, n int) {
		for i := 0; i < n; i++ {
			global := startIdx + i + 1
			body := makePayload(global)
			if err := ch.PublishWithContext(ctx, exchange, routing, false, false, amqp.Publishing{ContentType: "text/plain", Body: body, Timestamp: time.Now()}); err != nil {
				errCh <- fmt.Errorf("publish worker %d idx %d: %w", worker, global, err); return
			}
			if batch > 0 && global%batch == 0 { log.Printf("worker %d published %d/%d", worker, global, count) }
		}
		doneCh <- n
	}

	next := 0
	for w := 0; w < concurrency; w++ {
		n := perWorker
		if w == concurrency-1 { n += remainder }
		go publishRange(w, next, n)
		next += n
	}

	published := 0
	for published < count {
		select {
		case e := <-errCh: log.Fatalf("error: %v", e)
		case n := <-doneCh: published += n
		}
	}
	dur := time.Since(start)
	log.Printf("✅ Published %d messages in %s (%.0f msg/s)", count, dur, float64(count)/dur.Seconds())
}

func runConsumer(ch *amqp.Channel, queue string, count int, ack bool, prefetch int) {
	if prefetch > 0 { if err := ch.Qos(prefetch, 0, false); err != nil { log.Fatalf("qos: %v", err) } }
	if _, err := ch.QueueDeclare(queue, false, true, false, false, nil); err != nil { log.Fatalf("queue declare: %v", err) }
	autoAck := !ack
	msgs, err := ch.Consume(queue, "", autoAck, false, false, false, nil)
	if err != nil { log.Fatalf("consume: %v", err) }
	log.Printf("Consuming queue=%s target=%d ack=%v prefetch=%d", queue, count, ack, prefetch)
	start := time.Now()
	received := 0
	for m := range msgs {
		received++
		if ack { _ = m.Ack(false) }
		if received%1000 == 0 { log.Printf("consumed %d", received) }
		if count > 0 && received >= count { break }
	}
	dur := time.Since(start)
	log.Printf("✅ Consumed %d messages in %s (%.0f msg/s)", received, dur, float64(received)/dur.Seconds())
}

// printUsage loads USAGE.txt from the same directory (if present) and substitutes program name.
func printUsage() {
	data, err := os.ReadFile("USAGE.txt")
	if err != nil {
		fmt.Fprintf(os.Stderr, "(usage file missing) %v\n", err)
		return
	}
	prog := filepath.Base(os.Args[0])
	// Replace temporary build artifact names with a generic tool name for clarity.
	if strings.Contains(prog, "go-build") || prog == "main" {
		prog = "rabbitmq-tool"
	}
	text := strings.ReplaceAll(string(data), "{{prog}}", prog)
	fmt.Fprint(os.Stderr, text)
}
