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

#import "Download.h"


@implementation Download
@synthesize cacheDirectory;
@synthesize delegate;
@synthesize objectQueue;
@synthesize cacheMaxFiles;
-(id)init{
	self = [super init];
    if (self) {
		
		// create cache dir
		NSString *appName = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleName"];
		NSString *cacheDir = [NSHomeDirectory() stringByAppendingString:[NSString stringWithFormat:@"/Library/Caches/%@/", appName]] ;

		self.cacheDirectory = cacheDir;
		self.objectQueue = [NSMutableArray array];
		self.cacheMaxFiles = 3000;
		
		// create cache directory if it doesn't exist
		if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDirectory]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
		}

	}
	
	return self;
}

-(void)dealloc
{
	self.cacheDirectory = nil;
	self.delegate = nil;
	self.objectQueue = nil;
	

	[super dealloc];
}

// call this function on application launch if you want to clear cache
-(void)cacheClearer
{
	int numberOfFiles = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cacheDirectory error:nil] count];
	
	if (numberOfFiles > self.cacheMaxFiles)
	{
		NSFileManager* fm = [[[NSFileManager alloc] init] autorelease];
		NSDirectoryEnumerator* en = [fm enumeratorAtPath:self.cacheDirectory];    
		NSError* err = nil;
		BOOL res;
		
		NSString* file;
		while ((file = [en nextObject])) {
			res = [fm removeItemAtPath:[self.cacheDirectory stringByAppendingPathComponent:file] error:&err];
			if (!res && err) {
				NSLog(@"Couldn't delete cache: %@", err);
			}
		}
		
	}
}
// prepares object for processing
// @param NSString *url URL of the file to download
// @param DownloadType contentType In what form should the downloaded content be returned
// @param bool cache Should the content be cached?
// @param id reference Custom object (or nil) which can be used by delegate to identify origin of downloaded content
-(void)downloadURL:(NSString*)url ofType:(DownloadType)contentType postData:(id)postData cache:(bool)cache reference:(id)reference
{
	if (url == nil)
		return;
	
	NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
	
	[dict setObject:(reference!=nil?reference:[NSNull null]) forKey:@"reference"];
	[dict setObject:url forKey:@"url"];
	[dict setObject:[NSNumber numberWithInt: contentType] forKey:@"contentType"];
	[dict setObject:(postData!=nil?postData:@"") forKey:@"postData"];
	[dict setObject:[NSNumber numberWithInt:cache] forKey:@"cache"];
	
	[self addObjectInQueue:dict];
	
}

// add object in queue for download
-(void)addObjectInQueue:(NSMutableDictionary*)object
{
	[object retain];
	NSString *url = [object valueForKey:@"url"];
	BOOL cache = (BOOL)[[object valueForKey:@"cache"] intValue];
	NSString *filename = [Download returnFilenameForURL:url];
	
	// Object is already in cache. Don't add to queue, just skip to finish
	NSString *path = [self.cacheDirectory stringByAppendingString:filename];
	if (cache && [[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		NSString *data = [NSData dataWithContentsOfFile:path];
		[object setObject:data forKey:@"data"];
		[self sendObjectToDelegate:object];
		[object release];
		return;
	}
	// object is not in cache. download
	[self initiateDownload:object];
	[object release];
}



-(void)initiateDownload:(NSMutableDictionary*)object
{
	[object retain];
	NSString *url = [object valueForKey:@"url"];
	NSString *postData = [object valueForKey:@"postData"];
	NSURL *urlObject = [NSURL URLWithString:url];


	[self.objectQueue addObject:object];

	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:urlObject
														cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
														timeoutInterval:10];
	if (![postData isEqualToString:@""])
	{
		[request setHTTPMethod: @"POST"];
		[request setHTTPBody: [NSData dataWithBytes: [postData UTF8String] length: [postData lengthOfBytesUsingEncoding: NSUTF8StringEncoding]]];
	}
	
	//self.urlConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	// schedule in common loop, not only in event loop
	Download_Connection *urlConnection = [[Download_Connection alloc] initWithRequest:request delegate:self startImmediately:NO];
	urlConnection.referenceIndex = [self.objectQueue count]-1;
	[urlConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[urlConnection start];
	[urlConnection release];
	[object release];
}


// URL connection delegate
- (void)connection:(Download_Connection *)connection didReceiveData:(NSData *)data {

	
	NSMutableDictionary *object = [self.objectQueue objectAtIndex:connection.referenceIndex];
	NSMutableData *objectData = [object objectForKey:@"data" ];
	//DLog(@"Did receive some data with reference %@ for %d", [object objectForKey:@"reference"], connection.referenceIndex);
	
	if (!objectData)
		objectData = [NSMutableData dataWithData:data];
	
	else 
		[objectData appendData:data];
	
	[object setObject:objectData forKey:@"data"];
	[self.objectQueue replaceObjectAtIndex:connection.referenceIndex withObject:object];
}

- (void)connectionDidFinishLoading:(Download_Connection *)connection {
	[self retain]; //ensure that self isn't released in this method when the connection is finished with it.

	NSMutableDictionary *object = [self.objectQueue objectAtIndex:connection.referenceIndex];
	
	NSMutableData *data = [object valueForKey:@"data"];
	NSString *url = [object valueForKey:@"url"];
	BOOL cache = (BOOL)[[object valueForKey:@"cache"] intValue];
	NSString *filename = [Download returnFilenameForURL:url];
	
	// write cache
	if (cache)
	{
		NSString *path = [self.cacheDirectory stringByAppendingString:filename];
		NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
		
		if(handle == nil) {
			[[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
			handle = [NSFileHandle fileHandleForWritingAtPath:path];
		}
		
		
		[handle writeData:data];
		[handle closeFile];
	}

	[self sendObjectToDelegate:object];
    [self release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error 
{
	NSLog(@"URL connection failed %@",error);
	[self notifyDelegateAboutError:error];
}





// send the right form of object to the delegate
-(void)sendObjectToDelegate:(NSMutableDictionary*)object
{
	[object retain];
	DownloadType type = (DownloadType)[[object objectForKey:@"contentType"] intValue];
	NSData *data = [object objectForKey:@"data"];
	id reference = [object objectForKey:@"reference"];
	
	NSString *stringData;
	id parsedData;
	SBJsonParser *jParser;

	switch (type)
	{
		case DownloadTypeJSON:
			jParser =  [[[SBJsonParser alloc] init] autorelease];
			stringData = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
			parsedData = [jParser objectWithString:stringData];
			
			if (self.delegate)
				[self.delegate  downloadReady:parsedData forReference:reference];
			break;
					
		case DownloadTypeImage:
			parsedData = [[[UIImage alloc] initWithData:data] autorelease];
			if (self.delegate)
				[self.delegate  downloadReady:parsedData forReference:reference];
			break;
			
		case DownloadTypeString:
			stringData = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
			if (self.delegate)
				[self.delegate  downloadReady:stringData forReference:reference];

			break;
	}
	[object release];
	
}
-(void)notifyDelegateAboutError:(NSError*)error
{
	if (self.delegate)
		[self.delegate downloadFailed:error];
}

+(NSString*)returnFilenameForURL:(NSString*)url 
{
	url = [url stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	return url;
}
@end

