---
layout: post
title: Ghost S1复刻 & Hackintosh
date: 2020-06-03
tags: Hackintosh
category: Hackintosh
---

由于年初疫情的原因，去年装的黑苹果终于可以用来干点正事了(关于去年的黑苹果配置可以看前一篇文章)，在家办公一直使用黑苹果来开发。疫情渐渐远去，慢慢开始复工，复工后又开始用19年13寸中配的MBP办公。没有对比就没有伤害，没用黑苹果之前也没感觉这台笔记本会这么慢，编译一次项目2分钟的时长实在忍不了。经过权衡决定组装一台黑苹果在公司用。

这次装电脑又两个需求，一个是在公司用，另外一个是老家没电脑，每次放假回家都很无聊，所以希望这台电脑可以放假带回家用。有了便携这个需求，所以主机肯定是ITX的机型了。组ITX主机需要先去选机箱，然后根据机箱找合适的配件。正好同事推荐了Ghost S1复刻这个机箱，A4机箱，很满意，就是价格略贵。最后还是咬咬牙买了下来。机箱确定了，其他配件就好说了，最后敲定配置如下：


| 配件           | 型号                        | 入手渠道    | 价格   | 备注                                      |
|------------|---------------------------|---------|------|-----------------------------------------|
| 主板         | 技嘉Z370N Wi-Fi             | 闲鱼      | 1000 | Z390 ITX主板价格太高，缩预算选择Z370N，物超所值          |
| CPU        | i5 9600K                  | 淘宝散片    | 1400 | 主板都缩了，CPU也从开始的9700K缩到了9600K，主频够高，就是核数少点 |
| 显卡         | 蓝宝石5500xt                 | 淘宝官方旗舰店 | 1499 | 最便宜的7nm免驱卡，还可以低特效玩点游戏                   |
| 内存         | 海盗船复仇者16G*2 3200Hz        | 闲鱼      | 800  | 和主板一起收的，挺便宜                             |
| SSD        | 西数SN750 500G + SN550 500G | 淘宝      | 1060 | 一块装macOS，一块装Windows玩游戏                  |
| 电源         | 海盗船SF600金牌                | 闲鱼      | 773  | 闲鱼买的全新的，价格还算可以                          |
| WI-FI & 蓝牙 | BCM94360CS2               | 淘宝      | 180  | 免驱                                      |
| 散热器        | 利民AXP90                   | 京东      | 299  | 幸亏买的AXP90没买AXP100，尺寸正好                  |
| 机箱         | Ghost S1 复刻 K总家的          | 闲鱼      | 788  | 全新的要等40天，闲鱼买的二手                         |
| 定制电源线      | YY定制                      | 淘宝      | 180  | 线材长度正好，省了理线流程                           |
| 总计         | 7971                      |         |      |                                         |

## 组装
因为是第一次装ITX主机，所以和同事一起装的，过程还算顺利，照着教程撸了下来。中间大力出奇迹把显卡延长线的卡扣搞折了，不过不影响使用。整机图片如下：
![WechatIMG4](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/06/03/wechatimg4.jpeg)
![WechatIMG2](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/06/03/wechatimg2.jpeg)
![未命名](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/06/03/wei-ming-ming.png)
![WechatIMG1](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/06/03/wechatimg1.jpeg)


## 系统安装
本来以为用OpenCore安装起来很简单，结果下了一个同型号主板的EFI安装，死活不显示进macOS恢复模式的引导。后来从QQ群重新找了一个Z370主板的EFI可以进恢复模式，然后就和安装白苹果的流程一样了。中间在下载镜像时自动重启了，不走安装流程。期间还怀疑EFI有问题，后来怀着试试的态度，又重新走了一遍，顺利安装上了。中间甚至还烧了一个Clover的盘，后来也没用上。OpenCore安装起来很简单，只要找一个可以引导的EFI就可以。相关教程可以看[这个链接](https://github.com/cattyhouse/oc-guide/blob/master/oc-dmg-install.md)。
## 优化系统
系统安装上了，需要自己优化一下，毕竟是别人的EFI。需要自己填入自己生成的机型信息。本来以为用以前那台电脑的EFI就可以，因为以前的电脑也是技嘉的主板，只不过是Z390，都是300系列的。结果被现实啪啪打脸。折腾了一下午才搞好。主要是有个RTC相关的坑。新电脑的主板需要去改这个问题，旧的电脑没有这个问题。以后一定要照着教程好好撸一遍。相关教程可以看[xjn大佬的博客](https://blog.xjn819.com/?p=543)。经过一下午的优化以下功能可以正常工作：
* 核显
* 独显
* 声卡
* WIFI
* 蓝牙
* 主板网卡
* Sidecar
* 电源节能5项
* USB
* 睡眠唤醒
* USBPower充电
* 原生NVRAM启动盘切换
![-w586](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/06/03/15911783260128.jpg)
![-w751](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/06/03/15911784334508.jpg)
![-w893](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/06/03/15911784723872.jpg)
![-w893](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/06/03/15911784930758.jpg)
![-w893](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/06/03/15911785091634.jpg)

## 使用体验
在公司使用了一天的感受是编译速度明显变快，因为本身是iOS开发，所以拿编译工程来举例。以前Clean重新编译平均需要360s，CPU温度高的话500s的时候也有，MBP会在温度高的时候自动降频，降到1GHz。不Clean工程，跑缓存，平均一次编译需要120-150s不等。

换上新主机后Clean重新编译需要120-150s，不Clean平均编译需要70-90s。编译时CPU可以一直满速跑，基本不会掉频。Emmm，极大高了生产力，再也不会有打字都卡的情况了，心情愉悦... [EFI地址](https://github.com/zhangdongpo/Z370N-Wi-Fi-Hackintosh-EFI)

等后面装好Windows再看看游戏效果怎么样。