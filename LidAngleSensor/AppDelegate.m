//
//  AppDelegate.m
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//  Modified for background operation with system tray support.
//

#import "AppDelegate.h"
#import "StatusBarManager.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"[AppDelegate] Application did finish launching");
    
    // Hide the app from the dock (make it a background agent)
    NSLog(@"[AppDelegate] Setting activation policy to accessory");
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    
    // Initialize the status bar manager
    NSLog(@"[AppDelegate] Creating StatusBarManager");
    self.statusBarManager = [[StatusBarManager alloc] init];
    
    if (self.statusBarManager) {
        NSLog(@"[AppDelegate] StatusBarManager created successfully");
    } else {
        NSLog(@"[AppDelegate] ERROR: Failed to create StatusBarManager");
    }
    
    // Hide the main window if it exists (we don't want any windows)
    NSLog(@"[AppDelegate] Hiding any existing windows");
    for (NSWindow *window in [NSApp windows]) {
        [window orderOut:nil];
    }
    
    NSLog(@"[AppDelegate] Application launch completed");
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Cleanup is handled by StatusBarManager's dealloc
    self.statusBarManager = nil;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    // Don't show any windows when the app is reopened
    return NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    // Don't show any windows when the app becomes active
    for (NSWindow *window in [NSApp windows]) {
        [window orderOut:nil];
    }
}

@end
