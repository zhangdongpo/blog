---
layout: post
title: 读Objective-C高级编程笔记一——引用计数
date: 2017-08-15 23:27:57
tags: 读书笔记
categories: iOS
---
最近读了《Objective-C高级编程》这本进阶书：
![Objective-C高级编程](https://nightwish.oss-cn-beijing.aliyuncs.com/1503026660.png)。
这本书有三章，我们先来介绍第一章。可以从下图看下第一章的整体结构。
![内存管理](https://nightwish.oss-cn-beijing.aliyuncs.com/1503025584.png)。
<!-- more -->
本篇是第一篇，来写下iOS的内存管理，其实iOS的内存管理无论是ARC还是MRC都是通过引用计数来管理的。每个对象都有一个`retainCount `的属性。当一个对象的`retainCount `为0，就说明没有地方使用该对象了，可以释放了。
我们先看MRC，再看ARC，因为ARC其实是建立在MRC之上的，只是是编译器在合适的地方代替我们插入了内存管理的代码。

### 引用计数

前面我们一直在说引用计数，到底什么是引用计数呢？下图可以表达这个概念。
![照明管理](https://nightwish.oss-cn-beijing.aliyuncs.com/1503068536.png)
在Objective-C中，对象就相当于上图中的灯。使用计数功能计算需要照明的人数，办公室的灯得到了很好的管理。同样，使用引用计数功能，对象也能够得到很好的管理，这就是Objective-C的内存管理，如下图所示：
![引用计数的内存管理](https://nightwish.oss-cn-beijing.aliyuncs.com/1503071113.png)

### 内存管理思考方式

下面我们来了解下引用计数式的内存管理思考方式。
- 自己生成的对象，自己持有。
- 非自己生成的对象，自己也能持有。
- 不再需要自己持有的对象时释放。
- 非自己持有的对象不能释放。
其实引用计数式的内存管理思考方式仅此而已。除了上文提到的“生成”，“持有”，“释放”三种对对象的操作方式，还有一种“废弃”方式，各个词表示的Objective-C方法如下表：
| 对象操作                     | Objective-C方法
| 生成并持有对象         | alloc/new/copy/mutableCopy方法
| 持有对象                     | retain方法
| 释放对象                     | release方法
| 废弃对象                     | dealloc方法
这些有关Objective-C内存管理的方法，实际上不包括在该语言中，而是包含在Cocoa框架中用于iOS，OS X应用开发。Cocoa中Foundation框架库的`NSObject`类负责内存管理的职责。Objective-C内存管理的alloc/retain/release/dealloc方法分别指代NSObject累的alloc方法，retain方法，release方法和dealloc方法。
下面我们来详细了解下上面提到的内存管理思考方式。

#### 自己生成的对象自己持有

使用以下名称开头的方法名意味着自己生成并持有对象：
- alloc
- new
- copy
- mutableCopy
例如：
	id obj = [[NSObject alloc]init]
这句话就自己生成并持有了对象，另外使用NSObject的new类也能自己生成并持有对象。`[NSObject new]`和`[[NSObject alloc]init]`是完全一样的。
同样的copy和mutableCopy方法也可以自己生成并持有对象。两者的差异就是copy生成的是不可变对象，而mutableCopy生成的是可变对象。
另外，下列名称也意味着自己生成并持有对象：
- allocMyObject
- newThisObject
- copyThis
- mutableCopyYourObject
但是对象一下名称，即使使用alloc/new/copy/mutableCopy名称开头，也并不属于同一类方法。
- allocate
- newer
- copying
- mutableCopyed
反正只要记得上面说的几个方法是自己生成并持有对象就好。

#### 非自己生成的对象自己也能持有

因为是非自己生成并持有，所以该对象不是自己生成的，所以我们来使用上面说的几个方法外的方法试试。非常可以说明问题的就是NSMutableArray的array类方法：
	id obj = [NSMutableArray array];
上面代码中，其实obj是不持有生成的这个对象的，记得以前我还傻傻的以为这个和上面的一样会持有对象，结果一运行程序，直接崩溃了。我们可以使用retain方法来持有这个对象。

#### 不再需要自己持有的对象时释放

自己持有的对象，一旦不再需要，持有者有义务释放，使用release方法释放。无论是自己生成并持有的对象，还是通过retain方法持有的对象，在不需要时都需要通过release方法释放。下面我们来看下通过某个方法生成对象并将其return给调用方和调用`[NSMutableArray array] `方法取得对象的区别：

```-(id)allocObject
	{
	   id obj = [[NSObject alloc]init];
	   return obj;
	}
```

像上面这样，原封不动的返回生成并持有的对象，就能让调用方也持有该对象。和前面说的自己生成并持有没区别，为什么`[NSMutableArray array] `不行呢，下面我们来看下具体实现：

```-(id)object
	{
	  id obj = [[NSObject alloc]init];
	  [obj autorelease];
	  return obj;
	}
```

因为在这个里面使用了autorelease方法，使用这个方法，可以使取得的对象存在，但是自己并不持有该对象。autorelease提供了使对象在超出制定生存范围时能够自动并正确的释放，后面我们会对autorelease进行详细的说明。下图是autorelease和release的区别:
![autorelease和release的区别](https://nightwish.oss-cn-beijing.aliyuncs.com/1503112187.png)

#### 无法释放非自己持有的对象

这点就非常好理解了，不是自己持有的对象自己干嘛要去释放，像下面代码就会导致程序崩溃：

```id obj = [ [NSObject alloc]init];
[obj release];
[obj release];
```

在执行过一次release之后，obj指向的对象已经释放，再执行release肯定要访问到对象，访问已经废弃的对象时就boom了。
上面的四项内容就是内存管理的思考方式，下面我们来介绍下操作引用计数的函数实现。

### alloc/retain/release/dealloc实现

#### GNUstep的实现

GNUstep是Cocoa框架的互换框架。所以理解了GNUstep就相当于理解了Cocoa框架的实现。
我们先来看下alloc方法的实现：

```+(id)alloc
	{
	       return [self allocWithZone:NSDefaultMallocZone()];
	}
	+(id)allocWithZone:(NSZone *)z
	{
	      return NSAllocateObject(self,0,z);
	}
```

通过上面两个方法，我们看到其实最根本调用的是NSAllocateObject这个方法。下面我们来看看NSAllocateObject这个方法的实现：

```struct obj_layout
	{
	    NSUInteger retained;
	}
	
	inline id NSAllocateObject(Class aClass,NSUInteger extraBytes,NSZone *zone)
	{
	     int size = 计算容纳对象大小的size；
	     id new = NSZoneMalloc(zone,size);//分配对象内存
	     memset(new,0,size);//初始化内存
	     new = (id) &  ((struce obj_layout *) new)[1];
	}
```

NSZone是为了防止内存碎片化引入的结构，想要了解更多，那只能自己看书了，这里我们只介绍alloc方法操作引用计数的实现。
下面是去掉NSZone之后的源代码：
	
```struct obj_layout
	{
	    NSUInteger retained;
	}
	+(id)alloc
	{
	     int size = sizeof(struct obj_layout) + 对象的大小；
	     struct obj_layout *p = (struct obj_layout *)calloc(1,size); //将引用计数写入对象内存头部
	     return (id)(p + 1); //返回对象的初始地址
	}
```

alloc方法用struct `obj_layout`中的retained来保存引用计数，并将其写入对象内存头部，然后返回对象的初始地址。如下图所示：
![alloc返回对象的内存图](https://nightwish.oss-cn-beijing.aliyuncs.com/1503327298.png)
对象的引用计数可以通过retainCount来获得：

```id obj = [ [NSObject alloc]init];
	NSLog(@"retainCount = %d",[obj retainCount]);
	//显示为retainCount = 1；
执行alloc后对象的retainCount为1，下面我们来用GNUstep来看下原因：
	-(NSUInteger)retainCount
	{
	      return NSExtraRefCount(self) + 1;
	}
	inline NSUInteger NSExtraRefCount(id anObject)
	{
	    return ((struct obj_layout *)anObject)[-1].retained;  //这里这个-1，我是这么理解的，先把对象转成obj_layout类型，然后减去1个obj_layout指针大小，正好就指向obj_layout。下面的图更加明确的表示：
	}
```

![通过对象访问头像内存头部](https://nightwish.oss-cn-beijing.aliyuncs.com/1505032536.png)
因为分配时全部为0，所以retained为0.由 NSExtraRefCount(self)  + 1得出，retainCount为1.可以推测出，retain方法其实是让retained变量+1，二release方法使retained变量减1。
下面我们正好来看下retain方法的GNUstep实现：

	
```-(id)retain
	{
	    NSIncrementExtraRefCount(self);
	    return self;
	}
	inline void  NSIncrementExtraRefCount(id anObject)
	{
	    if(((struct obj_layout *)anObject)[-1].reatined == UINT_MAX - 1)
	        [NSException raise: NSInternalInconsistencyException format:@"NSIncrementExtraRefCount() asked to increment too far"];
	    ((struct obj_layout *)anObject)[-1].retained++;
	}
```

虽然写入了当retained变量超出最大值是发生的异常代码，但是实际上执行的是retained变量+1的代码。同样，release实例方法执行-1的代码，并且当引用计数变量为0时执行dealloc方法，下面我们来看下release的实现：

```-(void)release
	{
	    if(NSDecrementExtraRefCountWasZero(self))
	        [self dealloc]
	}
	BOOL  NSDecrementExtraRefCountWasZero(id anObject)
	{
	    if(((struct obj_layout *)anObject)[-1].retained == 0){
	        return YES;
	    }else{
	        ((struct obj_layout *)anObject)[-1].retained--;
	        return NO;
	    }
	}
```

和预想一样，release方法就是当retained变量大于0时减一，等于0时调用dealloc方法，废弃对象。（这里需要注意，我们调用retainedCount时，其实是retained变量+1，如果不是这样的话，那么会出现alloc后需要调用两次release才能dealloc）。下面我们来看下dealloc的实现：

```-(void)dealloc
	{
	    NSDeallocateObject(self);
	}
	inline void NSDeallocateObject(id anObject)
	{
	    struct obj_layout *o =  &((struct obj_layout *)anObject)[-1];
	    free(0);
	}
```

以上就是alloc/retain/release/dealloc在GNUstep中的实现。具体的总结：
- 在OC对象中存有引用计数这一整数值。
- 调用alloc和retain方法引用计数+1.
- 调用release方法引用计数-1.
- 当引用计数值为0时，调用dealloc方法释放对象。


#### 苹果的实现

因为NSObject类的源代码没有公开，所以我们利用lldb大概追溯其大概的实现过程。在alloc方法上打断点，可以看到程序的执行顺序如下：
1. +alloc；
2. +allocWithZone
3. class\_createInstance
4. calloc
alloc方法首先调用allocWithZone:方法，这个和GNUstep是相同的。后面调用class\_createInstance方法，这个方法可以在objc4的runtime/objc-runtime-new.mm中找到实现。然后再调用calloc来分配内存块。
retainCount/retain/release又是怎样实现的呢，我们用上面同样的方法可以看到retainCount/retain/release所执行的函数：


```-retainCount
	__CFDoExternRefOperation
	CFBasicHashGetCountOfKey
	
	-retain
	__CFDoExternRefOperation
	CFBasicHashAddValue
	
	-release
	__CFDoExternRefOperation
	CFBasicHashRemoveValue
	CFBasicHashRemoveValue返回0事，-release调用dealloc
```

通过看上面三个方法，都调用了\_\_CFDoExternRefOperation函数，这个函数的实现我们可以在CFRuntime.c中找到实现，下面是简化后的\_\_CFDoExternRefOperation函数实现：

```int __CFDoExternRefOperation(uintptr_t op,id obj)
	{
	    CFBasicHashRef table = 取得对象的散列表(obj)；
	    int count;
	    switch(op){
	        case OPERATION_retainCount:
	        count = CFBasicHashGetCountOfKey(table,obj);
	        return count;
	
	        case OPERATION_retain:
	        CFBasicHashAddValue(table,obj);
	        return obj;
	
	        case OPERATION_release:
	        cont = CFBasicHashRemoveValue(table,obj);
	        return count == 0;
	    }
	}
```

\_\_CFDoExternRefOperation函数按retainCount/retain/release操作进行分发，调用不同的函数，我们可以推断，NSObject类的retainCount/retain/release实例方法也许就如下面所示：

```-(NSUInteger)retainCount
	{
	    return (NSUInteger) \_\_CFDoExternRefOperation(OPERATION_retainCount,self);
	}
	-(id)retain
	{
	    return (id) \_\_CFDoExternRefOperation(OPERATION_retain,self);
	}
	-(void)release
	{
	    return  \_\_CFDoExternRefOperation(OPERATION_release,self);
	}

```

可以从\_\_CFDoExternRefOperation函数实现来看，苹果的实现大概就是采用散列表来管理引用计数。
![通过散列表管理引用计数](https://nightwish.oss-cn-beijing.aliyuncs.com/1503473841.png)
GNUstep将引用计数保存在对象占用内存块头部的变量中，而苹果则是保存在引用计数表中。
通过内存块头部管理引用计数的好处：
- 写的代码少。
- 能统一管理引用计数和对象内存块。
通过散列表管理引用计数的好处如下：
- 对象内存块的分配不需要考虑内存块头部。
- 引用计数表中存有内存块地址，可以从各个记录追溯到对象的内存块。
追溯内存块在调试时有着很重要的作用，即使出现故障导致对象占用的内存块损坏，只要引用计数表没坏，就可以确定内存块的位置。另外，再利用工具检测内存泄漏时，引用计数表的各记录也有助于检测个对象的持有者是否存在。

### autorelease

说到内存管理，就不得不提autorelease，autorelease看上去很像ARC，但实际上它更类似于C语言中自动变量的特性，当自动变量超过其作用域，该自动变量就会被自动废弃。autorelease会像C语言的自动变量那样来对待对象的实例。当超出其作用域时，对象实例的release方法被调用。另外，同C语言的自动变量不同的是，我们可以设定变量的作用域。
autorelease的具体使用方法如下：
1. 生成并持有NSAutoreleasePool对象；
2. 调用已分配对象的autorelease实例方法；
3. 废弃NSAutoreleasePool对象；
![NSAutoreleasePool对象的生命周期](https://nightwish.oss-cn-beijing.aliyuncs.com/1504753622.png)
NSAutoreleasePool对象的生存周期就相当于C语言变量的作用域，对于所有吊用过autorelease方法的对象，在废弃NSAutoreleasePool对象时，都将调用release方法。在Cocoa框架中，NSRunLoop对NSAutoreleasePool对象进行生成，持有和废弃处理。因此，我们不一定非得使用NSAutoreleasePool对象来进行开发工作。
尽管如此，但是在大量产生autorelease对象时，只要不废弃NSAutoreleasePool对象，那么生成的对象就不会释放，因此有时会产生内存不足的现象。典型的例子就是读入大量图像的同时改变其尺寸。图像文件读入到NSData对象，并从中生成UIImage对象，改变对象尺寸后生成新的UIImage对象。这种情况下，就会大量产生autorelease的对象。

```for(int i = 0; i < 图像数；i++){
	    //读入图像大量产生autorelease对象
	}
像上面这种情况，有必要在适当的地方生成，持有或废弃NSAutoreleasePool对象。
	for(int i = 0;i < 图像数；i++){
	    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	    //读入图像
	    [pool drain];
	    通过drain，autorelease的对象被遗弃release。
	}
```

另外，Cocoa框架中有很多类方法用于返回autorelease对象，比如NSMutableArray类的arrayWithCapacity类方法。
`id array = [NSMutableArray arrayWithCapacity:1];`
上面的代码等同于一下的源代码。
`id array = [[[NSMutableArray array]initWithCapacity:1]autorelease];`

### autorelease实现

#### GNUstep实现

我们先来看下GNUstep的实现:

```	-(id)autorelease
	{
	    [NSAutoreleasePool addObject:self];
	}
```

autorelease方法本质就是调用NSAutoreleasePool的addObject类方法。下面我们来看下NSAutoreleasePool类的实现，由于NSAutoreleasePool类的源代码比较复杂，我们假象一个简化的源代码进行说明。

```	+（void）addObject:（id）anObj
	{
	    NSAutoreleasePool *pool = 取得正在使用的NSAutoreleasePool对象；
	    if（pool ！= nil）{
	        [pool addObject:anObj];
	    }else{
	        NSLog（@"NSAutoreleasePool对象非存在在状态下吊用autorelease"）;
	    }
	}
```

addObject类方法调用正在使用的NSAutoreleasePool对象的addObject实例方法。如果嵌套生成或持有NSAutoreleasePool对象，理所当然会使用最内侧的对象。下面来看下addObject实例方法的实现。

```-（void）addObject：（id）anObj
	{
	    [array addObject:anObj];
	}
```

实际的GNUstep使用的是连接列表，同在NSMutableArray对象中添加对象是一样的。
如果调用NSObject类的autorelease实例方法，该对象被追加到正在使用的NSAutoreleasePool对象中的数组里。
下面我们看下drain方法废弃正在使用NSAutoreleasePool对象的过程。

```-（void）drain
	{
	    [self dealloc];
	}
	-（void）dealloc
	{
	    [self emptyPool];
	    [array release];
	}
	-（void）emptyPool
	{
	    for(id obj in array){
	        [obj release];
	    }
	}
```

虽然调用了好几个方法，但可以确定对于数组中的所有对象都调用了release方法。

#### 苹果的实现

可以通过objc4的runtime/NSObject.mm来看苹果的autorelease实现。

```class AutoreleasePoolPage
	{
	    static inline void *push()
	    {
	        相当于生成或持有NSAutoreleasePool类对象；
	    }
	    static inline void pop(void *token) 
	    {
	        相当于废弃NSAutoreleasePool类对象；
	        releaseAll();
	    }
	    static inline id autorelease(id obj)
	    {
	        这个相当于NSAutoreleasePool类的addObject类方法
	        AutoreleasePoolPage *autoreleasePoolPage = 取得正在使用的AutoreleasePoolPage实例；
	        autoreleasePoolPage->add(obj)；
	    }
	    id *add(id obj)
	    {
	        将对象追加到内部数组中；
	    }
	    void releaseAll()
	    {
	        调用内部数组中对象的release方法；
	    }
	};
	void *
	objc_autoreleasePoolPush(void)
	{
	    return AutoreleasePoolPage::push();
	}
	void
	objc_autoreleasePoolPop(void *ctxt)
	{
	    AutoreleasePoolPage::pop(ctxt);
	}


```
我们可以看下我们再使用NSAutoreleasePool时对应代码的实现：

```NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	/*等同于objc_autoreleasePoolPush()*/
	id obj = [[NSObject alloc]init];
	[obj autorelease];
	/*等同于objc_autorelease()*/
	[NSAutoreleasePool showPools];
	//将NSAutoreleasePool的状况输出到控制台。
	[pool drain];
	/*等同于objc_autoreleasePoolPop(pool)*/
```

另外， 不能autorelease NSAutoreleasePool对象。

### ARC

实际上“引用计数式内存管理”的本质在ARC中并没有改变，ARC只是自动帮助我们处理了“引用计数”的相关部分。所以MRC的内存管理思考方式在ARC下也是可行的。只是在源代码的记述方法上稍有不同。想要了解这些变化就需要理解ARC中追加的所有权声明（其实就是所有权修饰符）。

#### 所有权修饰符

Objective-C中为了处理对象，可将变量类型定义为id类型或各种对象类型。所谓对象类型就是指向NSObject这样的Objective-C类的之神，例如“NSObject \*”。id类型用于隐藏对象类型的类名部分，相当于C语言中常用的void\*.
ARC中，id类型和对象类型同C语言其他类型不同，其类型必须附加所有权修饰符，一共有四种：
- \_\_strong
- \_\_weak
- \_\_unsafe\_\_unretained
- \_\_autorelease
下面分别来看下这四种修饰符。

##### \_\_strong

ARC中所有id类型和对象类型的默认修饰符是\_\_strong。下面通过代码来看下\_\_strong的应用：

```id obj = [[NSObject alloc]init];
	id __strong obj = [[NSObject alloc]init];
	//这两种在ARC下是等效的。
```

上面两种写法看不出\_\_strong有什么作用，我们通过下面的代码来看下。
	
```{
	    //自己生成并持有对象
	    id __strong obj = [[NSObject alloc]init];
	}
	    //超出作用域，强引用失效，自动释放自己持有的对象
	//上面的代码和下面在MRC环境的代码等效
	{
	    id obj = [[NSObject alloc]init];
	    [obj release];
	}

```
如上面的代码所示，附有\_\_strong修饰符的变量obj在超出其变量作用域时，强引用失效，释放其持有的对象。所以\_\_strong的作用就是持有对象，持有的意思就是会导致对象的引用计数+1，当变量指向其他对象或超过作用域后，会释放其持有的对象，对象的引用计数-1。所以通过\_\_strong修饰符，不必再次键入retain或者release，完美的满足了内存管理的思考方式。

##### \_\_weak

看起来好像通过\_\_strong就能完美的进行内存管理，但是遗憾的是，仅仅通过\_\_strong是不能解决有些重大问题的，比如“循环引用”，什么时候会循环引用呢，我们举个例子：

```	@interface Test : NSObject
	{
	    id __strong obj_;
	}
	-(void)setObject:(id __strong)obj;
	@end
	@implementation Test
	-(id)init
	{
	    self = [super init];
	    return self;
	}
	-(void)setObject:(id)obj
	{
	    obj_ = obj;
	}
	@end
以下的代码就会发生循环引用：
	{
	    id test0 = [[Test alloc]init];//test0持有对象A
	   id test1 = [[Test alloc]init];//test1持有对象B
	         [test0 setObject:test1];//对象B的实例变量持有对象A
	         [test1 setObject:test0];//对象A的实例变量持有对象B
	}   
	//超出作用域test0释放对象A的引用，此时持有对象A的是对象B的实例变量
	//test1释放对对象B的引用，此时持有对象B的是对象A的实例变量
	//这样就发生了内存泄露（这里解释下内存泄露，内存泄露就是本该释放的对象没有释放，还占用着内存。记得刚开始学习的时候看到内存泄露这个名词不明白什么是内存泄露。）
	```
	
像上面这种是两个对象间的循环引用，也可能会出现自己对自己的循环引用如下面的代码：

```id test = [[Test alloc]init];
[test setObject:test];
```

讲了这么多问题，那到底怎么才能避免循环引用呢，看到\_\_strong就会意识到还有\_\_weak，和strong相对应，\_\_weak不持有对象，也就是不会导致对象的引用计数+1。来看下面的代码：

```id __weak obj = [[NSObject alloc]init];
//使用weak修饰的变量不持有对象
	//对象立即被释放。
```

我们可以通过\_\_weak来改变上面的循环引用问题，就是用下面的这种方式来声明实例变量

```
{
	   id __weak obj_;
}
```

\_\_weak还有一个优点，就是持有的对象被废弃，变量自动会置为nil，像这样可以通过使用\_\_weak来避免循环应用，还可以通过检查附有\_\_weak修饰符变量是否为nil来判断对象是否被废弃。（PS: \_\_weak只能在iOS4以上版本使用，在iOS4以下版本用\_\_unsafe\_\_unretain代替）。

##### \_\_unsafe\_unretained

\_\_unsafe\_unretained和\_\_weak很类似，都不会导致对象的引用计数+1，下面我们看看他们两个有什么不同。

```id __unsafe_unretained obj1;
	        {
	            id __strong ojb0 = [[NSObject alloc]init];//obj0持有对象
	            obj1 = ojb0;//obj1既不持有对象强引用也不持有弱引用
	            NSLog(@"A:%@",obj1);
	        }
	    //超出obj0作用域，强引用失效，对象无持有者，废弃对象
	        NSLog(@"B:%@",obj1);
	    //打印结果
	    A:<NSObject: 0x100203700>
	    B:<NSObject: 0x100203700>
	    //obj1所指向的对象已经废弃，所以发生野指针。
```

所以使用\_\_unsafe\_unretained和\_\_weak的区别就是某些情况下会发生野指针。那么在什么时候使用\_\_unsafe\_unretained呢，就上上面说的一样，在iOS4之前使用，不过这种情况已经很少啦。

##### \_\_autoreleasing

我们知道在ARC有效时不能调用对象的autorelease实例方法，也不能使用NSAutoreleasePool类，这样一来，虽然autorelease无法直接使用，但实际上，ARC有效时autorelease功能是起作用的。下面通过代码来看下如何在ARC下使用autorelease。

```@autoreleasepool {
	            id __autoreleasing obj = [[NSObject alloc]init];
	        }
```

![ARC和MRC比较](https://nightwish.oss-cn-beijing.aliyuncs.com/1504884931.png)
从上图可以看到这两种是等价的，也就是我们可以在ARC中使用@ autoreleasepool和\_\_autoreleasing来使用autorelease。
但是显式的附加\_\_autoreleasing和显示的附加\_\_strong一样罕见。我们通过实例来看下为什么非显式的使用\_\_autoreleasing修饰符也可以。
1. 如果不是以alloc/new/copy/mutableCopy方法名开头的创建对象的方法，那么自动将返回值的对象注册到autoreleasepool。（ps：init方法返回值对象不注册到autoreleasepool）。比如下面代码取得的对象就是autoreleasepool中的对象。


```	@autoreleasepool {       
				 id __strong obj = [NSMutableArray array];
			 }
```

我们看下[NSMutableArray array]具体实现：

``` +(id)array	
		{
			id obj = [[NSMutableArray alloc]init];
		'' return obj;//由于return使得对象超出其作用域，但是作为函数返回值，编译器自动将其注册到autoreleasepool。
		}
```

1. 访问\_\_weak修饰符变量时，实际上必定要访问到autoreleasepool的对象


```	    id __weak obj = obj0;
NSLog(@"class = %@",[obj class]);
//上面代码和下面代码相同
id __weak obj = obj0;
id __autoreleasing tem = obj;
NSLog(@"class = %@",[tem class]);
```

为什么访问附有\_\_weak修饰符变量时必须访问注册到autoreleasepool的对象呢，因为\_\_weak修饰符只持有弱引用，而在访问引用对象过程中，该对象有可能被废弃。如果把要访问对象注册到autoreleasepool中，那么@autoreleasepool块结束前都能确保对象存在。
1. 最后一个可非显示使用\_\_autoreleasing修饰符的就是二级指针了。比如我们声明一个NSObject \*\*obj,他的默认修饰符就是\_\_autoreleasing。那么在什么时候使用呢，比如我们为了获取详细的错误信息，需要传入NSError对象的指针，而不是使用函数返回值。如以下代码：


```-(BOOL)performOperationWithError:(NSError \*\*)error;
		-(BOOL)performOperationWithError:(NSError \* \_\_autoreleasing\*)error;
	//上面两种写法等价，默认的修饰符为\_\_autoreleasing
```

参数中持有NSError对象指针的方法，虽然为了响应结果，需要生成NSError类对象，但是也必须符合内存管理的思考方式，就是除了alloc/new/copy/mutableCopy外其他方法的返回值对象都会注册到autoreleasepool。
另外通过以下代码看看我们在使用二级指针时应该注意什么：

```NSError *error = nil;
NSError **perror = &error;
//上面的代码会报错，因为所有权修饰符必须一致。所以应该改成下面这样的
NSError *error = nil;
NSError * __strong *perror = &error;
//再来看下函数参数的使用
NSError __strong *error = nil;
[obj performOperationWithError:&error];
//因为所有权修饰符必须一致，但是这个不会报错，是因为编译器自动将代码转换成下面的样子
NSError __strong *error = nil;
NSErro __autoreleasing *tmp = error;
[obj performOperationWithError:&tmp];
//当然也可以显示的指定参数的所有权修饰符为__strong，但是为了在使用参数取得对象时符合内存管理的思考方式，不建议这样做。
```

在显示指定\_\_autoreleasing修饰符时，必须注意对象要为自动变量(包括局部变量，函数以及方法参数)，还有无论何时，我们都应该去使用@autoreleasepool块结构去代替NSAutoreleasepool，这样提高了程序的可读性，并且@ autoreleasepool在MRC环境下也有效。调试用的\_objc\_autoreleasePoolPrint()函数无论什么环境都可以调试注册到autoreleasepool上的对象。

#### ARC规则

在ARC下，我们需要遵守一定的规则
- 不能使用retain/release/retainCount/autorelease
这个应该不用解释，因为是自动引用计数，所以这些手动的就不能写啦！
- 不能使用NSAllocateObject/NSDeallocateObject
 ARC下一般通过调用alloc方法生成并持有对象，不能使用上面的两个函数生成和释放对象。
- 需要遵守内存管理的方法命名规则
使用alloc/new/copy/mutableCopy开头方法返回对象时必须返回给调用方所应当持有的对象，并且以init开头的方法必须是实例方法，并且必须返回对象，init方法只是对alloc的对象做了一些初始化。
- 不能显示调用dealloc
无论什么环境，只要对象的引用计数为0就是调用该对象的dealloc方法。但是在ARC环境下，我们在dealloc方法内不需要调用[super dealloc],因为ARC会自动处理。如果调用，编译器会报错。
- 使用@autoreleasepool代替NSAutoreleasePool
在ARC环境下，使用NSAutoreleasePool会报错.
- 不能使用NSZone
无论什么环境，Runtime已经单纯忽略了NSZone。
- 对象类型不能作为C语言的结构体成员
因为C语言没有办法管理结构体成员的生命周期，要把对象类型变量加入到结构体中，可以通过转换为void\*或者附加\_\_unsafe\_unretained。因为\_\_unsafe\_unretained修饰的变量不属于编译器内存管理对象。
- 显式转换id和void\*
在MRC下，像下面代码这样将id变量强制转换成void\*变量并不会出问题。

```id obj = [[NSObject alloc]init];
void *p = obj;
//更近一步用void*变量赋值给id变量中，调用其实例方法，运行时也不会有问题。
id o = p;
[o release];
```
但是在ARC环境下上面代码就会引起错误。因为id类型或对象类型赋值给void\*或者逆向赋值时都需要进行特定的转换。如果只是想单纯地赋值，可以使用“\_\_bridge”转换。如下面代码所示：

```id obj = [[NSObject alloc]init];
 void *p = (__bridge void *)(obj);
 id o = (__bridge id)p;
但是像上面这样转换为void\*类型，其安全性与赋值给\_\_unsafe\_unretained修饰符相近，甚至会更低。如果转换时不注意对象的所有者，会因为野指针导致程序崩溃。
\_\_bridge转换中还有另外两种转换，分别是“\_\_bridge\_retained”和“\_\_bridge\_transfer”。\_\_bridge\_retained的作用如下面代码所示：
//ARC
id obj = [[NSObject alloc]init];
void *p = (__bridge_retained  void *)(obj);
//MRC
id obj = [[NSObject alloc]init];
void *p = (__bridge_retained  void *)(obj);
[(id)p retain];
通过\_\_bridge\_retained转换，obj和p同时持有对象。
\_\_bridge\_transfer转换和\_\_bridge\_retained提供相反的动作。通过代码来看下：
//ARC   
id obj = (__bridge_transfer id)p;
//MRC
id obj = (id)p;
[obj retain];
[(id)p release];
```
可以看到当p赋值给obj后立马就释放了对对象的引用。
如果使用以上两种变换，那么不使用id或对象类型变量也可以生成，持有，以及释放对象，但是ARC中并不推荐使用这种方法，这些转化多数在Objective-C和Core Foundation对象之间的相互转换。（ps:Core Foundation对象主要使用在C语言编写的Core Foundation框架中，并使用引用计数的对象，Core Foundation框架中的release/retain分别是CFRelease/CFRetain，Core Foundation对象和Objective-C对象区别很小，不同的就是由哪个框架生成。无论由哪个框架生成，一旦生成后便能在不同框架中使用。Foundation框架对象可以由Core Foundation框架API释放，反之亦然。两种类型的对象互相转换不需要额外的CPU资源，因此也被称为“免费桥”（Toll-Free Bridge））。
以下函数可用于Objective-C对象和Core Foundation对象之间的相互转换。

```
CFTypeRef CFBridgingRetain(id X){
	            return (__bridge_retained CFTypeRef)X;
	        }
id CFBridgingRelease(CFTypeRef X){
	            return (__bridge_transfer id)X;
	        }
```
下面我们来看下具体使用：

``` CFMutableArrayRef cfObject = NULL;
{
	//变量obj持有对生成并持有对象的强引用
	id obj = [[NSMutableArray alloc]init];
	//通过CFBridgingRetain将对象CFRetain赋值给变量cfObject
	cfObject = CFBridgingRetain(obj);
	CFShow(cfObject);
	printf("retain count = %d\n",CFGetRetainCount(cfObject));
	//对象的引用计数为2
}
	//obj超过作用域，强引用失效引用计数为1
	printf("retain count after the scope = %d\n",CFGetRetainCount(cfObject));
	CFRelease(cfObject);
	//因为将对象CFRelease，所以引用计数为0，将对象废弃。
我们再看下使用\_\_bridge转换代替CFBridgingRetain或\_\_bridge\_retained转换时，源代码会变成什么样呢？
	CFMutableArrayRef cfObject = NULL;
	{
	   //变量obj持有对生成并持有对象的强引用
	   id obj = [[NSMutableArray alloc]init];
	   //因为通过__bridge转换时不改变对象的持有状况，所以引用计数为1
	   cfObject = （__bridge CFMutableArrayRef)obj;
	   CFShow(cfObject);
	   printf("retain count = %d\n",CFGetRetainCount(cfObject));
	//对象的引用计数为1
	}
	//obj超过作用域，强引用失效引用计数为0，将对象废弃，此后访问对象出错！野指针
	printf("retain count after the scope = %d\n",CFGetRetainCount(cfObject));
	CFRelease(cfObject);

```
由此可知，CFBridgingRetain或者\_\_bridge\_retained是不可或缺的。
下面我们反过来看下，这次由Core Foundation的API生成并持有对象，将该对象作为NSMutableArray对象来处理。
```{
	//变量cfObject生成并持有对象。
	CFMutableArrayRef cfObject = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
	//cfObject对象引用计数为1
	 printf("retain count = %d\n",CFGetRetainCount(cfObject));
	//通过CFBridgingRelease赋值，变量obj持有对象强引用的同时，对象通过CFRelease释放
	id obj = CFBridgingRelease(cfObject);
   printf("retain count after the cast = %d\n",CFGetRetainCount(cfObject));
	
	 //对象的引用计数为1
}
	//obj超过作用域，强引用失效引用计数为0，将对象废弃。
下面我们看看通过\_\_bridge代替会出现什么情况：
{
	 //变量cfObject生成并持有对象。
	 CFMutableArrayRef cfObject = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
	 //cfObject对象引用计数为1
	 printf("retain count = %d\n",CFGetRetainCount(cfObject));
	//通过__bridge赋值，变量obj持有对象强引用
	id obj = (__bridge id)cfObject;
	 printf("retain count after the cast = %d\n",CFGetRetainCount(cfObject));
	
	//对象的引用计数为2
}
	//obj超过作用域，强引用失效引用计数为1，发生内存泄露。
由上面可以看出必须通过CFBridgingRetain/CFBridgingRelease或者\_\_bridge\_retained/\_\_bridge\_transfer转换。

```

#### 属性

ARC时，Objective-C的属性也会发生变化，需要我们加上属性修饰符来声明属性，我们看下属性修饰符和所有权修饰符的对应关系：
![属性声明的属性与所有权修饰符对应的关系](https://nightwish.oss-cn-beijing.aliyuncs.com/1505010817.png)
以上各种属性赋值给指定的属性中就相当于赋值给附加各属性对应的所有权修饰符变量中。只有copy不是简单赋值，它赋值是通过NSCopying接口的copyWithZone：方法复制赋值源所生成的对象。

#### 数组

ARC所有权修饰符在修饰静态修饰符变量时和修饰对象类型变量是相同的。我们主要来看下修饰动态数组时的使用。将附有\_\_strong修饰符的变量作为动态数组使用时，根据不同的需要我们可以选择NSMutableArray，NSMutableDictionary，NSMutableSet等Foundation框架的容器。这些容器会恰当的持有追加的对象并帮助我们管理这些对象。但是在C语言的动态数组中也可以使用附有\_\_strong修饰符的变量，知识必须遵守一些事项，以下按顺序说明。
1. 声明动态数组：
```
id __strong *array = nil;
	//因为id *默认为__autoreleasing，所以这里显示指定__strong
```
2. 使用calloc函数确保想分配的附有\_\_strong修饰符变量的容量占有块
		
```
array = (id __strong *)calloc(entries, sizeof(id));
		//这里分配了entries个所需的内存块。由于使用附有__strong修饰符的变量前必须先将其初始化为nil，所以这里使用使分配区域初始化为0的calloc函数来分配内存。不使用calloc函数，在用malloc函数分配内存后可用memset等函数将内存填充为0，但是，像下面的代码是非常危险的，以内malloc函数分配的内存区域没有被初始化为0，因此nil会被赋值给__strong修饰符并且被赋值了随机地址的变量中，从而释放一个不存在的对象，所以在分配内存是使用calloc函数。
		array = (id __strong *)malloc(sizeof(id) * entries);
		    for (NSUInteger i = 0; i < entries; i++) {
		        array[i] = nil;
		    }
```
3. 通过calloc函数分配的动态数组就能想静态数组一样使用
		`array[0] = [[NSObject alloc]init];`
但是在动态数组中操作附有\_\_strong修饰符的变量和静态数组有很大区别，需要自己释放元素，不能只使用free函数释放数组，数组各元素也需要释放。因为在静态数组中，编译器能够根据变量的作用域自动插入释放赋值对象的代码，但是在动态数组中，编译器不能确定数组的声明周期所以无法处理。我们需要像下面代码所示去释放数组元素：
```  
for NSUInteger i = 0; i < entries; i++) {
	  array[i] = nil;
}
free(array);
```
同初始化时注意事项相反，即使使用memset函数将内存填充为0也不会释放数组元素对象，只会引起内存泄露，必须赋值为nil。另外使用memcpy和realloc函数重新分配内存块也会有危险，由于数组元素赋值的对象有可能被保留在内存中或是重复被废弃，所以这两个函数也禁止使用。最好不要用\_\_autoreleasing修饰符去修饰动态数组。由于\_\_unsafe\_unretained修饰在编译器内存管理对象之外，所以它与void \*类型一样，只能作为C语言的指针类型来使用。

#### ARC实现

苹果官方说明中称，ARC是由编译器进行内存管理的，其实编译器是无法完全胜任的，还需要Runtime的协助。

##### \_\_strong实现

我们通过clang可以看到程序的汇编输出，通过汇编输出和objc4库的源代码就能够知道程序是怎么工作的，我们来看下下面代码是怎么工作的：

```{
 id __strong obj = [[NSObject alloc]init];
}
//编译器的模拟代码如下：
id obj = objc_msgSend(NSObject,@selector(alloc));
objc_msgSend(obj,@selector(init));
objc_release(obj);
通过上面代码可以看到编译器自动调用了release。下面再来看下不是通过alloc/new/copy/mutableCopy方法创建对象会是什么情况：
{
	id __strong obj = [NSMutableArray array];
}
	//编译器模拟代码
id obj = objc_msgSend(NSMutableArray,@selector(array));
objc_retainAutoreleasedReturnValue(obj);
objc_release(obj);

```
这里稍有不同的是objc\_retainAutoreleasedReturnValue函数是什么呢，其实objc\_retainAutoreleasedReturnValue函数主要用于最优化程序运行。他的意思就是持有的对象是返回注册到autoreleasepool中对象的方法，或是函数的返回值。与objc\_retainAutoreleasedReturnValue函数相对的函数是objc\_autoreleaseReturnValue.下面我们来看下他的用法：

```+(id)array
{
	 return [[NSMutableArray alloc] init];
}
//转换后的源代码使用了objc\_autoreleaseReturnValue
+(id)array
{
	id obj = objc_msgSend(NSMutableArray.@selector(alloc));
	objc_msgSend(obj,@selector(init));
	return objc_autoreleaseReturnValue(obj);
}
```

objc\_autoreleaseReturnValue函数会检查使用该函数的方法或函数调用方的执行命令列表，如果方法或函数的调用方在调用了方法或函数后紧接着调用了objc\_retainAutoreleasedReturnValue函数，那么就不将返回的对象注册到autoreleasepool中，而是直接传递到方法或函数的调用方。（ps:在objc4版本493.9中，只能在OS X64位中最优化）如下图所示:
![省略了autoreleasepool注册](https://nightwish.oss-cn-beijing.aliyuncs.com/1505025357.png)

##### \_\_weak实现

我们先来看下\_\_weak的功能：
- 若附有\_\_weak修饰符的变量所引用的对象被废弃，自动置为nil。
- 使用\_\_weak修饰符的变量，即是使用注册到autoreleasepool中的对象。


```		id __weak obj1 = obj;
//转换后的源代码
id obj1 ;
objc_initWeak(&obj1,obj);
objc_destroyWeak(&obj1);

```
objc\_initWeak函数初始化附有\_\_weak修饰符的变量，在变量作用域结束时通过objc\_destroyWeak函数释放变量。那么objc\_initWeak又是怎么初始化的呢？我们看下面代码：
```obj1 = 0;
objc_storeWeak(&obj1,obj)；
//objc_initWeak首先将obj1初始化为0，然后再通过objc_storeWeak函数赋值给obj1。
//objc_destoryWeak函数将0作为参数调用objc_storeWeak函数，释放变量
bjc_storeWeak(&obj1,0)；
```
objc\_storeWeak函数把第二个参数的赋值对象作为键值，将第一参数的附有\_\_weak修饰符的变量的地址注册到weak表中，如果第二个参数为0，则把变量的地址从weak表中移除。
下面我么来看下对象废弃的动作：
1. objc\_release
2. 引用计数为0所以执行dealloc
3. \_objc\_rootDealloc
4. object\_dispose
5. objc\_destructInstance
6. objc\_clear\_deallocating
对象被废弃是调用objc\_clear\_deallocating的动作如下：
1. 从weak表中获取废弃对象的地址为键值的记录。
2. 将包含在记录中的所有附有\_\_weak修饰符变量的地址，赋值为nil
3. 从weak表中删除该记录。
4. 从引用计数表中删除废弃对象的地址为键值的记录。
根据上面的步骤，前面说的如果附有\_\_weak修饰符变量所引用的对象被废弃，则将nil赋值给该变量这一功能被实现，但是如果大量使用附有\_\_weak修饰符的变量，则会消耗响应的CPU资源。我们只在需要避免循环引用是使用\_\_weak修饰符。
下面我么来验证第二个功能：使用\_\_weak修饰符的变量即是使用注册到autoreleasepool中的对象。

```id __weak obj1 = obj;
NSLog(@"%@",obj1);
//该源代码转换成如下形式
id obj1;
objc_initWeak(&obj1,obj);
id tmp = objc_loadWeakRetained(&obj1);
objc_autorelease(tmp);
NSLog(@"%@",tmp);
objc_destroyWeak(&obj1);

```
相比于前面的情形，增加了objc\_loadWeakRetained函数和objc\_autorelease函数，这些函数调用动作如下：
1. objc\_loadWeakRetained函数取出附有\_\_weak修饰符变量所引用的对象，并且retain。
2. objc\_autorelease函数将对象注册到autoreleasepool中。
如果大量使用附有\_\_weak修饰符的变量，注册到autoreleasepool的对象也会大量增加，因此在使用附有\_\_weak修饰符的变量，最好先暂时赋值给\_\_strong修饰符的变量后再使用。

##### \_\_autoreleasing实现

```
@autoreleasepool {
    id __autoreleasing obj = [[NSObject alloc]init];
}
	//转换成如下形式
id pool = objc_autoreleasePoolPush();
id obj = objc_msgSend(NSObject,@selector(alloc));
objc_msgSend(obj,@selector(init));
objc_autorelease(obj);
objc_autoreleasePoolPop(pool);
```
这与苹果的autorelease实现中的说明完全相同。我们再来看下在autoreleasepool块中使用注册到autoreleasepool中的对象会如何。
```
@autoreleasepool {           
	id __autoreleasing obj = [NSMutableArray array];
}
	//转换成如下形式
	id pool = objc_autoreleasePoolPush();
	id obj = objc_msgSend(NSMutableArray,@selector(array));
	objc_retainAutoreleasedReturnValue(obj);
	objc_autorelease(obj);
	objc_autoreleasePoolPop(pool);
```
虽然持有对象的方法从alloc变为objc\_retainAutoreleasedReturnValue函数，但注册autoreleasepool的方法没有改变，仍是objc\_autorelease函数。

#### 引用计数

前面我们一直都在说的是引用计数管理的思考方式，没有过多的去关注引用计数的值，我们可以通过\_objc\_rootRetainCount(id obj)函数获取引用计数的值，但实际上并不能够完全信任该函数取得的值。对于已经释放的对象以及不正确的对象地址，有时也会返回1。另外在多线程中使用对象的引用计数数值，因为存有竞态条件的问题，所以取得的数值不一定完全可信。虽然在调试中\_objc\_rootRetainCount(id obj)很有用，但最好在了解其所具有的问题的基础上来使用。

### 感悟

平常我们写代码可能不会去想这些东西，但是我们一定需要了解这些东西，因为一旦出现问题，这些东西会让我们在分析问题，处理问题上更加得心应手。了解了一个东西，我们再去使用它。就像使用第三方库时，我们应该先了解再去使用，不应该只是看看他的API直接就用了，这样我们一点收获都没有。我们也没必要重复的去造轮子，了解了就可以拿来用。知其然，知其所以然，这一点是我们应该做到的。



