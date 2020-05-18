---
layout: post
title: WKWebView离线包开发小记
date: 2020-05-18
tags: WebView
category: iOS
---

随着项目里面Web页面内容越来越多，H5的加载速度变得越来越重要。在H5同学提出需求前就看过有关优化的文章。当时没有细致的去看，本来以为做起来轻车熟路，但是真做起来坑还是不少。下面记录一下整个优化过程。
## 优化思路
一个WebView加载的过程大约有以下几个步骤(内容来自于[腾讯Bugly的文章](https://mp.weixin.qq.com/s/0OR4HJQSDq7nEFUAaX1x5A)):
> 初始化 WebView -> 请求页面 -> 下载数据 -> 解析HTML -> 请求 js/css 资源 -> dom 渲染 -> 解析 JS 执行 -> JS 请求数据 -> 解析渲染 -> 下载渲染图片

![](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/05/18/15895445172664.jpg)
在dom渲染前，Web页面都是白屏，所以优化的思路就是优化dom渲染前的时间耗时。从上图可以看出优化主要集中优化以下两个阶段
1. WebView的初始化阶段，这个阶段可以采用类似UITableViewCell的复用池机制来解决。
2. 初始化后到渲染前的阶段的优化，请求页面、下载数据、请求js/css资源这些阶段可以通过提前下载H5资源到本地，加载H5的时候加载本地资源来优化。

## 优化WebView初始化阶段
WebView的初始化也需要一段时间，[美团]()已经测量过WebView加载需要的时间了，这里直接引用一下：
![-w1193](https://nightwish.oss-cn-beijing.aliyuncs.com/2020/05/18/15897743113037.jpg)
优化WebView初始化耗时的方式是在app启动之后启动一个WebView的复用池，创建一些备用的WebView，至于创建几个要根据app的使用情况来定，主要代码如下：

```objc
- (instancetype)init
{
	self = [super init];
	if (self) {
		self.capacity = 3;
		self.reuseableWebViewSet = [NSMutableSet new];
		self.visiableWebViewSet = [NSMutableSet new];
		[self prepareWebView];
	}
	return self;
}
- (void)prepareWebView {
	dispatch_async(dispatch_get_main_queue(), ^{
		for (NSUInteger i = 0; i < self.capacity; i++) {
			WBWebView *webView = [[WBWebView alloc] initWithFrame:CGRectZero configuration:[self defaultConfiguration]];
			[self.reuseableWebViewSet addObject:webView];
		}
	});
}

// 获取WebView
- (WBWebView *)getReuseWebViewForHolder:(id)holder {
	if (!holder) {
		return nil;
	}
	[self tryCompactWekHolders];
	WBWebView *webView = nil;
	dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
	if (self.reuseableWebViewSet.count > 0) {
		webView = [self.reuseableWebViewSet anyObject];
		[self.reuseableWebViewSet removeObject:webView];
		[self.visiableWebViewSet addObject:webView];
		[webView willReuse];
	} else {
		webView = [[WBWebView alloc] initWithFrame:CGRectZero configuration:[self defaultConfiguration]];
		[self.visiableWebViewSet addObject:webView];
	}
	webView.holdObject = holder;
	dispatch_semaphore_signal(self.semaphore);
	return webView;
}
// 用完之后回收WebView
- (void)recycleReuseWebView:(WBWebView *)webView {
	if (!webView) {
		return;
	}
	dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
	if ([self.visiableWebViewSet containsObject:webView]) {
		[webView endReuse];
		[self.visiableWebViewSet removeObject:webView];
		[self.reuseableWebViewSet addObject:webView];
	}
	dispatch_semaphore_signal(self.semaphore);
}
// 清除WebView复用池
- (void)clearReuseWebViews {
	dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
	[self.reuseableWebViewSet removeAllObjects];
	dispatch_semaphore_signal(self.semaphore);
}
```
WebView复用池写完后，发现了两个问题。其中一个是进入一个H5页面退出后，再次进入另一个H5页面调用webView的goBack方法会返回第一次进入的H5页面么。另外一个是如果WebView没有销毁，sessionStorage是不会清空的，如果两次进入的是同一个H5页面，而且H5用sessionStorage做一些业务逻辑的话，会有一些奇怪的bug。所以在一个WebView结束复用的时候，需要做一些操作来清除一些东西来保证进入复用池的WebView和一个新建的WebView一样，主要代码如下:

```objc
#define kWKWebViewReuseUrlString @"WBCustomScheme://reuse-webView"
- (void)willReuse {
	[self _clearBackForwardList];
}
- (void)endReuse {
	self.holdObject = nil;
	self.scrollView.delegate = nil;
	[self stopLoading];
	self.navigationDelegate = nil;
	self.UIDelegate = nil;
	[self clearWebSessionStorage];
	[self _clearBackForwardList];
	[self loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:kWKWebViewReuseUrlString]]];
	[self.configuration.userContentController removeScriptMessageHandlerForName:@"WebInteractiveWithNative"];
	[self.configuration.userContentController removeAllUserScripts];
}

// 清空页面历史记录
- (void)_clearBackForwardList {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	SEL sel = NSSelectorFromString([NSString stringWithFormat:@"%@%@%@%@", @"_re", @"moveA", @"llIte", @"ms"]);
	if ([self.backForwardList respondsToSelector:sel]) {
		[self.backForwardList performSelector:sel];
	}
#pragma clang diagnostic pop
}

// 清空sessonStorage
- (void)clearWebSessionStorage {
	NSSet *websiteDataTypes = [NSSet setWithArray:@[
													WKWebsiteDataTypeSessionStorage
													]];

	NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
	[[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
											   modifiedSince:dateFrom
										   completionHandler:^{}];
}

- (BOOL)canGoBack {
	if ([self.backForwardList.backItem.URL.absoluteString caseInsensitiveCompare:kWKWebViewReuseUrlString] == NSOrderedSame ||
		[self.URL.absoluteString isEqualToString:kWKWebViewReuseUrlString]) {
		return NO;
	}
	
	return [super canGoBack];
}

- (BOOL)canGoForward {
	if ([self.backForwardList.forwardItem.URL.absoluteString caseInsensitiveCompare:kWKWebViewReuseUrlString] == NSOrderedSame ||
		[self.URL.absoluteString isEqualToString:kWKWebViewReuseUrlString]) {
		return NO;
	}
	
	return [super canGoForward];
}
```
继承`WKWebView`写了一个子类，通过在`willReuse`和`endReuse`调用`_clearBackForwardList`方法来清空历史记录可以解决前面说的第一个问题，为了使回收后的WebView在重新用的时候更像一个新建的WebView，在`endReuse`时加载了一个`WBCustomScheme://reuse-webView`这样的url，这个其实是加载了一个类似前端`about:blank`这样的的页面。后面说离线包的时候再说怎么通过加载这个url可以加载一个空页面。这里多说一句，`_clearBackForwardList`这个方法调用了WebKit的私有api，关于审核风险也咨询了用的一些人，详情见[这个issue](https://github.com/dequan1331/HybridPageKit/issues/44#event-3326186119)
在`endReuse`时，调用`clearWebSessionStorage`这个方法可以清空WebView的sessionStorage，解决前面提到的第二个问题。复用池的坑就这么多，下面来看一下离线包的实现。
## 离线包优化
前面提到了，请求页面、下载数据、请求js/css资源这些阶段可以通过加载本地资源实现，也就是离线包的方式。离线包的核心技术是拦截，市面上有多种拦截方案，个有优劣。这次优化使用的是`WKWebView`自定义scheme的拦截方式来实现的离线包。
原理也很简单，WKWebView初始化时允许注册ShemeHandler，当WebView加载自定义的scheme的url时，SchemeHandler就可以拦截这个请求。拦截后可以检测所需要的资源是否在本地，在本地的话加载本地资源给WebView渲染。不在本地的话手动发一个请求去请求资源交给WebView渲染。关于post请求会被拦截的问题，可以让前端同学在js里面发post请求时不用相对路径，写死请求路径即可。SchemeHandler的代码如下:

```objc
// MARK: - WKURLSchemeHandler
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask  API_AVAILABLE(ios(11.0))
{
	self.holdURLSchemeTasks[urlSchemeTask.description] = @(YES);
	NSDictionary *headers = urlSchemeTask.request.allHTTPHeaderFields;
	NSString *accept = headers[@"Accept"];
	if (!accept || !urlSchemeTask.request.URL.absoluteString) {
		return;
	}
	NSString *requestUrlString = urlSchemeTask.request.URL.absoluteString;
	if (accept.length > 0 && [accept containsString:@"text/html"]) { // HTML拦截
		WBLogDebug(@"WBWebViewCustomURLSchemeHandler-- html = %@", urlSchemeTask.request.URL.absoluteString);
		[self loadLocalFileWithURLSchemeTask:urlSchemeTask];
	} else if ([self isJSOrCSSFile:requestUrlString]) { // JS/CSS拦截
		[self loadLocalFileWithURLSchemeTask:urlSchemeTask];
	} else if (accept.length >= @"image".length && [accept rangeOfString:@"image"].location != NSNotFound) { // image
		[self loadLocalFileWithURLSchemeTask:urlSchemeTask];
	} else {
		[self loadLocalFileWithURLSchemeTask:urlSchemeTask];
	}
}
- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask  API_AVAILABLE(ios(11.0))
{
	self.holdURLSchemeTasks[urlSchemeTask.description] = @(NO);
}

// MARK: - Private Method

// 判断当前资源是否在本地
- (void)loadLocalFileWithURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
	NSString *URLString = urlSchemeTask.request.URL.absoluteString;
	if ([URLString containsString:@"wbcustomscheme"]) {
		URLString = [URLString stringByReplacingOccurrencesOfString:@"wbcustomscheme" withString:@"https"];
	}
	URLString = [[URLString componentsSeparatedByString:@"?"] firstObject];
	EZTuple2 *tuple = [WBServiceWebViewOfflinePackage.service getLocalFileDataForURLString:URLString];
	NSData *data = tuple.first;
	if (data && data.length > 0) {
		WBLogDebug(@"离线包命中缓存");
		[self resendQuestForUrlSchemeTask:urlSchemeTask mimeType:tuple.second requestData:data];
	} else {
		[self requestRemoteForUrlSchemeTask:urlSchemeTask];
	}
}

// 把本地资源作为响应返回给UrlSchemeTask
- (void)resendQuestForUrlSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask mimeType:(NSString *)mimeType requestData:(NSData *)data {
	if (!urlSchemeTask.request.URL) {
		return;
	}
	BOOL isValid = [self.holdURLSchemeTasks[urlSchemeTask.description] boolValue];
	if (!isValid) {
		return;
	}
	NSURLResponse *resp = [[NSURLResponse alloc] initWithURL:urlSchemeTask.request.URL MIMEType:mimeType expectedContentLength:data.length textEncodingName:@"utf-8"];
	[urlSchemeTask didReceiveResponse:resp];
	[urlSchemeTask didReceiveData:data];
	[urlSchemeTask didFinish];
}

// 资源不在本地，请求远程资源
- (void)requestRemoteForUrlSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
	NSString *urlString = [urlSchemeTask.request.URL.absoluteString stringByReplacingOccurrencesOfString:@"wbcustomscheme" withString:@"https"];
	[self.httpSessionManager GET:urlString parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask *_Nonnull task, id _Nullable responseObject) {
		// urlSchemeTask 提前结束，调用实例方法会崩溃
		BOOL isValid = [self.holdURLSchemeTasks[urlSchemeTask.description] boolValue];
		if (!isValid) {
			return;
		}
		if (task.response && responseObject) {
			[urlSchemeTask didReceiveResponse:task.response];
			[urlSchemeTask didReceiveData:responseObject];
			[urlSchemeTask didFinish];
		} else {
			return;
		}
	} failure:^(NSURLSessionDataTask *_Nullable task, NSError *_Nonnull error) {
		// urlSchemeTask 提前结束，调用实例方法会崩溃
		BOOL isValid = [self.holdURLSchemeTasks[urlSchemeTask.description] boolValue];
		if (!isValid) {
			return;
		}
		[urlSchemeTask didFailWithError:error];
	}];
}
```
WebView初始化时需要注册的代码如下:

```objc
if (@available(iOS 11.0, *)) {
		if (![config urlSchemeHandlerForURLScheme:@"WBCustomScheme"]) {
			[config setURLSchemeHandler:[WBWebViewCustomURLSchemeHandler new] forURLScheme:@"WBCustomScheme"];
		}
	}
```
WebView加载url时的代码如下:

```objc
if (@available(iOS 11.0, *)) {
// 这里主要是服务端开关，和当前这个url的资源是否在本地的判断。
		if ([WBServiceWebViewOfflinePackage.service shouldOpenOfflinePackageFeature] && [urlString hasPrefix:@"https"] && [WBServiceWebViewOfflinePackage.service doseOfflinePackageContainUrlString:urlString]) { 
			tmpUrlString = [tmpUrlString stringByReplacingOccurrencesOfString:@"https" withString:@"WBCustomScheme"];
		}
	}
```
这样，整套离线包的实现主要就是这些。离线包主要就一个坑，把https换成自定义的scheme后cookie就不生效了。解决cookie的问题是通过localStorage来解决的，加载WebView时设置localStorage，前端想要获取一些信息就通过localStorage来取。除了cookie这个坑，离线包其他的坑还没遇到。
接下来看一下怎么通过加载`WBCustomScheme://reuse-webView`这个url时加载一个空的H5页面。其实很简单，因为加载这个页面时也是一个自定义的scheme，所以自定义的SchemeHandler可以拦截到请求，然后返回一个空的H5数据给WebView渲染就好了。具体代码如下:

```objc
if ([url.host isEqualToString:@"reuse-webView"]) {
		NSData *responseData = [[self _getWebViewReuseLoadString] dataUsingEncoding:NSUTF8StringEncoding];
		return EZTuple(responseData, @"text/html");
	}
	
	- (NSString *)_getWebViewReuseLoadString{
	return @"<html><head><meta name=\"viewport\" " @"content=\"initial-scale=1.0,width=device-width,user-scalable=no\"/><title></title></head><body></body></html>";
}
```

## 总结
本文主要讲述了在优化时的一些坑，看了一些文章，思路都差不多，但是这些坑都没有涉及到，所以总结一下。

## 参考链接
* [iOS 端 h5 页面秒开优化实践](https://juejin.im/post/5d8da122f265da5b5a7209fa)
* [iOS app秒开H5实战总结](https://juejin.im/post/5cf8ad2af265da1ba77c9465)
* [移动端本地 H5 秒开方案探索与实现](https://mp.weixin.qq.com/s/0OR4HJQSDq7nEFUAaX1x5A)
* [WebView性能、体验分析与优化](https://tech.meituan.com/2017/06/09/webviewperf.html)
* [JXBWKWebView](https://www.jianshu.com/p/97faf098e673)
* [HybridPageKit](https://github.com/dequan1331/HybridPageKit)
