//
//  AppDelegate.h
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import <Cocoa/Cocoa.h>

@class StatusBarManager;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) StatusBarManager *statusBarManager;

@end
