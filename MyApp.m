//----------------------------------------------------------------------------------------
//	MyApp.m - NSApplication's delegate
//
//  Copyright Dominique Peretti, 2004 - 2008.
//	Copyright © Chris, 2008 - 2009.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "MyApp.h"
#import "GetEthernetAddrSample.h"
#import "RepositoriesController.h"
#import "SvnFileStatusToColourTransformer.h"
#import "SvnDateTransformer.h"
#import "ArrayCountTransformer.h"
#import "SvnFilePathTransformer.h"
#import "FilePathCleanUpTransformer.h"
#import "TrimNewLinesTransformer.h"
#import "CommonUtils.h"


// TO_DO: Add file "TaskStatusToColorTransformer.h"
@interface TaskStatusToColorTransformer : NSObject
{
}
@end


//----------------------------------------------------------------------------------------

static void
addTransform (Class itsClass, NSString* itsName)
{
	[NSValueTransformer setValueTransformer: [[[itsClass alloc] init] autorelease] forName: itsName];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation MyApp

#define	kUseOldParsingMethod	@"useOldParsingMethod"

//----------------------------------------------------------------------------------------

+ (MyApp*) myApp
{
	static id controller = nil;

	if (!controller)
	{
		controller = [NSApp delegate];
	}

	return controller;
}


//----------------------------------------------------------------------------------------

+ (void) initialize
{
	NSMutableDictionary* const dictionary = [NSMutableDictionary dictionary];
	NSData* svnFileStatusModifiedColor = [NSArchiver archivedDataWithRootObject: [NSColor blackColor]];
	NSData* svnFileStatusNewColor      = [NSArchiver archivedDataWithRootObject: [NSColor blueColor]];
	NSData* svnFileStatusMissingColor  = [NSArchiver archivedDataWithRootObject: [NSColor redColor]];

	[dictionary setObject:svnFileStatusModifiedColor forKey: @"svnFileStatusModifiedColor"];
	[dictionary setObject:svnFileStatusNewColor      forKey: @"svnFileStatusNewColor"];
	[dictionary setObject:svnFileStatusMissingColor  forKey: @"svnFileStatusMissingColor"];

	SInt32 response;
	if (Gestalt(gestaltSystemVersion, &response) != noErr)
		response = 0;
	[dictionary setObject: (response >= 0x1050) ? @"/usr/bin" : @"/usr/local/bin"
													  forKey: @"svnBinariesFolder"];
	[dictionary setObject: kNSTrue                    forKey: @"cacheSvnQueries"];
	[dictionary setObject: [NSNumber numberWithInt:0] forKey: @"defaultDiffApplication"];
	[dictionary setObject: @"%y-%d-%m %H:%M:%S"       forKey: @"dateformat"];

	// Working Copy
	[dictionary setObject: kNSTrue  forKey: @"addWorkingCopyOnCheckout"];
	[dictionary setObject: kNSFalse forKey: kUseOldParsingMethod];

	[dictionary setObject: kNSTrue  forKey: @"abbrevWCFilePaths"];
	[dictionary setObject: kNSTrue  forKey: @"expandWCTree"];
	[dictionary setObject: kNSFalse forKey: @"autoRefreshWC"];

	// Review & Commit
	id obj = [NSDictionary dictionaryWithObjectsAndKeys:
									@"Simple File List",                    @"name",
									@"Files:\n\t(<FILES>)\n\t(</FILES>)\n", @"body", nil];
	[dictionary setObject: [NSArray arrayWithObject: obj] forKey: @"msgTemplates"];
	[dictionary setObject: @"5"    forKey: @"diffContextLines"];
	[dictionary setObject: kNSTrue forKey: @"diffShowFunction"];
	[dictionary setObject: kNSTrue forKey: @"diffShowCharacters"];

	[dictionary setObject: [NSNumber numberWithInt: 99] forKey: @"loggingLevel"];

	[Preferences() registerDefaults: dictionary];
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues: dictionary];

	// Transformers																		// Used by:
	addTransform([SvnFileStatusToColourTransformer class],
												@"SvnFileStatusToColourTransformer");	// MyWorkingCopy
	addTransform([SvnDateTransformer class], @"SvnDateTransformer");					// MySvnLogView
	addTransform([ArrayCountTransformer class], @"ArrayCountTransformer");				// MySvnLogView
	addTransform([FilePathCleanUpTransformer class], @"FilePathCleanUpTransformer");	// FavoriteWorkingCopies
	addTransform([FilePathWorkingCopy class], @"FilePathWorkingCopy");					// FavoriteWorkingCopies
	addTransform([SvnFilePathTransformer class], @"lastPathComponent");					// SingleFileInspector
	addTransform([TrimNewLinesTransformer class], @"TrimNewLines");						// MySvnLogView (to filter author name)
	addTransform([TaskStatusToColorTransformer class], @"TaskStatusToColor");			// Activity Window in svnX.nib
}


//----------------------------------------------------------------------------------------

- (bool) checkSVNExistence: (bool) warn
{
	NSString* svnPath = GetPreference(@"svnBinariesFolder");
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* svnFilePath = [svnPath stringByAppendingPathComponent:@"svn"];
	bool exists = [fm fileExistsAtPath:svnFilePath];

	if (!exists && warn)
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Error: Unable to locate svn binary."
										 defaultButton:@"Open Preferences"
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:@"Make sure the svn binary is present at path:\n%C%@%C.\n\n"
														"Is a Subversion client installed?"
														" If so, make sure the path is correctly set in the preferences.",
														0x201C, svnPath, 0x201D];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];							 
		[preferencesWindow makeKeyAndOrderFront:self];
	}
	return exists;
}


//----------------------------------------------------------------------------------------

- (void) initUI: (NSNotification*) note
{
	#pragma unused(note)
	[repositoriesController showWindow];
	[favoriteWorkingCopies showWindow];
}


- (void) awakeFromNib
{
	[self checkSVNExistence:true];

	// Show the Repositories & Working Copies windows after ALL awakeFromNib calls
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(initUI:) name: @"initUI" object: self];
	[[NSNotificationQueue defaultQueue] enqueueNotification: [NSNotification notificationWithName: @"initUI" object: self]
										postingStyle:        NSPostWhenIdle]; 
}


//----------------------------------------------------------------------------------------

#if qDebug
- (IBAction) test: (id) sender
{
	#pragma unused(sender)
	dprintf("sender=%@", sender);
}
#endif


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	AppleScript Support
//----------------------------------------------------------------------------------------
// Compare a single file in a svnX window. Invoked from Applescript.

- (void)fileHistoryOpenSheetForItem:(NSString *)path
{
	[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
	[favoriteWorkingCopies fileHistoryOpenSheetForItem: path];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

- (IBAction) openPreferences: (id) sender
{
	#pragma unused(sender)
	[preferencesWindow makeKeyAndOrderFront: self];
}


//----------------------------------------------------------------------------------------

- (IBAction) closePreferences: (id) sender
{
	#pragma unused(sender)
	[preferencesWindow close];
}


- (BOOL) applicationShouldHandleReopen: (NSApplication*) theApplication
		 hasVisibleWindows:             (BOOL)           visibleWindows
{
	#pragma unused(theApplication)
	if (!visibleWindows)
	{
		[favoriteWorkingCopies showWindow];
	}

	return YES;
}


//----------------------------------------------------------------------------------------

- (BOOL) applicationShouldOpenUntitledFile: (NSApplication*) sender 
{
	#pragma unused(sender)
	return NO;
}


//----------------------------------------------------------------------------------------

- (BOOL) application: (NSApplication*) theApplication
		 openFile:    (NSString*)      filename
{
	#pragma unused(theApplication)
	[self fileHistoryOpenSheetForItem: filename];

	return YES;
}


//----------------------------------------------------------------------------------------

- (void) openRepository: (NSURL*) url user: (NSString*) user pass: (NSString*) pass
{
	[repositoriesController openRepositoryBrowser: [url absoluteString] title: [url absoluteString] user: user pass: pass];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Tasks management
//----------------------------------------------------------------------------------------
// called from MySvn class

- (void) newTaskWithDictionary: (NSMutableDictionary*) taskObj
{
	[tasksManager newTaskWithDictionary:taskObj];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Sparkle Plus delegate methods
//----------------------------------------------------------------------------------------

- (NSMutableArray*) updaterCustomizeProfileInfo: (NSMutableArray*) profileInfo
{
	NSString *MACAddress = [self getMACAddress];
	NSArray *profileDictObjs = [NSArray arrayWithObjects:@"MACAddr",@"MAC Address", MACAddress, MACAddress, nil];
	NSArray *profileDictKeys = [NSArray arrayWithObjects:@"key", @"visibleKey", @"value", @"visibleValue", nil];

	[profileInfo addObject: [NSDictionary dictionaryWithObjects: profileDictObjs forKeys: profileDictKeys]];

	//NSLog(@"%@", profileInfo);
	
	return profileInfo;
}


//----------------------------------------------------------------------------------------

- (NSString*) getMACAddress
{
	EnetData data[10];
	UInt32 entryCount = 10;
	MACAddress mac;

	int err = GetEthernetAddressInfo((EnetData*)&data, &entryCount);

	if ( err == noErr )
	{
		NSValue *value = [NSValue valueWithBytes:&data[0].macAddress objCType:@encode(MACAddress)];
		[value getValue:&mac];
		NSMutableString *s = [NSMutableString string];
		int i;
		
		for ( i=0; i<kIOEthernetAddressSize; i++ )
		{
			[s appendFormat:@"%02X", mac[i]];
		
			if(i < kIOEthernetAddressSize-1) [s appendString:@":"];
		}
		
		return s;
	}
	
	return @"";
}

@end	// MyApp


//----------------------------------------------------------------------------------------
// End of MyApp.m
