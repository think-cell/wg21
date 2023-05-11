---
title: "operator for"
subtitle: "Generator ranges without coroutine overhead"
document: P2881R0
date: today
audience: EWG
author:
  - name: Jonathan Müller
    email: <jmueller@think-cell.com>
  - name: Barry Revzin
    email: <barry.revzin@gmail.com>
---

# Introduction

# Motivation

# Proposed Design

## `std::yield_handle`

The type `std::yield_handle` gives access to the sink generated from the body of the `for` loop.

```cpp
template <typename T, typename Sink = void>
class yield_handle
{
public:
    using yield_type = T;

    // Create or make the handle empty.
    constexpr yield_handle();
    constexpr yield_handle(std::nullptr_t);
    yield_handle& operator=(std::nullptr_t);

    // implicit copy/move constructor, destructor
    // implicit copy/move assign

    // Returns true if non-nullptr.
    explicit constexpr operator bool() const noexcept;

    // Returns true if the `for` loop has been exited early.
    @_see-below_@ done() const;

    // Yields a value to the sink.
    // Precondition: !done()
    void operator()(T&& obj).

    // Type-erases the sink.
    constexpr operator yield_handle<T>() const noexcept;

    friend constexpr std::strong_ordering operator==(yield_handle lhs, yield_handle rhs) noexcept;
    friend constexpr std::strong_ordering operator<=>(yield_handle lhs, yield_handle rhs) noexcept;
};
```

If the `Sink` is `void`, the yield handle is type-erased.
`done()` returns `bool`.

If the `Sink` is non-`void`, it represents the implementation-defined type of the sink generated from the body.
If the body contains `break` or `return`, `done()` returns `bool`. Otherwise, `done()` is `static constexpr` and returns `std::true_type`.

## `operator for`

```cpp
// Member, type-erased.
operator for(std::yield_handle<@_yield-type_@> sink);
// Member, non-type erased.
template <typename Sink>
operator for(std::yield_handle<@_yield-type_@, Sink> sink);

// Non-member, type-erased.
operator for(@_my-class_@ obj, std::yield_handle<@_yield-type_@> sink);
// Non-member, non-type erased.
template <typename Sink>
operator for(@_my-class_@ obj, std::yield_handle<@_yield-type_@, Sink> sink);
```

`operator for` is a new operator that can be overloaded by user-defined types, either as a member or as a non-member.

Besides `*this`, it either takes a single argument of type `std::yield_handle<T, Sink>`, where `T` is the *yield type*, and `Sink` is either `void` or a generic type parameter (since it is an implementation-defined type, passing a concrete type does not make sense).

The syntax for `operator for` does not allow a return type.
When called manually by the user, it will return `void`.
`operator for` is never a coroutine, even though it may use `co_yield`.

For the same cv-qualified `*this`, all overloads of `operator for` must have the same `@_yield-type_@`, to allow `for (auto x : obj)`.

The expected behavior of `operator for` is to invoke the `sink` with each yielded value,
until the `sink` is `.done()`.

```cpp
struct generator123
{
    template <typename Sink>
    operator for(std::yield_handle<int, Sink> sink) const
    {
        sink(1);
        if (sink.done()) return;

        sink(2);
        if (sink.done()) return;

        sink(3);
        if (sink.done()) return;
    }
};
```

## `co_yield` inside `operator for`

::: cmptable

> Lowering of `co_yield(sink) expr;`

### User code

```cpp
operator for(std::yield_handle<@_yield-type_@> @_sink_@)
{
    co_yield(@_sink_@) @_expr_@;
}
```

### Equivalent code

```cpp
operator for(std::yield_handle<@_yield-type_@> @_sink_@)
{
    @_sink_(@_expr_@);
    if (!@_sink_) return;
}
```

:::

For syntax sugar, a special `co_yield` statement is allowed in the body of an `operator for`.
It is equivalent to passing the value of `expr` to the `sink` and returning if necessary.

Unlike the `co_yield` in a coroutine, it is a statement, not an expression.

## `std::yield_type` trait

```cpp
namespace std
{
    template <typename T>
    struct yield_type
    {
        using type = …;
    };

    template <typename T>
    using yield_type_t = typename yield_type<T>::type;
}
```

The trait `std::yield_type` determines the yield type of a type with an overloaded `operator for`.
If a type does not overload `operator for`, the `::type` member does not exist.

The yield type of a type is the unique type specified in the `std::yield_handle` of the `operator for` overload that would be invoked for the cv-ref-qualified `T`.

```cpp
struct generator123
{
    operator for(std::yield_handle<int>) &;
    operator for(std::yield_handle<float>) const&;
    operator for(std::yield_handle<const char*>) &&;
};

static_assert(std::is_same_v<std::yield_type_t<generator123 &>, int>);
static_assert(std::is_same_v<std::yield_type_t<generator123 const&>, float>);
static_assert(std::is_same_v<std::yield_type_t<generator123 &&>, const char*>);
static_assert(std::is_same_v<std::yield_type_t<generator123 const&&>, float>);
static_assert(std::is_same_v<std::yield_type_t<generator123>, const char*>);
```

## Generator-based `for` loop

Previously, a range-based `for` loop is always translated to a version that uses iterators.
We propose an additional alternative lowering that uses `operator for` instead,
which is used whenever `std::yield_type_t` of the range object is well-formed.
When a type provides both `operator for` and iterators, `operator for` is preferred.

::: cmptable

> Basic lowering of a generator-based `for` loop.

### User code

```cpp
for (@_cv-ref-T_@ @_name_@ : @_object_@)
{
    @_body_@
}
```

### Lowered code

```cpp
{
    auto __lambda = [&](@_cv-ref-T_@ @_name_@) -> @_see-below_@ {
                        @_body_@
                        return std::true_type{};
                    });

    using __yield_type = std::yield_type_t<decltype(@_object_@)>;
    std::yield_handle<__yield_type, @_implementation-defined_@> __yield
      = std::__make_yield_handle<__yield_type>(__lambda);

    @_object_@.operator for(__yield);
    // or
    operator for(@_object_@, __yield);
}
```

:::

The body of the for loop is transformed to a lambda that takes `@_cv-ref-T_@ @_name_@`, which will serve as the sink.
The compiler then constructs a `std::yield_handle` from it in some implementation-defined way,
and passes it to the `operator for` overload.

`operator for` will then invoke `__yield` for each value of its range, which will forward it to the lambda and thus execute the body of the original loop.

By default, the body of the for loop is transformed into a lambda that captures everything by reference and has a return type of `std::true_type`.
Control flow statements in the body change this transformation:

* A `continue;` will be translated to a `return std::true_type{}`.
  This will exit the lambda and thus not execute the rest of the body.
* A `break;` will be translated to a `return std::false_type{}`.
* A `return;` will be translated to a `return std::false_type{}` after setting a compiler-generated flag to mark the return.
  The compiler will generate code to check that flag after the call to `operator for`.
  If it is set, it returns from the function containing the `for` loop.
* A `return @_expr_@;` will be translated to a `return std::false_type{}` after setting a compiler-generated flag to mark the return and store the value of `expr` somewhere.
  The compiler will generate code to check that flag after the call to `operator for`.
  If it is set, it returns the saved value from the function containing the `for` loop.
* A `goto` statement in the body of the `for` loop that jumps to a label defined outside the `for` loop is ill-formed.
* A `throw` statement is left as-is.
  The `operator for` function may catch that exception when it is raised from the call to the yield handle, but that's considered acceptable.

The return type of the generated lambda is `std::common_type_t` of all return statements,
that is either `std::true_type` (no `break` or `return`), or `bool`.
When the lambda returns `false` or `std::false_type{}`, it sets `.done()` on the `std::yield_handle`.

# Potential implementation

A potential implementation of `std::yield_handle` is available here: [godbolt.org/z/bMsvj1e56](https://godbolt.org/z/bMsvj1e56)

The lowering transformation has been done manually in the examples.

