---
layout: post
title: Objective-C Runtime --- 消息发送
date: 2018-05-20 19:01:38
tags: runtime
category: iOS
---
上篇文章分析了对象的数据结构，这篇我们就结合源码来分析下Objective-C最核心的东西——消息发送。在Objective-C中，我们调用方法，其实都是发送消息。发送消息为Objective-C增加了动态特性，下面我们就来看一下Objective-C的消息发送过程。
<!--more-->
# objc_msgSend简介
其实我们看大部分runtime文章，都是从这个函数看起的。在Objective-C中，我们调用方法的语法是这样的`[receiver message]`。编译期会把这个方法调用转换成下面这个函数：

```
objc_msgSend(receiver, selector, arg1, arg2, ...)
```
其中第一个函数就是我们调用方法的recevier，第二个是个方法选择器，类型是`SEL`，我们看下`SEL`的定义：

```
/// An opaque type that represents a method selector.
typedef struct objc_selector *SEL;
```
`objc_selector`是一个映射到方法的C字符串。我们可以通过调用`@selector()`和`sel_registerName`生成一个`SEL`。等下会具体分析`SEL`。现在继续分析objc_msgSend函数。
当receiver收到一条消息，消息发送函数通过isa指针找到类对象，在其类对象中查找方法实现。如果类对象中没有，通过superclass指针，找到其父类对象，在其中查找实现。一直查找到`NSObject`，只要找到实现就会去调用。这就是runtime查找方法实现的过程。为了加快方法调用，runtime系统缓存了已经调用过的方法。接下来我们会通过源码来分析。如果receiver为`nil`，会直接返回，并不会报错。
![](http://ohg2bgicd.bkt.clouddn.com/1526885161.png)
# objc_msgSend源码解析
## @selector
在`objc_msgSend`中，第一个参数我们不用过多解释。第二个参数selector，看起来简单，其实有些东西需要我们明白。这里需要我们注意的是：**不同类中，相同方法名不带参数的方法所对应的方法选择器相同，如果方法有参数且参数数量相同，所对应的方法选择器也相同(和参数类型无关)。**。前面这句话有点不太好懂，用代码来看一下：

```
@interface TestObject : NSObject
-(void)sayHello; // 1
-(void)sayHello:(int)a; // 2
@end

@implementation TestObject
-(void)sayHello:(int)a
{
    NSLog(@"%d",a);
}
-(void)sayHello {
    NSLog(@"Hello");
}
@end

@interface TestTwoObject : NSObject
-(void)sayHello;  // 3
-(void)sayHello:(NSString *)str; // 4
@end

@implementation TestTwoObject
-(void)sayHello:(NSString *)str {
    NSLog(str);
}
-(void)sayHello {
    NSLog(@"Hello");
}
@end
```
其中1和3对应的方法选择器相同，2和4对应的方法选择器相同。
>1. Objective-C为我们维护了一个方法选择器表。
2. 使用`@selector()`时会从这个选择器表中查找对应的`SEL`，如果没有找到，会生成一个新的`SEL`添加到表中。
3. 在编译期间会扫描全部的头文件和实现文件将其中的方法以及使用`@selector()`生成的选择子加入到方法选择器表中。

>具体分析请看[从源代码看 ObjC 中消息的发送](https://github.com/Draveness/analyze/blob/master/contents/objc/%E4%BB%8E%E6%BA%90%E4%BB%A3%E7%A0%81%E7%9C%8B%20ObjC%20%E4%B8%AD%E6%B6%88%E6%81%AF%E7%9A%84%E5%8F%91%E9%80%81.md)

## 解析objc_msgSend
`objc_msgSend`是使用汇编写的，在`objc-msg-arm64.s`和`objc-msg-x86_64.s`中，有对应实现。由于自己能力不够，读不懂汇编，但是从里面的注释可以看出来，在`objc_msgSend`中，先会去缓存中查找方法，如果缓存没有找到，会调用`class_lookupMethodAndLoadCache3`这个函数。`class_lookupMethodAndLoadCache3`这个函数在runtime源码中是有实现的：

```
/***********************************************************************
* _class_lookupMethodAndLoadCache.
* Method lookup for dispatchers ONLY. OTHER CODE SHOULD USE lookUpImp().
* This lookup avoids optimistic cache scan because the dispatcher
* already tried that.
**********************************************************************/
IMP _class_lookupMethodAndLoadCache3(id obj, SEL sel, Class cls)
{
    return lookUpImpOrForward(cls, sel, obj, 
                              YES/*initialize*/, NO/*cache*/, YES/*resolver*/);
}
```
我们看到它调用了`lookUpImpOrForward`这个函数，并且传递cache参数为NO，因为调用`class_lookupMethodAndLoadCache3`之前，已经进行了cache查找，没有找到才调用`_class_lookupMethodAndLoadCache3`，所以这里传NO是避免再次查找缓存。
具体的汇编代码分析请看[神经病院Objective-C Runtime住院第二天——消息发送与转发](https://www.jianshu.com/p/4d619b097e20)。
对objc_msgSend的分析有两种情况，一种是有缓存，一种是无缓存。我们向TestObject发送两次相同的消息就可以模拟出来。代码如下：

```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        TestObject *object = [TestObject new];
        [object sayHello];
        [object sayHello];
    }
    return 0;
}
```
### 无缓存
我们先在第一次调用方法这一行打断点：
![](http://ohg2bgicd.bkt.clouddn.com/1526974679.png)
当到达这个断点之后在`lookUpImpOrForward`函数打断点，确保查找的消息是`sayHello`。
![](http://ohg2bgicd.bkt.clouddn.com/1526974777.png)
当断点到达`lookUpImpOrForward`这个函数，左侧调用栈如下图：
![](http://ohg2bgicd.bkt.clouddn.com/1526974866.png)
从图中可以看出来`objc_msgSend`并没有直接调用`class_lookupMethodAndLoadCache3`，而是通过`_objc_msgSend_uncached`调用。下面我们就来分析下`lookUpImpOrForward`这个函数。这个才是实际干活的。
#### lookUpImpOrForward
由于`lookUpImpOrForward`涉及很多的函数调用，我们将它分成几个部分来分析：

1. 无锁的缓存查找。
2. 加锁。
3. 如果类没有实现或初始化，实现或初始化。
4. 在当前类的缓存中查找。
5. 在当前类的方法列表中查找。
6. 在父类的缓存和方法列表中查找。
7. 没有找到实现，尝试方法解析。
8. 使用消息转发。
9. 解锁返回实现。

下面，我们来看下这个过程的具体实现
##### 无锁的缓存查找

```
runtimeLock.assertUnlocked();

// Optimistic cache lookup
if (cache) {
    imp = cache_getImp(cls, sel);
    if (imp) return imp;
}
```
由于通过`class_lookupMethodAndLoadCache3`调用`lookUpImpOrForward`时传入cache为`NO`，所以这一步的缓存查找直接略过了。
##### 加锁

```
// runtimeLock is held during isRealized and isInitialized checking
// to prevent races against concurrent realization.

// runtimeLock is held during method search to make
// method-lookup + cache-fill atomic with respect to method addition.
// Otherwise, a category could be added but ignored indefinitely because
// the cache was re-filled with the old value after the cache flush on
// behalf of the category.
runtimeLock.read();
```
通过注释我们可以看到，`runtimeLock`需要在`isRealized`和`isInitialized`检查过程中加锁，避免并发实现过程中的资源竞争(其实锁这些东西我也不太明白，后面学操作系统时会补一下这方面知识)。
##### 如果类没有实现或初始化，实现或初始化

```
if (!cls->isRealized()) {
        // Drop the read-lock and acquire the write-lock.
        // realizeClass() checks isRealized() again to prevent
        // a race while the lock is down.
        runtimeLock.unlockRead();
        runtimeLock.write();

        realizeClass(cls);

        runtimeLock.unlockWrite();
        runtimeLock.read();
    }

if (initialize  &&  !cls->isInitialized()) {
    runtimeLock.unlockRead();
    _class_initialize (_class_getNonMetaClass(cls, inst));
     runtimeLock.read();
     // If sel == initialize, _class_initialize will send +initialize and 
    // then the messenger will send +initialize again after this 
    // procedure finishes. Of course, if this is not being called 
    // from the messenger then it won't happen. 2778172
}
```
在Objective-C运行时初始化过程中，会通过`realizeClass()`为类分配可读写的`class_rw_t`。`_class_initialize`会调用类的`+initialize`方法。以后会分析`+initialize`方法。
##### 在当前类的缓存中查找

```
imp = cache_getImp(cls, sel);
if (imp) goto done;
```
这个很简单，直接调用`cache_getImp`函数，从类的`cache`属性中查找，找到实现直接执行`goto done`。我们先看下`done`的实现。很简单，直接解锁，返回实现。`cache_getImp`也是使用汇编写的。感兴趣可以去看[Objective-C 消息发送与转发机制原理](http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)。其原理就是在类的cache中查找实现并返回。因为我们这个小节是模拟无缓存消息发送，所以这一步查找不到，继续下一步。

``` 
done:
runtimeLock.unlockRead();
return imp;
```
##### 在当前类的方法列表中查找

```
// Try this class's method lists.
{
    Method meth = getMethodNoSuper_nolock(cls, sel);
    if (meth) {
        log_and_fill_cache(cls, meth->imp, sel, inst, cls);
        imp = meth->imp;
        goto done;
    }
}
```
通过调用`getMethodNoSuper_nolock`函数查找方法的结构体指针`method_t *`

```
static method_t *
getMethodNoSuper_nolock(Class cls, SEL sel)
{
    runtimeLock.assertLocked();

    assert(cls->isRealized());
    // fixme nil cls? 
    // fixme nil sel?

    for (auto mlists = cls->data()->methods.beginLists(), 
              end = cls->data()->methods.endLists(); 
         mlists != end;
         ++mlists)
    {
        method_t *m = search_method_list(*mlists, sel);
        if (m) return m;
    }

    return nil;
}

```
因为类对象中`method_array_t`是一个二维数组，所以循环`method_array_t`之后还需要`search_method_list`这个函数去查找对应的`method_t`。

```
static method_t *search_method_list(const method_list_t *mlist, SEL sel)
{
    int methodListIsFixedUp = mlist->isFixedUp();
    int methodListHasExpectedSize = mlist->entsize() == sizeof(method_t);
    
    if (__builtin_expect(methodListIsFixedUp && methodListHasExpectedSize, 1)) {
        return findMethodInSortedMethodList(sel, mlist);
    } else {
        // Linear search of unsorted method list
        for (auto& meth : *mlist) {
            if (meth.name == sel) return &meth;
        }
    }

#if DEBUG
    // sanity-check negative results
    if (mlist->isFixedUp()) {
        for (auto& meth : *mlist) {
            if (meth.name == sel) {
                _objc_fatal("linear search worked when binary search did not");
            }
        }
    }
#endif

    return nil;
}
```
在这个方法中，会判断mlist是否是一个有序列表，如果是有序列表，会使用`findMethodInSortedMethodList`这个函数执行二分查找，如果无序就遍历查找。
如果`getMethodNoSuper_nolock`这个方法找到了`Method`，通过`log_and_fill_cache`将实现加入缓存中。这个操作最后通过`cache_fill_nolock`完成。

```
static void cache_fill_nolock(Class cls, SEL sel, IMP imp, id receiver)
{
    cacheUpdateLock.assertLocked();

    // Never cache before +initialize is done
    if (!cls->isInitialized()) return;

    // Make sure the entry wasn't added to the cache by some other thread 
    // before we grabbed the cacheUpdateLock.
    if (cache_getImp(cls, sel)) return;

    cache_t *cache = getCache(cls);
    cache_key_t key = getKey(sel);

    // Use the cache as-is if it is less than 3/4 full
    mask_t newOccupied = cache->occupied() + 1;
    mask_t capacity = cache->capacity();
    if (cache->isConstantEmptyCache()) {
        // Cache is read-only. Replace it.
        cache->reallocate(capacity, capacity ?: INIT_CACHE_SIZE);
    }
    else if (newOccupied <= capacity / 4 * 3) {
        // Cache is less than 3/4 full. Use it as-is.
    }
    else {
        // Cache is too full. Expand it.
        cache->expand();
    }

    // Scan for the first unused slot and insert there.
    // There is guaranteed to be an empty slot because the 
    // minimum size is 4 and we resized at 3/4 full.
    bucket_t *bucket = cache->find(key, receiver);
    if (bucket->key() == 0) cache->incrementOccupied();
    bucket->set(key, imp);
}
```
为了保证缓存有一个空的位置，当缓存中使用的容量大于总容量的3/4时，会扩充缓存，使缓存的大小翻倍。
>在缓存翻倍的过程中，当前类全部的缓存都会被清空，Objective-C 出于性能的考虑不会将原有缓存的 bucket_t 拷贝到新初始化的内存中。

缓存完成后执行`goto done`返回实现调用。
##### 在父类的缓存和方法列表中查找。

```
 // Try superclass caches and method lists.
    {
        unsigned attempts = unreasonableClassCount();
        for (Class curClass = cls->superclass;
             curClass != nil;
             curClass = curClass->superclass)
        {
            // Halt if there is a cycle in the superclass chain.
            if (--attempts == 0) {
                _objc_fatal("Memory corruption in class list.");
            }
            
            // Superclass cache.
            imp = cache_getImp(curClass, sel);
            if (imp) {
                if (imp != (IMP)_objc_msgForward_impcache) {
                    // Found the method in a superclass. Cache it in this class.
                    log_and_fill_cache(cls, imp, sel, inst, curClass);
                    goto done;
                }
                else {
                    // Found a forward:: entry in a superclass.
                    // Stop searching, but don't cache yet; call method 
                    // resolver for this class first.
                    break;
                }
            }
            
            // Superclass method list.
            Method meth = getMethodNoSuper_nolock(curClass, sel);
            if (meth) {
                log_and_fill_cache(cls, meth->imp, sel, inst, curClass);
                imp = meth->imp;
                goto done;
            }
        }
    }

```
这个过程和上面差不多，只是多了一个迭代父类的过程。和上面的区别是，在父类中找到的`_objc_msgForward_impcache`需要交给当前类来处理。
##### 尝试方法解析器
    
```
 if (resolver  &&  !triedResolver) {
    runtimeLock.unlockRead();
    _class_resolveMethod(cls, sel, inst);
    runtimeLock.read();
    // Don't cache the result; we don't hold the lock so it may have 
    // changed already. Re-do the search from scratch instead.
    triedResolver = YES;
    goto retry;
 }
```
上面这部分代码调用了`_class_resolveMethod`来解析没有实现的方法:

```
void _class_resolveMethod(Class cls, SEL sel, id inst)
{
    if (! cls->isMetaClass()) {
        // try [cls resolveInstanceMethod:sel]
        _class_resolveInstanceMethod(cls, sel, inst);
    } 
    else {
        // try [nonMetaClass resolveClassMethod:sel]
        // and [cls resolveInstanceMethod:sel]
        _class_resolveClassMethod(cls, sel, inst);
        if (!lookUpImpOrNil(cls, sel, inst, 
                            NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
        {
            _class_resolveInstanceMethod(cls, sel, inst);
        }
    }
}
```
先判断当前类是否为元类，如果为元类就调用`_class_resolveClassMethod`，如果不是就调用`_class_resolveInstanceMethod`。我们可以看到，在当前类为元类的时候，最后如果没有找到实现，还会再去调用`_class_resolveInstanceMethod`。

```
static void _class_resolveInstanceMethod(Class cls, SEL sel, id inst)
{
    if (! lookUpImpOrNil(cls->ISA(), SEL_resolveInstanceMethod, cls, 
                         NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
    {
        // Resolver not implemented.
        return;
    }

    BOOL (*msg)(Class, SEL, SEL) = (__typeof__(msg))objc_msgSend;
    bool resolved = msg(cls, SEL_resolveInstanceMethod, sel);

    // Cache the result (good or bad) so the resolver doesn't fire next time.
    // +resolveInstanceMethod adds to self a.k.a. cls
    IMP imp = lookUpImpOrNil(cls, sel, inst, 
                             NO/*initialize*/, YES/*cache*/, NO/*resolver*/);

}

static void _class_resolveClassMethod(Class cls, SEL sel, id inst)
{
    assert(cls->isMetaClass());

    if (! lookUpImpOrNil(cls, SEL_resolveClassMethod, inst, 
                         NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
    {
        // Resolver not implemented.
        return;
    }

    BOOL (*msg)(Class, SEL, SEL) = (__typeof__(msg))objc_msgSend;
    bool resolved = msg(_class_getNonMetaClass(cls, inst), 
                        SEL_resolveClassMethod, sel);

    // Cache the result (good or bad) so the resolver doesn't fire next time.
    // +resolveClassMethod adds to self->ISA() a.k.a. cls
    IMP imp = lookUpImpOrNil(cls, sel, inst, 
                             NO/*initialize*/, YES/*cache*/, NO/*resolver*/);
}
```
这两个方法其实就是判断当前类是否实现了`+ (BOOL)resolveInstanceMethod:(SEL)sel`和`+ (BOOL)resolveClassMethod:(SEL)sel`这两个方法。如果实现了用objc_msgSend去调用。在调用解析方法后还会使用`lookUpImpOrNil`去判断是否添加上`sel`对应的`IMP`。

```
IMP lookUpImpOrNil(Class cls, SEL sel, id inst, 
                   bool initialize, bool cache, bool resolver)
{
    IMP imp = lookUpImpOrForward(cls, sel, inst, initialize, cache, resolver);
    if (imp == _objc_msgForward_impcache) return nil;
    else return imp;
}
```
其中`_objc_msgForward_impcache`是一个汇编程序入口，作为缓存中消息转发的标记。上面这个函数就是查找有没有对应`SEL`的实现，不包括转发。
调用完`_class_resolveMethod`后，会跳转到retry标签，重新查找。只不过不会再次调用`_class_resolveMethod`这个方法了，因为将`triedResolver`标记为了`YES`。
##### 使用消息转发

```
// No implementation found, and method resolver didn't help. 
// Use forwarding.

imp = (IMP)_objc_msgForward_impcache;
cache_fill(cls, sel, imp, inst);
```
上面注释写的很清楚了，没有找到方法实现，并且方法解析不帮忙，只能使用转发了。将`imp`设置为`_objc_msgForward_impcache`，加入缓存。
###### 转发过程
因为我们把`_objc_msgForward_impcache`返回，因为`_objc_msgForward_impcache`是一个汇编标记。如果是`_objc_msgForward_impcache`这个标记，就会去调用`_objc_msgForward`或`_objc_msgForward_stret`，从这两个函数名来看，一个是有返回值的函数，一个是无返回值。

```
MESSENGER_START
nop
MESSENGER_END_SLOW
	
jne	__objc_msgForward_stret
jmp	__objc_msgForward

END_ENTRY __objc_msgForward_impcache
	
	
ENTRY __objc_msgForward
// Non-stret version

movq	__objc_forward_handler(%rip), %r11
jmp	*%r11

END_ENTRY __objc_msgForward


ENTRY __objc_msgForward_stret
// Struct-return version

movq	__objc_forward_stret_handler(%rip), %r11
jmp	*%r11

END_ENTRY __objc_msgForward_stret
```
从汇编中可以看出`_objc_msgForward`和`_objc_msgForward_impcache`分别会去调用`__objc_forward_handler`和`__objc_forward_stret_handler`

```
#if !__OBJC2__

// Default forward handler (nil) goes to forward:: dispatch.
void *_objc_forward_handler = nil;
void *_objc_forward_stret_handler = nil;

#else

// Default forward handler halts the process.
__attribute__((noreturn)) void 
objc_defaultForwardHandler(id self, SEL sel)
{
    _objc_fatal("%c[%s %s]: unrecognized selector sent to instance %p "
                "(no message forward handler is installed)", 
                class_isMetaClass(object_getClass(self)) ? '+' : '-', 
                object_getClassName(self), sel_getName(sel), self);
}
void *_objc_forward_handler = (void*)objc_defaultForwardHandler;

#if SUPPORT_STRET
struct stret { int i[100]; };
__attribute__((noreturn)) struct stret 
objc_defaultForwardStretHandler(id self, SEL sel)
{
    objc_defaultForwardHandler(self, sel);
}
void *_objc_forward_stret_handler = (void*)objc_defaultForwardStretHandler;
#endif
```
从上面代码可以看出，Objc2.0之前，`_objc_forward_handler`和`_objc_forward_stret_handler`都是`nil`，新版本中，都是`objc_defaultForwardHandler`。在`objc_defaultForwardHandler`中，我们看到了最熟悉的那段话`unrecognized selector sent to instance`。
其实handler默认就是打印日志，触发crash，要实现消息转发，就是手动替换默认的handler。`objc_setForwardHandler`实现替换。

```
void objc_setForwardHandler(void *fwd, void *fwd_stret)
{
    _objc_forward_handler = fwd;
#if SUPPORT_STRET
    _objc_forward_stret_handler = fwd_stret;
#endif
}
```
有关对`objc_setForwardHandler`的调用，以及之后的消息转发调用栈，可以参考[Objective-C 消息发送与转发机制原理](http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)。
我们直接来看这个过程：
>1. 先调用`forwardingTargetForSelector`方法获取新的`target`作为`receiver`重新执行`selector`，如果返回的内容不合法（为`nil`或者跟旧`receiver`一样），那就进入第二步。
2. 调用`methodSignatureForSelector`获取方法签名后，判断返回类型信息是否正确，再调用 `forwardInvocation`执行`NSInvocation`对象，并将结果返回。如果对象没实现`methodSignatureForSelector`方法，进入第三步。
3. 调用 doesNotRecognizeSelector 方法

杨萧玉大神总结了一张图，在这里贴一下。
![](http://ohg2bgicd.bkt.clouddn.com/1527064101.png)
>图片来自[Objective-C 消息发送与转发机制原理](http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)

#### 运行结果
通过`lookUpImpOrForward`，我们就完成了第一次方法调用。缓存中没有，但是在`TestObject`类对象方法列表中找到了对应的实现。
![](http://ohg2bgicd.bkt.clouddn.com/1527056409.png)
### 缓存命中
如果调用方法时，缓存命中了，那么情况就和上面不一样了。我们来看下。
在第二次调用`sayHello`时，我们打个断点。
![](http://ohg2bgicd.bkt.clouddn.com/1527057108.png)
当断点走到这里，我们在`lookUpImpOrForward`中打断点，然后继续运行，发现`lookUpImpOrForward`中的断点没有走，直接打印了结果。前面我们也说过，在调用`lookUpImpOrForward`这个方法前，objc_msgSend已经访问过了类的缓存，没有找到实现，才通过`class_lookupMethodAndLoadCache3`这个函数调用的`lookUpImpOrForward`。如何验证下objc_msgSend在发送消息过程中先进行了缓存查找呢？
#### 验证
我们在调用前，手动加入错误缓存，看会有什么情况出现。
![](http://ohg2bgicd.bkt.clouddn.com/1527060788.png)
在上面，第一次调用前，我们手动加入缓存。可以看到在调用`objc_msgSend`时会去使用错误的缓存去实现。由此可以推断，在`objc_msgSend`确实查找了缓存。这个可以很强力的说明了`objc_msgSend`会先去缓存中查找实现。

# 总结
通过解析objc_msgSend，比较形象的了解了Objective-C中消息发送的过程，其中有一些汇编代码。虽然过程很痛苦，但是收获也是很大。虽然汇编看的似懂非懂，重点是理解这个过程。其实这个过程还是很直观的。

1. 查找缓存
2. 查找当前类的缓存和方法列表
3. 查找父类的缓存和方法列表
4. 动态方法解析
5. 消息转发

这两篇文章都比较虚，后面会来看一下，我们在工作中可以利用runtime来干些什么。毕竟实用才是王道

# 参考
* [从源代码看 ObjC 中消息的发送](https://github.com/Draveness/analyze/blob/master/contents/objc/%E4%BB%8E%E6%BA%90%E4%BB%A3%E7%A0%81%E7%9C%8B%20ObjC%20%E4%B8%AD%E6%B6%88%E6%81%AF%E7%9A%84%E5%8F%91%E9%80%81.md)
* [神经病院Objective-C Runtime住院第二天——消息发送与转发](https://www.jianshu.com/p/4d619b097e20)
* [Objective-C 消息发送与转发机制原理](http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)
* [Obj-C Optimization: The faster objc_msgSend](http://www.mulle-kybernetik.com/artikel/Optimization/opti-9.html)
* [Objective-C Runtime Programming Guide](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Introduction/Introduction.html)

