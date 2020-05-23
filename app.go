package main

import (
	"fmt"
	"time"
	"runtime"
)

func produce(ints chan<- int) {
	for j := 0; j < 1000; j++ {
		ints <- j
	}
	close(ints)
}

func consume(ints <-chan int, sums chan<- int) {
	sum := 0
	for i := range ints {
		sum += i
	}
	sums <- sum
}

func main() {
	threads := 1000

	t0 := time.Now()

	sums := make(chan int, threads)

	for i := 0; i < threads; i++ {
		ints := make(chan int, 100)
		go produce(ints)
		go consume(ints, sums)
	}

	sumsums := 0
	for i := 0; i < threads; i++ {
		sumsums += <- sums
	}

	t1 := time.Now()

	fmt.Println( "Workers\tResult\t\tTime" );
	fmt.Printf( "%d\t%d\t%v" , runtime.GOMAXPROCS(0) , sumsums , t1.Sub(t0) );
}
