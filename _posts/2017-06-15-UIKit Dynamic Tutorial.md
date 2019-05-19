---
layout: post
title:  UIKit Dynamic Tutorial
date:   2017-06-15 23:14:22
tags: UI
categories: iOS       
---
这是一篇翻译自Raywenderlich上的文章，[原文](https://www.raywenderlich.com/50197/uikit-dynamics-tutorial)。
<!-- more -->
## What's UIKit Dynamic
&emsp;&emsp;iOS7鼓励我们设计出一个物理动态的效果，这个听起来是一个很艰巨的任务。但是苹果爸爸已经为我们提供了一些非常好用的东西，就是UIKit Dynamics和Motion Effects。
 * UIKit Dynamics 是一个被整合的UIKit中的完整物理引擎。它允许你通过添加一些重力，附件(弹簧），力等行为来创建感觉真实的效果。你只管定义界面元素采用的物理特征，其他的就交给UIKit Dynamics。
 * Motion Effects 就是你创建的一些行为，比如上面提到的那些重力，附件等等的东西。
当把这两个用在一起时，将会很自然的响应自己的行为。
## Getting started
我们新建一个项目，然后在viewController里面加上下面的代码：

```
UIView* square = [[UIView alloc]initWithFrame:CGRectMake(100, 100, 100, 100)];
square.backgroundColor = [UIColor grayColor];
[self.view addSubview:square];

```
上面的代码仅仅是往view上面加了一个灰色的方形view。如下图：![](https://nightwish.oss-cn-beijing.aliyuncs.com/1496933761.png)。
## Adding Gravity
仍然在ViewController.m中，我们添加两个实例变量

```
UIDynamicAnimator* _animator;
UIGravityBehavior* _gravity;
```
然后在`viewDidLoad:`的最下面添加下面代码

```
_animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
_gravity = [[UIGravityBehavior alloc] initWithItems:@[square]];
[_animator addBehavior:_gravity];
```
等下再解释这两行代码，编译运行程序，你会发现灰色方块缓慢的开始加速下落。
![加重力](https://nightwish.oss-cn-beijing.aliyuncs.com/gravity.gif)
在代码中，仅仅添加了两个东西，一个是`UIDynamicAnimator`，一个是`UIGravityBehavior`
* ==UIDynamicAnimator== 是一个UIKit的物理引擎，该类跟踪你添加到这个引擎的不同行为，例如，重力，并且提供整个上下文。当你创建一个`UIDynamicAnimator`实例时，你传入一个view，`UIDynamicAnimator`实例把你传入的view定义为他的坐标系。说了这么多，其实就是创建一个坐标系来执行动画。
* ==UIGravityBehavior== 是一个重力行为的model，添加到相应的viwe上。他将影响和他关联的view。
很多的行为都有很多属性，用到的时候我们可以看他们响应的头文件，这里就不再赘述了。
## Setting boundaries
虽然我们可以看到这个方形的灰色view，他一直再下落，为了让他在屏幕定义的边界内。我们还要在添加一个behavior。
在`ViewController.m`中，添加一个变量：

```
UICollisionBehavior* _collision;
```
然后在`viewDidLoad:`最下面添加下面代码：

```
_collision = [[UICollisionBehavior alloc]
                                      initWithItems:@[square]];
_collision.translatesReferenceBoundsIntoBoundary = YES;
[_animator addBehavior:_collision];
```
上面的代码创建了一个碰撞的行为，它为和他相关联的items定义了边界。但是不是明确的边界，我们需要将他的`_collision.translatesReferenceBoundsIntoBoundary`这个属性设置为YES，这样边界就是animator的referenceview的bounds（`setTranslatesReferenceBoundsIntoBoundaryWithInsets:`这样的方法来设定某一个区域作为碰撞边界，更复杂的边界可以使用addBoundaryWithIdentifier:forPath:来添加UIBezierPath，或者addBoundaryWithIdentifier:fromPoint:toPoint:来添加一条线段为边界，详细地还请查阅文档）。
运行代码，如下图：
![collision](https://nightwish.oss-cn-beijing.aliyuncs.com/collison.gif)

## Handling collision
下面你将要添加一个和方块view相互作用的栅栏。
在`viewDidLoad`中，在添加完方块view后面插入下面代码：
```
UIView* barrier = [[UIView alloc] initWithFrame:CGRectMake(0, 300, 130, 20)];
barrier.backgroundColor = [UIColor redColor];
[self.view addSubview:barrier];
```
跑一下代码，如下图：
![barrier](https://nightwish.oss-cn-beijing.aliyuncs.com/barrier.gif)
WTF，这不是我们想要的结果，但是它给我们提供了一个非常重要的信息：dynamics只作用于和行为相关联的view。关系如下图:
![](https://nightwish.oss-cn-beijing.aliyuncs.com/1497453589.png)
## Making objects respond to collisions
为了让灰色方块和红色的栅栏碰撞，我们把初始化`_collision`的代码改成下面的这样：

```
_collision = [[UICollisionBehavior alloc] initWithItems:@[square, barrier]];
```
碰撞的对象需要知道交互的view，所以我们把barrier加入到数组中。运行一下会发现是下图这样的效果:
![barrierInteract](https://nightwish.oss-cn-beijing.aliyuncs.com/collisonInteract.gif)
碰撞的行为会为它相关联的item形成边界，所以你会看到这样的情况，更新一下前面关系图表变成下面这张图:
![update](https://nightwish.oss-cn-beijing.aliyuncs.com/1497531917.png)
然而，依然不是我们想要的结果，本来红色的栅栏应该是不动的，但是两个物体碰撞，栅栏被撞倒，开始向屏幕底部旋转。
更奇怪的是，栅栏从底部反弹，并不想方块那么沉稳。这是因为重力行为和栅栏无关，这也解释了为什么栅栏在碰撞之前不会下落。
看起来，需要另一个方法来解决问题。由于栅栏不能移动，所以动态引擎不需要知道它的存在。但是如何来检测碰撞呢？
## Invisible boundaries and collisions
还是把初始化`_collision`的函数改回原来那样。然后加入一个边界，代码如下:

```
CGPoint rightEdge = CGPointMake(barrier.frame.origin.x +
                                barrier.frame.size.width, barrier.frame.origin.y);
[_collision addBoundaryWithIdentifier:@"barrier"
                            fromPoint:barrier.frame.origin
                              toPoint:rightEdge];
```
上面的代码添加了一个隐形的边界，这个边界就是红色栅栏的上方。
红色栅栏对于用户可见，但是对于动态引擎是不可见的。边界就恰恰相反了。随着灰色方块的下降，他似乎是和栅栏碰撞，实际上却是和边界碰撞，运行程序结果如下图:
![隐藏边界](https://nightwish.oss-cn-beijing.aliyuncs.com/invisble.gif)
方块现在从边界反弹，然后继续下落的屏幕底部。
到现在为止，UIKit Dynamics变得越来越清晰，只需要几行代码就可以完成相当多的功能。下面展示下动态引擎交互的细节。
## Behind the scenes of collisions
每一个动态行为都有一个`aciton`的属性，它是一个block，动画执行的每一步都会调用这个block，加入下面的代码:

```
_collision.action =  ^{
    NSLog(@"%@, %@", 
          NSStringFromCGAffineTransform(square.transform), 
          NSStringFromCGPoint(square.center));
};
```
上面的代码打印了方块的transform和center。运行下程序，将会看到下面的打印信息:

```
2017-06-15 21:27:53.525 UIDynamicPlayground[883:29136] [1, 0, 0, 1, 0, 0], {150, 150}
2017-06-15 21:27:53.534 UIDynamicPlayground[883:29136] [1, 0, 0, 1, 0, 0], {150, 150}
2017-06-15 21:27:53.550 UIDynamicPlayground[883:29136] [1, 0, 0, 1, 0, 0], {150, 151}
```
这里你可以看到动态引擎是改变view的center，相当于改变它的frame。
一旦方块和栅栏碰撞，会产生下面的信息:

```
2017-06-15 21:27:53.985 UIDynamicPlayground[883:29136] [0.99875026039496628, 0.049979169270678331, -0.049979169270678331, 0.99875026039496628, 0, 0], {152, 251}
2017-06-15 21:27:54.001 UIDynamicPlayground[883:29136] [0.99470018796194981, 0.10281797541510752, -0.10281797541510752, 0.99470018796194981, 0, 0], {153, 250}
```
在这里，可以看到动态引擎正在使用放射变换和frmae的改变来改变方块的位置。
虽然动态引擎对这些确切的值没什么兴趣，但是重要的是它们可以被使用。因此，如果在动态引擎正在运行的时候，我们不能改变这些属性。
动态行为的方法使用在那些遵守`UIDynamicItem`协议的对象上，协议如下:

```
@protocol UIDynamicItem <NSObject>

@property (nonatomic, readwrite) CGPoint center;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readwrite) CGAffineTransform transform;
@end
```
`UIDynamicItem`协议提供了center和transform的读写权限，允许它基于动态内部计算移动item。Dynamics还具有对bounds的读权限，它用于确定item的大小，这样可以在item周边创建碰撞边界，还可以计算当item被施加力时的质量。
这个协议以为着Dynamics并不耦合于UIView。其实还有另外一个UIKit类遵守了这个协议--UICollectionViewLayoutAttributes。它允许Dynamics对collection view的item做动画。
## Collision notifications
前面你添加了一些view和behaviors，下一步你将看到如何接收item碰撞的信息。
我们让`ViewController.m`遵守`UICollisionBehaviorDelegate`协议。
然后把自己设置为`_collision`的代理。实现协议方法：

```
- (void)collisionBehavior:(UICollisionBehavior *)behavior beganContactForItem:(id<UIDynamicItem>)item 
            withBoundaryIdentifier:(id<NSCopying>)identifier atPoint:(CGPoint)p {
    NSLog(@"Boundary contact occurred - %@", identifier);
}
```
代理函数将会在碰撞出现的时候执行，在控制台打印一些信息。
运行程序，方块和红色栅栏会交互，并且看到下面的打印:

```
2017-06-15 22:30:22.393 UIDynamicPlayground[1145:47436] Boundary contact occurred - barrier
2017-06-15 22:30:22.843 UIDynamicPlayground[1145:47436] Boundary contact occurred - barrier
2017-06-15 22:30:23.042 UIDynamicPlayground[1145:47436] Boundary contact occurred - barrier
2017-06-15 22:30:23.842 UIDynamicPlayground[1145:47436] Boundary contact occurred - (null)
2017-06-15 22:30:23.859 UIDynamicPlayground[1145:47436] Boundary contact occurred - (null)
2017-06-15 22:30:24.143 UIDynamicPlayground[1145:47436] Boundary contact occurred - (null)

```
从打印的信息来看，barrier就是我们添加的不可见的碰撞边界，null就是和reference view边界碰撞。
下面我们来添加一下碰撞时的指示，在代理打印代码下面加入下面的代码:

```
UIView* view = (UIView*)item;
view.backgroundColor = [UIColor yellowColor];
[UIView animateWithDuration:0.3 animations:^{
    view.backgroundColor = [UIColor grayColor];
}];
```
上面的代码在碰撞时改变了方块的颜色为黄色，然后再让它渐变成灰色。运行程序效果如下图:
![碰撞指示](https://nightwish.oss-cn-beijing.aliyuncs.com/inditor.gif)
到目前为止，UIKit Dynamics通过根据你项目的边界来进行计算，自动设置item的物理属性(如质量或弹性).接下来，将会看到如何通过`UIDynamicItemBehavior`这个类来控制这些物理属性。
## Configuring item properties
在`viewDidLoad`中，在最下面添加下面的代码:

```
UIDynamicItemBehavior* itemBehaviour = [[UIDynamicItemBehavior alloc] initWithItems:@[square]];
itemBehaviour.elasticity = 0.6;
[_animator addBehavior:itemBehaviour];
```
上面的代码床架了一个item behavior，并且把它和方块相关联。然后把这个行为添加到animator中。elasticity属性控制item的柔软度；值为1.0表示完全弹性碰撞，也就是说，碰撞中没有动能损失，这里讲弹性设置为0.6，就意味着每次碰撞动能衰减0.6.
上面的代码只是改变了item的弹性，然而，behavior有很多属性可以在代码中操作，它们如下:
* elasticity - 决定弹性的碰撞。
* friction - 摩擦，表示活动时的阻力。
* density - 密度，当和size组合时，将会给出一个总体的质量，质量越大，惯性越大。
* resistance - 阻力，决定任何线性运动的阻力，和摩擦的区别是，阻力仅仅作用于滑动。
* angularResistance - 决定旋转运动的阻力
* allowsRotation - 这是一个很有趣的属性，他不和任何物理属性映射，当它的值为NO时，对象不会旋转，不理会任何旋转的力。
## Adding behaviors dynamically
下面我们来看下如何动态的添加和移除behaviors。
我们在`ViewController.m`中添加下面的实例变量:

```
BOOL _firstContact;
```
在碰撞的代理方法最后面添加下面的代码:

```
if (!_firstContact)
{
    _firstContact = YES;
    
    UIView* square = [[UIView alloc] initWithFrame:CGRectMake(30, 0, 100, 100)];
    square.backgroundColor = [UIColor grayColor];
    [self.view addSubview:square];
    
    [_collision addItem:square];
    [_gravity addItem:square];
    
    UIAttachmentBehavior* attach = [[UIAttachmentBehavior alloc] initWithItem:view
                                                               attachedToItem:square];
    [_animator addBehavior:attach];
}
```
上面的代码将会在第一次碰撞时创建另一个方块并且给方块添加重力和碰撞行为。另外，还设置了附件行为，创建了使用虚拟弹簧连接一对对象的效果。
运行程序，当方块集中栅栏的时候，将会看到新的方块，并且两个方块之间还想有东西连接着他们，但是并不会显示出来。效果如下图:
![attachment](https://nightwish.oss-cn-beijing.aliyuncs.com/attachment.gif)。
当然我们除了使用SDK预先定义好的行为外，还可以自定义自己想要的行为。这种定义可以发生在两个层面上，一个是打包官方的行为，另一种完全定义新的计算规则。具体可以参见[喵神的博客](https://onevcat.com/2013/06/uikit-dynamics-started/)。

## 参考
* [Understand UIKit Dynamics](https://www.raywenderlich.com/50197/uikit-dynamics-tutorial)
* [喵神的wwdc总结](https://onevcat.com/2013/06/uikit-dynamics-started/)

