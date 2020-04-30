//
//  AppDelegate.h
//  IOSObjCWebSockets
//
//  Created by Eamon White on 4/25/20.
//  Copyright © 2020 Eamon White. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "ViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

