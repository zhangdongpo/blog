---
layout: post
title: iOS 13 ScrollView截图问题记录
date: 2019-09-24
tags: iOS
category: 作问题
---
最近有个需求，需要给TabelView截图。当时做的比较着急，从stackoverflow上面抄了如下一段代码，并且可以正常运行。代码如下：
```objc
UIImage* image = nil;
UIGraphicsBeginImageContext(_scrollView.contentSize);
{
	CGPoint savedContentOffset = _scrollView.contentOffset;
	CGRect savedFrame = _scrollView.frame;

	_scrollView.contentOffset = CGPointZero;
	_scrollView.frame = CGRectMake(0, 0, _scrollView.contentSize.width, _scrollView.contentSize.height);

	[_scrollView.layer renderInContext: UIGraphicsGetCurrentContext()];     
	image = UIGraphicsGetImageFromCurrentImageContext();

	_scrollView.contentOffset = savedContentOffset;
	_scrollView.frame = savedFrame;
}
UIGraphicsEndImageContext();
```
最近发版，QA同学在iOS13的手机上面测试，发现这个方法截图只能截到TableView高度的图，没有截到TableView全部的图。于是仔细看了一下截图的代码，发现原理是把TableView的frame改为和TableView的containerSize相同后，再去截图，但是在iOS13上面不好用。经过各种尝试，发现可以通过创建一个和TableView大小相同的临时view，然后把TableView添加到这个临时view，然后再对这个临时view进行截图，就可以再iOS13上面截到完整的图了。代码如下：
```
- (UIImage *)getTableViewImageWithTabelview:(UITableView *)tableview{
    UIImage* viewImage = nil;
    UITableView *scrollView = tableview;
    UIGraphicsBeginImageContextWithOptions(scrollView.contentSize, NO, 0.0);
    {
		// 保存原来的偏移量
        CGPoint savedContentOffset = scrollView.contentOffset;
        // CGPoint savedFrame = scrollView.frame;

		// 设置截图需要的偏移量和frame
        scrollView.contentOffset = CGPointZero;
        scrollView.frame = CGRectMake(0, 0, scrollView.contentSize.width, scrollView.contentSize.height);
        
		// 创建临时view，并且把要截图的view添加到临时view上面
        UIView *tempView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, scrollView.contentSize.width, scrollView.contentSize.height)];
        [scrollView removeFromSuperview];
        [tempView addSubview:scrollView];
        
		// 对临时view进行截图
        [tempView.layer renderInContext:UIGraphicsGetCurrentContext()];
        viewImage = UIGraphicsGetImageFromCurrentImageContext();
        
		// 恢复截图view原来的状态
        [scrollView removeFromSuperview];
        [self addSubview:scrollView];
        scrollView.contentOffset = savedContentOffset;

		// 如果原来是frame布局，需要设置frame，如果是Auto layout需要再次进行Auto layout布局。
		// scrollView.frame = savedFrame;
        [scrollView mas_makeConstraints:^(MASConstraintMaker *make) 	{
            make.edges.equalTo(self);
        }];
    }
    UIGraphicsEndImageContext();
    
    return viewImage;
}
```
这里需要注意，如果原来TableView用的是Auto layout进行的布局，那么后面需要对TableView再次进行布局。不然的话，截图之后会发现TableView不见了。