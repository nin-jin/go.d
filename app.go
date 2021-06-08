package main

import (
	"fmt"
	"runtime"
	"time"
)

func produce(ints chan<- int64) {
	for j := int64(0); j < 10000; j++ {
		ints <- j
	}
	close(ints)
}

func consume(ints <-chan int64, sums chan<- int64) {
	sum := int64(0)
	for i := range ints {
		sum += i
	}
	sums <- sum
}

func main() {
	threads := 100

	t0 := time.Now()

	sums := make(chan int64, threads)

	for i := 0; i < threads; i++ {
		ints := make(chan int64, 100)
		go produce(ints)
		go consume(ints, sums)
	}

	sumsums := int64(0)
	for i := 0; i < threads; i++ {
		sumsums += <-sums
	}

	t1 := time.Now()

	fmt.Println("Workers\tResult\t\tTime")
	fmt.Printf("%d\t%d\t%v", runtime.GOMAXPROCS(0), sumsums, t1.Sub(t0))
}
