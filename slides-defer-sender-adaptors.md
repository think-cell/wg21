---
title: "FR-031-319: Defer sender adaptors to C++29"
author: "Jonathan Müller"
date: 2025-11-03
---

# What `std::execution` provides

::: incremental

* Common vocabulary for asynchronous work (“senders/receivers”)
* Traits and concepts
* Pre-defined execution contexts (`ex::run_loop`, `ex::parallel_scheduler`)
* A coroutine task type (`ex::task`)
* Execution scopes for structured concurrency (`ex::counting_scope`)
* Pre-defined sender factories (`ex::just`, `ex::schedule`)
* Pre-defined sender consumers (`this_thread::sync_wait`, `ex::spawn`)
* Pre-defined sender adaptors (`ex::then`, `ex::let_value`, `ex::when_all`)

:::


# Most value for library authors: Vocabulary and concepts

\heading{Finally, a common vocabulary for async work in C++!}
\vspace{1em}

```cpp
ex::sender auto my_async_algorithm()
{
    ex::sender auto data = library_a::read_data_async();
    ex::sender auto processed = library_b::process_data(data, fn);
    ex::sender auto result = library_c::async_write_async_data(processed);
    return result;
}
```

The "iterators" of asynchronous code.

# Most value for average users: Usable coroutines

\heading{Finally, coroutine support in the standard library!}
\vspace{1em}

```cpp
ex::task<Data> my_coroutine()
{
    auto data = co_await library_a::read_data_async();
    fn(data);
    auto result = co_await library_c::async_write_data(data);
    return result;
}
```

The "range-based for loop" of asynchronous code.

# Also: Sender adaptors

\heading{Generic algorithms on senders.}
\vspace{1em}

```cpp
ex::sender auto my_async_algorithm()
{
    return library_a::read_data_async()
      | ex::then(fn)
      | ex::let_value([&](const auto& data) {
          return library_c::async_write_data(data);
      });
}
```

The `std::views` of asynchronous code.

# Sender adaptors are useful

* Provide many common operations on senders
* Declarative way of composing senders
* Avoid coroutine overhead

# But: Sender adaptors are hard to design

Papers that need to be considered in C++26:

::: incremental

* P3718: Fixing Lazy Sender Algorithm Customization, Again (Eric Niebler)
* P3826: Fix or Remove Sender Algorithm Customization (Eric Niebler)
* P3425: Reducing operation-state sizes for subobject child operations (Lewis Baker)
* P3373: Of Operation States and Their Lifetimes (Robert Leahy)

:::

# ISO standards are supposed to be stable

::: incremental

* API can only be changed if it essentially hasn't been implemented yet
* ABI can only be changed before implementations ship a version that promises ABI stability
* DRs are supposed to be for minor issues not fundamental design changes

:::

\onslide<4>
\vspace{2em}
\heading{It is a process failure if we ship something that we know is not yet right.}

\subheading{The C++ standard does not have an experimental channel.}

# Are we sure we can get it done in C++26?

::: incremental

* This is the third (?) approach to sender adaptor Customization
* Reducing operation-state sizes is currently UB and probably requires core language changes
* Is there consensus on how the lifetime of operation states should work?

:::

\onslide<4>
\vspace{2em}
\heading{Do we really have sufficient implementation experience for something designed \textit{this year}?}
\subheading{Adopting it now is risky.}

# Luckily: Sender adaptors are also somewhat annoying to use

* Slow build times
* Hard to debug code
* Poor error messages

. . .

\vspace{2em}
\heading{The average programmer barely uses \texttt{std::views}!}

\subheading{I don't foresee widespread adoption of the sender adaptors.}

# Therefore: Defer sender adaptors to C++29

::: incremental

* We still have the concepts and vocabulary, unblocking standardized networking
* We still have usable coroutines
* We still have execution contexts and structured concurrency
* We still have composition of senders using coroutines or third-party libraries

:::

\onslide<5>
\vspace{2em}
\calltoaction{We also have three more years to get sender adaptors right.}

\subheading{This is precisely why we switched to a train model.}

