//
// Created by wangyang on 2017/4/14.
// Copyright (c) 2017 wangyang. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LocalNFTMarkerData;
@interface LocalNFTMarkerManager : NSObject
+ (NSArray *)loadNFTMarkers;
+ (void)removeMarker:(LocalNFTMarkerData *)data;
@end
