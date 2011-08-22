/*
 Copyright (C) 2011 Matej Balantič. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 * Neither the name of the author nor the names of its contributors may be used
 to endorse or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 
 // EXAMPLE USAGE: 
 
 - (id)init
 {
	self = [super init];
	if (self) 
	{
		self.download = [[Download alloc] init];
		self.download.delegate = self;
	}
 
	return self; 
 }
 
 - (void)dealloc
 {
	[self.download release];
	self.download = nil;
 
	[super dealloc];
 }
 
 - (void)viewDidLoad
 {
	NSString *url1= @"http://www.google.com/calendar/feeds/developer-calendar@google.com/public/full?alt=json-in-script&callback=insertAgenda&orderby=starttime&max-results=15&singleevents=true&sortorder=ascending&futureevents=true";
	NSString *postData1 = @"variable1=test&variable2=test2";
	[self.download downloadURL:url1 ofType:DownloadTypeJSON postData:postData1 cache:YES reference:[NSDictionary  dictionaryWithObject:@"theXML" forKey:@"type"]];
 
	NSString *url2= @"http://google.com/ping";
	[self.download downloadURL:url2 ofType:DownloadTypeString postData:nil cache:NO reference:[NSDictionary  dictionaryWithObject:@"theSTRING" forKey:@"type"]];
 }
 
 
 #pragma mark -
 #pragma mark WEB responses
 
 -(void)downloadReady:(id)object forReference:(id)reference
 {
	[object retain];
	[reference retain];
 
 
	if ([[reference valueForKey:@"type"] isEqualToString:@"theXML"])
	{		
		NSLog(@"This is our JSON object %@", object);
	}
 
	else if ([[reference valueForKey:@"type"] isEqualToString:@"theSTRING"])
	{
		NSLog(@"This is our STRING object %@", object);
	}
 
	[object release];
	[reference release];
 
 }
 -(void)downloadFailed:(id)reference
 {
	NSLog(@"Download failed with error");
 }
 */


#import <Foundation/Foundation.h>
#import "Download+Connection.h"
#import "JSON.h"

@protocol DownloadDelegate;

typedef enum {
    DownloadTypeJSON,
	DownloadTypeImage,
	DownloadTypeString

} DownloadType;


@interface Download : NSObject
{
	
}
@property (nonatomic, retain) NSString *cacheDirectory;
@property (nonatomic) int cacheMaxFiles;

@property (nonatomic, retain) NSMutableArray *objectQueue;
@property (nonatomic, assign) id <DownloadDelegate> delegate;
-(id)init;
-(void)downloadURL:(NSString*)url ofType:(DownloadType)contentType postData:(NSString*)postData cache:(bool)cache reference:(id)reference;
-(void)addObjectInQueue:(NSMutableDictionary*)object;
-(void)sendObjectToDelegate:(NSMutableDictionary*)object;
-(void)notifyDelegateAboutError:(NSError*)error;
-(void)initiateDownload:(NSMutableDictionary*)object;
-(void)cacheClearer;
+(NSString*)returnFilenameForURL:(NSString*)url;

@end

@protocol DownloadDelegate

@required
-(void)downloadReady:(id)object forReference:(id)reference;
-(void)downloadFailed:(id)reference;
@end
