---
title: "noncopyable and nonmovable utility classes"
document: P2895
date: today
audience: LEWG
author:
  - name: Sebastian Theophil
    email: <stheophil@think-cell.com>
  - name: Jonathan Müller
    email: <jmueller@think-cell.com>
---

# Abstract

We propose the addition of `std::noncopyable` and `std::nonmoveable`, utility classes you can inherit form to make your class non-copyable and/or non-moveable.

# Motivation

Developers may want to declare that a class is a move-only type, i.e., that it is movable but non-copyable. This is often useful for RAII classes that must not duplicate the resource they manage. Similarly, developers may want to declare that a class is neither movable nor copyable. Consider the following example that deals with a legacy API: 

::: cmptable

### Before

```cpp
```cpp
extern "C" RegisterCallbackInLegacyAPI(
      void (* callback)(void const*), void const* context);

static void callback(void const* context) noexcept;

class legacy_callback {
    legacy_callback(legacy_callback const&) = delete;
    legacy_callback& operator=(legacy_callback const&) = delete;

    void register_callback() noexcept {
        RegisterCallbackInLegacyAPI(callback, this);
    }
};
```

### After

```cpp
extern "C" RegisterCallbackInLegacyAPI(
      void (* callback)(void const*), void const* context);

static void callback(void const* context) noexcept;

class legacy_callback : std::nonmovable {


    void register_callback() noexcept {
        RegisterCallbackInLegacyAPI(callback, this);
    }
};
```

:::

Passing the `this` pointer as context to a legacy callback requires that `this` remains constant. `std::mutex` is also an object that is neither copyable nor movable. 

By declaring the copy-constructor and the copy-assignment operator of a class as deleted, developers can make their own classes non-copyable and non-movable. This seems straight-forward. Yet, users get this wrong. Indeed, two very popular StackOverflow answers on how to make an object non-copyable and non-movable were initially wrong, as the comments show. [1](https://stackoverflow.com/questions/7823990/what-are-the-advantages-of-boostnoncopyable) [2](https://stackoverflow.com/questions/31940886/is-there-a-stdnoncopyable-or-equivalent).

Many libraries such as [boost](https://www.boost.org/doc/libs/1_82_0/libs/core/doc/html/core/noncopyable.html) have introduced a type called `noncopyable` (or similar) that user-defined classes can derive from and that deletes both copy-construction and copy-assignment. Deriving from `noncopyable` lets users declare their _intent_ clearly and succinctly. [3](https://os.mbed.com/docs/mbed-os/v6.16/apis/noncopyable.html)
[4](https://www.sfml-dev.org/documentation/2.5.1/classsf_1_1NonCopyable.php)
[5](https://www.nsnam.org/docs/release/3.29/doxygen/classns3_1_1_non_copyable.html)
[6](https://github.com/adobe/webkit/blob/master/Source/WTF/wtf/Noncopyable.h)
[7](https://docs.nvidia.com/jetson/archives/l4t-multimedia-archived/l4t-multimedia-281/classArgus_1_1NonCopyable.html)
[8](https://github.com/think-cell/think-cell-library/blob/main/tc/base/noncopyable.h)

[A code search for "noncopyable" yields almost 5000 hits.](https://codesearch.isocpp.org/cgi-bin/cgi_ppsearch?q=noncopyable&search=Search) 
It has thus clearly become a common idiom that is frequently used and reimplemented and therefore deserves to be included in the standard library. 

# Naming

Unfortunately, `boost::noncopyable` (and all other referenced implementations except [8](https://github.com/think-cell/think-cell-library/blob/main/tc/base/noncopyable.h)) makes a class non-copyable **and** non-movable because the implementation of `boost::noncopyable` precedes the introduction of move semantics. This collides with the names of already standardized concepts `std::copyable` and `std::movable`. A class may not satisfy `std::copyable` yet may be `std::movable`. We propose to introduce types `noncopyable` and `nonmovable` that match the names of the already standardized concepts. Thus, a class deriving from `noncopyable` cannot satisfy `std::copyable` but may satisfy `std::movable`. A class deriving from `nonmovable` cannot satisfy `std::movable` and thus cannot satisfy `std::copyable` either.

Type `noncopyable` could also be called `moveonly` or `move_only`. 

According to [codesearch.isocpp.org](https://codesearch.isocpp.org), the name `nonmovable` has only been used in the [test framework for the range v3 library](https://codesearch.isocpp.org/actcd19/main/r/range-v3/range-v3_0.4.0-1/test/utility/concepts.cpp) together with a type `moveonly`. The alternative spelling `move_only` has also often been used in test frameworks for libcxx, libstdc++, boost.hana and gcc.  

# Proposed Implementation

We propose the following definitions for both classes:

```cpp
struct noncopyable {
    noncopyable() = default;
    noncopyable(noncopyable&&) = default;
    noncopyable& operator=(noncopyable&&) = default;
};

struct nonmovable {
    nonmovable() = default;
    nonmovable(nonmovable const&) = delete;
    nonmovable& operator=(nonmovable const&) = delete;
};
```

In both classes, the default constructor is declared as default and is thus trivial. `noncopyable` and `nonmovable` are therefore empty standard layout classes and "empty base optimization" is required when deriving from either. Deriving from `noncopyable` or `nonmovable` therefore incurs no space or runtime overhead.

# Acknowledgements 

Alisdair for the original paper [@N2675].

# Wording

Add to header `<utility>` synopsis in [utility.syn]{.sref}

::: add

```cpp
// [utility.noncopyable], class noncopyable
namespace noncopyable-adl-namespace { 
   struct noncopyable;
}
using noncopyable-nonmovable-adl-namespace::noncopyable;

// [utility.nonmovable], class nonmovable
namespace nonmovable-adl-namespace { 
   struct nonmovable;
}
using nonmovable-adl-namespace::nonmovable;
```

:::

Append a new section to [utility]{.sref}

::: add

## 22.2.x Support Classes [utility.support] {-}

The following classes are provided to simplify the implementation of common idioms.

### 22.2.x.1 Class `noncopyable` [utility.noncopyable] {-}

```cpp
namespace noncopyable-adl-namespace { 
    struct noncopyable {
        noncopyable() = default;
        noncopyable(noncopyable&&) = default;
        noncopyable& operator=(noncopyable&&) = default;
    };
}
using noncopyable-adl-namespace::noncopyable;
```

[1]{ .pnum } `noncopyable` is provided to simplify creation of classes that have move-only semantics, i.e. they are movable but not copyable.

[*Note*: `noncopyable` is provided in an unspecified nested namespace to limit argument dependent lookup [basic.lookup.argdep]{ .sref }; no other names should be declared in this namespace. — *end note*]

[*Example*:
```cpp
class file : std::noncopyable { 
public:
    file(std::string const& strPath) 
     : fp( std::fopen(strPath.c_str(), "w") ) 
    {}

    file(file&& f) : fp(std::exchange(f.fp, nullptr)) {}
    file& operator=(file&& f) { ... }
    
    ~file() { if(fp) std::fclose(fp); } 
private:
    std::FILE* fp;
}; 
```
— *end example*]

### 22.2.x.2 Class `nonmovable` [utility.nonmovable] {-}

```cpp
namespace nonmovable-adl-namespace { 
    struct nonmovable {
        nonmovable() = default;
        nonmovable(nonmovable const&) = delete;
        nonmovable& operator=(nonmovable const&) = delete;
    };
}
using nonmovable-adl-namespace::nonmovable;
```

[1]{.pnum} `nonmovable` is provided to simplify creation of classes that inhibit move and copy semantics.

[*Note*: `nonmoveable` is provided in an unspecified nested namespace to limit argument dependent lookup [basic.lookup.argdep]{ .sref }; no other names should be declared in this namespace. — *end note*]

[*Example*:
```cpp
class mutex : std::nonmovable { 
public:
    mutex();
    ~mutex();
}; 
```
— *end example*]

:::

