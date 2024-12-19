---
title: 源码分析--Laravel Pipeline
date: 2024-12-19 23:20:26
updated:
category: [Tech]
tags: [PHP, Laravel, Pipeline, 源码分析]
mermaid:
index_img:
---

在软件开发中，数据处理往往需要经过多个步骤。Laravel 框架提供的 Pipeline（管道）模式为这类需求提供了优雅的解决方案。本文将深入剖析 Pipeline 模式的工作原理及其在实际开发中的应用。

<!-- more -->

{% note primary %}
Laravel: 11.x
PHP: 8.x
code: vendor/laravel/framework/src/Illuminate/Pipeline/Pipeline.php
docs: https://laravel.com/docs/11.x/helpers#pipeline
{% endnote %}

## 理解 Pipeline 模式

要理解 Pipeline 模式，不妨想象一条工业生产线：产品从流水线的一端进入，依次经过不同的工作站，每个工作站都会对产品进行特定的处理。到达终点时，产品就完成了所有必要的加工步骤。Pipeline 模式就是这个概念在软件中的实现——数据像产品一样，流经一系列预设的处理环节，每个环节都可以对数据进行验证、转换或者其他必要的处理。

## Laravel Pipeline 的设计思路

Laravel 的 Pipeline 实现主要包含以下核心要素：

1. Pipeline 主体类（`Illuminate\Pipeline\Pipeline`）
2. 多个独立的处理管道
3. 需要处理的数据
4. 处理完成后的回调函数

框架为我们提供了四个关键方法来操作这个流程：

- `send()`：输入初始数据
- `through()`：设置处理管道的顺序
- `via()`：指定处理方法（默认是"handle"）
- `then()`：执行整个流程并处理结果

## 实战应用

让我们通过一个用户注册的例子来展示 Pipeline 的实际应用：

```php
namespace App\Services;

use Closure;
use Illuminate\Pipeline\Pipeline;

class UserRegistrationPipeline
{
    public function processRegistration($userData)
    {
        return app(Pipeline::class)
            ->send($userData)
            ->through([
                ValidateUserData::class,        // 数据验证
                NormalizeUserInput::class,      // 数据标准化
                CreateUserAccount::class,       // 创建账户
                SendWelcomeEmail::class         // 发送欢迎邮件
            ])
            ->thenReturn();
    }
}
```

每个处理环节都专注于特定的任务：

```php
class ValidateUserData
{
    public function handle($userData, Closure $next)
    {
        if (!filter_var($userData['email'], FILTER_VALIDATE_EMAIL)) {
            throw new \Exception('邮箱格式不正确');
        }
        return $next($userData);
    }
}

class NormalizeUserInput
{
    public function handle($userData, Closure $next)
    {
        // 统一转换为小写，确保数据一致性
        $userData['name'] = strtolower($userData['name']);
        $userData['email'] = strtolower($userData['email']);
        return $next($userData);
    }
}
```

## 扩展功能

### 条件处理

Pipeline 集成了 Conditionable trait，我们可以使用 `when` 和 `unless` 方法来实现条件处理：

```php
$result = $pipeline
    ->send($data)
    ->when($needsValidation)->through([ValidateData::class])
    ->when($needsNormalization)->through([NormalizeData::class])
    ->when($isProduction)->through([LogOperation::class])
    ->thenReturn();
```

when 源码：

```php
public function when($value = null, ?callable $callback = null, ?callable $default = null)
    {
        $value = $value instanceof Closure ? $value($this) : $value;

        if (func_num_args() === 0) {
            return new HigherOrderWhenProxy($this);
        }

        if (func_num_args() === 1) {
            return (new HigherOrderWhenProxy($this))->condition($value);
        }

        if ($value) {
            return $callback($this, $value) ?? $this;
        } elseif ($default) {
            return $default($this, $value) ?? $this;
        }

        return $this;
    }
```

when 可以接受 0-3 个参数，第一个参数可以是闭包/一个值，第二个/第三个为回调函数，分别当第一个值/闭包返回 true/false 执行，unless 相反

这里面有个有意思的地方：当你传递 0-1 个参数时，when 会返回一个 higherOrderWhenProxy 对象，如果传递 1 个参数为 false，则后面链式调用的函数不会调用（目前不清楚 0 个参数的意义，实现原理就是代理模式）

### 异常处理

每个处理环节都内置了异常处理机制，通过 try-catch 结构确保整个流程的稳定性。这样即使某个环节出现问题，也能及时捕获并处理。

## Pipeline 模式的优势

在实际开发中，Pipeline 模式具有以下优势：

1. **职责明确**：每个处理环节只负责一个特定任务，代码结构清晰。

2. **易于测试**：可以独立测试每个处理环节，提高代码质量。

3. **灵活可配**：可以根据需要轻松调整处理流程，增加或删除处理环节。

4. **逻辑分明**：将复杂的处理流程拆分成多个独立步骤，提高代码可读性。

## 核心源码解析

Pipeline 的核心实现采用了数组归约的方式。让我们看看 `then()` 方法的关键实现：

```php
   /**
     * Run the pipeline with a final destination callback.
     *
     * @param  \Closure  $destination
     * @return mixed
     */
    public function then(Closure $destination)
    {
        $pipeline = array_reduce(
            array_reverse($this->pipes()), $this->carry(), $this->prepareDestination($destination)
        );

        return $pipeline($this->passable);
    }

    /**
     * Get the final piece of the Closure onion.
     *
     * @param  \Closure  $destination
     * @return \Closure
     */
    protected function prepareDestination(Closure $destination)
    {
        return function ($passable) use ($destination) {
            try {
                return $destination($passable);
            } catch (Throwable $e) {
                return $this->handleException($passable, $e);
            }
        };
    }

    /**
     * Get a Closure that represents a slice of the application onion.
     *
     * @return \Closure
     */
    protected function carry()
    {
        return function ($stack, $pipe) {
            return function ($passable) use ($stack, $pipe) {
                try {
                    if (is_callable($pipe)) {
                        // If the pipe is a callable, then we will call it directly, but otherwise we
                        // will resolve the pipes out of the dependency container and call it with
                        // the appropriate method and arguments, returning the results back out.
                        return $pipe($passable, $stack);
                    } elseif (! is_object($pipe)) {
                        [$name, $parameters] = $this->parsePipeString($pipe);

                        // If the pipe is a string we will parse the string and resolve the class out
                        // of the dependency injection container. We can then build a callable and
                        // execute the pipe function giving in the parameters that are required.
                        $pipe = $this->getContainer()->make($name);

                        $parameters = array_merge([$passable, $stack], $parameters);
                    } else {
                        // If the pipe is already an object we'll just make a callable and pass it to
                        // the pipe as-is. There is no need to do any extra parsing and formatting
                        // since the object we're given was already a fully instantiated object.
                        $parameters = [$passable, $stack];
                    }

                    $carry = method_exists($pipe, $this->method)
                                    ? $pipe->{$this->method}(...$parameters)
                                    : $pipe(...$parameters);

                    return $this->handleCarry($carry);
                } catch (Throwable $e) {
                    return $this->handleException($passable, $e);
                }
            };
        };
    }
```

```PHP
$pipeline = new Pipeline();
$result = $pipeline
    ->send(15)
    ->through([$pipe1, $pipe2, $pipe3])
    ->then($destination);
```
- 以这段代码为例，通过 array_reduce+carry 包装成 $destination($pipe3($pipe2($pipe1($passable)))) 的形式去执行，注意 then 里面的 reverse，将 pipe1，pipe2，pipe3 逆序后再 reduce
- carry 先返回一个闭包处理管道函数，在里面有内层闭包处理当前请求
- carry 可以处理 callable，字符串（可以解析成对象），现成对象

## 使用建议

在使用 Pipeline 模式时，有以下几点建议：

1. 保持每个处理环节的单一职责原则
2. 合理安排处理环节的顺序
3. 为每个环节选择清晰、明确的命名
4. 注意大数据量处理时的性能问题
5. 做好异常处理和日志记录

## 应用场景

Pipeline 模式特别适合以下场景：

- 需要对数据进行多步骤处理的业务流程
- 处理步骤可能需要灵活调整的场合
- 处理逻辑需要在多处复用的情况
- 需要严格管控处理流程的应用

不过需要注意的是，对于简单的顺序处理任务，使用 Pipeline 可能会显得过于复杂。在选择是否使用这个模式时，应该根据实际业务的复杂度来权衡。

## 总结

Laravel 的 Pipeline 模式为我们提供了一个强大而优雅的数据处理方案。它不仅让代码结构更加清晰，还提供了极大的灵活性。无论是处理复杂的数据转换，实现中间件功能，还是管理业务流程，Pipeline 都是一个值得掌握的开发工具。

通过合理使用 Pipeline 模式，我们可以将复杂的处理流程变得简单明了，同时保持代码的可维护性和可扩展性。这正是 Laravel 框架追求优雅开发体验的一个体现。