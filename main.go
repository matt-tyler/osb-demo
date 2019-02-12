package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"cloud.google.com/go/storage"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	timeout := ctx.Done()

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	done := make(chan struct{})
	go func(ctx context.Context, done chan<- struct{}) {
		client, err := storage.NewClient(ctx)
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s\n", err)
			return
		}

		bktName, ok := os.LookupEnv("STORAGE_BUCKET")
		if !ok {
			fmt.Fprintf(os.Stderr, "STORAGE_BUCKET environment variable was not set\n")
			return
		}

		fmt.Printf("Bucket set to: %v\n", bktName)

		bkt := client.Bucket(bktName)

		obj := bkt.Object("latency2018")

		w := obj.NewWriter(ctx)
		defer func() {
			if err := w.Close(); err != nil {
				fmt.Fprintf(os.Stderr, "%s\n", err)
			}
			done <- struct{}{}
		}()

		if bytes, err := fmt.Fprintf(w, "Hello latency 2018!\n\nIt worked!\n"); err != nil {
			fmt.Fprintf(os.Stderr, "%s\n", err)
		} else {
			fmt.Fprintf(os.Stdout, "%d bytes written\n", bytes)
		}
	}(ctx, done)

	select {
	case <-c:
		fmt.Println("Application received termination signal.")
		os.Exit(1)
	case <-timeout:
		fmt.Println("Application timed out.")
		os.Exit(1)
	case <-done:
		fmt.Println("Application completed successfully")
		os.Exit(0)
	}
}
