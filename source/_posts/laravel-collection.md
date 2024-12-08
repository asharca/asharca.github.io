---
title: 源码分析--Laravel Collection
date: 2024-11-28 18:52:40
updated:
category: [Tech]
tags: [PHP, Laravel, Collection, 源码分析]
mermaid:
index_img: ../img/cover_laravel_collection.jpg
---

Laravel Collection 原理和用法解析。

<!-- more -->

{% note primary %}
Laravel: 11.x
PHP: 8.x
code: vendor/laravel/framework/src/Illuminate/Collections/Collection.php
docs: https://laravel.com/docs/11.x/collections
{% endnote %}

## 介绍

{% note primary %}
Illuminate\Support\Collection 类提供了一个流畅、方便的包装器来处理数据数组。Collection 可以看作是 PHP 数组的超级增强版。不仅保留了数组的所有基本功能，还提供了大量强大的方法，将复杂的数据操作转变为简单、优雅的链式调用，提高了开发效率和代码可读性。
{% endnote %}

在 Laravel 里面，Collection 随处可见

```php
# 数据库查询结果
$users = User::where('status', 'active')->get();
$activeUsers = $users->filter(function ($user) {
    return $user->age > 18;
})->map(function ($user) {
    return [
        'name' => $user->name,
        'email' => $user->email
    ];
});

# API 响应的数据
public function index()
{
    $products = Product::all();
    return response()->json(
        $products->map(function ($product) {
            return [
                'id' => $product->id,
                'name' => $product->name,
                'price' => number_format($product->price, 2)
            ];
        })
    );
}

# 复杂的数据聚合
$orders = Order::all();
$statistics = $orders->groupBy('status')
    ->map(function ($group) {
        return [
            'total_count' => $group->count(),
            'total_amount' => $group->sum('amount')
        ];
    });

# LazyCollection：延迟计算
$lazyCollection = collect(range(1, 1000))
    ->lazy()
    ->map(function ($item) {
        // 仅在遍历时计算
        return $item * 2;
    });
```

## 继承的类

### ArrayAccess

PHP 内置接口，实现后可以让对象像数组一样操作。

### CanBeEscapedWhenCastToString

定义了一个类在被强制转换为字符串（或调用 __toStirng）时，是否应该自动进行 HTML 转义（HTML escaping）。避免手动调用 htmlspecialchars 或类似函数，blade 模板在渲染数据也会检查是否实现了这个接口。

### Enumerable

Enumerable 接口是框架中集合（Collections）相关功能的核心接口之一，它定义了用于操作和遍历集合的方法。比如 every、map、filter、reduce 之类的。主要可以对集合可以进行链式调用、数据操作和迭代等操作。这个类也继承了一些数组相关的类，如下：

#### Arrayable

Illuminate\Contracts\Support 定义的接口，有一个 toArray 方法。

#### Countable

PHP 内置接口，有一个 count 方法，返回对象的数量。

#### IteratorAggregate

PHP 内置接口，实现可以对其使用 foreach 语法。

#### Jsonable

Illuminate\Contracts\Support 接口，toJson 方法。

#### JsonSerializable

PHP 内置接口，可以 json 化。

## 使用的 Trait

### EnumeratesValues

提供一系列用于枚举和处理值的方法。这里面使用了 HigherOrderCollectionProxy 代理，功能就是代理原来 Collection 自身的方法通过简化的方式调用，具体看下面。

```php
// Collection 创建和基本使用
$collection = collect([1, 2, 3, 4, 5]);

// EnumeratesValues 提供的方法
$filteredCollection = $collection->filter(function($item) {
    return $item > 2;
});

// HigherOrderCollectionProxy 语法
$users = collect([
    ['name' => 'Alice', 'active' => true],
    ['name' => 'Bob', 'active' => false]
]);

// 使用 Higher Order Proxy
$activeUsers = $users->filter->active;  // 简化的过滤语法
```

{% note primary %}
HigherOrderCollectionProxy 大致原理：Collection 本身没有 filter, map, reduce 属性（注意这里是属性，不是方法），通过 EnumeratesValues 的__get() 方法调用 HigherOrderCollectionProxy 并设置 method 为 filter/map 等等，然后返回 HigherOrderCollectionProxy，当链式调用属性 active 时会通过 HigherOrderCollectionProxy 的 __get 去使用代理的 method，返回 Collection 类，循环往复。
{% endnote %}

### Macroable

Macroable 允许为类动态添加方法，也就是「宏」，使类具有高度的可扩展性。通过使用 Macroable，可以在运行时给类添加自定义行为，而不需要修改类的源码。添加的方法支持静态调用和箭头调用。

```php
use Illuminate\Support\Collection;

# 注册一个宏（动态方法）。
Collection::macro('toUpper', function () {
    return $this->map(fn($value) => strtoupper($value));
});

$collection = collect(['a', 'b', 'c'])->toUpper();
// 结果：['A', 'B', 'C']
# 将一个对象或类的方法注入当前类。
class MyCollectionMacros {
    public function capitalize() {
        return function () {
            return $this->map(fn($value) => ucfirst($value));
        };
    }
}

Collection::mixin(new MyCollectionMacros);

$collection = collect(['hello', 'world'])->capitalize();
// 结果：['Hello', 'World']
```

## LazyCollection

延迟计算（Lazy Evaluation）是一种优化技术，核心思想是「需要时才计算」。在 Laravel 的 Collection 中，主要通过 LazyCollection 实现。

它的主要原理如下

- 迭代器模式：使用 PHP 迭代器延迟计算
- 惰性求值：只在真正需要时计算
- 流式处理：一次处理一个元素


```php
$lazyCollection = collect([1, 2, 3, 4, 5])
    ->lazy()  // 创建延迟集合
    ->map(function ($number) {
        // 这个函数不会立即执行
        return $number * 2;
    });

// 只有在实际使用时才会计算
foreach ($lazyCollection as $item) {
    // 此时才真正执行 map 操作
    echo $item;
}
```

## 总结

Collection 有很多使用的方法，比如按照对象的某个元素分组 groupBy，分块 chunk，扁平化 flatten，函数式编程（map、filter、reduce、every...）。还了解到 data_set,data_get,date_forget helper 系列函数负责使用「.」符号处理嵌套的数组。

从源码角度上分析学到了 PHP 接口和 Trait 的结合使用，闭包的设计，`__get()` `__call()` `__callStatic()` 的动态调用，使用 `func_num_args()` 方法实现方法重载。

{% note primary %}
`__get()`：当类不存在属性时调用这个方法
`__call()`：当方法不存在时调用这个方法
`__callStatic()`：当静态方法不存在时调用的方法
`func_num_args()`：返回函数的参数个数
{% endnote %}